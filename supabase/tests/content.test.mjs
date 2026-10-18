import test from 'node:test';
import assert from 'node:assert/strict';
import {allowedIdentity,contentHandler,validateRequest,providerBody,extractSuggestion,verifiedCharge,RESERVE_MICRO_USD} from '../functions/_shared/content.mjs';
const requestData=(task='example')=>{
  const h=Date.now().toString(16).padStart(12,'0');
  return {requestId:`${h.slice(0,8)}-${h.slice(8)}-7000-8000-000000000001`,task,
    targetLanguage:'fr',nativeLanguage:'de',targetText:'chat',nativeText:'Katze'};
};
const output=(value,extra={})=>({status:'completed',model:'gpt-6-luna',service_tier:'default',usage:{input_tokens:100,output_tokens:40},
  output:[{type:'message',role:'assistant',content:[{type:'output_text',text:JSON.stringify(value)}]}],...extra});
const example={targetText:'Le chat dort.',nativeText:'Die Katze schläft.'};
const request=(data=requestData())=>new Request('https://local.test/piko-content',{method:'POST',headers:{Authorization:'Bearer synthetic'},body:JSON.stringify(data)});
test('before quality approval only an explicitly allowed verified anonymous evaluator can spend',()=>{
  const id='00000000-0000-4000-8000-000000000001',user={id,is_anonymous:true};
  assert.equal(allowedIdentity(user,false,new Set()),null);
  assert.equal(allowedIdentity(user,false,new Set([id])),id);
  assert.equal(allowedIdentity(user,true,new Set()),id);
  assert.equal(allowedIdentity({...user,is_anonymous:false},true,new Set([id])),null);
  assert.equal(allowedIdentity({id:'forged',is_anonymous:true},true,new Set()),null);
});
test('strict six-field contract, language/type/bounds/time checks reject extras before any provider call',()=>{
  const valid=requestData(); assert.deepEqual(validateRequest(valid),valid);
  for(const extra of [{collectionId:'private'},{targetLanguage:'zz'},{nativeLanguage:'fr'},
    {task:'translate'},{targetText:''},{nativeText:'a'.repeat(13000)}])
    assert.throws(()=>validateRequest({...requestData(),...extra}));
  assert.throws(()=>validateRequest(requestData(),Date.now()+3600000));
});
test('fixed structured provider tasks have no tools/reasoning/store or existing content',()=>{
  for(const task of ['example','hint']){
    const body=providerBody(requestData(task));
    assert.equal(body.model,'gpt-6-luna');assert.equal(body.store,false);
    assert.deepEqual(body.tools,[]);assert.deepEqual(body.reasoning,{effort:'none'});
    assert.equal(body.service_tier,'default');assert.equal(body.text.format.strict,true);
    assert.equal(body.max_output_tokens,768);
    assert.deepEqual(Object.keys(JSON.parse(body.input)).sort(),['nativeLanguage','nativeText','targetLanguage','targetText']);
  }
});
test('malformed/refused/incomplete/overlong results cannot partially apply',()=>{
  assert.deepEqual(extractSuggestion(output(example),requestData()).example,example);
  for(const data of [output({targetText:'only'}),output({...example,nativeText:''}),
    output({...example,targetText:'x'.repeat(1001)}),output(example,{status:'incomplete'}),
    output(example,{output:[{type:'message',role:'assistant',content:[{type:'refusal',refusal:'no'}]}]})])
    assert.throws(()=>extractSuggestion(data,requestData()));
  assert.equal(extractSuggestion(output({hint:'Ein Haustier.'}),requestData('hint')).hint,'Ein Haustier.');
});
test('conservative cost bound includes full model context; unverifiable usage cannot release reservation',()=>{
  assert.equal(verifiedCharge(output(example)),45);
  assert.ok(RESERVE_MICRO_USD>=verifiedCharge(output(example,{usage:{input_tokens:1050000,output_tokens:768}})));
  for(const extra of [{service_tier:'priority'},{model:'other'},{usage:null},
    {usage:{input_tokens:1,output_tokens:769}},{usage:{input_tokens:-1,output_tokens:1}}])
    assert.equal(verifiedCharge(output(example,extra)),null);
});
test('service, authentication and atomic admission gates prevent provider use',async()=>{
  for(const gate of ['disabled','unauthorized','busy','duplicate','day_limit','minute_limit','budget_limit','unavailable']){
    let calls=0,finishes=0;
    const handler=contentHandler({enabled:gate!=='disabled',authenticate:async()=>gate==='unauthorized'?null:'user',
      admit:async()=>gate,provider:async()=>{calls++;},finish:async()=>{finishes++;}});
    const result=await handler(request()); assert.ok(result.status>=400);
    assert.equal(calls,0);assert.equal(finishes,0);
  }
});
test('success, paid malformed failure and uncertain timeout settle once without automatic retry',async()=>{
  for(const scenario of ['success','malformed','timeout']){
    const finishes=[];let calls=0;
    const handler=contentHandler({enabled:true,authenticate:async()=> 'user',
      admit:async(_user,_id,reserve)=>{assert.equal(reserve,RESERVE_MICRO_USD);return 'admitted';},
      provider:async()=>{calls++;if(scenario==='timeout') throw Error('synthetic');return output(scenario==='malformed'?{bad:'response'}:example);},
      finish:async(...args)=>{finishes.push(args);}});
    const result=await handler(request()); assert.equal(result.status,scenario==='success'?200:502);
    assert.equal(calls,1);assert.equal(finishes.length,1);
    assert.equal(finishes[0][2],scenario==='success'?'success':scenario==='malformed'?'failed':'uncertain');
    assert.equal(finishes[0][3],scenario==='timeout'?null:45);
    if(scenario==='success') assert.deepEqual((await result.json()).example,example);
  }
});
test('oversized chunked body never reaches authentication or admission',async()=>{
  let calls=0;
  const handler=contentHandler({enabled:true,authenticate:async()=>{calls++;},admit:async()=>{calls++;}});
  const result=await handler(request({...requestData(),targetText:'a'.repeat(20000)}));
  assert.equal(result.status,400);assert.equal(calls,0);
});
