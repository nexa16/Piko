const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const J=require('./round2-json.js'),S=require('./round2-speed.js'),samples=require('./sample-data.js');
const source=fs.readFileSync(path.join(__dirname,'round2.js'),'utf8');
const copy={};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../shared/copy.js'),'utf8'),copy);
function section(start,end){const from=source.indexOf(start),to=source.indexOf(end,from);assert.ok(from>=0&&to>from);return source.slice(from,to);}
function model(locale='en'){
  const collections=samples.createCollections().map((c,i)=>({...c,id:'c'+i,entries:c.entries.map((e,j)=>({...e,id:i+'-'+j,categoryAssignments:[],learning:J.freshLearning()}))}));
  const views=new Map(collections.map(c=>[c.id,{search:'',filters:{},manual:[],selecting:false}]));
  const ctx={J,S,collections,views,s:{book:0},editor:null,manual:new Set(),poolSize:5,speedDirection:J.directions[0],game:null,round:null};
  ctx.C=()=>collections[ctx.s.book];ctx.V=()=>views.get(ctx.C().id);ctx.word=id=>ctx.C().entries.find(e=>e.id===id);
  ctx.esc=value=>String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  ctx.raw=(key,params={})=>copy.PIKO_COPY.entries[key][locale].replace(/\{(\w+)\}/g,(_,key)=>params[key]);
  ctx.t=(key,params)=>ctx.esc(ctx.raw(key,params));ctx.directionLabel=d=>d===J.directions[0]?'KO → DE':'DE → KO';
  ctx.uiIcon=()=>'';ctx.tags=()=>'';ctx.input=(value,attrs)=>'<input value="'+value+'" '+attrs+'>';
  ctx.field=(key,markup)=>'<label>'+ctx.t(key)+markup+'</label>';
  ctx.btn=(key,action,style='ghost')=>'<button class="btn '+style+'" onclick="R2.'+action+'">'+ctx.t(key)+'</button>';
  ctx.dialogActions=primary=>'<div class="r2-dialog-actions">'+primary+'</div>';
  ctx.render=()=>{};ctx.saveEditor=()=>true;
  const nodes=new Map();ctx.document={getElementById:id=>{if(!nodes.has(id))nodes.set(id,{});return nodes.get(id);}};
  vm.createContext(ctx);
  vm.runInContext(section('  function filtered(','  function tags(')+section('  function reviewActions()','  function headingR2()')+section('  function listMarkup()','  function picker(')+section('  function speedIds(','  function renderR2()'),ctx);
  ctx.R2=vm.runInContext('({'+section('    setupSpeed(','    number(')+'})',ctx);
  ctx.R2.show=name=>ctx.opened=name;
  return ctx;
}

// Exercise the actual reveal/grade/minigame handlers with the same Speed model
// and learning-state fixtures; DOM rendering is captured as markup here.
function speedSession(locale='en',ids=['0-0','0-1'],poolSize=5){
  const c=model(locale);c.clone=value=>JSON.parse(JSON.stringify(value));
  c.backButton=()=>'';c.progress=()=>'';c.previous=null;c.previewRound=2;
  vm.runInContext(section('  function reviewCurrent()', '  function undoMarkup()'),c);
  Object.assign(c.R2,vm.runInContext('({'+section('    number(', '    correctPrevious(')+'})',c));
  c.R2.navigate=page=>{c.s.page=page;c.game=null;};
  c.round={mode:'speed',direction:J.directions[0],speed:S.create(ids,poolSize),revealed:false};
  c.render=()=>{if(c.round)c.markup=c.learningR2();};c.render();
  return c;
}

for(const locale of ['en','de'])test('Speed reveal, wrong number taps and a completed game preserve learning in '+locale,()=>{
  const c=speedSession(locale),state=c.clone(c.C()),initial=c.clone(c.round.speed);
  c.R2.reveal();assert.deepEqual(c.round.speed,initial);assert.equal(c.round.revealed,true);
  c.R2.grade(false);assert.equal(c.reviewCurrent(),'0-1');assert.equal(c.game,null);
  c.R2.reveal();c.R2.grade(false);assert.ok(S.needsGame(c.round.speed));
  assert.deepEqual(c.C(),state);assert.equal(c.game.next,1);
  assert.deepEqual(Array.from(c.game.numbers).sort((a,b)=>a-b),[1,2,3,4,5,6,7,8,9,10]);
  const pending=c.clone(c.round.speed);c.R2.reveal();assert.equal(c.round.revealed,false);
  c.R2.number(2);assert.equal(c.game.next,1);assert.deepEqual(c.round.speed,pending);
  for(let n=1;n<=10;n++)c.R2.number(n);
  assert.equal(c.game,null);assert.equal(S.needsGame(c.round.speed),false);
  assert.deepEqual(c.C(),state);assert.equal(c.round.speed.ordinal,2);
  assert.equal(c.reviewCurrent(),'0-0');c.R2.reveal();c.R2.grade(true);
  assert.equal(c.reviewCurrent(),'0-1');assert.equal(c.game,null);
  c.R2.reveal();c.R2.grade(true);assert.equal(c.game.next,1);
  assert.equal(c.round.speed.ordinal,4);assert.equal(c.round.speed.completed,0);
  assert.deepEqual(c.C(),state);
});

test('five one-word attempts have four games and preserve completion-only reset effects',()=>{
  const c=speedSession('en',['0-0']),e=c.word('0-0'),before=c.clone(e.learning);let games=0;
  for(const [index,correct] of [false,false,true,true,true].entries()){
    if(index){assert.ok(c.game);for(let n=1;n<=10;n++)c.R2.number(n);games++;}
    c.R2.reveal();c.R2.grade(correct);
    if(index<4)assert.deepEqual(e.learning,before);
  }
  assert.equal(games,4);assert.equal(c.round,null);assert.equal(c.game,null);assert.equal(c.s.page,'detail');
  assert.equal(e.learning.targetToNative.generation,before.targetToNative.generation+1);
  assert.equal(e.learning.targetToNative.speedCompleted,true);
  assert.deepEqual(e.learning.targetToNative.reviews,before.targetToNative.reviews);
  assert.deepEqual(e.learning.nativeToTarget,before.nativeToTarget);
});

test('error-free Speed completion adds only its marker and has no final game',()=>{
  const c=speedSession('en',['0-0']),e=c.word('0-0'),before=c.clone(e.learning);
  c.R2.reveal();c.R2.grade(true);
  assert.equal(c.round,null);assert.equal(c.game,null);assert.equal(c.s.page,'detail');
  assert.deepEqual(e.learning,{...before,targetToNative:{...before.targetToNative,speedCompleted:true}});
});

test('directional Speed availability uses each direction, preserving collection order',()=>{
  const c=model();assert.equal(c.speedIds('targetToNative').length,5);assert.equal(c.speedIds('nativeToTarget').length,5);
  assert.equal((c.speedActions().match(/class="btn r2-speed-action"/g)||[]).length,2);
  c.C().entries.forEach(e=>e.learning.targetToNative.speedCompleted=true);
  assert.equal(c.speedIds('targetToNative').length,0);
  const single=c.speedActions();assert.equal((single.match(/class="btn r2-speed-action"/g)||[]).length,1);
  assert.match(single,/setupSpeed\('nativeToTarget'\)/);assert.doesNotMatch(single,/targetToNative/);
  c.C().entries.forEach(e=>e.learning.nativeToTarget.reviews.push({generation:0}));
  assert.equal(c.speedActions(),'');
});
test('round-2 Speed only uses filtered new words; stale manual selection cannot override it',()=>{
  const c=model();c.C().entries.forEach(e=>e.learning.targetToNative.speedCompleted=true);
  c.V().search='missing';c.V().manual=['0-3','0-1'];
  assert.deepEqual(Array.from(c.speedIds('targetToNative')),[]);
  c.s.book=1;assert.equal(c.speedIds('targetToNative').length,3);
  c.s.book=0;assert.equal(c.speedIds('targetToNative').length,0);
  c.V().search='';assert.equal(c.speedIds('nativeToTarget').length,5);
});
test('manual selection controls are absent and visible directional counts match eligibility',()=>{
  const c=model();c.V().manual=['0-2'];c.V().selecting=true;
  assert.doesNotMatch(c.listMarkup(),/type="checkbox"/);
  assert.equal(c.R2.toggleSelection,undefined);assert.equal(c.speedIds().length,5);
  c.V().search='Apfel';assert.equal(c.speedIds().length,1);
  assert.match(c.speedActions(),/<span>KO → DE · 1<\/span>/);
  assert.match(c.speedActions(),/<span>DE → KO · 1<\/span>/);
});
for(const locale of ['en','de'])for(const direction of J.directions)test('Speed setup keeps the clicked '+direction+' without a second choice in '+locale,()=>{
  const c=model(locale);c.R2.setupSpeed(direction);assert.equal(c.speedDirection,direction);assert.equal(c.opened,'speed');
  let html=c.speedSetup();assert.ok(html.includes('<p class="meta r2-speed-direction">'+c.directionLabel(direction)+'</p>'));
  assert.match(html,/id="r2-pool"/);assert.match(html,/class="r2-warning"/);assert.doesNotMatch(html,/<select|<option|<details|<summary|type="checkbox"|speedDirection\(/);
  assert.equal(c.R2.speedDirection,undefined);
  assert.ok(html.includes(c.t('r2.speedNewCount',{count:5})));
  assert.ok(html.includes(c.t('r2.speedResetWarning')));
  c.V().manual=['0-0','0-2'];c.V().search='Apfel';html=c.speedSetup();assert.ok(html.includes(c.t('r2.speedNewOne')));
  c.R2.pool('3');assert.equal(c.speedDirection,direction);
  c.R2.startSpeed();assert.equal(c.round.direction,direction);assert.equal(c.round.speed.total,1);
});
test('zero-eligible and invalid-pool launches do not create a Speed round',()=>{
  const c=model();c.C().entries.forEach(e=>e.learning.targetToNative.speedCompleted=true);
  c.R2.setupSpeed('targetToNative');assert.equal(c.opened,undefined);c.R2.startSpeed();assert.equal(c.round,null);
  c.R2.setupSpeed('nativeToTarget');c.R2.pool('0');c.R2.startSpeed();assert.equal(c.round,null);
  c.R2.pool('2');c.R2.startSpeed();assert.equal(c.round.direction,'nativeToTarget');
});
test('regular action emphasis follows visible order, independent of Speed eligibility',()=>{
  const c=model();c.C().entries.forEach(e=>e.learning.targetToNative.card.lastReview='2026-10-15T00:00:00Z');
  const html=c.reviewActions();assert.match(html,/r2-review-primary/);assert.doesNotMatch(html,/r2-review-secondary/);assert.match(html,/DE → KO/);
  assert.equal(c.speedIds('targetToNative').length,5);
});
test('Speed half-width grid and warning colors consume canonical configuration with readable contrast',()=>{
  const config={};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../shared/design-config.js'),'utf8'),config);
  const p=config.PIKO_DESIGN.previews.round2;
  const luminance=hex=>{const rgb=hex.slice(1).match(/../g).map(x=>parseInt(x,16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722;};
  for(const [bg,fg] of [[p.warningBackground,p.warningText],[p.reviewSecondaryBackground,p.reviewSecondaryText]]){
    const a=luminance(bg),b=luminance(fg);assert.ok((Math.max(a,b)+.05)/(Math.min(a,b)+.05)>=4.5);
  }
  const css=fs.readFileSync(path.join(__dirname,'round2.css'),'utf8');
  assert.match(css,/\.r2-speed-actions\{[^}]*grid-template-columns:repeat\(2,minmax\(0,1fr\)\)/);
  assert.match(css,/\.r2-warning\{[^}]*var\(--r2-warning-border\)/);
  assert.match(css,/\.btn\.r2-speed-action\{background:var\(--piko-tint\);color:var\(--piko-primary\)/);
  assert.match(css,/#r2-review-actions \.review-cta\{margin:0/);
});
