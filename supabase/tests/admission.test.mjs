import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
const {PGlite}=await import(process.env.PIKO_PGLITE_MODULE??'@electric-sql/pglite');
const migration=await readFile(new URL('../migrations/20261018083814_piko_ai_admission.sql',import.meta.url),'utf8');
function id(time=Date.now()) {
  const h=time.toString(16).padStart(12,'0'), random=randomUUID().replaceAll('-','');
  return `${h.slice(0,8)}-${h.slice(8)}-7${random.slice(0,3)}-8${random.slice(3,6)}-${random.slice(6,18)}`;
}
async function fixture() {
  const db=new PGlite();
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; grant usage on schema auth to service_role;
    create table auth.users(id uuid primary key,is_anonymous boolean not null,created_at timestamptz default now(),last_sign_in_at timestamptz);
    grant select on auth.users to service_role;`);
  await db.exec(migration);
  const identity=randomUUID();
  await db.query('insert into auth.users(id,is_anonymous) values($1,true)',[identity]);
  const query=async(sql,args=[])=>db.query(sql,args);
  const admit=async(user=identity,request=id(),reserve=100)=>
    (await query('select public.piko_ai_admit($1,$2,$3) result',[user,request,reserve])).rows[0].result;
  const enable=async(limit=10000)=>query(`insert into piko_ai.month_budget(month,enabled,limit_micro_usd)
    values(date_trunc('month',now() at time zone 'UTC')::date,true,$1)`,[limit]);
  const finish=async(request,actual=null,outcome='success',user=identity)=>query(
    'select public.piko_ai_finish($1,$2,$3,$4)',[user,request,outcome,actual]);
  return {db,query,identity,admit,enable,finish};
}
test('disabled by default; service-only access, forged identity and expired replay fail closed',async()=>{
  const f=await fixture();try {
    assert.equal(await f.admit(),'unavailable'); await f.enable();
    assert.equal(await f.admit(randomUUID()),'authentication');
    assert.equal(await f.admit(f.identity,id(Date.now()-3600000)),'expired');
    await f.db.exec('set role authenticated');
    await assert.rejects(f.admit(),/permission denied/);
    await assert.rejects(f.query('select * from piko_ai.request_usage'),/permission denied/);
    await f.db.exec('reset role; set role service_role');
    assert.equal(await f.admit(),'admitted');
  }finally{await f.db.close();}
});
test('single flight, duplicate admission, paid failure accounting and two/minute',async()=>{
  const f=await fixture();try {
    await f.enable(); const first=id(); assert.equal(await f.admit(f.identity,first),'admitted');
    assert.equal(await f.admit(),'busy'); assert.equal(await f.admit(f.identity,first),'duplicate');
    await f.finish(first,null,'uncertain');
    const second=id(); assert.equal(await f.admit(f.identity,second),'admitted'); await f.finish(second,20);
    assert.equal(await f.admit(),'minute_limit');
    const budget=(await f.query('select reserved_micro_usd from piko_ai.month_budget')).rows[0];
    assert.equal(Number(budget.reserved_micro_usd),120);
    assert.equal((await f.query('select daily_count from piko_ai.identity_usage')).rows[0].daily_count,2);
    await f.finish(first,0); // A repeated/late settlement cannot release an uncertain reservation.
    assert.equal(Number((await f.query('select reserved_micro_usd from piko_ai.month_budget')).rows[0].reserved_micro_usd),120);
  }finally{await f.db.close();}
});
test('100/day, UTC rollover, stale completion and unknown timeout remain bounded',async()=>{
  const f=await fixture();try {
    await f.enable(); const first=id(); await f.admit(f.identity,first); await f.finish(first);
    await f.query(`update piko_ai.identity_usage set daily_count=100,recent_starts='{}'`);
    assert.equal(await f.admit(),'day_limit');
    await f.query(`update piko_ai.identity_usage set usage_day=usage_day-1`);
    const second=id(); assert.equal(await f.admit(f.identity,second),'admitted');
    await f.finish(first,0); assert.equal(await f.admit(),'busy');
    assert.equal((await f.query('select daily_count from piko_ai.identity_usage')).rows[0].daily_count,1);
  }finally{await f.db.close();}
});
test('shared atomic cap survives concurrent submissions and rotating identities',async()=>{
  const f=await fixture();try {
    await f.enable(250); const users=Array.from({length:12},()=>randomUUID());
    for(const user of users) await f.query('insert into auth.users(id,is_anonymous) values($1,true)',[user]);
    const results=await Promise.all(users.map(user=>f.admit(user,id(),100)));
    assert.equal(results.filter(r=>r==='admitted').length,2);
    assert.equal(results.filter(r=>r==='budget_limit').length,10);
    assert.equal(Number((await f.query('select reserved_micro_usd from piko_ai.month_budget')).rows[0].reserved_micro_usd),200);
    // PGlite serializes submitted transactions. This checks SQL admission and
    // atomicity; independent hosted connections remain a deployment acceptance.
  }finally{await f.db.close();}
});
test('invalid settlement rolls back and retention blocks reactivation before deletion',async()=>{
  const f=await fixture();try {
    await f.enable(); const request=id(); await f.admit(f.identity,request);
    await assert.rejects(f.finish(request,101),/Invalid actual charge/);
    assert.equal(await f.admit(),'busy');
    await f.finish(request,10);
    await f.query(`update piko_ai.identity_usage set last_seen=now()-interval '91 days'`);
    await f.query(`update piko_ai.request_usage set admitted_at=now()-interval '36 days'`);
    const old=randomUUID(); await f.query(`insert into auth.users(id,is_anonymous,created_at) values($1,true,now()-interval '91 days')`,[old]);
    const candidates=(await f.query('select * from public.piko_ai_cleanup_candidates()')).rows;
    assert.deepEqual(new Set(candidates.map(r=>r.identity_id)),new Set([f.identity,old]));
    assert.equal((await f.query('select * from piko_ai.request_usage')).rows.length,0);
    assert.equal(await f.admit(),'authentication');
  }finally{await f.db.close();}
});
