import {modelBody,validateInput,validOutputEnvelope} from './ai-protocol.mjs';
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const api='https://api.openai.com/v1/responses';
const maxBytes=192000,maxResponseBytes=2000000;
const json=(status,body)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json','Cache-Control':'no-store'}});
export class AiServiceError extends Error{
 constructor(code){super(code);this.code=code;}
}
function errorStatus(code){return ({access_denied:403,limit:429,expired:410,replay:409,invalid_request:400,context_limit:413,invalid_response:422})[code]??503;}
async function readBytes(stream,limit,code='context_limit'){
 const parts=[];let length=0;
 if(!stream)throw new AiServiceError(code==='context_limit'?'invalid_request':code);
 for await(const part of stream){length+=part.byteLength;if(length>limit)throw new AiServiceError(code);parts.push(part);}
 const all=new Uint8Array(length);let offset=0;for(const part of parts){all.set(part,offset);offset+=part.byteLength;}return all;
}
async function decoded(response,limit=maxResponseBytes){
 const bytes=await readBytes(response.body,limit,'invalid_response');
 try{return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{throw new AiServiceError('invalid_response');}
}
async function digest(bytes){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');}

/** All storage access is a privileged server adapter. It persists only metadata.
 * Missing config fails closed. One POST is one paid attempt; GET only polls that
 * exact owned provider response. Unknown POST outcomes never cause a retry. */
export function createAiHandler({enabled=false,providerKey,authenticate,rpc,fetchImpl=fetch}){
 async function provider(path,body){
   const response=await fetchImpl(path,{method:body?'POST':'GET',redirect:'error',
     headers:{Authorization:'Bearer '+providerKey,'Content-Type':'application/json'},
     ...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(25000)});
   if(!response.ok)throw new AiServiceError(response.status===429?'limit':'unavailable');
   return decoded(response);
 }
 async function result(response,requestId,userId,hash,cardCeiling){
   if(['queued','in_progress'].includes(response.status))return json(202,{requestId,state:'pending',requestDigest:hash});
   const usage=response.usage;
   if(usage&&Number.isInteger(usage.input_tokens)&&Number.isInteger(usage.output_tokens)&&usage.input_tokens>=0&&usage.output_tokens>=0){
     await rpc('piko_ai_settle',{p_user_id:userId,p_request_id:requestId,p_input_tokens:usage.input_tokens,p_output_tokens:usage.output_tokens});
   }else throw new AiServiceError('unavailable'); // retain conservative reservation
   if(response.status!=='completed'||response.incomplete_details)throw new AiServiceError('invalid_response');
   const output=[];
   for(const message of response.output??[]){
     if(message.type==='message')for(const content of message.content??[]){
       if(content.type==='refusal')throw new AiServiceError('invalid_response');
       if(content.type==='output_text')output.push(content.text);
     }
   }
   let parsed;try{parsed=JSON.parse(output.join(''));}catch{throw new AiServiceError('invalid_response');}
   if(!validOutputEnvelope(parsed,requestId)||(!Number.isInteger(cardCeiling)||cardCeiling<1||cardCeiling>1000)||parsed.cards.length>cardCeiling)throw new AiServiceError('invalid_response');
   return json(200,parsed);
 }
 return async function handler(req){
   try{
     if(!enabled||!providerKey||!authenticate||!rpc)throw new AiServiceError('unavailable');
     if(!['POST','GET'].includes(req.method))return json(405,{code:'invalid_request'});
     const authorization=req.headers.get('Authorization')??'';
     if(!authorization.startsWith('Bearer ')||authorization.length>16000)throw new AiServiceError('access_denied');
     const userId=await authenticate(authorization.slice(7));if(!uuid.test(userId??''))throw new AiServiceError('access_denied');
     const url=new URL(req.url);
     if(req.method==='GET'){
       const requestId=url.searchParams.get('requestId'),hash=req.headers.get('X-Piko-Request-Digest');
       if(!uuid.test(requestId??'')||!/^[a-f0-9]{64}$/.test(hash??'')||url.searchParams.size!==1)throw new AiServiceError('invalid_request');
       const status=await rpc('piko_ai_status',{p_user_id:userId,p_request_id:requestId,p_hash:hash});
       if(!/^resp_[a-zA-Z0-9_-]+$/.test(status?.responseId??''))throw new AiServiceError('unavailable');
       return await result(await provider(api+'/'+encodeURIComponent(status.responseId)),requestId,userId,hash,status.cardCeiling);
     }
     if(url.search)throw new AiServiceError('invalid_request');
     const bytes=await readBytes(req.body,maxBytes);let input;
     try{input=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{throw new AiServiceError('invalid_request');}
     if(!validateInput(input))throw new AiServiceError('invalid_request');
     const hash=await digest(bytes);
     // The configured output ceiling is returned by the atomic admission RPC.
     // Measure the full system/schema/user payload before reserving any spend.
     const measured=new TextEncoder().encode(JSON.stringify(modelBody(input,128000))).byteLength;
     if(measured>maxBytes)throw new AiServiceError('context_limit');
     const admitted=await rpc('piko_ai_admit',{p_user_id:userId,p_request_id:input.requestId,
       p_issued_at:input.issuedAt,p_hash:hash,p_action:input.action,p_input_bytes:measured,p_scope:input.scope,p_prior_cards:input.previous?.cards.length??0});
     if(!admitted?.new){
       if(!/^resp_[a-zA-Z0-9_-]+$/.test(admitted?.responseId??''))throw new AiServiceError('unavailable');
       return await result(await provider(api+'/'+encodeURIComponent(admitted.responseId)),input.requestId,userId,hash,admitted.cardCeiling);
     }
     if(!Number.isInteger(admitted.maxOutputTokens)||admitted.maxOutputTokens<1||admitted.maxOutputTokens>128000)throw new AiServiceError('unavailable');
     const response=await provider(api,modelBody(input,admitted.maxOutputTokens));
     if(!/^resp_[a-zA-Z0-9_-]+$/.test(response.id??''))throw new AiServiceError('invalid_response');
     await rpc('piko_ai_attach',{p_user_id:userId,p_request_id:input.requestId,p_response_id:response.id});
     return await result(response,input.requestId,userId,hash,admitted.cardCeiling);
   }catch(error){
     const code=error instanceof AiServiceError?error.code:'unavailable';
     return json(errorStatus(code),{code});
   }
 };
}
