import {modelBody,validateInput,validOutputEnvelope} from './ai-protocol.mjs';
import {AiServiceError} from './ai-service.mjs';

const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const digestPattern=/^[a-f0-9]{64}$/;
const encoder=new TextEncoder();
const api='https://api.openai.com/v1/responses';
const bytes=v=>encoder.encode(JSON.stringify(v)).byteLength;
const json=(status,body)=>Response.json(body,{status,headers:{'Cache-Control':'no-store'}});
const fail=(code,details={})=>{throw Object.assign(new AiServiceError(code),{details});};
export function canonical(value){
 if(Array.isArray(value))return value.map(canonical);
 if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])]));
 return value;
}
export async function textHash(value){return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(value))),x=>x.toString(16).padStart(2,'0')).join('');}
export async function snapshotHash(value){return textHash(JSON.stringify(canonical(value)));}
const exact=(v,keys)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).every(k=>keys.includes(k));
const language=v=>typeof v==='string'?v:v?.name??v?.id;
const safeEntry=e=>({id:e.id,target:e.target,native:e.native,hint:e.hint,examples:e.examples,assignments:e.assignments});

export function reviewInput(manifest,entries,id){
 return {requestId:id,issuedAt:new Date().toISOString(),action:'review',scope:'ordinary',goal:'Review the frozen eligible Collection inventory.',
  allowNewGroups:manifest.allowNewGroups??true,allowNewValues:manifest.allowNewValues??true,
  options:Object.fromEntries(['level','goals','checks','categoryMode'].map(key=>[key,manifest.options?.[key]])),
  context:{targetLanguage:language(manifest.collection.targetLanguage),nativeLanguage:language(manifest.collection.nativeLanguage),groups:manifest.groups,entries:entries.map(safeEntry)}};
}

export function validateManifest(m){
 if(!exact(m,['version','collection','options','entries','groups','allowNewGroups','allowNewValues'])||m.version!==1||
  !exact(m.collection,['id','name','targetLanguage','nativeLanguage','level'])||!uuid.test(m.collection.id??'')||typeof m.collection.name!=='string'||
  !Array.isArray(m.entries)||!m.entries.length||m.entries.length>10000||!Array.isArray(m.groups)||
  typeof m.allowNewGroups!=='boolean'||typeof m.allowNewValues!=='boolean')fail('invalid_request');
 const ids=m.entries.map(e=>e.id);
 if(ids.some(id=>!uuid.test(id))||new Set(ids).size!==ids.length||ids.some((id,i)=>i&&id<=ids[i-1]))fail('invalid_request');
 for(const e of m.entries){
  if(!exact(e,['id','target','native','hint','examples','assignments','active','hintVisibility'])||typeof e.active!=='boolean'||
    !['always','hidden'].includes(e.hintVisibility))fail('invalid_request');
 }
 if(!validateInput(reviewInput(m,m.entries,'00000000-0000-4000-8000-000000000001')))fail('invalid_request');
 return m;
}

/** Precompute a finite DAG. Every pair of inventory shards is compared: no
 * nearest-neighbour heuristic silently drops a cross-shard relation. */
export function planReview(m,config,{newId=()=>crypto.randomUUID()}={}){
 validateManifest(m);
 if(!Number.isInteger(config.maxOutputTokens)||config.maxOutputTokens<1||!Number.isInteger(config.maxInputBytes)||
  !(config.inputNanoUsd>0&&config.outputNanoUsd>0&&config.eurPerUsd>0))fail('unavailable');
 const plan=[],index=m.entries.map(e=>({...safeEntry(e),examples:[]}));
 const add=(entries,phase)=>{
  const requestId=newId(),input=reviewInput(m,entries,requestId),body=modelBody(input,config.maxOutputTokens);
  if(phase==='consistency')body.instructions+='\nCOLLECTION CONSISTENCY PHASE: all supplied entries are compact index records. Empty examples here mean omitted from this index, never missing examples. Compare every supplied meaning and category for duplicates, conflicting translations, overlapping senses and inconsistent classifications. Do not propose example edits or new vocabulary. Return processedIds for every supplied ID. Preserve distinct meanings; mark uncertainty unresolved.';
  const inputBytes=bytes(body);
  if(inputBytes>config.maxInputBytes)fail('context_limit',{limitType:'context',diagnosticCode:'review_step_context'});
  // UTF8 bytes are a deliberately conservative token upper bound. Framing and
  // output allowance are included; prices/FX come only from operator config.
  const reserveCents=Math.max(1,Math.ceil(((inputBytes+8192)*config.inputNanoUsd+config.maxOutputTokens*config.outputNanoUsd)*config.eurPerUsd/10000000));
  plan.push({requestId,phase,ids:entries.map(e=>e.id),input,body,inputBytes,reserveCents});
  if(plan.length>256)fail('context_limit',{limitType:'context',diagnosticCode:'review_plan_steps'});
 };
 let batch=[];
 for(const entry of m.entries){
  const candidate=[...batch,entry],probe=modelBody(reviewInput(m,candidate,'00000000-0000-4000-8000-000000000001'),config.maxOutputTokens);
  if(batch.length&&(candidate.length>50||bytes(probe)>config.maxInputBytes)){add(batch,'detail');batch=[];}
  batch.push(entry);
 }
 if(batch.length)add(batch,'detail');
 // Bound shards to half a context so *any* two fit together. This is a fixed
 // complete comparison plan, not free-form provider-chosen continuation.
 const shards=[];let shard=[];
 const fits=entries=>bytes(modelBody(reviewInput(m,entries,'00000000-0000-4000-8000-000000000001'),config.maxOutputTokens))+1024<=config.maxInputBytes;
 for(const entry of index){
  if(shard.length&&!fits([...shard,...shard,entry,entry])){shards.push(shard);shard=[];}
  if(!fits([entry,entry]))fail('context_limit',{limitType:'context',diagnosticCode:'review_index_entry'});
  shard.push(entry);
 }
 if(shard.length)shards.push(shard);
 for(let i=0;i<shards.length;i++){
  add(shards[i],'consistency');
  for(let j=i+1;j<shards.length;j++)add([...shards[i],...shards[j]],'consistency');
 }
 const maximumCostCents=plan.reduce((sum,s)=>sum+s.reserveCents,0);
 return {steps:plan,maximumCostCents,total:m.entries.length};
}

export function validateReviewResult(result,step){
 if(!validOutputEnvelope(result,step.requestId)||result.complete!==true||result.cards.length||
  result.processedIds.length!==step.ids.length||new Set(result.processedIds).size!==step.ids.length||
  result.processedIds.some(id=>!step.ids.includes(id)))fail('invalid_response',{diagnosticCode:'incomplete_review_step'});
 const fields={target:'translations',native:'translations',hint:'hints',examples:'examples',assignments:'categories'},seen=new Set(),proposalIds=new Set(step.ids);
 const groups=new Set(step.input.context.groups.map(g=>g.id)),values=new Set(step.input.context.groups.flatMap(g=>g.values.map(v=>v.id)));
 for(const id of [...groups,...values])proposalIds.add(id);
 const addId=id=>{if(proposalIds.has(id))fail('invalid_response');proposalIds.add(id);};
 if((!step.input.allowNewGroups&&result.groups.length)||(!step.input.allowNewValues&&result.values.length)||
  (!step.input.options.checks.includes('categories')&&(result.groups.length||result.values.length)))fail('invalid_response');
 for(const g of result.groups){addId(g.id);groups.add(g.id);}
 for(const v of result.values){addId(v.id);if(!groups.has(v.groupId))fail('invalid_response');values.add(v.id);}
 for(const edit of result.edits){
  addId(edit.id);
  const key=edit.entryId+'\0'+edit.field;
  if(!step.ids.includes(edit.entryId)||seen.has(key)||!step.input.options.checks.includes(fields[edit.field])||
    (step.phase==='consistency'&&edit.field==='examples')||(edit.outcome==='noHintNeeded'&&(edit.field!=='hint'||edit.value!==null)))fail('invalid_response');
  if(edit.outcome==='change'){
   if(['target','native','hint'].includes(edit.field)&&(typeof edit.value!=='string'||!edit.value.trim()))fail('invalid_response');
   if(edit.field==='examples'&&(!Array.isArray(edit.value)||!edit.value.length))fail('invalid_response');
   if(edit.field==='assignments'&&(!Array.isArray(edit.value)||edit.value.some(a=>!groups.has(a.groupId)||a.valueIds.some(v=>!values.has(v)))))fail('invalid_response');
  }
  seen.add(key);
 }
 return result;
}

export function aggregateReview(jobId,steps){
 const out={requestId:jobId,complete:true,processedIds:[],groups:[],values:[],cards:[],edits:[],limitations:[]},byField=new Map(),ids=new Set(),conflicts=[];
 const norm=name=>name.normalize('NFC').toLowerCase().replace(/\s+/gu,' ').trim();
 const groupAliases=new Map(),valueAliases=new Map(),groupsByName=new Map(),valuesByName=new Map(),ambiguous=new Set();
 const results=steps.map(step=>validateReviewResult(step.result,step));
 const originalGroups=steps[0]?.input.context.groups??[];
 for(const g of originalGroups){groupsByName.set(norm(g.name),{...g,saved:true,alternatives:[g]});for(const v of g.values)valuesByName.set(g.id+'\0'+norm(v.name),v);}
 // Definitions from independent steps form one shared namespace. Equivalent
 // names/modes use one proposal; an incompatible mode is never silently chosen.
 for(const [index,r] of results.entries())for(const g of r.groups){
  const key=norm(g.name),known=groupsByName.get(key),alias=index+'\0'+g.id;
  if(known){
   groupAliases.set(alias,known.id);known.alternatives.push(g);
   if(known.mode!==g.mode)ambiguous.add(known.id);
  }else{
   const group={...g,id:'job-'+index+'-'+g.id,alternatives:[g]};groupsByName.set(key,group);groupAliases.set(alias,group.id);
  }
 }
 for(const g of groupsByName.values()){
  if(ambiguous.has(g.id))conflicts.push({kind:'definition',name:g.name,alternatives:g.alternatives.map(x=>({value:{name:x.name,mode:x.mode},reason:x.reason??'Existing definition'}))});
  else if(!g.saved)out.groups.push({id:g.id,name:g.name,mode:g.mode,reason:g.reason});
 }
 for(const [index,r] of results.entries())for(const v of r.values){
  const groupId=groupAliases.get(index+'\0'+v.groupId)??v.groupId,key=groupId+'\0'+norm(v.name),known=valuesByName.get(key);
  if(known)valueAliases.set(index+'\0'+v.id,known.id);
  else{const value={...v,id:'job-'+index+'-'+v.id,groupId};valuesByName.set(key,value);valueAliases.set(index+'\0'+v.id,value.id);if(!ambiguous.has(groupId))out.values.push(value);}
 }
 for(const [index,step] of steps.entries()){
  const r=results[index];
  for(const id of r.processedIds)ids.add(id);
  for(const e of r.edits){
   const edit={...e,id:'job-'+index+'-'+e.id};
   if(e.field==='assignments'&&Array.isArray(e.value)){
    edit.value=e.value.map(a=>({groupId:groupAliases.get(index+'\0'+a.groupId)??a.groupId,valueIds:a.valueIds.map(v=>valueAliases.get(index+'\0'+v)??v)}));
    if(edit.value.some(a=>ambiguous.has(a.groupId))){edit.outcome='unresolved';edit.reason='Conflicting category definitions; no automatic correction.';}
   }
   const key=e.entryId+'\0'+e.field,prior=byField.get(key);
   if(!prior)byField.set(key,{edit,alternatives:[edit]});
   else if(!prior.alternatives.some(x=>JSON.stringify(canonical([x.outcome,x.value]))===JSON.stringify(canonical([edit.outcome,edit.value])))){
    prior.alternatives.push(edit);
    prior.edit={...prior.edit,outcome:'unresolved',reason:'Conflicting review steps; no automatic correction.',rule:'Cross-batch consistency'};
   }
  }
  out.limitations.push(...r.limitations);
 }
 for(const {edit,alternatives} of byField.values())if(alternatives.length>1)conflicts.push({entryId:edit.entryId,field:edit.field,alternatives:alternatives.map(x=>({value:x.value,outcome:x.outcome,reason:x.reason,rule:x.rule}))});
 out.processedIds=[...ids].sort();out.edits=[...byField.values()].map(v=>v.edit);out.limitations=[...new Set(out.limitations)];
 if(conflicts.length)out.limitations.push('Conflicting proposals remain unresolved and cannot be applied.');
 return {result:out,conflicts};
}

export function createReviewJobHandler({enabled=false,authenticate,rpc}){
 return async req=>{
  try{
   const url=new URL(req.url),action=url.searchParams.get('job');
   if((!enabled&&!['cancel','status','result','capabilities'].includes(action))||!authenticate||!rpc)fail('unavailable');
   const queryKeys=action==='result'?['job','jobId','installationId','part']:['job','jobId','installationId'];
   if(!['prepare','upload','start','status','resume','cancel','result','capabilities'].includes(action)||[...url.searchParams.keys()].some(k=>!queryKeys.includes(k)))fail('invalid_request');
   const read=['status','result','capabilities'].includes(action);
   if(req.method!==(read?'GET':'POST'))return json(405,{code:'invalid_request'});
   const auth=req.headers.get('Authorization')??'',userId=auth.startsWith('Bearer ')?await authenticate(auth.slice(7)):null;
   if(!uuid.test(userId??''))fail('access_denied');
   if(action==='capabilities'){
    const available=enabled&&(await rpc('piko_ai_review_capabilities',{p_user_id:userId}))?.reviewJobsAvailable===true;
    return json(200,{reviewJobProtocol:1,snapshotVersion:1,resultPartsVersion:1,reviewJobsAvailable:available});
   }
   const raw=read?'{}':await boundedText(req,210000),data=read?{installationId:url.searchParams.get('installationId')}:JSON.parse(raw),jobId=read?url.searchParams.get('jobId'):data.jobId;
   if(!uuid.test(jobId??''))fail('invalid_request');
   if(action==='prepare'){
    if(!digestPattern.test(data.snapshotDigest??'')||!Number.isSafeInteger(data.maxCostCents)||data.maxCostCents<1||
      !Array.isArray(data.scopeIds)||!data.scopeIds.length||data.scopeIds.length>10000||new Set(data.scopeIds).size!==data.scopeIds.length||data.scopeIds.some(id=>!uuid.test(id)))fail('invalid_request');
    const metadata={version:data.version,collection:data.collection,options:data.options,groups:data.groups,allowNewGroups:data.allowNewGroups??true,allowNewValues:data.allowNewValues??true};
    if(bytes(metadata)>120000)fail('context_limit');
    return json(200,await rpc('piko_ai_review_job',{p_user_id:userId,p_job_id:jobId,p_action:action,p_data:{...data,metadata}}));
   }
   if(action==='start'){
    const manifest=await rpc('piko_ai_review_job',{p_user_id:userId,p_job_id:jobId,p_action:'manifest',p_data:{installationId:data.installationId}});
    if(manifest.state!=='preparing')return json(200,manifest.status);
    const snapshot={...manifest.metadata,entries:manifest.entries};
    if(await snapshotHash(snapshot)!==manifest.snapshotDigest)fail('replay',{diagnosticCode:'snapshot_digest_mismatch'});
    const plan=planReview(snapshot,manifest.config);
    if(plan.maximumCostCents>manifest.maxCostCents)fail('limit',{limitType:'jobBudget',limitMaximum:manifest.maxCostCents,limitRemaining:manifest.maxCostCents,limitUnit:'cents',required:plan.maximumCostCents,diagnosticCode:'review_plan_budget'});
    return json(200,await rpc('piko_ai_review_job',{p_user_id:userId,p_job_id:jobId,p_action:'start',p_data:{installationId:data.installationId,snapshotDigest:manifest.snapshotDigest,pricing:manifest.config,steps:plan.steps,maximumCostCents:plan.maximumCostCents}}));
   }
   if(action==='upload'&&(!Number.isInteger(data.index)||data.index<0||!Array.isArray(data.entries)||data.entries.length>50||!data.entries.length||
    data.entries.some(e=>!exact(e,['id','target','native','hint','examples','assignments','active','hintVisibility'])||!uuid.test(e.id??''))))fail('invalid_request');
   if(action==='result'){
    const rawPart=url.searchParams.get('part')??'0';
    if(!/^(0|[1-9]\d*)$/.test(rawPart)||!Number.isSafeInteger(Number(rawPart)))fail('invalid_request');
    const result=await rpc('piko_ai_review_job',{p_user_id:userId,p_job_id:jobId,p_action:action,p_data:data}),serialized=JSON.stringify(result);
    const parts=Math.max(1,Math.ceil(serialized.length/200000)),part=Number(rawPart);
    if(part>=parts)fail('invalid_request');
    return json(200,{jobId,snapshotDigest:result.snapshotDigest,resultHash:await textHash(serialized),part,parts,content:serialized.slice(part*200000,(part+1)*200000)});
   }
   return json(200,await rpc('piko_ai_review_job',{p_user_id:userId,p_job_id:jobId,p_action:action,p_data:data}));
  }catch(error){
   const code=error instanceof AiServiceError?error.code:'invalid_request';
   return json(({access_denied:403,expired:410,replay:409,invalid_request:400,context_limit:413,limit:429,invalid_response:422})[code]??503,{code,...(error.details??{})});
  }
 };
}
async function boundedText(req,max){
 if(!req.body)fail('invalid_request');let length=0;const parts=[];
 for await(const part of req.body){length+=part.length;if(length>max)fail('context_limit');parts.push(part);}
 const all=new Uint8Array(length);let offset=0;for(const part of parts){all.set(part,offset);offset+=part.length;}
 return new TextDecoder('utf-8',{fatal:true}).decode(all);
}

/** Each invocation performs at most one POST or GET. A persisted dispatch
 * marker precedes POST: a crashed/uncertain attempt cannot be replayed. */
export function createReviewWorker({enabled=false,workerSecret,providerKey,rpc,fetchImpl=fetch}){
 return async req=>{
  if(req.method!=='POST'||!enabled||!workerSecret||!providerKey||req.headers.get('Authorization')!=='Bearer '+workerSecret)return json(403,{code:'access_denied'});
  let task,dispatchStarted=false,attached=false,responseKnownId;
  try{
   task=await rpc('piko_ai_review_claim',{});
   if(!task)return json(200,{state:'idle'});
   if(task.finalize){
    const combined=aggregateReview(task.jobId,task.steps);
    await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:null,p_token:task.token,p_event:'complete',p_data:combined});
    return json(200,{state:'completed'});
   }
   const post=!task.responseId;
   if(post){await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:'dispatch',p_data:{}});dispatchStarted=true;}
   let response;
   try{
    const fetched=await fetchImpl(post?api:api+'/'+encodeURIComponent(task.responseId),{method:post?'POST':'GET',redirect:'error',headers:{Authorization:'Bearer '+providerKey,'Content-Type':'application/json'},...(post?{body:JSON.stringify(task.body)}:{}),signal:AbortSignal.timeout(25000)});
    if(!fetched.ok){
     const retryHeader=fetched.headers.get('Retry-After'),seconds=Number(retryHeader),retryAt=Number.isFinite(seconds)&&seconds>0?new Date(Date.now()+seconds*1000).toISOString():null;
     const event=post?'unknown':fetched.status===404?'failed':'pending';
     await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:event,p_data:{code:fetched.status===429?'limit':fetched.status===404?'provider_result_expired':'unavailable',limitType:fetched.status===429?'providerRate':null,retryAt}});
     return json(200,{state:event});
    }
    response=JSON.parse(await boundedText(fetched,2000000));
   }catch{
    await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:post?'unknown':'pending',p_data:{code:post?'provider_outcome_unknown':'unavailable'}});
    return json(200,{state:post?'unknown':'pending'});
   }
   if(!/^resp_[a-zA-Z0-9_-]+$/.test(response.id??''))fail('invalid_response');
   responseKnownId=response.id;
   if(post){await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:'attached',p_data:{responseId:response.id}});attached=true;}
   if(['queued','in_progress'].includes(response.status)){
    await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:'pending',p_data:{}});
    return json(200,{state:'pending'});
   }
   const usage=response.usage;
   const knownUsage=usage&&Number.isInteger(usage.input_tokens)&&Number.isInteger(usage.output_tokens);
   if(knownUsage)await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:'usage',p_data:{inputTokens:usage.input_tokens,outputTokens:usage.output_tokens}});
   await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:'provider_result',p_data:{response}});
   if(!knownUsage)fail('invalid_response');
   if(response.status!=='completed'||response.incomplete_details)fail('invalid_response');
   const output=(response.output??[]).filter(x=>x.type==='message').flatMap(x=>x.content??[]);
   if(output.some(x=>x.type==='refusal'))fail('invalid_response');
   const result=JSON.parse(output.filter(x=>x.type==='output_text').map(x=>x.text).join(''));
   validateReviewResult(result,task);
   await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:'result',p_data:{result}});
   return json(200,{state:'step_completed'});
  }catch(error){
   if(task&&!task.finalize){try{await rpc('piko_ai_review_finish',{p_job_id:task.jobId,p_step_id:task.requestId,p_token:task.token,p_event:dispatchStarted&&!attached?'unknown':'failed',p_data:{code:dispatchStarted&&!attached?'provider_outcome_unknown':'invalid_response',...(responseKnownId?{responseId:responseKnownId}:{})}});}catch{}}
   return json(503,{code:error instanceof AiServiceError?error.code:'unavailable'});
  }
 };
}
