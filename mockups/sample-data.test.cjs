const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const samples=require('./sample-data.js'),json=require('./round2-json.js');
const base=fs.readFileSync(path.join(__dirname,'mockup.js'),'utf8');
const next=fs.readFileSync(path.join(__dirname,'round2.js'),'utf8');
const copyContext={};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../shared/copy.js'),'utf8'),copyContext);
function section(source,start,end){const from=source.indexOf(start),to=source.indexOf(end,from);assert.ok(from>=0&&to>from);return source.slice(from,to);}
function context(locale='en'){
  const raw=(key,params={})=>copyContext.PIKO_COPY.entries[key][locale].replace(/\{([a-z]+)\}/g,(_,name)=>params[name]);
  const esc=value=>String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const t=(key,params)=>esc(raw(key,params));let sequence=0;
  return vm.createContext({PikoSampleData:samples,J:json,s:{book:0},raw,t,esc,
    button:key=>'<button>'+t(key)+'</button>',btn:key=>'<button>'+t(key)+'</button>',uiIcon:()=>'',head:()=>'',
    emptyCollections:false,scope:'minimum',id:()=>String(++sequence),reviewRounds:new Map(),manual:new Set(),clearTimeout:()=>{},timer:0,
    language:samples.languageKey});
}
function baseModel(ctx){vm.runInContext(section(base,'const sampleCollections=','let collectionAutoName='),ctx);}
function nextModel(ctx){vm.runInContext(section(next,'  function initialize()','  function filtered(')+'initialize();',ctx);}
function baseOverview(ctx){return vm.runInContext(section(base,'function overview(){','function metrics(')+'overview();',ctx);}
function nextOverview(ctx){return vm.runInContext(section(next,'  const due =','  function tags(')+section(next,'  function overviewR2()','  function reviewActions(')+'overviewR2();',ctx);}
const metadata=html=>[...html.matchAll(/<span class="meta">([^<]+)<\/span>/g)].map(m=>m[1]);
const names=html=>[...html.matchAll(/<strong>([^<]+)<\/strong>/g)].map(m=>m[1]);
const counts=html=>[...html.matchAll(/<span class="count">(\d+)<\/span>/g)].map(m=>Number(m[1]));

test('sample collections return independent complete fixtures for both rounds',()=>{
  const a=samples.createCollections(),b=samples.createCollections();
  assert.deepEqual(a,b);assert.deepEqual(a.map(c=>c.entries.length),[5,3,3]);
  a[0].name='Changed';a[0].entries[0].nativeText='Changed';a.pop();
  assert.deepEqual(b,samples.createCollections());
});
for(const locale of ['en','de'])test('both actual overview renderers show matching localized metadata in '+locale,()=>{
  const ctx=context(locale);baseModel(ctx);nextModel(ctx);
  const before=baseOverview(ctx),after=nextOverview(ctx);
  assert.deepEqual(names(before),['Korean Basics','French A1','English Notes']);
  assert.deepEqual(names(after),names(before));assert.deepEqual(metadata(after),metadata(before));
  assert.deepEqual(metadata(after),locale==='en'?['Korean · German · 5 entries','French · German · 3 entries','English · German · 3 entries']:['Koreanisch · Deutsch · 5 Einträge','Französisch · Deutsch · 3 Einträge','Englisch · Deutsch · 3 Einträge']);
  assert.deepEqual(counts(before),[5,3,3]);assert.deepEqual(counts(after),[10,6,6]);
  assert.equal((after.match(/class="cover" aria-hidden="true"/g)||[]).length,3);
  const pairs=vm.runInContext('books.map((_,i)=>getCollectionEntries(i))',ctx);
  assert.deepEqual(JSON.parse(JSON.stringify(pairs)),ctx.collections.map(c=>c.entries.map(e=>[e.targetText,e.nativeText])));
});
test('editing/resetting one preview cannot change the other preview or its seed',()=>{
  const ctx=context();baseModel(ctx);nextModel(ctx);
  vm.runInContext("getCollectionEntries(0)[0][1]='Edited only in round 1';books[0][0]='Renamed';",ctx);
  assert.equal(ctx.collections[0].name,'Korean Basics');assert.equal(ctx.collections[0].entries[0].nativeText,'Apfel');
  ctx.collections[0].entries.splice(0,1);vm.runInContext('initialize();',ctx);
  assert.equal(ctx.collections[0].entries.length,5);
  assert.equal(vm.runInContext('getCollectionEntries(0)[0][1]',ctx),'Edited only in round 1');
  assert.equal(samples.createCollections()[0].entries[0].nativeText,'Apfel');
});
test('round-1 review starts with the same actual vocabulary total as round 2',()=>{
  const ctx=context();baseModel(ctx);
  ctx.document={getElementById:()=>({value:'targetNative'})};ctx.go=()=>{};
  vm.runInContext('let reviewSession;'+section(base,'function startReview(){','let dialogReturnFocus=')+'startReview();',ctx);
  assert.equal(vm.runInContext('reviewSession.total',ctx),5);
  assert.equal(vm.runInContext('reviewSession.completed',ctx),0);
  assert.equal(vm.runInContext('reviewSession.correct',ctx),0);
});
