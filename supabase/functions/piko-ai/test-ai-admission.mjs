import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {randomUUID} from 'node:crypto';
const pg=new PGlite();
const owner='00000000-0000-4000-8000-000000000001',other='00000000-0000-4000-8000-000000000002';
const hash='a'.repeat(64);
before(async()=>{
 await pg.exec('create role anon; create role authenticated; create role service_role bypassrls;');
 await pg.exec('create schema auth; create table auth.users(id uuid primary key,is_anonymous boolean,created_at timestamptz,last_sign_in_at timestamptz); create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id));');
 await pg.exec(await fs.readFile(new URL('../../migrations/20261018230610_owner_ai_admission.sql',import.meta.url),'utf8'));
});
after(()=>pg.close());
beforeEach(async()=>{
 await pg.exec('reset role; truncate piko_ai_private.receipts,piko_ai_private.owner_access,auth.sessions,auth.users;');
 await pg.exec("update piko_ai_private.config set enabled=false,active_month=date_trunc('month',now() at time zone 'utc')::date,allowance_cents=200,reserved_and_spent_cents=0,request_reserve_cents=100,input_nano_usd=2500,output_nano_usd=10000,eur_per_usd=1,max_output_tokens=32000,max_input_bytes=192000,max_inflight=2");
 await pg.query("insert into piko_ai_private.owner_access(user_id,enabled,expires_at) values($1,true,now()+interval '1 day'),($2,true,now()+interval '1 day')",[owner,other]);
});
async function active(){await pg.exec('update piko_ai_private.config set enabled=true');}
async function admit({user=owner,id=randomUUID(),issued=new Date().toISOString(),digest=hash}={}){
 const result=await pg.query('select public.piko_ai_admit($1,$2,$3,$4,$5,$6) as result',[user,id,issued,digest,'generate',1000]);
 return {id,...result.rows[0].result};
}
async function balance(){return (await pg.query('select enabled,reserved_and_spent_cents from piko_ai_private.config')).rows[0];}
test('default disabled, unknown/expired owner, expired request and null identity cannot admit',async()=>{
 await assert.rejects(admit(),/unavailable/);await active();
 await assert.rejects(admit({user:randomUUID()}),/access_denied/);
 await assert.rejects(admit({issued:new Date(Date.now()-700000).toISOString()}),/expired/);
 await assert.rejects(admit({user:null}),/invalid_request/);
 assert.equal((await balance()).reserved_and_spent_cents,0);
});
test('anon/authenticated cannot call RPCs or read balances; server role can admit approved owner',async()=>{
 await active();
 for(const role of ['anon','authenticated']){
  await pg.exec('set role '+role);
  await assert.rejects(pg.query('select * from piko_ai_private.config'),/permission denied/);
  await assert.rejects(admit(),/permission denied/);
  await pg.exec('reset role');
 }
 await pg.exec('set role service_role');const r=await admit();assert.equal(r.new,true);await pg.exec('reset role');
});
test('duplicate request never reserves twice; altered owner/hash replay is denied',async()=>{
 await active();const first=await admit(),second=await admit({id:first.id});
 assert.equal(first.new,true);assert.equal(second.new,false);assert.equal((await balance()).reserved_and_spent_cents,100);
 await assert.rejects(admit({id:first.id,user:other}),/replay/);
 await assert.rejects(admit({id:first.id,digest:'b'.repeat(64)}),/replay/);
 await assert.rejects(admit({id:first.id,digest:null}),/invalid_request/);
});
test('one in-flight per owner and shared balance survive a second approved identity',async()=>{
 await active();const first=await admit();await assert.rejects(admit(),/limit/);
 await pg.exec('update piko_ai_private.config set allowance_cents=150');
 await assert.rejects(admit({user:other}),/limit/);assert.equal((await balance()).reserved_and_spent_cents,100);
 await pg.query('select public.piko_ai_attach($1,$2,$3)',[owner,first.id,'resp_synthetic']);
 await assert.rejects(pg.query('select public.piko_ai_attach($1,$2,$3)',[owner,first.id,'resp_synthetic_second']),/replay/);
});
test('known usage settles once with admission-time rates; uncertain usage retains full reserve',async()=>{
 await active();const first=await admit();await pg.query('select public.piko_ai_attach($1,$2,$3)',[owner,first.id,'resp_synthetic']);
 await pg.exec('update piko_ai_private.config set input_nano_usd=1,output_nano_usd=1,eur_per_usd=0.01');
 await pg.query('select public.piko_ai_settle($1,$2,$3,$4)',[owner,first.id,1000,24750]);
 assert.equal((await balance()).reserved_and_spent_cents,25);
 await pg.query('select public.piko_ai_settle($1,$2,$3,$4)',[owner,first.id,1000,24750]);assert.equal((await balance()).reserved_and_spent_cents,25);
 await pg.exec('update piko_ai_private.config set input_nano_usd=2500,output_nano_usd=10000,eur_per_usd=1');
 const uncertain=await admit({user:other});
 await assert.rejects(pg.query('select public.piko_ai_settle($1,$2,$3,$4)',[other,uncertain.id,null,1]),/invalid_usage/);
 assert.equal((await balance()).reserved_and_spent_cents,125);
});
test('minute/day quotas count settled attempts, inactive month and inadequate reserve fail closed',async()=>{
 await active();await pg.exec('update piko_ai_private.config set request_reserve_cents=1');await assert.rejects(admit(),/unavailable/);
 await pg.exec("update piko_ai_private.config set request_reserve_cents=100,active_month=(active_month-interval '1 month')::date");await assert.rejects(admit(),/unavailable/);
 await pg.exec("update piko_ai_private.config set active_month=date_trunc('month',now() at time zone 'utc')::date");
 for(let i=0;i<2;i++){const r=await admit();await pg.query('select public.piko_ai_settle($1,$2,$3,$4)',[owner,r.id,1,1]);}
 await assert.rejects(admit(),/limit/);
 await pg.exec("update piko_ai_private.receipts set created_at=now()-interval '2 minutes'");
 for(let i=2;i<100;i++)await pg.query("insert into piko_ai_private.receipts(request_id,user_id,issued_at,deadline,created_at,request_hash,action,status,reserve_cents,input_nano_usd,output_nano_usd,eur_per_usd,max_output_tokens) values($1,$2,now(),now(),now()-interval '2 minutes',$3,'generate','settled',1,2500,10000,1,32000)",[randomUUID(),owner,hash]);
 await assert.rejects(admit(),/limit/);
});
test('revocation denies status and cleanup drops old receipts without refunding current balance',async()=>{
 await active();const r=await admit();await pg.query('select public.piko_ai_attach($1,$2,$3)',[owner,r.id,'resp_synthetic']);
 await assert.rejects(pg.query('select public.piko_ai_status($1,$2,$3)',[other,r.id,hash]),/expired/);
 await pg.query('update piko_ai_private.owner_access set enabled=false where user_id=$1',[owner]);
 await assert.rejects(pg.query('select public.piko_ai_status($1,$2,$3)',[owner,r.id,hash]),/access_denied/);
 await pg.exec("update piko_ai_private.receipts set created_at=now()-interval '36 days'; select public.piko_ai_cleanup();");
 assert.equal((await pg.query('select count(*)::int as n from piko_ai_private.receipts')).rows[0].n,0);assert.equal((await balance()).reserved_and_spent_cents,100);
});
test('database-owner cleanup deletes only inactive anonymous identities, revoking access and sessions; service client cannot invoke it',async()=>{
 const inactive=randomUUID(),recent=randomUUID(),permanent=randomUUID();
 await pg.query("insert into auth.users values($1,true,now()-interval '100 days',null),($2,true,now(),null),($3,false,now()-interval '100 days',null),($4,true,now()-interval '100 days',null)",[inactive,recent,permanent,owner]);
 await pg.query('insert into auth.sessions values($1,$2)',[randomUUID(),inactive]);
 await pg.exec('set role service_role');await assert.rejects(pg.query('select piko_ai_private.purge_inactive_anonymous_identities()'),/permission denied/);await pg.exec('reset role');
 const result=await pg.query('select piko_ai_private.purge_inactive_anonymous_identities() as n');assert.equal(result.rows[0].n,1);
 const users=(await pg.query('select id from auth.users')).rows.map(u=>u.id);assert.deepEqual(new Set(users),new Set([recent,permanent,owner]));
 assert.equal((await pg.query('select count(*)::int as n from auth.sessions')).rows[0].n,0);
});

test('continuation admission preserves only remaining technical capacity and rejects exhausted scope',async()=>{
 await active();
 const args=[owner,randomUUID(),new Date().toISOString(),hash,'generate',1000,'ordinary',199];
 const r=(await pg.query('select public.piko_ai_admit($1,$2,$3,$4,$5,$6,$7,$8) as result',args)).rows[0].result;
 assert.equal(r.cardCeiling,1);
 assert.equal((await pg.query('select card_ceiling from piko_ai_private.receipts')).rows[0].card_ceiling,1);
 args[1]=randomUUID();args[7]=200;
 await assert.rejects(pg.query('select public.piko_ai_admit($1,$2,$3,$4,$5,$6,$7,$8)',args),/invalid_request/);
});
