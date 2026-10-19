import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createAnonymousAuthenticator} from './ai-auth.mjs';

const owner='00000000-0000-4000-8000-000000000001';
const session='00000000-0000-4000-8000-000000000002';
const token=(overrides={})=>'synthetic.'+Buffer.from(JSON.stringify({
  sub:owner,session_id:session,exp:Math.floor(Date.now()/1000)+600,...overrides,
})).toString('base64url')+'.synthetic';
function fixture({user={id:owner,is_anonymous:true},authError=null,active=true,rpcError=null,throws=false}={}) {
  const calls=[];
  const authenticate=createAnonymousAuthenticator({
    auth:{getUser:async jwt=>{calls.push(['verify',jwt]);if(throws)throw Error('SYNTHETIC_PRIVATE_ERROR');return {data:{user},error:authError};}},
    rpc:async(name,args)=>{calls.push(['session',name,args]);return {data:active,error:rpcError};},
  });
  return {authenticate,calls};
}
test('verified anonymous identity requires matching active session on every call',async()=>{
  const f=fixture();const jwt=token();
  assert.equal(await f.authenticate(jwt),owner);
  assert.deepEqual(f.calls,[['verify',jwt],['session','piko_ai_session_active',{p_user_id:owner,p_session_id:session}]]);
  assert.equal(await f.authenticate(jwt),owner);
  assert.equal(f.calls.filter(c=>c[0]==='session').length,2);
});
test('forged/rejected JWT is not decoded or checked against sessions',async()=>{
  const f=fixture({authError:{message:'synthetic invalid signature'}});
  assert.equal(await f.authenticate(token()),null);
  assert.equal(f.calls.length,1);
});
test('nonanonymous, missing and malformed verified users are denied before session lookup',async()=>{
  for(const user of [null,{id:owner,is_anonymous:false},{id:'invalid',is_anonymous:true},{id:owner}]) {
    const f=fixture({user});assert.equal(await f.authenticate(token()),null);assert.equal(f.calls.length,1);
  }
});
test('missing/malformed session, wrong subject, expired and malformed payload deny without RPC',async()=>{
  const bad=[token({session_id:undefined}),token({session_id:'invalid'}),token({sub:session}),
    token({exp:1}),token({exp:undefined}),token({exp:'99999999999'}),'synthetic.%%%25.synthetic',
    'synthetic.'+Buffer.from('{').toString('base64url')+'.synthetic','not-a-jwt'];
  for(const jwt of bad){const f=fixture();assert.equal(await f.authenticate(jwt),null);assert.equal(f.calls.length,1);}
});
test('revoked session, RPC error and nonboolean responses fail closed',async()=>{
  for(const options of [{active:false},{active:null},{active:'true'},{active:{active:true}},{rpcError:{message:'synthetic denied'}}]){
    const f=fixture(options);assert.equal(await f.authenticate(token()),null);assert.equal(f.calls.length,2);
  }
});
test('sign-out revocation is rechecked and a refreshed session is accepted only after verification',async()=>{
  let active=true;const lookedUp=[];
  const authenticate=createAnonymousAuthenticator({auth:{getUser:async()=>({data:{user:{id:owner,is_anonymous:true}},error:null})},
    rpc:async(name,args)=>{lookedUp.push(args.p_session_id);return {data:active,error:null};}});
  assert.equal(await authenticate(token()),owner);active=false;
  assert.equal(await authenticate(token()),null);active=true;
  assert.equal(await authenticate(token({session_id:owner})),owner);
  assert.deepEqual(lookedUp,[session,session,owner]);
});
test('missing client and authentication/backend exceptions return only denial',async()=>{
  assert.equal(await createAnonymousAuthenticator(null)(token()),null);
  assert.equal(await fixture({throws:true}).authenticate(token()),null);
  const authenticate=createAnonymousAuthenticator({auth:{getUser:async()=>({data:{user:{id:owner,is_anonymous:true}},error:null})},rpc:async()=>{throw Error('SYNTHETIC_PRIVATE_ERROR');}});
  assert.equal(await authenticate(token()),null);
});
