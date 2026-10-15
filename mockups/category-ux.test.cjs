const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'round2.js'),'utf8');
const copy={};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../shared/copy.js'),'utf8'),copy);
function section(start,end){return source.slice(source.indexOf(start),source.indexOf(end,source.indexOf(start)));}
function model(locale='en'){
  const dimension={id:'topic',name:'Topic',mode:'multiple',values:[{id:'food',name:'Food'},{id:'school',name:'School'}]};
  const entry={id:'word',targetText:'사과',nativeText:'Apfel',categoryAssignments:[{dimensionId:'topic',valueIds:['food']}],learning:{untouched:true}};
  const collection={categoryDimensions:[dimension],entries:[entry]},view={search:'Apfel',filters:{topic:['school']}};
  let sequence=0;
  const ctx={J:require('./round2-json.js'),s:{modal:'r2.assign'},modalData:{dimension:'topic',original:['food'],selected:['food']},editor:{original:structuredClone(entry),draft:structuredClone(entry)},entry:null,C:()=>collection,V:()=>view,id:()=>`new-${++sequence}`,clone:structuredClone,saveEditor:()=>true,render:()=>{},modalR2:()=>{},fitDialog:()=>{},bindVocabularySwipe:()=>{},listMarkup:()=>'',learningActions:()=>''};
  ctx.raw=(key,p={})=>copy.PIKO_COPY.entries[key][locale].replace(/\{(\w+)\}/g,(_,k)=>p[k]);ctx.esc=String;ctx.t=ctx.raw;ctx.uiIcon=()=>'<span class="icon"></span>';
  ctx.input=(v,a)=>`<input value="${v}" ${a}>`;ctx.field=(k,h)=>`<label>${ctx.t(k)}${h}</label>`;
  ctx.icon=(k,a)=>`<button onclick="R2.${a}">${ctx.t(k)}</button>`;ctx.btn=ctx.icon;
  const nodes=new Map();ctx.node=id=>{if(!nodes.has(id))nodes.set(id,{value:'',focus(){ctx.focused=id;}});return nodes.get(id);};
  ctx.document={getElementById:ctx.node,querySelector:()=>ctx.node('selector'),querySelectorAll:()=>[]};
  ctx.language=require('./sample-data.js').languageKey;
  vm.createContext(ctx);vm.runInContext(section('  const choices =','  const progress =')+section('  function categoryMode(','  function modalR2()'),ctx);
  ctx.R2=vm.runInContext('({'+section('    search(value)','    edit(eid)')+section('    assign(d,v','    removeWord(eid)')+'})',ctx);
  ctx.R2.close=()=>{ctx.s.modal='';};ctx.R2.show=(key,data)=>{ctx.s.modal='r2.'+key;ctx.modalData=data;};return ctx;
}
test('clearing filters stays pending until Apply and keeps search; clearing search keeps filters',()=>{
  const c=model();c.s.modal='r2.filters';c.modalData={filters:structuredClone(c.V().filters),original:structuredClone(c.V().filters)};c.R2.clearFilters();assert.equal(c.V().search,'Apfel');assert.equal(Object.keys(c.modalData.filters).length,0);assert.deepEqual(c.V().filters,{topic:['school']});assert.equal(c.s.modal,'r2.filters');c.R2.applySelection();assert.equal(Object.keys(c.V().filters).length,0);
  c.V().filters={topic:['food']};c.R2.clearSearch();assert.equal(c.V().search,'');assert.deepEqual(c.V().filters,{topic:['food']});assert.equal(c.focused,'r2-search');
});
test('inline value creation validates and preserves popup, text, assignments and learning',()=>{
  const c=model(),before=structuredClone(c.editor.draft);c.R2.beginValue();assert.equal(c.s.modal,'r2.assign');assert.equal(c.modalData.adding,true);
  c.node('r2-value-name').value=' food ';c.R2.saveValue();assert.equal(c.C().categoryDimensions[0].values.length,2);assert.ok(c.node('r2-modal-error').textContent);
  c.node('r2-value-name').value=' Travel ';c.R2.saveValue();assert.equal(c.C().categoryDimensions[0].values.at(-1).name,'Travel');assert.equal(c.s.modal,'r2.assign');assert.equal(c.modalData.adding,false);assert.deepEqual(c.editor.draft,before);
});
test('assignment is staged, and Apply appears only while selection differs from opening',()=>{
  const c=model();assert.equal(c.selectionChanged(),false);c.R2.assign('topic','school',true);assert.equal(c.modalData.selected.length,2);assert.deepEqual(c.editor.draft.categoryAssignments[0].valueIds,['food']);assert.equal(c.node('r2-selection-actions').hidden,false);
  c.R2.assign('topic','school',false);assert.equal(c.selectionChanged(),false);assert.equal(c.node('r2-selection-actions').hidden,true);
  c.R2.assign('topic','school',true);c.R2.applySelection();assert.equal(c.editor.draft.categoryAssignments[0].valueIds.length,2);assert.equal(c.s.modal,'');
});
test('single assignment replaces values only on Apply; dismissal leaves entry intact',()=>{
  const c=model();c.C().categoryDimensions[0].mode='single';c.R2.assign('topic','school',true);assert.deepEqual(Array.from(c.modalData.selected),['school']);assert.deepEqual(c.editor.draft.categoryAssignments[0].valueIds,['food']);c.R2.close();assert.deepEqual(c.editor.draft.categoryAssignments[0].valueIds,['food']);
  c.s.modal='r2.assign';c.R2.applySelection();assert.deepEqual(Array.from(c.editor.draft.categoryAssignments[0].valueIds),['school']);
});
test('multiple-to-single validates saved entries and unsaved drafts without losing mode/name',()=>{
  const c=model();c.s.modal='r2.menu';c.modalData.mode='single';c.node('r2-category-name').value='Topic renamed';c.editor.draft.categoryAssignments[0].valueIds.push('school');c.R2.saveCategory();assert.equal(c.C().categoryDimensions[0].mode,'multiple');assert.equal(c.C().categoryDimensions[0].name,'Topic');
  c.editor.draft.categoryAssignments[0].valueIds.pop();c.R2.saveCategory();assert.equal(c.C().categoryDimensions[0].mode,'single');assert.equal(c.C().categoryDimensions[0].name,'Topic renamed');assert.equal(c.s.modal,'r2.menu');
});
test('name and mode are one pending form; saving validates both together',()=>{
  const c=model(),d=c.C().categoryDimensions[0];c.s.modal='r2.menu';c.modalData.name='Unfinished rename';c.R2.changeCategoryMode('single');assert.equal(d.mode,'multiple');assert.equal(d.name,'Topic');assert.equal(c.categoryChanged(d),true);
  c.node('r2-category-name').value='Unfinished rename';c.editor.draft.categoryAssignments[0].valueIds.push('school');c.R2.saveCategory();assert.equal(d.mode,'multiple');assert.ok(c.node('r2-modal-error').textContent);
  c.editor.draft.categoryAssignments[0].valueIds.pop();c.R2.saveCategory();assert.equal(d.mode,'single');assert.equal(d.name,'Unfinished rename');assert.equal(c.categoryChanged(d),false);
});
test('category deletion returns to expanded menu and preserves unrelated filters, words and learning',()=>{
  const c=model();c.s.modal='r2.menu';c.modalData.expanded=true;c.V().filters.topic=['food','school'];c.R2.confirmCategoryDelete('food');assert.equal(c.s.modal,'r2.deleteCategory');c.R2.cancelCategoryDelete();assert.equal(c.s.modal,'r2.menu');assert.equal(c.C().categoryDimensions[0].values.length,2);
  c.R2.confirmCategoryDelete('food');c.R2.deleteCategory();assert.equal(c.s.modal,'r2.menu');assert.equal(c.modalData.expanded,true);assert.equal(c.C().entries.length,1);assert.deepEqual(c.C().entries[0].learning,{untouched:true});assert.deepEqual(c.V().filters.topic,['school']);assert.equal(c.editor.draft.categoryAssignments[0].valueIds.length,0);
});
for(const locale of ['en','de'])test('category controls use inline forms and visible two-choice radios in '+locale,()=>{
  const c=model(locale),d=c.C().categoryDimensions[0];c.modalData.expanded=true;
  assert.equal((c.categoryMode('multiple').match(/type="radio"/g)||[]).length,2);assert.doesNotMatch(c.categoryMode(),/<select/);
  assert.doesNotMatch(c.categoryManager(),/navigate\(|show\('value'/);assert.ok(c.categoryManager().includes(c.t('r2.editCategories')));
  const form=c.dimensionForm(d);assert.match(form,/id="r2-category-actions" hidden/);assert.ok(form.indexOf('r2-category-actions')>form.indexOf('</fieldset>'));assert.doesNotMatch(form,/r2-inline-input/);
  c.modalData.adding=true;assert.match(c.assignmentPicker(d),/id="r2-value-name"/);assert.match(c.assignmentPicker(d),/id="r2-value-search" hidden/);assert.doesNotMatch(c.assignmentPicker(d),/<h3/);
});
test('search is enabled only when full values overflow, stays while querying, and adapts to resize',()=>{
  const c=model(),list={children:[],scrollHeight:88,clientHeight:88},search={hidden:true,querySelector:()=>({value:c.modalData.query||''})};let resize;
  c.window={addEventListener:(_,fn)=>resize=fn,removeEventListener:()=>{}};c.document.getElementById=()=>search;c.document.querySelector=()=>list;c.R2.findValue=()=>{};
  c.bindCategoryPicker();assert.equal(search.hidden,true);list.scrollHeight=440;resize();assert.equal(search.hidden,false);list.scrollHeight=88;c.modalData.query='foo';resize();assert.equal(search.hidden,false);c.modalData.query='';list.scrollHeight=0;resize();assert.equal(search.hidden,true);
});
test('no-modal render clears the previous popup without looking up an empty copy key',()=>{
  const c=model();c.s.modal='';c.categoryCleanup=()=>{};c.dialogCleanup=()=>{};c.modalHeader=()=>{throw Error('Must not build a header without a modal');};c.node('overlay').innerHTML='old popup';
  vm.runInContext(section('  function modalR2()','  function speedIds('),c);c.modalR2();assert.equal(c.node('overlay').innerHTML,'');assert.equal(c.node('overlay').onkeydown,null);
});
test('category chips use a separate grid row and absent assignments create no empty chip row',()=>{
  const c=model();c.editor=null;c.filtered=()=>c.C().entries;c.tags=()=>'<span class="r2-tag">Food</span>';vm.runInContext(section('  function listMarkup()','  function picker('),c);
  assert.match(c.listMarkup(),/<span>Apfel<\/span>.*<span class="r2-word-tags">/);c.tags=()=>'';assert.doesNotMatch(c.listMarkup(),/r2-word-tags/);
  assert.match(fs.readFileSync(path.join(__dirname,'round2.css'),'utf8'),/\.r2-word-tags\{grid-column:1\/-1/);
});

test('filter changes and reversions toggle Apply without changing active filtering',()=>{
  const c=model();c.s.modal='r2.filters';c.modalData={original:{topic:['school']},filters:{topic:['school']}};
  c.R2.filter('topic','food',true);assert.equal(c.node('r2-selection-actions').hidden,false);assert.deepEqual(c.V().filters,{topic:['school']});
  c.R2.filter('topic','food',false);assert.equal(c.node('r2-selection-actions').hidden,true);c.R2.filter('topic','school',false);c.R2.close();assert.deepEqual(c.V().filters,{topic:['school']});
});

test('adding a value retains unconfirmed assignment changes and does not apply them',()=>{
  const c=model();c.R2.assign('topic','school',true);c.R2.beginValue();c.node('r2-value-name').value='Travel';c.R2.saveValue();
  assert.deepEqual(Array.from(c.modalData.selected),['food','school']);assert.deepEqual(c.editor.draft.categoryAssignments[0].valueIds,['food']);assert.equal(c.s.modal,'r2.assign');assert.equal(c.selectionChanged(),true);
});

test('new and edited dimension confirmation is below both fields and disappears on revert',()=>{
  const c=model();c.s.modal='r2.dimension';c.modalData={};assert.match(c.dimensionForm(),/id="r2-category-actions" hidden/);
  c.R2.categoryDraft('name','Difficulty');assert.equal(c.node('r2-category-actions').hidden,false);c.R2.categoryDraft('name','');assert.equal(c.node('r2-category-actions').hidden,true);
  c.R2.changeCategoryMode('multiple');assert.equal(c.node('r2-category-actions').hidden,false);c.R2.changeCategoryMode('single');assert.equal(c.node('r2-category-actions').hidden,true);
});

for(const locale of ['en','de'])test('all round-2 popup purposes share the accepted controls in '+locale,()=>{
  const c=model(locale);c.C().name='Korean Basics';c.categoryCleanup=()=>{};c.dialogCleanup=()=>{};c.bindDialogLayout=()=>{};c.bindCategoryPicker=()=>{};c.due=()=>[{}];c.directionLabel=d=>d;c.J={...c.J,directions:['targetToNative','nativeToTarget']};c.speedSetup=()=>c.dialogActions(c.btn('learn.start','startSpeed()'));
  c.modalHeader=(id,key,closeId,action)=>'<header class="summary-header"><h2 id="'+id+'">'+c.t(key)+'</h2><button id="'+closeId+'" onclick="'+action+'">'+c.t('common.close')+'</button></header>';
  const host=c.node('overlay');host.querySelector=()=>({focus(){}});vm.runInContext(section('  function modalR2()','  function speedIds('),c);
  for(const key of ['menu','newCollection','rename','direction','assign','filters','dimension','deleteCategory','deleteCollection','speed','entryExit']){
    c.s.modal='r2.'+key;c.modalData={dimension:'topic',original:['food'],selected:['food']};if(key==='dimension')c.modalData={};if(key==='filters')c.modalData={original:{},filters:{}};
    c.modalR2();const html=host.innerHTML;assert.match(html,/role="dialog" aria-modal="true"/);assert.match(html,/r2-modal-body/);
    if(['deleteCategory','deleteCollection','entryExit'].includes(key)){
      assert.doesNotMatch(html,/id="r2-close"/);assert.match(html,/data-dialog-safe/);assert.match(html,/data-dialog-primary/);assert.ok(html.indexOf('data-dialog-safe')<html.indexOf('data-dialog-primary'));
      assert.ok(html.includes(c.t(key==='entryExit'?'entry.continue':'action.cancel')));
    }else assert.match(html,/id="r2-close"/);
    if(['assign','filters'].includes(key))assert.match(html,/id="r2-selection-actions" hidden/);
    if(key==='newCollection')assert.ok(html.includes(c.t('action.create')));
    if(key==='direction')assert.doesNotMatch(html,/r2-dialog-actions/);
  }
});

test('unchanged or reverted category forms cannot save through Enter or another stale action',()=>{
  const c=model(),d=c.C().categoryDimensions[0];let renders=0;c.modalR2=()=>renders++;c.s.modal='r2.menu';
  c.modalData.name=' Topic ';c.node('r2-category-name').value=' Topic ';assert.equal(c.categoryChanged(d),false);c.R2.saveCategory();assert.equal(renders,0);assert.equal(d.name,'Topic');
  c.R2.beginValue('food');renders=0;c.R2.categoryDraft('valueName',' Food ');c.node('r2-value-name').value=' Food ';
  assert.equal(c.node('r2-value-save').hidden,true);c.R2.saveValue();assert.equal(renders,0);assert.equal(c.modalData.adding,true);assert.equal(d.values[0].name,'Food');
});

function usePopupLifecycle(c){
  c.dialogFocus=null;c.dialogFocusAction=null;c.app={querySelectorAll:()=>[]};
  Object.assign(c.R2,vm.runInContext('({'+section('    show(key','    quick(index)')+'})',c));
}

test('dismissing assignment/filter drafts restores focus and reopening starts from committed values',()=>{
  const c=model();usePopupLifecycle(c);const opener={isConnected:true,getAttribute:()=>"R2.show('assign')",focus(){c.restored=true;}};c.document.activeElement=opener;c.s.modal='';
  c.R2.show('assign',{dimension:'topic'});c.R2.assign('topic','school',true);c.R2.close();assert.equal(c.restored,true);assert.deepEqual(c.editor.draft.categoryAssignments[0].valueIds,['food']);
  c.R2.show('assign',{dimension:'topic'});assert.deepEqual(Array.from(c.modalData.selected),['food']);c.R2.close();
  c.R2.show('filters');c.R2.filter('topic','food',true);c.R2.close();c.R2.show('filters');assert.deepEqual(c.modalData.filters,{topic:['school']});
});

test('safe confirmation dismissal keeps entry drafts and pending category management form values',()=>{
  const c=model();usePopupLifecycle(c);c.entry={draft:{targetText:'Unfinished',nativeText:'',categoryAssignments:[]}};const before=structuredClone(c.entry);c.s.modal='r2.entryExit';c.R2.close();assert.deepEqual(c.entry,before);
  c.s.modal='r2.menu';c.modalData={dimension:'topic',expanded:true,name:'Pending title',mode:'single'};c.R2.confirmCategoryDelete('food');c.R2.close();
  assert.equal(c.s.modal,'r2.menu');assert.equal(c.modalData.name,'Pending title');assert.equal(c.modalData.mode,'single');assert.equal(c.C().categoryDimensions[0].values.length,2);
});

test('summary replacement disposes prior handlers before binding its viewport layout',()=>{
  const c=model();let categories=0,dialogs=0,layout=0;c.categoryCleanup=()=>categories++;c.dialogCleanup=()=>dialogs++;c.bindDialogLayout=()=>layout++;
  const host=c.node('overlay');host.onkeydown=()=>{throw Error('stale modal handler');};c.overlay=()=>host.innerHTML='summary';c.s.modal='summary.title';
  vm.runInContext(section('  function modalR2()','  function speedIds('),c);c.modalR2();assert.equal(categories,1);assert.equal(dialogs,1);assert.equal(layout,1);assert.equal(host.onkeydown,null);assert.equal(host.innerHTML,'summary');
});

test('switching implementation rounds disposes modal listeners and keyboard callbacks',()=>{
  const c=model();let categories=0,dialogs=0;c.categoryCleanup=()=>categories++;c.dialogCleanup=()=>dialogs++;c.entryCleanup=()=>{};c.clearTimeout=()=>{};c.timer=0;
  c.previewRound=2;c.r1State={page:'collections',modal:''};c.r2State={};c.document.documentElement={dataset:{}};c.URL=URL;c.location='http://localhost/mockups/piko-mockup.html?round=2';c.history={replaceState(){}};
  const host=c.node('overlay');host.onkeydown=()=>{};host.innerHTML='popup';
  const methods=vm.runInContext('({'+section('    setRound(value)','    reset()')+'})',c);methods.setRound(1);
  assert.equal(categories,1);assert.equal(dialogs,1);assert.equal(host.onkeydown,null);assert.equal(host.innerHTML,'');assert.equal(c.previewRound,1);
});

test('reused summary dismissal disposes round-2 viewport listeners without changing round-1 dismissal',()=>{
  const c=model();let cleanups=0,closed=0;c.previewRound=2;c.cleanupDialog=()=>cleanups++;c.baseCloseSummary=()=>closed++;
  vm.runInContext(section('  closeSessionSummary=','  go='),c);c.closeSessionSummary();assert.equal(cleanups,1);assert.equal(closed,1);
  c.previewRound=1;c.closeSessionSummary();assert.equal(cleanups,1);assert.equal(closed,2);
});

test('inline form controls cannot implicitly submit another action and retain explicit Enter handlers',()=>{
  const c=model();c.button=(key,action)=>'<button onclick="'+action+'">'+c.t(key)+'</button>';
  vm.runInContext(section('  const btn =','  const field ='),c);c.modalData.adding=true;c.modalData.valueName='Travel';
  const value=c.valueForm();assert.match(value,/onsubmit="event.preventDefault\(\);R2.saveValue\(\)"/);assert.equal((value.match(/type="button"/g)||[]).length,2);
  const dimension=c.dimensionForm(c.C().categoryDimensions[0]);assert.match(dimension,/onsubmit="event.preventDefault\(\);R2.saveCategory\(\)"/);assert.match(dimension,/type="button"[^>]*onclick="R2.saveCategory\(\)"/);
});
