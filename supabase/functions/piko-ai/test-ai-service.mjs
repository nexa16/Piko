import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {createAiHandler,AiServiceError} from './ai-service.mjs';
const owner='00000000-0000-4000-8000-000000000001';
const base='https://synthetic.supabase.co/functions/v1/piko-ai';
function input(){return {requestId:randomUUID(),issuedAt:new Date().toISOString(),action:'generate',scope:'ordinary',goal:'Hotel B1',allowNewGroups:true,allowNewValues:true,
 context:{targetLanguage:'en',nativeLanguage:'de',groups:[],entries:[]}};}
function output(id){return {requestId:id,complete:true,processedIds:[],groups:[],values:[],cards:[{id:'new-1',target:'to learn',native:'lernen',hint:null,
 examples:[{target:'I learn French.','native':'Ich lerne Französisch.'}],assignments:[],reason:'Independent lexical verb'}],edits:[],limitations:[]};}
function completed(id,answer=output(id)){return {id:'resp_synthetic',status:'completed',incomplete_details:null,usage:{input_tokens:1000,output_tokens:1000},output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(answer)}]}]};}
function fixture({enabled=true,authorized=true,deny=null,providerError=false,providerMode='queued'}={}){
 const receipts=new Map(),calls=[],rpcs=[];let authentications=0,paid=0,currentId;
 const handler=createAiHandler({enabled,providerKey:'synthetic-server-only-key',authenticate:async token=>{authentications++;return authorized&&token==='synthetic-owner'?owner:null;},
  rpc:async(name,args)=>{rpcs.push({name,args});
   if(deny)throw new AiServiceError(deny);
   if(name==='piko_ai_admit'){
    currentId=args.p_request_id;const old=receipts.get(currentId);
    if(old){if(old.hash!==args.p_hash)throw new AiServiceError('replay');return {new:false,status:'started',responseId:old.responseId,cardCeiling:old.ceiling};}
    const receipt={hash:args.p_hash,responseId:null,ceiling:(args.p_scope==='comprehensiveLevel'?1000:200)-(args.p_prior_cards??0)};receipts.set(currentId,receipt);return {new:true,maxOutputTokens:32000,cardCeiling:receipt.ceiling};
   }
   if(name==='piko_ai_attach'){receipts.get(args.p_request_id).responseId=args.p_response_id;return null;}
   if(name==='piko_ai_status'){
    const receipt=receipts.get(args.p_request_id);if(!receipt||receipt.hash!==args.p_hash)throw new AiServiceError('expired');currentId=args.p_request_id;
    return {status:'started',responseId:receipt.responseId,cardCeiling:receipt.ceiling};
   }
   if(name==='piko_ai_settle')return null;
   throw Error('Unexpected RPC');
  },fetchImpl:async(url,options)=>{
   calls.push({url,options});if(options.method==='POST')paid++;
   if(providerError)throw Error('SYNTHETIC_SECRET_DO_NOT_ECHO');
   if(options.method==='POST'&&providerMode==='queued')return Response.json({id:'resp_synthetic',status:'queued'});
   if(typeof providerMode==='function')return Response.json(providerMode(currentId));
   return Response.json(completed(currentId));
  }});
 const send=(v,token='synthetic-owner')=>handler(new Request(base,{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(v)}));
 const poll=(id,hash)=>handler(new Request(base+'?requestId='+id,{headers:{Authorization:'Bearer synthetic-owner','X-Piko-Request-Digest':hash}}));
 return {handler,send,poll,receipts,calls,rpcs,get paid(){return paid;},get authentications(){return authentications;}};
}
test('default disabled and forged access never reach admission/provider',async()=>{
 const off=fixture({enabled:false});assert.equal((await off.send(input())).status,503);assert.equal(off.authentications,0);assert.equal(off.paid,0);
 const forged=fixture();assert.equal((await forged.send(input(),'forged')).status,403);assert.equal(forged.rpcs.length,0);assert.equal(forged.paid,0);
});
test('server owner/quota denial occurs before a paid attempt',async()=>{
 for(const [code,status]of [['access_denied',403],['limit',429]]){const f=fixture({deny:code});assert.equal((await f.send(input())).status,status);assert.equal(f.paid,0);}
});
test('one fixed Sol low/background/store-false call follows full-context reservation, with no quantity/tool override',async()=>{
 const f=fixture(),v=input(),response=await f.send(v);assert.equal(response.status,202);assert.equal(f.paid,1);
 const body=JSON.parse(f.calls[0].options.body);assert.equal(body.model,'gpt-6.1-sol');assert.equal(body.reasoning.effort,'low');assert.equal(body.store,false);assert.equal(body.background,true);assert.equal(body.tools,undefined);
 assert.equal(body.text.format.strict,true);assert.equal(body.text.format.schema.properties.cards.maxItems,undefined);
 const context=JSON.parse(body.input[0].content);assert.equal(context.issuedAt,undefined);assert.equal(context.goal,v.goal);
 assert.ok(f.rpcs.find(c=>c.name==='piko_ai_admit').args.p_input_bytes>JSON.stringify(v).length);
 assert.equal(response.headers.get('Cache-Control'),'no-store');
});
test('status polling and duplicate POST retrieve the same owned response without another generation',async()=>{
 const f=fixture(),v=input(),started=await (await f.send(v)).json();assert.match(started.requestDigest,/^[a-f0-9]{64}$/);
 const polled=await f.poll(v.requestId,started.requestDigest);assert.equal(polled.status,200);assert.equal((await polled.json()).cards.length,1);assert.equal(f.paid,1);
 const duplicate=await f.send(v);assert.equal(duplicate.status,200);assert.equal(f.paid,1);assert.equal(f.calls.filter(c=>c.options.method==='GET').length,2);
});
test('uncertain provider attempt stays reserved; no automatic or duplicate paid retry',async()=>{
 const f=fixture({providerError:true}),v=input();assert.equal((await f.send(v)).status,503);assert.equal(f.paid,1);
 assert.equal((await f.send(v)).status,503);assert.equal(f.paid,1);assert.equal(f.receipts.size,1);assert.equal(f.rpcs.filter(c=>c.name==='piko_ai_settle').length,0);
});
test('model overrides, learning payload and complete-context overflow are rejected before admission',async()=>{
 const f=fixture();const model=input();model.model='unselected';assert.equal((await f.send(model)).status,400);
 const learning=input();learning.context.entries=[{id:'x',target:'one',native:'eins',hint:null,assignments:{},history:[]}];assert.equal((await f.send(learning)).status,400);
 const huge=input();huge.goal='x'.repeat(200000);assert.equal((await f.send(huge)).status,413);assert.equal(f.paid,0);assert.equal(f.rpcs.length,0);
});
test('refusal, incomplete, malformed schema and missing usage never become applicable content',async()=>{
 const modes=[
  id=>({...completed(id),output:[{type:'message',content:[{type:'refusal',refusal:'No'}]}]}),
  id=>({...completed(id),status:'incomplete',incomplete_details:{reason:'max_output_tokens'}}),
  id=>{const answer=output(id);answer.cards[0].examples=[];return completed(id,answer);},
  id=>({...completed(id),usage:null}),
 ];
 for(const providerMode of modes){const f=fixture({providerMode}),r=await f.send(input());assert.ok([422,503].includes(r.status));assert.equal((await r.json()).cards,undefined);assert.equal(f.paid,1);}
});
test('technical 200/1000 admission ceilings are enforced outside the model task',async()=>{
 const providerMode=id=>{const answer=output(id);answer.cards=Array.from({length:201},(_,i)=>({...answer.cards[0],id:'card-'+i}));return completed(id,answer);};
 const ordinary=fixture({providerMode});assert.equal((await ordinary.send(input())).status,422);
 const broad=fixture({providerMode}),v=input();v.scope='comprehensiveLevel';assert.equal((await broad.send(v)).status,200);
});
test('RPC metadata contains no lexical context; wrong receipt digest cannot poll another operation',async()=>{
 const f=fixture(),v=input();await f.send(v);const serialized=JSON.stringify(f.rpcs);assert.ok(!serialized.includes('Hotel'));assert.ok(!serialized.includes('lernen'));
 assert.equal((await f.poll(v.requestId,'b'.repeat(64))).status,410);assert.equal(f.paid,1);
});
test('provider/raw exception details are never echoed into client diagnostics',async()=>{
 const f=fixture({providerError:true}),response=await f.send(input()),body=await response.text();assert.equal(response.status,503);assert.ok(!body.includes('SYNTHETIC_SECRET'));assert.equal(body,'{"code":"unavailable"}');
});

test('continuation keeps prior proposals in model context and limits the remaining result outside the prompt',async()=>{
 const f=fixture({providerMode:'completed'}),v=input();
 const previous=output(randomUUID());previous.complete=false;previous.cards=Array.from({length:199},(_,i)=>({...previous.cards[0],id:'prior-'+i}));
 v.previous=previous;
 const r=await f.send(v);
 assert.equal(r.status,200);
 assert.equal(f.paid,1);
 const sent=JSON.parse(f.calls[0].options.body);
 assert.equal(JSON.parse(sent.input[0].content).previous.cards.length,199);
 assert.equal(f.rpcs.find(c=>c.name==='piko_ai_admit').args.p_prior_cards,199);
 assert.equal(JSON.stringify(sent).includes('cardCeiling'),false);
 const g=fixture(),bad=input();bad.previous={...previous,complete:true};
 assert.equal((await g.send(bad)).status,400);assert.equal(g.paid,0);
});
