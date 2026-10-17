import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { validate } from './check-documentation.mjs';

function fixture(t) {
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'piko-docs-'));
  t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
  fs.mkdirSync(path.join(root,'docs/images'),{recursive:true});
  fs.mkdirSync(path.join(root,'app'));
  const png=Buffer.alloc(24); Buffer.from('89504e470d0a1a0a','hex').copy(png);png.writeUInt32BE(1080,16);png.writeUInt32BE(2400,20);
  fs.writeFileSync(path.join(root,'docs/images/home.png'),png);
  const hash='a'.repeat(64), id=`sha256:${hash}`;
  const manifest={schemaVersion:1,build:{id,packageId:'test',versionName:'1',versionCode:1,artifact:'app.apk',apkSha256:hash,mode:'release',signing:'development',sourceCommit:'b'.repeat(40),builtOn:'2026-10-17',timeZone:'Europe/Vienna',toolchain:{}},documents:Object.fromEntries(['features','technical','screenshots','development','maintenance','verification'].map(k=>[k,`docs/${k}.md`])),screenshots:[{id:'home',path:'docs/images/home.png',sha256:crypto.createHash('sha256').update(png).digest('hex'),buildId:id,classification:'ordinary-product-emulator',state:'Home',task:'docs/features.md#home',locale:'en',device:{model:'test'},pixelSize:[1080,2400],logicalSize:[411,914],textScale:1,orientation:'portrait',capturedAt:'2026-10-17T12:00:00Z',fixture:'synthetic',alt:'Empty Home'}]};
  const write=()=>fs.writeFileSync(path.join(root,'docs/build-manifest.json'),JSON.stringify(manifest));write();
  for(const f of ['README.md','app/README.md',...Object.values(manifest.documents)])fs.writeFileSync(path.join(root,f),'# Home\n\n[Home](../docs/features.md#home)\n');
  fs.writeFileSync(path.join(root,'README.md'),'# Piko\n\n[Guide](docs/features.md#home)\n');
  fs.appendFileSync(path.join(root,'docs/screenshots.md'),'\n![Empty Home](images/home.png)\n');
  return {root,manifest,write,check:()=>validate(root,{checkSource:false})};
}
test('consistent bundle and explicit anchors validate',t=>{
  const f=fixture(t);assert.deepEqual(f.check(),[]);
  fs.appendFileSync(path.join(f.root,'docs/features.md'),'\n<a id="stable-task"></a>\n## Renamed task\n');
  fs.appendFileSync(path.join(f.root,'README.md'),'\n[Task](docs/features.md#stable-task)\n');assert.deepEqual(f.check(),[]);
});
test('broken task anchors block the handoff',t=>{
  const f=fixture(t);fs.appendFileSync(path.join(f.root,'README.md'),'\n[Missing](docs/features.md#missing)\n');
  assert.ok(f.check().some(e=>e.includes('missing anchor')));
});
test('altered or mis-sized images are rejected',t=>{
  const f=fixture(t);f.manifest.screenshots[0].pixelSize=[1,1];f.write();assert.ok(f.check().some(e=>e.includes('dimensions mismatch')));
  fs.appendFileSync(path.join(f.root,'docs/images/home.png'),'changed');assert.ok(f.check().some(e=>e.includes('checksum mismatch')));
});
test('test captures and other APK identities cannot enter current gallery',t=>{
  const f=fixture(t);f.manifest.screenshots[0].classification='instrumented-test';f.manifest.screenshots[0].buildId='old';f.write();
  const e=f.check();assert.ok(e.some(s=>s.includes('ordinary product')));assert.ok(e.some(s=>s.includes('selected-build mismatch')));
});
test('private local links and absent documents are rejected',t=>{
  const f=fixture(t);fs.appendFileSync(path.join(f.root,'README.md'),'\n[Private](.local/planning/index.md)\n');fs.unlinkSync(path.join(f.root,'docs/technical.md'));
  const e=f.check();assert.ok(e.some(s=>s.includes('private/machine')));assert.ok(e.some(s=>s.includes('Missing document')));
});
test('HTML images used by the guide require alternative text and a manifest record',t=>{
  const f=fixture(t);fs.appendFileSync(path.join(f.root,'docs/features.md'),'\n<img src="images/home.png" width="320" alt="">\n');
  assert.ok(f.check().some(e=>e.includes('empty image alternative text')));
});
