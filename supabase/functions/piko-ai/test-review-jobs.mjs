import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {snapshotHash,textHash,planReview,aggregateReview,validateReviewResult,createReviewJobHandler,createReviewWorker} from './review-jobs.mjs';
const owner='00000000-0000-4000-8000-000000000001',other='00000000-0000-4000-8000-000000000002';
const options={level:'B1',goals:[],checks:['translations','examples','hints','suitability','structure','categories'],categoryMode:'improve',filters:{}};
const pricing={maxInputBytes:192000,maxOutputTokens:32000,inputNanoUsd:2500,outputNanoUsd:10000,eurPerUsd:1};
function manifest(count=3){return {version:1,collection:{id:randomUUID(),name:'Synthetic Collection',targetLanguage:{kind:'catalog',id:'en'},nativeLanguage:{kind:'catalog',id:'de'},level:'B1'},options,groups:[],allowNewGroups:true,allowNewValues:true,
 entries:Array.from({length:count},(_,i)=>({id:randomUUID(),target:'term '+i,native:'Wort '+i,active:i%2===0,hint:null,hintVisibility:'always',examples:[{target:'This is '+i,native:'Das ist '+i}],assignments:{}})).sort((a,b)=>a.id.localeCompare(b.id))};}
function output(step){return {requestId:step.requestId,complete:true,processedIds:step.ids,groups:[],values:[],cards:[],edits:[],limitations:[]};}
test('700 entries are covered exactly once in details and every compact ID is compared globally',()=>{
 const m=manifest(700),p=planReview(m,pricing),details=p.steps.filter(s=>s.phase==='detail'),global=p.steps.filter(s=>s.phase==='consistency');
 assert.equal(details.length,14);assert.deepEqual(details.flatMap(s=>s.ids).sort(),m.entries.map(e=>e.id));
 assert.ok(global.some(s=>s.ids.length===700));assert.ok(p.steps.every(s=>s.inputBytes<=pricing.maxInputBytes));
 assert.ok(p.maximumCostCents>0);assert.ok(p.steps.every(s=>s.body.store===false&&s.body.background===true&&s.body.model==='gpt-6.1-sol'));
});
test('oversized compact index shards compare each pair without losing cross-shard relationships',()=>{
 const m=manifest(25);for(const e of m.entries)e.hint='x'.repeat(1000);
 const p=planReview(m,{...pricing,maxInputBytes:30000}),steps=p.steps.filter(s=>s.phase==='consistency');
 for(const a of m.entries)for(const b of m.entries)assert.ok(steps.some(s=>s.ids.includes(a.id)&&s.ids.includes(b.id)));
 assert.ok(p.steps.every(s=>s.inputBytes<=30000));
});
test('snapshot canonical hash is deterministic and content/filter/flag changes invalidate it',async()=>{
 const m=manifest(),hash=await snapshotHash(m),reordered=Object.fromEntries(Object.entries(m).reverse());
 assert.equal(hash,await snapshotHash(reordered));
 for(const edit of [x=>x.entries[0].target='changed',x=>x.options={...x.options,filters:{some:['value']}},x=>x.allowNewGroups=false]){const x=structuredClone(m);edit(x);assert.notEqual(hash,await snapshotHash(x));}
});
test('actual Dart manifest fixture preserves custom language/name/inactive/categories/filters and cross-language SHA',async()=>{
 const fixture=JSON.parse(await fs.readFile(new URL('./fixtures/dart-review-manifest.json',import.meta.url),'utf8'));
 const plan=planReview(fixture.document,pricing);assert.equal(await snapshotHash(fixture.document),fixture.digest);
 assert.equal(plan.steps[0].input.context.targetLanguage,'Synthetic language');assert.equal(plan.total,1);assert.equal(plan.steps.length,2);
});
test('incomplete IDs, unknown IDs, cards and forbidden fields never become completed review',()=>{
 const s=planReview(manifest(),pricing).steps[0];
 for(const change of [x=>x.complete=false,x=>x.processedIds.pop(),x=>x.processedIds[0]=randomUUID(),x=>x.processedIds.push(x.processedIds[0])]){const r=output(s);r.processedIds=[...r.processedIds];change(r);assert.throws(()=>validateReviewResult(r,s));}
 const r=output(s);r.edits=[{id:'one',entryId:s.ids[0],field:'examples',value:[],outcome:'change',reason:'Reason',rule:'rule'}];
 assert.throws(()=>validateReviewResult(r,{...s,phase:'consistency'}));
});
test('cross-step conflicting proposals are unresolved; definitions receive globally distinct IDs',()=>{
 const s=planReview(manifest(),pricing).steps[0],a=output(s),b=output(s);
 a.edits=[{id:'same',entryId:s.ids[0],field:'hint',value:'first',outcome:'change',reason:'Reason',rule:'rule'}];b.edits=[{...a.edits[0],value:'second'}];
 const result=aggregateReview(randomUUID(),[{...s,result:a},{...s,result:b}]);
 assert.equal(result.result.edits[0].outcome,'unresolved');assert.equal(result.conflicts.length,1);assert.deepEqual(result.conflicts[0].alternatives.map(x=>x.value),['first','second']);assert.equal(result.result.processedIds.length,s.ids.length);
});
test('equivalent category definitions from independent steps are aliased; incompatible modes remain readonly',()=>{
 const step=planReview(manifest(),pricing).steps[0],a=output(step),b=output(step);
 a.groups=[{id:'topic',name:'Topic',mode:'multiple',reason:'Reason'}];a.values=[{id:'travel',groupId:'topic',name:'Travel',reason:'Reason'}];
 a.edits=[{id:'edit',entryId:step.ids[0],field:'assignments',value:[{groupId:'topic',valueIds:['travel']}],outcome:'change',reason:'Reason',rule:'Categories'}];
 b.groups=[{id:'other-topic',name:' topic ',mode:'multiple',reason:'Reason'}];b.values=[{id:'other-travel',groupId:'other-topic',name:'travel',reason:'Reason'}];
 b.edits=[{...a.edits[0],value:[{groupId:'other-topic',valueIds:['other-travel']}]}];
 const merged=aggregateReview(randomUUID(),[{...step,result:a},{...step,result:b}]);
 assert.equal(merged.result.groups.length,1);assert.equal(merged.result.values.length,1);assert.equal(merged.result.edits[0].outcome,'change');assert.equal(merged.conflicts.length,0);
 b.groups[0].mode='single';
 const conflict=aggregateReview(randomUUID(),[{...step,result:a},{...step,result:b}]);assert.equal(conflict.result.groups.length,0);assert.equal(conflict.result.values.length,0);assert.equal(conflict.result.edits[0].outcome,'unresolved');assert.equal(conflict.conflicts[0].kind,'definition');assert.equal(conflict.conflicts[0].alternatives.length,2);
});

const pg=new PGlite();
before(async()=>{
 await pg.exec('create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create table auth.users(id uuid primary key,is_anonymous boolean,created_at timestamptz,last_sign_in_at timestamptz);create table auth.sessions(id uuid primary key,user_id uuid);');
 for(const name of ['20261018230610_owner_ai_admission.sql','20261019102706_private_ai_pilot.sql'])await pg.exec(await fs.readFile(new URL('../../migrations/'+name,import.meta.url),'utf8'));
 // PGlite does not bundle PGMQ. Exercise the same SQL boundaries with a small
 // local queue fixture; hosted extension/real connection concurrency stays gated.
 await pg.exec(`create schema pgmq;create table pgmq.messages(msg_id bigint generated always as identity,message jsonb,visible_at timestamptz);
 create function pgmq.send(text,jsonb,integer default 0) returns bigint language sql as 'insert into pgmq.messages(message,visible_at) values($2,clock_timestamp()+make_interval(secs=>$3)) returning msg_id';
 create function pgmq.read(text,integer,integer) returns table(msg_id bigint,message jsonb) language sql as 'select msg_id,message from pgmq.messages where visible_at<=clock_timestamp() order by msg_id limit $3';
 create function pgmq.delete(text,bigint) returns boolean language sql as 'with x as(delete from pgmq.messages where msg_id=$2 returning 1) select exists(select 1 from x)';`);
 const migration=await fs.readFile(new URL('../../migrations/20261023120000_review_jobs.sql',import.meta.url),'utf8');
 await pg.exec(migration.replace(/-- PGMQ_SETUP_BEGIN[\s\S]*?-- PGMQ_SETUP_END/,''));
});
after(()=>pg.close());
beforeEach(async()=>{
 await pg.exec('reset role;truncate piko_ai_private.review_cancellations,piko_ai_private.review_jobs,piko_ai_private.payloads,piko_ai_private.receipts,piko_ai_private.owner_access,piko_ai_private.regressions,pgmq.messages cascade;');
 await pg.exec("update piko_ai_private.config set enabled=true,review_jobs_enabled=true,deployment_verified=true,pilot_started_at=now()-interval '1 day',pilot_ends_at=now()+interval '13 days',last_cleanup_at=now(),notice_version='test-v2',contact='synthetic',processor_details='synthetic',allowance_cents=1900,non_ai_usage_cents=100,new_cash_outlay_cents=0,prepaid_available_cents=1900,reserved_and_spent_cents=0,request_reserve_cents=100,input_nano_usd=2500,output_nano_usd=10000,eur_per_usd=1,max_output_tokens=32000,max_inflight=2");
 await pg.query("insert into piko_ai_private.owner_access(user_id,pilot_slot,enabled,expires_at,consent_version,consent_at) values($1,0,true,now()+interval '14 days','test-v2',now()),($2,1,true,now()+interval '14 days','test-v2',now())",[owner,other]);
});
async function rpc(name,args){
 const keys=Object.keys(args),params=keys.map((k,i)=>k+'=> $'+(i+1)).join(','),values=Object.values(args).map(v=>v&&typeof v==='object'?JSON.stringify(v):v);
 try{return (await pg.query('select public.'+name+'('+params+') as r',values)).rows[0].r;}
 catch(error){throw Object.assign(new Error(error.message),{code:error.message});}
}
const op=(id,action,data={},uid=owner)=>rpc('piko_ai_review_job',{p_user_id:uid,p_job_id:id,p_action:action,p_data:{installationId:'synthetic',...data}});
async function prepared(m=manifest(),maxCostCents=1900){
 const id=randomUUID(),digest=await snapshotHash(m),metadata={...m};delete metadata.entries;
 await op(id,'prepare',{installationId:'synthetic',idempotencyKey:id,snapshotDigest:digest,snapshotVersion:'1',scopeIds:m.entries.map(e=>e.id),metadata,maxCostCents});
 for(let i=0;i<m.entries.length;i+=50)await op(id,'upload',{index:i/50,entries:m.entries.slice(i,i+50)});
 return {id,m,digest,metadata};
}
async function started(m=manifest()){
 const p=await prepared(m),plan=planReview(m,pricing);
 await op(p.id,'start',{snapshotDigest:p.digest,steps:plan.steps,maximumCostCents:plan.maximumCostCents,pricing});return {...p,plan};
}
test('job binds full uploaded inventory, rejects cross-owner access/replayed chunks and app-role RPCs',async()=>{
 const p=await prepared();const manifest=await op(p.id,'manifest');assert.equal(await snapshotHash({...manifest.metadata,entries:manifest.entries}),p.digest);
 await assert.rejects(op(p.id,'status',{},other),/access_denied/);
 await assert.rejects(op(p.id,'upload',{index:0,entries:[{...p.m.entries[0],target:'changed'}]}),/replay/);
 for(const role of ['anon','authenticated']){await pg.exec('set role '+role);await assert.rejects(op(p.id,'status'),/permission denied/);await pg.exec('reset role');}
});
test('two claims cannot dispatch a paid step twice; pre-dispatch crash reuses the receipt and reservation',async()=>{
 const p=await started(),first=await rpc('piko_ai_review_claim',{});assert.equal(first.jobId,p.id);
 assert.equal(await rpc('piko_ai_review_claim',{}),null);
 const balance=(await pg.query('select reserved_and_spent_cents as n from piko_ai_private.config')).rows[0].n;
 await pg.exec("update piko_ai_private.review_steps set lease_until=now()-interval '1 second';update pgmq.messages set visible_at=now()");
 const again=await rpc('piko_ai_review_claim',{});assert.equal(again.requestId,first.requestId);assert.notEqual(again.token,first.token);
 assert.equal((await pg.query('select reserved_and_spent_cents as n from piko_ai_private.config')).rows[0].n,balance);
});
test('crash after persisted dispatch becomes unknown without replay or refund and cancellation releases its lease',async()=>{
 const p=await started(),task=await rpc('piko_ai_review_claim',{});
 await rpc('piko_ai_review_finish',{p_job_id:p.id,p_step_id:task.requestId,p_token:task.token,p_event:'dispatch',p_data:{}});
 await pg.exec("update piko_ai_private.review_steps set lease_until=now()-interval '1 second';update pgmq.messages set visible_at=now()");
 assert.equal(await rpc('piko_ai_review_claim',{}),null);assert.equal((await op(p.id,'status')).state,'unknown');
 await assert.rejects(op(p.id,'resume'),/replay/);assert.equal((await op(p.id,'cancel')).state,'cancelled');
 const row=(await pg.query('select * from piko_ai_private.receipts where request_id=$1',[task.requestId])).rows[0];assert.equal(row.actual_cents,null);assert.equal(row.status,'uncertain');
});
test('completed worker steps and report survive a later status call without provider GET',async()=>{
 const p=await started();let paid=0;
 const worker=createReviewWorker({enabled:true,workerSecret:'synthetic',providerKey:'not-real',rpc,fetchImpl:async(url,opt)=>{
  paid++;const input=JSON.parse(JSON.parse(opt.body).input[0].content),step=p.plan.steps.find(s=>s.requestId===input.requestId),result=output(step);
  return Response.json({id:'resp_synthetic',status:'completed',usage:{input_tokens:100,output_tokens:100},output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(result)}]}]});
 }});
 const req=()=>new Request('https://synthetic/?worker=review',{method:'POST',headers:{Authorization:'Bearer synthetic'}});
 for(let i=0;i<p.plan.steps.length+1;i++){await pg.exec('update pgmq.messages set visible_at=now()');assert.equal((await worker(req())).status,200);}
 const status=await op(p.id,'status');assert.equal(status.state,'completed');assert.equal(status.processed,p.m.entries.length);
 const result=await op(p.id,'result');assert.equal(result.requestId,p.id);assert.equal(result.snapshotDigest,p.digest);assert.equal(paid,p.plan.steps.length);
 assert.equal((await worker(req())).status,200);assert.equal(paid,p.plan.steps.length);
});
test('limits pause, expiry terminates, withdrawal deletes new content, and late usage settles exactly once',async()=>{
 const p=await started();await pg.exec('update piko_ai_private.config set reserved_and_spent_cents=1900');
 assert.equal(await rpc('piko_ai_review_claim',{}),null);assert.equal((await op(p.id,'status')).error.limitType,'sharedBudget');
 await pg.exec('update piko_ai_private.config set reserved_and_spent_cents=0');await op(p.id,'resume');const task=await rpc('piko_ai_review_claim',{});
 await op(p.id,'cancel');
 for(let i=0;i<2;i++)await rpc('piko_ai_review_finish',{p_job_id:p.id,p_step_id:task.requestId,p_token:task.token,p_event:'usage',p_data:{inputTokens:100,outputTokens:100}});
 const c=(await pg.query('select reserved_and_spent_cents as n from piko_ai_private.config')).rows[0].n;assert.equal(c,1);
 await pg.exec("update piko_ai_private.owner_access set enabled=false,withdrawn_at=now() where pilot_slot=0");
 assert.equal((await pg.query('select count(*)::int as n from piko_ai_private.review_jobs')).rows[0].n,0);
});
test('legacy expired uncertain receipts retain money but stop occupying concurrency forever',async()=>{
 const id=randomUUID();await pg.query("insert into piko_ai_private.receipts(request_id,user_id,issued_at,deadline,request_hash,action,status,reserve_cents,input_nano_usd,output_nano_usd,eur_per_usd,max_output_tokens) values($1,$2,now(),now()-interval '1 second',$3,'review','uncertain',100,2500,10000,1,32000)",[id,owner,'a'.repeat(64)]);
 await pg.exec('update piko_ai_private.config set reserved_and_spent_cents=100');
 const r=await rpc('piko_ai_admit',{p_user_id:owner,p_request_id:randomUUID(),p_issued_at:new Date().toISOString(),p_hash:'b'.repeat(64),p_action:'generate',p_input_bytes:1000});
 assert.equal(r.new,true);assert.equal((await pg.query('select reserved_and_spent_cents as n from piko_ai_private.config')).rows[0].n,200);
});
test('cancellation before a delayed prepare is an authoritative tombstone and cannot target another owner job',async()=>{
 const id=randomUUID(),cancelled=await op(id,'cancel');assert.equal(cancelled.state,'cancelled');
 const m=manifest(),metadata={...m};delete metadata.entries;
 await assert.rejects(op(id,'prepare',{installationId:'synthetic',idempotencyKey:id,snapshotDigest:await snapshotHash(m),snapshotVersion:'1',scopeIds:m.entries.map(e=>e.id),metadata,maxCostCents:1900}),/replay/);
 const p=await prepared();await assert.rejects(op(p.id,'cancel',{},other),/access_denied/);assert.equal((await op(p.id,'status')).state,'preparing');
});
test('requested local expiry cannot be widened; cleanup expires and deletes retained job content on schedule',async()=>{
 const p=await prepared(),earlier=new Date(Date.now()-1000).toISOString();
 await pg.query('update piko_ai_private.review_jobs set expires_at=$2 where id=$1',[p.id,earlier]);assert.equal((await op(p.id,'status')).state,'expired');
 await pg.exec("update piko_ai_private.review_jobs set content_expires_at=now()-interval '1 second';select public.piko_ai_cleanup()");
 assert.equal((await pg.query('select count(*)::int as n from piko_ai_private.review_jobs')).rows[0].n,0);
});
test('ordinary cached results remain recoverable beyond provider TTL without extending content expiry',async()=>{
 const requestId=randomUUID();await rpc('piko_ai_admit',{p_user_id:owner,p_request_id:requestId,p_issued_at:new Date().toISOString(),p_hash:'c'.repeat(64),p_action:'generate',p_input_bytes:1000});
 await rpc('piko_ai_capture',{p_user_id:owner,p_request_id:requestId,p_stage:'sent',p_payload:{synthetic:'request'}});
 await rpc('piko_ai_capture',{p_user_id:owner,p_request_id:requestId,p_stage:'result',p_payload:{id:'resp_synthetic',status:'completed'}});
 await pg.query("update piko_ai_private.receipts set deadline=now()-interval '1 day' where request_id=$1",[requestId]);
 const status=await rpc('piko_ai_status',{p_user_id:owner,p_request_id:requestId,p_hash:'c'.repeat(64)});assert.equal(status.cachedResponse.status,'completed');
});
test('HTTP prepare/upload/start enforces complete canonical manifest and budget before paid admission',async()=>{
 const m=manifest(),id=randomUUID(),hash=await snapshotHash(m),handler=createReviewJobHandler({enabled:true,authenticate:async()=>owner,rpc});
 const send=(action,data)=>handler(new Request('https://synthetic/?job='+action,{method:'POST',headers:{Authorization:'Bearer synthetic'},body:JSON.stringify({jobId:id,installationId:'synthetic',...data})}));
 assert.equal((await send('prepare',{...m,entries:undefined,jobId:id,snapshotDigest:hash,snapshotVersion:'1',scopeIds:m.entries.map(e=>e.id),maxCostCents:1,idempotencyKey:id,installationId:'synthetic'})).status,200);
 assert.equal((await send('upload',{index:0,entries:m.entries})).status,200);
 const denied=await send('start',{});assert.equal(denied.status,429);assert.equal((await denied.json()).limitType,'jobBudget');
 assert.equal((await pg.query('select count(*)::int as n from piko_ai_private.receipts')).rows[0].n,0);
 const malformed=await send('upload',{index:1,entries:[{...m.entries[0],learning:{secret:'not allowed'}}]});assert.equal(malformed.status,400);
});
test('disabled dispatch still acknowledges cancellation; worker secret failure invokes no privileged RPC',async()=>{
 const id=randomUUID(),handler=createReviewJobHandler({enabled:false,authenticate:async()=>owner,rpc});
 const response=await handler(new Request('https://synthetic/?job=cancel',{method:'POST',headers:{Authorization:'Bearer synthetic'},body:JSON.stringify({jobId:id,installationId:'synthetic'})}));assert.equal(response.status,200);assert.equal((await response.json()).state,'cancelled');
 let calls=0;const worker=createReviewWorker({enabled:true,workerSecret:'synthetic-secret',providerKey:'synthetic-only',rpc:async()=>{calls++;}});
 assert.equal((await worker(new Request('https://synthetic/',{method:'POST',headers:{Authorization:'Bearer wrong'}}))).status,403);assert.equal(calls,0);
});
test('known admission limit details expose bounded cause and real retry time without other tester counts',async()=>{
 await pg.exec('update piko_ai_private.config set reserved_and_spent_cents=1900');
 try{await pg.query('select public.piko_ai_admit($1,$2,$3,$4,$5,$6)',[owner,randomUUID(),new Date().toISOString(),'d'.repeat(64),'generate',1000]);assert.fail('expected limit');}
 catch(error){assert.match(error.message,/limit/);const detail=JSON.parse(error.detail);assert.equal(detail.limitType,'sharedBudget');assert.equal(detail.remainingCents,0);assert.equal(detail.otherUsers,undefined);}
});
test('finalization has its own recovery wake-up after a worker crashes before commit',async()=>{
 const p=await started();
 for(const s of p.plan.steps)await pg.query("update piko_ai_private.review_steps set state='completed',result=$2 where id=$1",[s.requestId,JSON.stringify(output(s))]);
 await pg.exec('truncate pgmq.messages');await pg.query("select pgmq.send('piko_ai_review',$1,0)",[JSON.stringify({jobId:p.id})]);
 const abandoned=await rpc('piko_ai_review_claim',{});assert.equal(abandoned.finalize,true);
 assert.equal((await pg.query('select count(*)::int as n from pgmq.messages')).rows[0].n,1);
 await pg.exec('update pgmq.messages set visible_at=now()');const recovered=await rpc('piko_ai_review_claim',{});assert.equal(recovered.finalize,true);
 await rpc('piko_ai_review_finish',{p_job_id:p.id,p_step_id:null,p_token:recovered.token,p_event:'complete',p_data:aggregateReview(p.id,recovered.steps)});
 assert.equal((await op(p.id,'status')).state,'completed');
});
test('preflight counts already used UTC-day slots and practical one-minute scheduler capacity',async()=>{
 const p=await prepared(),plan=planReview(p.m,pricing);
 await pg.query("update piko_ai_private.review_jobs set expires_at=now()+interval '1 hour' where id=$1",[p.id]);
 for(let i=0;i<20;i++)await pg.query("insert into piko_ai_private.receipts(request_id,user_id,issued_at,deadline,created_at,request_hash,action,status,reserve_cents,input_nano_usd,output_nano_usd,eur_per_usd,max_output_tokens) values($1,$2,now(),now(),date_trunc('day',now() at time zone 'utc') at time zone 'utc',$3,'generate','settled',1,2500,10000,1,32000)",[randomUUID(),owner,'e'.repeat(64)]);
 const nearMidnight=(await pg.query("select piko_ai_private.review_capacity($1,date_trunc('day',now() at time zone 'utc') at time zone 'utc'+interval '23 hours',date_trunc('day',now() at time zone 'utc') at time zone 'utc'+interval '1 day') as n",[owner])).rows[0].n;
 assert.equal(nearMidnight,0);
 const tiny=(await pg.query("select piko_ai_private.review_capacity($1,now(),now()+interval '2 minutes') as n",[other])).rows[0].n;assert.equal(tiny,0);
 // The actual current-hour case may cross midnight; compare the exact helper
 // capacity rather than assuming the execution host's current time of day.
 await pg.query("update piko_ai_private.review_jobs set expires_at=now()+interval '2 minutes' where id=$1",[p.id]);
 await assert.rejects(op(p.id,'start',{snapshotDigest:p.digest,steps:plan.steps,maximumCostCents:plan.maximumCostCents,pricing}),/limit/);
});
test('actual three-parameter GET contract binds installation and remains readable when paid flags stop',async()=>{
 const p=await prepared(),handler=createReviewJobHandler({enabled:false,authenticate:async()=>owner,rpc});
 const read=installation=>handler(new Request('https://synthetic/?job=status&jobId='+p.id+'&installationId='+installation,{headers:{Authorization:'Bearer synthetic'}}));
 await pg.exec('update piko_ai_private.config set enabled=false,review_jobs_enabled=false');
 assert.equal((await read('synthetic')).status,200);
 const wrong=await read('another-install');assert.notEqual(wrong.status,200);
});
test('malformed provider identity after dispatch remains unknown and never silently unlocks as a definite failure',async()=>{
 const p=await started();let paid=0;
 const worker=createReviewWorker({enabled:true,workerSecret:'synthetic',providerKey:'not-real',rpc,fetchImpl:async()=>{paid++;return Response.json({id:'malformed',status:'completed'});}});
 const request=()=>new Request('https://synthetic/',{method:'POST',headers:{Authorization:'Bearer synthetic'}});
 assert.equal((await worker(request())).status,503);assert.equal((await op(p.id,'status')).state,'unknown');
 await pg.exec('update pgmq.messages set visible_at=now()');await worker(request());assert.equal(paid,1);
});
test('lost attach acknowledgement recovers the known response by GET, without repeating its POST',async()=>{
 const p=await started();let paid=0,polled=0,once=true;
 const safeRpc=async(name,args)=>{const result=await rpc(name,args);if(name==='piko_ai_review_finish'&&args.p_event==='attached'&&once){once=false;throw Error('synthetic lost ack');}return result;};
 const worker=createReviewWorker({enabled:true,workerSecret:'synthetic',providerKey:'not-real',rpc:safeRpc,fetchImpl:async(url,opt)=>{
  if(opt.method==='POST'){paid++;return Response.json({id:'resp_synthetic',status:'queued'});}
  polled++;return Response.json({id:'resp_synthetic',status:'completed',usage:{input_tokens:100,output_tokens:100},output:[{type:'message',content:[{type:'output_text',text:JSON.stringify(output(p.plan.steps[0]))}]}]});
 }});
 const request=()=>new Request('https://synthetic/',{method:'POST',headers:{Authorization:'Bearer synthetic'}});
 assert.equal((await worker(request())).status,503);assert.equal((await op(p.id,'status')).state,'running');
 await pg.exec('update pgmq.messages set visible_at=now()');assert.equal((await worker(request())).status,200);assert.equal(paid,1);assert.equal(polled,1);
});
test('completed reports larger than 2MB round-trip as immutable bounded GET parts with a whole-report checksum',async()=>{
 const p=await prepared(),report={requestId:p.id,complete:true,processedIds:p.m.entries.map(e=>e.id),groups:[],values:[],cards:[],edits:[],limitations:Array.from({length:1300},(_,i)=>'Synthetic '+i+' '+String.fromCodePoint(0x1F4DA).repeat(900))};
 await pg.query("update piko_ai_private.review_jobs set state='completed',result=$2 where id=$1",[p.id,JSON.stringify(report)]);
 const handler=createReviewJobHandler({enabled:true,authenticate:async()=>owner,rpc});
 const fetchPart=part=>handler(new Request('https://synthetic/?job=result&jobId='+p.id+'&installationId=synthetic&part='+part,{headers:{Authorization:'Bearer synthetic'}}));
 const first=await (await fetchPart(0)).json();assert.ok(first.parts>2);let serialized='';
 for(let part=0;part<first.parts;part++){
  const response=await fetchPart(part),body=await response.text();assert.ok(new TextEncoder().encode(body).length<2000000);
  const piece=JSON.parse(body);assert.equal(piece.part,part);assert.equal(piece.resultHash,first.resultHash);assert.equal(piece.snapshotDigest,p.digest);serialized+=piece.content;
 }
 assert.ok(new TextEncoder().encode(serialized).length>2000000);assert.equal(await textHash(serialized),first.resultHash);assert.deepEqual(JSON.parse(serialized).limitations,report.limitations);
 assert.equal((await fetchPart(first.parts)).status,400);assert.equal((await pg.query('select count(*)::int as n from piko_ai_private.receipts')).rows[0].n,0);
});
