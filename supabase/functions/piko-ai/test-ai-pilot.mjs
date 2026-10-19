import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {randomUUID} from 'node:crypto';
const pg=new PGlite(),owner='00000000-0000-4000-8000-000000000001',other='00000000-0000-4000-8000-000000000002',hash='a'.repeat(64);
before(async()=>{
 await pg.exec('create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create table auth.users(id uuid primary key,is_anonymous boolean,created_at timestamptz,last_sign_in_at timestamptz);create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id));');
 for(const name of ['20261018230610_owner_ai_admission.sql','20261019102706_private_ai_pilot.sql'])await pg.exec(await fs.readFile(new URL('../../migrations/'+name,import.meta.url),'utf8'));
});
after(()=>pg.close());
beforeEach(async()=>{
 await pg.exec('reset role;truncate piko_ai_private.payloads,piko_ai_private.receipts,piko_ai_private.owner_access,piko_ai_private.regressions;');
 await pg.exec("update piko_ai_private.config set enabled=true,deployment_verified=true,pilot_started_at=now()-interval '1 day',pilot_ends_at=now()+interval '13 days',last_cleanup_at=now(),notice_version='synthetic-v2',contact='synthetic invitation contact',processor_details='synthetic local test only',allowance_cents=1900,non_ai_usage_cents=100,new_cash_outlay_cents=0,prepaid_available_cents=1900,reserved_and_spent_cents=0,request_reserve_cents=100,input_nano_usd=2500,output_nano_usd=10000,eur_per_usd=1,max_output_tokens=32000,max_inflight=2");
 await pg.query("insert into piko_ai_private.owner_access(user_id,pilot_slot,enabled,expires_at) values($1,0,true,now()+interval '14 days'),($2,1,true,now()+interval '14 days')",[owner,other]);
});
const pilot=async(op,user=owner,version=null)=>(await pg.query('select public.piko_ai_pilot($1,$2,$3) as r',[user,op,version])).rows[0].r;
const consent=async(user=owner)=>pilot('consent',user,'synthetic-v2');
const admit=async(user=owner,id=randomUUID())=>({id,...(await pg.query('select public.piko_ai_admit($1,$2,$3,$4,$5,$6) as r',[user,id,new Date().toISOString(),hash,'generate',1000])).rows[0].r});
const capture=async(id,stage,payload,user=owner)=>pg.query('select public.piko_ai_capture($1,$2,$3,$4)',[user,id,stage,JSON.stringify(payload)]);
const balance=async()=>(await pg.query('select reserved_and_spent_cents as n from piko_ai_private.config')).rows[0].n;

test('copying APK/rotating identity or omitting/forging consent never admits; notice gives only configured details',async()=>{
 await assert.rejects(admit(),/access_denied/);await assert.rejects(pilot('notice',randomUUID()),/access_denied/);
 const notice=await pilot('notice');assert.equal(notice.version,'synthetic-v2');assert.ok(!notice.consented);assert.equal(notice.allowance_cents,undefined);
 await assert.rejects(pilot('consent',owner,'old'),/invalid_request/);await consent();assert.equal((await admit()).new,true);
 assert.equal(await balance(),100);
});
test('six fixed invitation slots only; ordinary authenticated users cannot read payloads or issue privileged RPCs',async()=>{
 await assert.rejects(pg.query("insert into piko_ai_private.owner_access(user_id,pilot_slot,expires_at) values($1,6,now())",[randomUUID()]),/check constraint/);
 for(const role of ['anon','authenticated']){
  await pg.exec('set role '+role);await assert.rejects(pg.query('select * from piko_ai_private.payloads'),/permission denied/);
  await assert.rejects(pilot('consent'),/permission denied/);await pg.exec('reset role');
 }
 await consent();await pg.exec('set role service_role');assert.equal((await admit()).new,true);await pg.exec('reset role');
});
test('expiry, missing deployment/notice/balance and stale cleanup disable admission',async()=>{
 await consent();
 for(const change of ["deployment_verified=false","contact=''","prepaid_available_cents=0","last_cleanup_at=now()-interval '25 hours'","pilot_started_at=now()-interval '15 days',pilot_ends_at=now()-interval '1 day'"]){
  await pg.exec('begin');await pg.exec('update piko_ai_private.config set '+change);await assert.rejects(admit(),/unavailable/);await pg.exec('rollback');
 }
 assert.equal(await balance(),0);
});
test('shared total includes non-AI usage, crosses month boundaries and duplicate calls never reserve twice',async()=>{
 await consent();await consent(other);
 await pg.exec("update piko_ai_private.config set active_month=(date_trunc('month',now())-interval '1 month')::date,reserved_and_spent_cents=1800");
 const a=await admit();assert.equal(await balance(),1900);assert.equal((await admit(owner,a.id)).new,false);
 await assert.rejects(admit(other),/limit/);assert.equal(await balance(),1900);
 await pg.query('select public.piko_ai_settle($1,$2,1000,24750)',[owner,a.id]);assert.equal(await balance(),1825);
 await assert.rejects(pg.exec('update piko_ai_private.config set allowance_cents=2000'),/check constraint/);
 await assert.rejects(pg.exec('update piko_ai_private.config set new_cash_outlay_cents=2001'),/check constraint/);
});
test('queued concurrent admissions serialize at global reserve; uncertain result remains charged',async()=>{
 await consent();await consent(other);await pg.exec('update piko_ai_private.config set reserved_and_spent_cents=1800');
 const results=await Promise.allSettled([admit(),admit(other),admit(),admit(other)]);
 assert.equal(results.filter(x=>x.status==='fulfilled').length,1);assert.equal(await balance(),1900);
});
test('20 daily attempts, two per minute and one in-flight apply also to paid failures',async()=>{
 await consent();let r=await admit();await assert.rejects(admit(),/limit/);
 await pg.query('select public.piko_ai_settle($1,$2,1,1)',[owner,r.id]);r=await admit();await pg.query('select public.piko_ai_settle($1,$2,1,1)',[owner,r.id]);
 await assert.rejects(admit(),/limit/);
 await pg.exec("update piko_ai_private.receipts set created_at=date_trunc('day',clock_timestamp() at time zone 'utc') at time zone 'utc'");
 for(let i=2;i<20;i++)await pg.query("insert into piko_ai_private.receipts(request_id,user_id,issued_at,deadline,created_at,request_hash,action,status,reserve_cents,input_nano_usd,output_nano_usd,eur_per_usd,max_output_tokens) values($1,$2,now(),now(),date_trunc('day',clock_timestamp() at time zone 'utc') at time zone 'utc',$3,'generate','uncertain',1,2500,10000,1,32000)",[randomUUID(),owner,hash]);
 await assert.rejects(admit(),/limit/);
});
test('withdraw deletes live payloads immediately, blocks new/late logging and status even with old JWT; accounting retained',async()=>{
 await consent();const r=await admit();await capture(r.id,'sent',{request:{goal:'synthetic text'}});await capture(r.id,'result',{answer:'synthetic result'});
 await assert.rejects(capture(r.id,'feedback',{text:'cross tester'},other),/access_denied/);
 const withdrawn=await pilot('withdraw');assert.equal(withdrawn.livePayloadsDeleted,true);assert.equal(withdrawn.backupExpiryDays,7);
 assert.equal((await pg.query('select count(*)::int as n from piko_ai_private.payloads')).rows[0].n,0);
 await assert.rejects(capture(r.id,'result',{late:true}),/access_denied/);await assert.rejects(admit(),/access_denied/);
 await assert.rejects(pg.query('select public.piko_ai_status($1,$2,$3)',[owner,r.id,hash]),/access_denied/);
 assert.equal(await balance(),100);assert.equal((await pilot('withdraw')).withdrawn,true);
});
test('payload result capture is immutable and replay does not extend expiry; adoption/feedback separately recorded',async()=>{
 await consent();const r=await admit();await capture(r.id,'sent',{synthetic:'input'});
 const expiry=(await pg.query('select expires_at from piko_ai_private.payloads')).rows[0].expires_at;
 await capture(r.id,'result',{synthetic:'first'});await capture(r.id,'result',{synthetic:'second'});
 await capture(r.id,'adoption',{selected:['card-a']});await capture(r.id,'feedback',{text:'synthetic feedback'});
 const row=(await pg.query('select * from piko_ai_private.payloads')).rows[0];assert.deepEqual(row.result,{synthetic:'first'});assert.equal(row.expires_at.getTime(),expiry.getTime());assert.deepEqual(row.adoption,{selected:['card-a']});
});
test('cleanup expires live content early enough for copies, retains receipts, and stops regressions at pilot bound',async()=>{
 await consent();const r=await admit();await capture(r.id,'sent',{synthetic:true});
 await pg.exec("update piko_ai_private.payloads set captured_at=now()-interval '23 days',expires_at=now()-interval '1 day'");
 await pg.query("insert into piko_ai_private.regressions values($1,now()-interval '83 days',now()-interval '1 day',true,'{}')",[randomUUID()]);
 await pg.exec('select public.piko_ai_cleanup()');
 for(const table of ['payloads','regressions'])assert.equal((await pg.query('select count(*)::int as n from piko_ai_private.'+table)).rows[0].n,0);
 assert.equal((await pg.query('select count(*)::int as n from piko_ai_private.receipts')).rows[0].n,1);
});

test('an expired receipt with unknown paid outcome still occupies in-flight admission until reconciled',async()=>{
 await consent();await admit();await pg.exec("update piko_ai_private.receipts set deadline=now()-interval '1 hour',created_at=now()-interval '2 minutes',status='uncertain'");
 await assert.rejects(admit(),/limit/);assert.equal(await balance(),100);
});
test('invitation slots cannot be deleted/rebound during the active pilot',async()=>{
 await assert.rejects(pg.query('delete from piko_ai_private.owner_access where user_id=$1',[other]),/pilot_slot_retained/);
 await assert.rejects(pg.query('update piko_ai_private.owner_access set user_id=$1 where user_id=$2',[randomUUID(),other]),/pilot_slot_retained/);
});
