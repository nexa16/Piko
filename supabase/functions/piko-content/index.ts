import { allowedIdentity, boundedJson, contentHandler } from '../_shared/content.mjs';

const url=Deno.env.get('SUPABASE_URL')??'';
const publicKey=Deno.env.get('PIKO_PUBLISHABLE_KEY')??'';
const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??'';
const providerKey=Deno.env.get('OPENAI_API_KEY')??'';
const qualityApproved=Deno.env.get('PIKO_AI_QUALITY_APPROVED')==='true';
const evaluationIdentities=new Set((Deno.env.get('PIKO_AI_EVAL_IDENTITIES')??'').split(',').filter(Boolean));
const enabled=Deno.env.get('PIKO_AI_LIVE_APPROVED')==='true' &&
  /^https:\/\/[a-z0-9]+\.supabase\.co$/.test(url) && !!publicKey && !!serviceKey && !!providerKey;
const headers={'content-type':'application/json',apikey:serviceKey,Authorization:`Bearer ${serviceKey}`};
async function rpc(name:string,body:object) {
  const response=await fetch(`${url}/rest/v1/rpc/${name}`,{method:'POST',headers,
    body:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(10000)});
  if(!response.ok) throw Error('accounting');
  return response.status===204?null:await response.json();
}
Deno.serve(contentHandler({enabled,
  authenticate:async (authorization:string|null)=>{
    if(!authorization?.startsWith('Bearer ') || authorization.length>16384) return null;
    const response=await fetch(`${url}/auth/v1/user`,{headers:{apikey:publicKey,Authorization:authorization},
      redirect:'error',signal:AbortSignal.timeout(10000)});
    if(!response.ok) return null;
    const user=await response.json();
    return allowedIdentity(user,qualityApproved,evaluationIdentities);
  },
  admit:(identity:string,id:string,reserve:number)=>rpc('piko_ai_admit',{
    p_identity:identity,p_request:id,p_reserve:reserve}),
  provider:async(body:object)=>{
    const response=await fetch('https://api.openai.com/v1/responses',{method:'POST',
      headers:{'content-type':'application/json',Authorization:`Bearer ${providerKey}`},
      body:JSON.stringify(body),redirect:'error',signal:AbortSignal.timeout(25000)});
    if(!response.ok) throw Error('provider');
    return await boundedJson(response,65536);
  },
  finish:(identity:string,id:string,outcome:string,actual:number|null)=>rpc('piko_ai_finish',{
    p_identity:identity,p_request:id,p_outcome:outcome,p_actual:actual}),
}));
