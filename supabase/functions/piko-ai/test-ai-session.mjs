import {test,before,after,beforeEach} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';

const pg=new PGlite();
const owner='00000000-0000-4000-8000-000000000001';
const other='00000000-0000-4000-8000-000000000002';
const session='00000000-0000-4000-8000-000000000003';
before(async()=>{
  await pg.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create table auth.sessions(id uuid primary key,user_id uuid not null,not_after timestamptz,sensitive_fixture text);
    -- Session-column privileges must come exclusively from the migration.`);
  await pg.exec(await fs.readFile(new URL('../../migrations/20261019133600_verify_ai_sessions.sql',import.meta.url),'utf8'));
});
after(()=>pg.close());
beforeEach(async()=>{
  await pg.exec('reset role; truncate auth.sessions;');
  await pg.query('insert into auth.sessions(id,user_id) values($1,$2)',[session,owner]);
});
async function active(user=owner,id=session){
  const result=await pg.query('select public.piko_ai_session_active($1,$2) as active',[user,id]);
  return result.rows[0].active;
}
test('service role can verify an unbounded or future session matching its user',async()=>{
  await pg.exec('set role service_role');assert.equal(await active(),true);
  await pg.exec('reset role');
  await pg.exec("update auth.sessions set not_after=now()+interval '1 hour'");
  await pg.exec('set role service_role');assert.equal(await active(),true);
});
test('missing, null and mismatched identity/session cannot authorize',async()=>{
  await pg.exec('set role service_role');
  for(const [user,id] of [[other,session],[owner,other],[null,session],[owner,null],[null,null]]){
    assert.equal(await active(user,id),false);
  }
});
test('deleted sign-out session is denied immediately',async()=>{
  await pg.exec('set role service_role');assert.equal(await active(),true);
  await pg.exec('reset role; delete from auth.sessions; set role service_role');
  assert.equal(await active(),false);
});
test('expired and exactly-expiring session lifetime is denied',async()=>{
  await pg.exec("update auth.sessions set not_after=now()-interval '1 second'; set role service_role");
  assert.equal(await active(),false);
  await pg.exec('reset role; begin; update auth.sessions set not_after=now(); set role service_role');
  try{assert.equal(await active(),false);}finally{await pg.exec('rollback');}
});
test('app roles cannot execute session check, even with a known valid pair',async()=>{
  for(const role of ['anon','authenticated']){
    await pg.exec('set role '+role);
    await assert.rejects(active(),/permission denied for function piko_ai_session_active/);
    await pg.exec('reset role');
  }
});
test('function remains invoker and has no PUBLIC execute grant',async()=>{
  const result=await pg.query(`select p.prosecdef,
    has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute,
    has_function_privilege('authenticated',p.oid,'EXECUTE') as app_execute,
    has_function_privilege('service_role',p.oid,'EXECUTE') as service_execute,
    exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
      where a.grantee=0 and a.privilege_type='EXECUTE') as public_execute
    from pg_proc p where p.oid='public.piko_ai_session_active(uuid,uuid)'::regprocedure`);
  assert.deepEqual(result.rows,[{prosecdef:false,anon_execute:false,app_execute:false,service_execute:true,public_execute:false}]);
  // Without its narrowly granted Auth-table read, invoker execution cannot bypass
  // permissions merely because the function itself has EXECUTE privilege.
  await pg.exec('revoke select(id,user_id,not_after) on auth.sessions from service_role; set role service_role');
  try{await assert.rejects(active(),/permission denied for table sessions/);}
  finally{await pg.exec('reset role; grant select(id,user_id,not_after) on auth.sessions to service_role');}
});

test('migration grants only session-check columns, excluding unrelated session data',async()=>{
  await pg.exec('set role service_role');
  const rows=await pg.query('select id,user_id,not_after from auth.sessions');
  assert.equal(rows.rows.length,1);
  assert.equal(rows.rows[0].id,session);
  await assert.rejects(pg.query('select sensitive_fixture from auth.sessions'),/permission denied for table sessions/);
  await assert.rejects(pg.query('select * from auth.sessions'),/permission denied for table sessions/);
});
