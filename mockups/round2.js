/* Implementation-round prototype controller. Sample data only; never application storage or FSRS. */
(() => {
  const baseRender = render, baseGo = go, baseCloseSummary = closeSessionSummary;
  const clone = value => structuredClone(value), J = PikoR2Json, S = PikoR2Speed;
  const id = () => crypto.randomUUID();
  const previewParams = new URLSearchParams(location.search);
  let previewRound = (previewParams.get('round') || previewParams.get('release')) === '2' ? 2 : 1;
  let r1State = clone(s), r2State = {...clone(s), page:'collections', book:0};
  let collections, views, editor = null, entry = null, round = null, timer = 0, undo = null;
  let renaming=false;
  let scenario = 'default', modalData = {}, jsonText = '', jsonResult = null, jsonMessage = '', groups = ['targetText','nativeText','categoryAssignments'];
  let speedDirection = J.directions[0], poolSize = 5, game = null, previous = null;
  let categoryCleanup = () => {};
  let dialogCleanup = () => {}, fitDialog = () => {};
  let dialogFocus = null, dialogFocusAction = null, reviewRounds = new Map(), entryCleanup = () => {};
  const language = PikoSampleData.languageKey;
  const C = () => collections[s.book];
  const V = () => views.get(C().id);
  const word = eid => C().entries.find(e => e.id === eid);
  const directionLabel = direction => (direction === J.directions[0] ? [C().targetLanguage,C().nativeLanguage] : [C().nativeLanguage,C().targetLanguage]).join(' → ').toUpperCase();
  const btn = (key,action,style='ghost',icon='') => button(key,'R2.'+action,style,icon ? uiIcon(icon)+' ' : '').replace('<button ','<button type="button" ');
  const icon = (key,action,name) => '<button type="button" class="btn ghost icon-button" aria-label="'+t(key)+'" title="'+t(key)+'" onclick="R2.'+action+'">'+uiIcon(name)+'</button>';
  const field = (key,markup) => '<div class="field"><label>'+t(key)+markup+'</label></div>';
  const input = (value,attrs='') => '<input class="input" value="'+esc(value)+'" '+attrs+'>';
  const choices = (key,checked,action,type='checkbox',value='') => '<label class="r2-choice"><input type="'+type+'" '+(checked?'checked':'')+' '+value+' onchange="R2.'+action+'">'+esc(key)+'</label>';
  const progress = (done,total) => '<div class="r2-progress" role="progressbar" aria-valuemin="0" aria-valuemax="'+total+'" aria-valuenow="'+done+'"><span style="width:'+(total ? 100*done/total : 0)+'%"></span></div>';
  const backButton = () => icon(s.page==='learning'?'learn.exit':'common.back',"navigate('detail')",'back');
  function initialize() {
    collections = PikoSampleData.createCollections().map(sample => {
      const d = {id:id(), name:raw('r2.topic'), mode:'multiple', values:[{id:id(),name:raw('r2.food')},{id:id(),name:raw('r2.school')}]};
      return {...sample,id:id(),categoryDimensions:[d],reviewScopes:{targetToNative:{ordinal:0,revision:0},nativeToTarget:{ordinal:0,revision:0}},entries:sample.entries.map((pair,i)=>({...pair,id:id(),categoryAssignments:i<3?[{dimensionId:d.id,valueIds:[d.values[i<2?0:1].id]}]:[],learning:J.freshLearning()}))};
    });
    views = new Map(collections.map(c=>[c.id,{search:'',filters:{}}]));
    editor=null;entry=null;round=null;previous=null;reviewRounds.clear();undo=null;game=null;
    clearTimeout(timer);
    jsonText='';jsonResult=null;jsonMessage='';s.modal='';s.book=0;
  }
  function filtered(c=C()) {
    const view=views.get(c.id),query=J.key(view.search);
    return c.entries.filter(e=>(!query||J.key(e.targetText).includes(query)||J.key(e.nativeText).includes(query)) && Object.entries(view.filters).every(([dimension,values])=>!values.length||e.categoryAssignments.some(a=>a.dimensionId===dimension&&a.valueIds.some(v=>values.includes(v)))));
  }
  const due = (c,direction,subset=c.entries) => subset.filter(e=>e.learning[direction].card.lastReview===null || e.learning[direction].retry);
  function tags(e) {
    return e.categoryAssignments.flatMap(a=>C().categoryDimensions.find(d=>d.id===a.dimensionId)?.values.filter(v=>a.valueIds.includes(v.id))||[]).map(v=>'<span class="r2-tag">'+esc(v.name)+'</span>').join('');
  }
  function head() { return '<header class="home-header"><span class="home-brand">'+t('app.name')+'</span>'+btn('nav.settings',"navigate('settings')",'ghost','settings')+'</header>'; }
  function overviewR2() {
    return head()+'<div class="head collection-heading"><h2>'+t('home.collections')+'</h2>'+btn('action.new',"show('newCollection')",'ghost','plus')+'</div><div class="r2-stack">'+(emptyCollections?'':collections.map((c,index)=>{
      const count=J.directions.reduce((n,d)=>n+due(c,d).length,0);
      return '<article class="card collection-card"><button class="collection-open" onclick="R2.open('+index+')"><span class="cover" aria-hidden="true">'+esc(c.targetLanguage.toUpperCase())+'</span><span class="collection-info"><strong>'+esc(c.name)+'</strong><span class="meta">'+collectionMetadata([language(c.targetLanguage),language(c.nativeLanguage)],c.entries.length)+'</span></span>'+uiIcon('chevron')+'</button>'+(count?'<div class="collection-actions">'+btn('action.review','quick('+index+')','tint','review').replace('</button>',' <span class="count">'+count+'</span></button>')+'</div>':'')+'</article>';
    }).join(''))+(!collections.length||emptyCollections?'<section class="card"><p>'+t('home.emptyDescription')+'</p>'+btn('action.firstCollection',"show('newCollection')",'primary')+'</section>':'')+'</div>';
  }
  function reviewActions() {
    const entries=filtered(),actions=J.directions.filter(d=>due(C(),d,entries).length);
    if(!C().entries.length)return '';
    if(!entries.length)return '<p class="meta">'+t('r2.noMatches')+'</p>';
    return actions.length ? '<div class="r2-review-stack">'+actions.map((d,index)=>'<button class="card review-cta r2-review-'+(index?'secondary':'primary')+'" onclick="R2.startReview(\''+d+'\',true)"><span><strong>'+t('r2.due',{direction:directionLabel(d),count:due(C(),d,entries).length})+'</strong><span class="meta">'+t('action.reviewNow')+'</span></span>'+(index===0?'<img class="r2-review-mascot" src="../app/assets/brand/piko-reading.png" width="64" height="64" alt="" aria-hidden="true" draggable="false">':'')+uiIcon('review')+'</button>').join('')+'</div>' : '<p class="card r2-caught-up">'+t('r2.caughtUp')+'</p>';
  }
  function speedActions() {
    const available=J.directions.filter(d=>speedIds(d).length);
    return available.length?'<div class="r2-speed-actions">'+available.map(d=>'<button class="btn r2-speed-action" aria-label="'+t(speedIds(d).length===1?'r2.speedDirectionOne':'r2.speedDirectionAction',{direction:directionLabel(d),count:speedIds(d).length})+'" onclick="R2.setupSpeed(\''+d+'\')"><span class="r2-speed-label">'+uiIcon('speed')+t('action.speed')+'</span><span>'+t('r2.speedDirectionCount',{direction:directionLabel(d),count:speedIds(d).length})+'</span></button>').join('')+'</div>':'';
  }
  function learningActions() {return reviewActions()+speedActions();}
  function headingR2() {
    return renaming?'<form class="rename-form" onsubmit="event.preventDefault();R2.rename()">'+input(C().name,'id="r2-name" aria-label="'+t('collection.name')+'" required')+icon('action.saveName','rename()','check')+icon('action.cancel','cancelRename()','cancel')+'</form>':'<div class="detail-heading"><h1>'+esc(C().name)+'</h1>'+icon('collection.rename','beginRename()','edit')+'</div>';
  }
  function detailR2() {
    return '<div class="detail-topbar">'+icon('common.back',"navigate('collections')",'back')+'<button class="btn ghost icon-button" aria-label="'+t('r2.menu')+'" onclick="R2.show(\'menu\')">⋮</button></div>'+headingR2()+'<p class="sub r2-detail-sub">'+t('language.'+language(C().targetLanguage))+' · '+t('language.'+language(C().nativeLanguage))+' · '+t('common.entries',{count:C().entries.length})+'</p><div id="r2-review-actions">'+learningActions()+'</div><div class="head r2-vocabulary-heading"><h2>'+t('collection.vocabulary')+'</h2>'+btn('action.new',"navigate('entry')",'ghost','plus').replace('<button ','<button aria-label="'+t('action.addEntry')+'" ')+'</div><div class="r2-toolbar"><div class="r2-search">'+input(V().search,'id="r2-search" type="search" aria-label="'+t('collection.search')+'" placeholder="'+t('collection.search')+'" oninput="R2.search(this.value)"')+icon('r2.clearSearch','clearSearch()','cancel').replace('<button ','<button id="r2-clear-search" '+(V().search?'':'hidden '))+'</div>'+btn('action.filters',"show('filters')",'ghost','filters')+'</div><div id="r2-wordlist" class="r2-list">'+listMarkup()+'</div>'+undoMarkup();
  }
  function listMarkup() {
    const entries=filtered();
    if(!entries.length)return '<section class="card"><p>'+t(C().entries.length?'r2.noMatches':'collection.empty')+'</p>'+(C().entries.length?'<div class="actions">'+(V().search?btn('r2.clearSearch','clearSearch()'):'')+(Object.values(V().filters).some(v=>v.length)?btn('r2.clearFilters','clearFilters()'):'')+'</div>':'')+'</section>';
    return entries.map(e=>editor?.id===e.id?editorMarkup(e):'<article class="vocab-swipe"><button class="btn vocab-delete-action danger" onclick="R2.removeWord(\''+e.id+'\')">'+uiIcon('trash')+t('vocab.delete')+'</button><button class="card row word-row" onclick="R2.edit(\''+e.id+'\')"><strong>'+esc(e.targetText)+'</strong><span>'+esc(e.nativeText)+'</span>'+uiIcon('edit')+(tags(e)?'<span class="r2-word-tags">'+tags(e)+'</span>':'')+'</button></article>').join('');
  }
  function picker(e) {
    return C().categoryDimensions.map(d=>{
      const assigned=e.categoryAssignments.find(a=>a.dimensionId===d.id)?.valueIds||[];
      return '<div class="r2-dimension"><button class="btn ghost" onclick="R2.show(\'assign\',{dimension:\''+d.id+'\'})">'+esc(d.name)+' '+uiIcon('chevron')+'</button><div>'+d.values.filter(v=>assigned.includes(v.id)).map(v=>'<span class="r2-tag">'+esc(v.name)+'</span>').join('')+'</div></div>';
    }).join('')+btn('category.addDimension',"show('dimension')",'ghost','plus');
  }
  function editorMarkup(e) {
    const draft=editor.draft,changed=JSON.stringify(editor.original)!==JSON.stringify(draft);
    return '<article class="card word-inline"><div class="head"><strong>'+t('vocab.inlineEdit')+'</strong><div class="r2-toolbar"><span id="r2-discard">'+(changed?icon('vocab.inlineDiscard','discard()','cancel'):'')+'</span><span id="r2-finish">'+icon(changed?'vocab.inlineFinish':'vocab.inlineCollapse','finish()',changed?'check':'cancel')+'</span></div></div><div class="inline-entry-fields">'+[C().targetLanguage,C().nativeLanguage].map((code,i)=>field('language.'+language(code),input(draft[i?'nativeText':'targetText'],'id="r2-edit-'+i+'" enterkeyhint="'+(i?'done':'next')+'" onkeydown="R2.nextField(event,'+i+')" oninput="R2.updateText('+i+',this.value)"'))).join('')+'</div><p id="r2-editor-error" class="entry-error" role="alert"></p>'+picker(draft)+'<div class="actions">'+btn('vocab.delete',"removeWord('"+e.id+"')",'ghost danger','trash')+'</div><p class="caption">'+t('entry.autoSave')+'</p></article>';
  }
  function validEntry(candidate) {return candidate.targetText.trim()&&candidate.nativeText.trim()&&!C().entries.some(e=>e.id!==candidate.id&&J.pairKey(e)===J.pairKey(candidate));}
  function saveEditor() {
    if(!editor)return true;
    const valid=validEntry(editor.draft),error=document.getElementById('r2-editor-error');
    if(error)error.textContent=valid?'':raw(editor.draft.targetText.trim()&&editor.draft.nativeText.trim()?'vocab.inlineDuplicate':'entry.required');
    if(valid)Object.assign(word(editor.id),clone(editor.draft));
    return !!valid;
  }
  function jsonR2() {
    const result=jsonResult;
    return backButton()+'<h1>'+t('json.title')+'</h1><p>'+esc(C().name)+'</p><p class="meta">'+t('r2.jsonNotice')+'</p><section class="card"><div class="actions"><label class="btn tint">'+t('json.file')+'<input type="file" class="json-file" accept=".json,application/json" onchange="R2.file(this)"></label>'+btn('json.paste','paste()')+btn('json.example','copy(true)')+'</div>'+field('json.input','<textarea class="input json-input" rows="9" spellcheck="false" oninput="R2.jsonEdit(this.value)">'+esc(jsonText)+'</textarea>')+'<fieldset><legend>'+t('r2.jsonGroups')+'</legend>'+['targetText','nativeText','categoryAssignments'].map(g=>choices(raw('r2.'+g),groups.includes(g),"group('"+g+"',this.checked)")).join('')+'</fieldset><div class="actions">'+btn('json.analyze','analyze()','primary')+'</div></section><div id="r2-json-result">'+(result?'<section class="card"><h2>'+t('json.review')+'</h2><p>'+t('r2.jsonSummary',{added:result.counts.new,updated:result.counts.updated,unchanged:result.counts.unchanged,errors:result.counts.errors})+'</p>'+result.errors.map(e=>'<p class="entry-error">'+(e.row?e.row+': ':'')+t(e.code)+'</p>').join('')+(result.keptCategoryMetadata?'<p>'+t('r2.jsonMetadata')+'</p>':'')+(result.next?btn('import.confirm','applyJson()','primary'):'')+'</section>':'')+'</div><p role="status">'+esc(jsonMessage)+'</p><section class="card"><h2>'+t('json.export')+'</h2><div class="actions">'+btn('json.download','download()','tint')+btn('json.copy','copy(false)')+'</div></section>';
  }
  function entryR2() {
    if(!entry)entry={draft:{id:id(),targetText:'',nativeText:'',categoryAssignments:[],learning:J.freshLearning()},active:null};
    return '<div class="entry-header">'+backButton()+'<h1>'+t('entry.title')+'</h1>'+icon('entry.complete','completeEntry()','check')+'</div><div class="actions">'+btn('json.title',"navigate('import')",'ghost','upload')+'</div><div class="r2-entry-stack" id="r2-entry-stack">'+C().entries.map((e,i)=>'<article class="card" data-entry="'+e.id+'"><button class="row btn ghost" onclick="R2.activateEntry(\''+e.id+'\')"><span>'+t('entry.number',{count:i+1})+'</span><span>'+t('entry.saved')+'</span></button>'+(entry.active===e.id&&editor?editorMarkup(e):'<p><strong>'+esc(e.targetText)+'</strong><br>'+esc(e.nativeText)+'</p>')+'</article>').join('')+'<article class="card '+(!entry.active?'is-active':'')+'" data-entry="draft"><div class="head"><span>'+t('entry.number',{count:C().entries.length+1})+'</span><span class="meta">'+t('entry.new')+'</span></div>'+[C().targetLanguage,C().nativeLanguage].map((code,i)=>field('language.'+language(code),input(entry.draft[i?'nativeText':'targetText'],'id="r2-draft-'+i+'" enterkeyhint="'+(i?'done':'next')+'" oninput="R2.draftText('+i+',this.value)" onkeydown="R2.draftNext(event,'+i+')"'))).join('')+picker(entry.draft)+'<p id="r2-entry-error" class="entry-error" role="alert"></p><div class="row"><span class="meta">'+t('entry.draft')+'</span>'+icon('action.saveNext','saveEntry()','check')+'</div></article></div>';
  }
  function bindEntry() {
    const stack=document.getElementById('r2-entry-stack');if(!stack)return;
    let userScroll=false,settle=0,programmatic=false;
    const fit=()=>{stack.style.height=Math.max(0,(window.visualViewport?.height||innerHeight)-stack.getBoundingClientRect().top-PIKO_DESIGN.spacing['3'])+'px';};
    const reveal=()=>{fit();const target=document.activeElement.closest?.('[data-entry]');if(!target)return;const region=stack.getBoundingClientRect(),rect=target.getBoundingClientRect(),control=document.activeElement.getBoundingClientRect();programmatic=true;if(rect.height<=region.height){if(rect.bottom>region.bottom)stack.scrollTop+=rect.bottom-region.bottom;if(rect.top<region.top)stack.scrollTop-=region.top-rect.top;}else if(control.bottom>region.bottom)stack.scrollTop+=control.bottom-region.bottom+PIKO_DESIGN.spacing['3'];requestAnimationFrame(()=>programmatic=false);};
    const gesture=()=>userScroll=true;
    stack.addEventListener('pointerdown',gesture);stack.addEventListener('wheel',gesture,{passive:true});
    stack.addEventListener('focusin',()=>requestAnimationFrame(reveal));
    stack.addEventListener('scroll',()=>{if(!userScroll||programmatic)return;clearTimeout(settle);settle=setTimeout(()=>{userScroll=false;if(stack.contains(document.activeElement)&&document.activeElement.matches('input'))return;const bounds=stack.getBoundingClientRect(),center=bounds.top+bounds.height/2;let nearest=null,distance=Infinity;for(const card of stack.children){const rect=card.getBoundingClientRect(),delta=Math.abs(rect.top+rect.height/2-center);if(delta<distance){nearest=card;distance=delta;}}if(nearest&&nearest.dataset.entry!=='draft'&&nearest.dataset.entry!==entry.active)R2.activateEntry(nearest.dataset.entry);},PIKO_DESIGN.previews.round2.entrySettleMs);},{passive:true});
    window.visualViewport?.addEventListener('resize',reveal);window.addEventListener('resize',fit);fit();
    const target=stack.querySelector('[data-entry="'+(entry.active||'draft')+'"]');if(target)stack.scrollTop=target.offsetTop-stack.offsetTop;
    entryCleanup=()=>{clearTimeout(settle);window.visualViewport?.removeEventListener('resize',reveal);window.removeEventListener('resize',fit);};
  }
  function reviewCurrent() {
    if(!round)return null;
    if(round.mode==='speed')return S.current(round.speed);
    const pending=round.pending.find(p=>round.ordinal-p.ordinal>=p.gap||(p.deadline&&Date.now()>=p.deadline));
    if(pending)return pending.id;
    if(round.queue.length)return round.queue[0];
    if(round.pending.length&&!round.pending[0].deadline){round.pending[0].deadline=Date.now()+10000;const state=word(round.pending[0].id)?.learning[round.direction];if(state?.retry)state.retry.waitEligibleAt=new Date(round.pending[0].deadline).toISOString();}
    return null;
  }
  function learningR2() {
    if(!round)return detailR2();
    const speed=round.mode==='speed',done=speed?round.speed.completed:round.completed,total=speed?round.speed.total:round.total;
    let content='';const eid=reviewCurrent();
    if(speed&&S.needsGame(round.speed)) {
      if(!game){const numbers=Array.from({length:10},(_,i)=>i+1);for(let i=9;i>0;i--){const j=Math.floor(Math.random()*(i+1));[numbers[i],numbers[j]]=[numbers[j],numbers[i]];}game={numbers,next:1};}
      content='<section class="card"><h2>'+t('r2.game')+'</h2><p>'+t('r2.gameHint')+'</p><p role="status">'+t('r2.gameNext',{number:game.next})+'</p><div class="r2-game">'+game.numbers.map(n=>'<button class="btn tint" '+(n<game.next?'disabled':'')+' onclick="R2.number('+n+')">'+n+'</button>').join('')+'</div></section>';
    } else if(!eid) {
      const seconds=Math.max(0,Math.ceil(((round.pending?.[0]?.deadline||Date.now())-Date.now())/1000));
      content='<section class="card r2-wait" role="status"><strong>'+seconds+'</strong><p>'+t('r2.wait',{seconds})+'</p></section>';
      timer=setTimeout(()=>{if(previewRound===2&&s.page==='learning')render();},Math.min(1000,Math.max(50,seconds*1000)));
    } else {
      const e=word(eid),forward=round.direction===J.directions[0],prompt=e[forward?'targetText':'nativeText'],answer=e[forward?'nativeText':'targetText'];
      content='<button class="card learning '+(round.revealed?'is-revealed':'')+'" '+(round.revealed?'disabled':'onclick="R2.reveal()"')+'><span class="'+(round.revealed?'answer-pair':'')+'"><span class="word '+(round.revealed?'answer-prompt':'')+'">'+esc(prompt)+'</span>'+(round.revealed?'<span class="answer-divider"></span><span class="word answer-translation">'+esc(answer)+'</span>':'')+'</span>'+(!round.revealed?'<span class="meta reveal-cue">'+uiIcon('book')+t('learn.revealCue')+'</span>':'')+'</button>'+(round.revealed?(!speed?'<label class="review-hard r2-hard"><input type="checkbox" onchange="R2.hard(this.checked)" '+(round.hard?'checked':'')+'>'+t('learn.hard')+'</label>':'')+'<div class="r2-grade">'+btn('action.incorrect','grade(false)','incorrect')+btn('action.correct','grade(true)','correct')+'</div>':'')+(!speed&&!round.revealed&&previous?'<div class="actions review-previous">'+btn('learn.correctPrevious','correctPrevious()','review-correct-previous','back')+'</div>':'');
    }
    return backButton()+'<h1>'+esc(C().name)+'</h1><div class="review-context"><span>'+esc(directionLabel(round.direction))+'</span><span class="meta">'+(speed?t(total===1?'r2.selectedOne':'r2.selected',{count:total}):t('learn.progress',{completed:done,total,correct:round.correct}))+'</span></div>'+progress(done,total)+content;
  }
  function undoMarkup() {return undo&&Date.now()<undo.expires?'<div class="vocabulary-undo" role="status">'+t('vocab.deleted')+btn('vocab.undo','undoDelete()')+'</div>':'';}
  function categoryMode(mode='single') {
    return '<fieldset class="r2-mode"><legend>'+t('r2.mode')+'</legend><div>'+['single','multiple'].map(value=>'<label><input type="radio" name="category-mode" value="'+value+'" '+(mode===value?'checked':'')+' onchange="R2.changeCategoryMode(this.value)"><span>'+t('r2.'+value)+'</span></label>').join('')+'</div></fieldset>';
  }
  const sameValues = (a,b) => JSON.stringify([...a].sort())===JSON.stringify([...b].sort());
  const sameFilters = (a,b) => [...new Set([...Object.keys(a),...Object.keys(b)])].every(key=>sameValues(a[key]||[],b[key]||[]));
  function categoryChanged(d) {
    return (modalData.name??d?.name??'').trim()!==(d?.name||'')||(modalData.mode||d?.mode||'single')!==(d?.mode||'single');
  }
  function selectionChanged() {
    return s.modal==='r2.assign'?!sameValues(modalData.selected,modalData.original):!sameFilters(modalData.filters,modalData.original);
  }
  function dialogActions(primary,safe='',attrs='') {
    return '<div class="r2-dialog-actions" '+attrs+'>'+(safe?'<span data-dialog-safe>'+safe+'</span>':'')+'<span data-dialog-primary>'+primary+'</span></div>';
  }
  function refreshModalActions() {
    const dimension=C().categoryDimensions.find(d=>d.id===modalData.dimension);
    const category=document.getElementById('r2-category-actions');if(category)category.hidden=!categoryChanged(dimension);
    const selection=document.getElementById('r2-selection-actions');if(selection&&['r2.assign','r2.filters'].includes(s.modal))selection.hidden=!selectionChanged();
    const value=document.getElementById('r2-value-save');if(value)value.hidden=(modalData.valueName||'').trim()===(dimension?.values.find(v=>v.id===modalData.value)?.name||'');
    fitDialog();
  }
  function dimensionForm(d) {
    return '<form class="r2-category-form" onsubmit="event.preventDefault();R2.saveCategory()"><div class="field"><label for="r2-category-name">'+t('r2.name')+'</label>'+input(modalData.name??d?.name??'','id="r2-category-name" required oninput="R2.categoryDraft(\'name\',this.value)"')+'</div>'+categoryMode(modalData.mode||d?.mode||'single')+dialogActions(btn(d?'r2.save':'category.addDimension','saveCategory()','primary','check'),'','id="r2-category-actions" '+(categoryChanged(d)?'':'hidden'))+'</form>';
  }
  function valueForm() {
    const original=C().categoryDimensions.find(d=>d.id===modalData.dimension)?.values.find(v=>v.id===modalData.value)?.name||'';
    return '<form class="r2-inline-input" onsubmit="event.preventDefault();R2.saveValue()">'+input(modalData.valueName||'','id="r2-value-name" aria-label="'+t('r2.valueName')+'" placeholder="'+t('r2.valueName')+'" required oninput="R2.categoryDraft(\'valueName\',this.value)"')+icon('r2.saveValue','saveValue()','check').replace('<button ','<button id="r2-value-save" '+((modalData.valueName||'').trim()===original?'hidden ':''))+icon('action.cancel','cancelValue()','cancel')+'</form>';
  }
  function categoryManager() {
    const d=C().categoryDimensions.find(d=>d.id===modalData.dimension);
    return '<button class="btn ghost r2-menu-row" aria-expanded="'+!!modalData.expanded+'" onclick="R2.expandCategories()">'+uiIcon('edit')+'<span>'+t('r2.editCategories')+'</span>'+uiIcon('chevron')+'</button>'+(modalData.expanded?'<div class="r2-category-management">'+C().categoryDimensions.map(item=>'<section class="r2-category-section"><button class="btn ghost r2-menu-row" aria-expanded="'+(item===d)+'" onclick="R2.expandDimension(\''+item.id+'\')">'+uiIcon('group')+'<span>'+esc(item.name)+'</span>'+uiIcon('chevron')+'</button>'+(item===d?'<div class="r2-category-details">'+dimensionForm(d)+'<div class="r2-managed-values">'+d.values.map(v=>'<div class="r2-menu-row"><span>'+esc(v.name)+'</span>'+icon('r2.editValue',"beginValue('"+v.id+"')",'edit')+icon('r2.deleteCategory',"confirmCategoryDelete('"+v.id+"')",'trash')+'</div>').join('')+'</div><div class="r2-value-create">'+(modalData.adding?valueForm():btn('r2.addValue','beginValue()','ghost','plus'))+'</div>'+btn('r2.deleteCategory','confirmCategoryDelete()','ghost danger','trash')+'</div>':'')+'</section>').join('')+(!C().categoryDimensions.length?'<p class="meta">'+t('r2.noCategories')+'</p>':'')+(modalData.newDimension?dimensionForm():btn('category.addDimension','newDimension()','ghost','plus'))+'</div>':'');
  }
  function assignmentPicker(d) {
    const assigned=modalData.selected;
    return '<div class="r2-assignment"><div id="r2-value-search" hidden>'+input(modalData.query||'','type="search" aria-label="'+t('r2.categorySearch')+'" placeholder="'+t('r2.categorySearch')+'" oninput="R2.findValue(this)"')+'</div><div class="r2-value-options">'+d.values.map(v=>'<label class="r2-choice" data-value="'+v.id+'"><input type="checkbox" '+(assigned.includes(v.id)?'checked':'')+' onchange="R2.assign(\''+d.id+'\',\''+v.id+'\',this.checked)"><span>'+esc(v.name)+'</span></label>').join('')+'</div><p class="meta r2-value-empty" '+(d.values.length?'hidden':'')+'>'+t(d.values.length?'r2.noValueMatches':'r2.noValues')+'</p><div class="r2-value-create">'+(modalData.adding?valueForm():btn('r2.addValue','beginValue()','ghost','plus'))+'</div></div>';
  }
  function bindCategoryPicker() {
    const search=document.getElementById('r2-value-search'),list=document.querySelector('.r2-value-options');if(!search||!list)return;
    const fit=()=>{for(const row of list.children)row.hidden=false;search.hidden=!(list.scrollHeight>list.clientHeight+1||modalData.query);R2.findValue(search.querySelector('input'));};
    fit();window.addEventListener('resize',fit);window.visualViewport?.addEventListener('resize',fit);
    categoryCleanup=()=>{window.removeEventListener('resize',fit);window.visualViewport?.removeEventListener('resize',fit);};
  }
  function bindDialogLayout(host) {
    const modal=host.querySelector('.modal');if(!modal)return;
    fitDialog=()=>{
      const viewport=window.visualViewport,overlay=host.querySelector('.overlay');
      if(viewport){overlay.style.top=viewport.offsetTop+'px';overlay.style.height=viewport.height+'px';overlay.style.bottom='auto';modal.style.maxHeight=Math.max(0,viewport.height-2*PIKO_DESIGN.spacing['4'])+'px';}
      for(const actions of host.querySelectorAll('.r2-dialog-actions')){
        if(actions.hidden)continue;
        const active=document.activeElement,primary=actions.querySelector('[data-dialog-primary]'),safe=actions.querySelector('[data-dialog-safe]');
        actions.classList.remove('is-stacked');
        const widths=[...actions.children].map(child=>child.getBoundingClientRect().width);
        const stacked=widths.reduce((sum,width)=>sum+width,0)+PIKO_DESIGN.spacing['2']*(widths.length-1)>actions.clientWidth;
        actions.classList.toggle('is-stacked',stacked);
        if(safe){const first=stacked?primary:safe;if(actions.firstElementChild!==first){actions.prepend(first);if(active?.isConnected)active.focus({preventScroll:true});}}
      }
    };
    fitDialog();
    const observer=new ResizeObserver(fitDialog);observer.observe(modal);
    window.addEventListener('resize',fitDialog);window.visualViewport?.addEventListener('resize',fitDialog);
    const fit=fitDialog;dialogCleanup=()=>{observer.disconnect();window.removeEventListener('resize',fit);window.visualViewport?.removeEventListener('resize',fit);fitDialog=()=>{};};
  }
  function cleanupDialog() {
    categoryCleanup();categoryCleanup=()=>{};
    dialogCleanup();dialogCleanup=()=>{};
    document.getElementById('overlay').onkeydown=null;
  }
  function modalR2() {
    cleanupDialog();
    if(s.modal==='summary.title'){overlay();bindDialogLayout(document.getElementById('overlay'));return;}
    let body='',titleKey='',titleText='',action='',form=false,confirmation=false,footer='';
    const d=C()?.categoryDimensions.find(d=>d.id===modalData.dimension);
    switch(s.modal) {
      case 'r2.menu':titleKey='r2.menu';body=categoryManager()+'<div class="r2-menu-footer">'+btn('collection.delete',"show('deleteCollection')",'ghost danger','trash')+'</div>';break;
      case 'r2.deleteCollection':titleKey='collection.delete';confirmation=true;body='<p>'+t('collection.deleteWarning',{name:C().name})+'</p>';footer=dialogActions(btn('collection.delete','deleteCollection()','r2-destructive','trash'),btn('action.cancel','close()','r2-safe'));break;
      case 'r2.newCollection':case 'r2.rename': {
        const creating=s.modal==='r2.newCollection';titleKey=creating?'dialog.newCollection':'collection.rename';form=true;action=creating?'createCollection()':'rename()';
        body=(creating?field('collection.targetLanguage','<select class="input" id="r2-target" onchange="R2.defaultName()">'+['ko','fr','en','de'].map(code=>'<option value="'+code+'">'+t('language.'+language(code))+'</option>').join('')+'</select>')+field('collection.nativeLanguage','<select class="input" id="r2-native">'+['de','en','fr','ko'].map(code=>'<option value="'+code+'">'+t('language.'+language(code))+'</option>').join('')+'</select>'):'')+field('collection.name',input(creating?raw('language.korean'):C().name,'id="r2-name" required oninput="this.dataset.custom=\'true\';R2.collectionDraft(this.value)"'));footer=dialogActions('<button class="btn primary" type="submit">'+t(creating?'action.create':'r2.save')+'</button>','','id="r2-collection-actions" '+(creating?'':'hidden'));break;
      }
      case 'r2.direction':titleKey='learn.setup';body='<div class="r2-stack">'+J.directions.filter(dir=>due(C(),dir).length).map(dir=>'<button class="btn tint" onclick="R2.startReview(\''+dir+'\',false)">'+t('r2.due',{direction:directionLabel(dir),count:due(C(),dir).length})+'</button>').join('')+'</div>';break;
      case 'r2.assign': {
        titleKey='action.categories';titleText=uiIcon('group')+'<span>'+esc(d.name)+'</span>';body=assignmentPicker(d);footer=dialogActions(btn('r2.apply','applySelection()','primary','check'),'','id="r2-selection-actions" '+(selectionChanged()?'':'hidden'));break;
      }
      case 'r2.filters':titleKey='action.filters';body='<div class="r2-filter-groups">'+C().categoryDimensions.map(d=>'<fieldset><legend>'+esc(d.name)+'</legend>'+d.values.map(v=>choices(v.name,(modalData.filters[d.id]||[]).includes(v.id),"filter('"+d.id+"','"+v.id+"',this.checked)")).join('')+'</fieldset>').join('')+'</div>'+btn('r2.clearFilters','clearFilters()');footer=dialogActions(btn('r2.apply','applySelection()','primary','check'),'','id="r2-selection-actions" '+(selectionChanged()?'':'hidden'));break;
      case 'r2.dimension':titleKey='category.addDimension';body=dimensionForm();break;
      case 'r2.deleteCategory':titleKey='r2.deleteCategory';confirmation=true;body='<p><strong>'+esc(d.values.find(v=>v.id===modalData.value)?.name||d.name)+'</strong></p><p>'+t('r2.deleteCategoryWarning')+'</p>';footer=dialogActions(btn('r2.deleteCategory','deleteCategory()','r2-destructive','trash'),btn('action.cancel','cancelCategoryDelete()','r2-safe'));break;
      case 'r2.speed':titleKey='action.speed';body=speedSetup();break;
      case 'r2.entryExit':titleKey='entry.exitTitle';confirmation=true;body='<p>'+t('entry.exitWarning')+'</p>';footer=dialogActions(btn('entry.discard','discardEntryExit()','r2-destructive'),btn('entry.continue','close()','r2-safe'));break;
    }
    const host=document.getElementById('overlay');
    if(!titleKey){host.innerHTML='';host.onkeydown=null;return;}
    const header=confirmation?'<header class="summary-header"><h2 id="r2-modal-title">'+t(titleKey)+'</h2></header>':modalHeader('r2-modal-title',titleKey,'r2-close','R2.close()');
    host.innerHTML=titleKey?'<div class="overlay" onclick="R2.close()"><section class="modal r2-modal" role="dialog" aria-modal="true" aria-labelledby="r2-modal-title" onclick="event.stopPropagation()">'+(titleText?header.replace(t(titleKey),titleText):header)+'<div class="r2-modal-body">'+(form?'<form onsubmit="event.preventDefault();R2.'+action+'">':'')+body+'<p class="entry-error" role="alert" id="r2-modal-error"></p>'+footer+(form?'</form>':'')+'</div></section></div>':'';
    bindDialogLayout(host);
    if(titleKey){(host.querySelector('#r2-close')||host.querySelector('[data-dialog-safe] button')||host.querySelector('button')).focus({preventScroll:true});bindCategoryPicker();host.onkeydown=event=>{if(event.key==='Escape'){event.preventDefault();R2.close();}if(event.key==='Tab'){const controls=[...host.querySelectorAll('button,input,select,textarea,summary')].filter(e=>!e.disabled&&e.getClientRects().length),first=controls[0],last=controls.at(-1);if(event.shiftKey&&document.activeElement===first){last.focus();event.preventDefault();}else if(!event.shiftKey&&document.activeElement===last){first.focus();event.preventDefault();}}};}else host.onkeydown=null;
  }
  function speedIds(direction=speedDirection) {
    return filtered().filter(e=>!e.learning[direction].speedCompleted&&!e.learning[direction].reviews.some(r=>r.generation===e.learning[direction].generation)).map(e=>e.id);
  }
  function speedSummary() {const count=speedIds().length;return t(count===1?'r2.speedNewOne':'r2.speedNewCount',{count});}
  function speedSetup() {
    return '<div class="r2-speed-setup"><p class="meta r2-speed-direction">'+esc(directionLabel(speedDirection))+'</p><p id="r2-selected" class="r2-speed-summary" role="status">'+speedSummary()+'</p><div class="r2-warning"><p>'+t('r2.speedResetWarning')+'</p></div>'+field('r2.pool',input(poolSize,'id="r2-pool" type="number" min="1" step="1" oninput="R2.pool(this.value)"'))+'<p class="meta">'+t('r2.poolHint')+'</p></div>'+dialogActions(btn('learn.start','startSpeed()','r2-speed-action').replace('<button ','<button id="r2-speed-start" '+(!speedIds().length?'disabled ':'')));
  }
  function renderR2() {
    clearTimeout(timer);entryCleanup();entryCleanup=()=>{};vocabularySwipeObserver.disconnect();scope='minimum';document.documentElement.lang=locale;
    app.innerHTML=({collections:overviewR2,detail:detailR2,import:jsonR2,entry:entryR2,learning:learningR2,settings:()=>icon('common.back',"navigate('collections')",'back')+settings()}[s.page]||overviewR2)();
    if(s.page==='detail')bindVocabularySwipe();if(s.page==='entry')bindEntry();modalR2();
    document.querySelector('.brand').textContent=raw('app.name');document.querySelector('aside .caption').textContent=raw('r2.notice');toolbar();
  }
  function toolbar() {
    let bar=document.getElementById('round-preview');if(!bar){bar=document.createElement('section');bar.id='round-preview';bar.className='round-preview';document.body.prepend(bar);}
    bar.innerHTML=field('r2.release','<select class="input" onchange="R2.setRound(Number(this.value))"><option value="1" '+(previewRound===1?'selected':'')+'>'+t('r2.first')+'</option><option value="2" '+(previewRound===2?'selected':'')+'>'+t('r2.second')+'</option></select>')+(previewRound===2?field('r2.scenario','<select class="input" onchange="R2.scenario(this.value)">'+['default','one','done','empty','waitDemo','speedDemo','jsonDemo'].map(value=>'<option value="'+value+'" '+(scenario===value?'selected':'')+'>'+t('r2.'+value)+'</option>').join('')+'</select>')+btn('r2.reset','reset()')+'<p class="caption">'+t('r2.notice')+'</p>':'');
  }
  globalThis.R2={
    setRound(value){if(![1,2].includes(value)||value===previewRound)return;clearTimeout(timer);entryCleanup();cleanupDialog();document.getElementById('overlay').innerHTML='';if(previewRound===1)r1State=clone(s);else {r2State={...clone(s),page:'collections',modal:''};round=null;editor=null;entry=null;}previewRound=value;document.documentElement.dataset.round=String(previewRound);s=clone(previewRound===1?r1State:r2State);s.modal='';const url=new URL(location);url.searchParams.delete('release');url.searchParams.set('round',previewRound);history.replaceState(null,'',url);render();},
    reset(){initialize();s.page='collections';scenario='default';render();},
    scenario(value){initialize();scenario=value;const c=C();if(value==='empty')c.entries=[];else if(value==='done'||value==='one')for(const e of c.entries)for(const dir of(value==='one'?[J.directions[0]]:J.directions)){const state=e.learning[dir],reviewedAt=new Date().toISOString();state.card.lastReview=reviewedAt;state.reviews.push({id:1,generation:state.generation,reviewedAt,rating:'good'});}s.page='detail';if(value==='waitDemo'){c.entries=c.entries.slice(0,2);R2.startReview(J.directions[0],false);round.revealed=true;R2.grade(true);round.revealed=true;R2.grade(false);return;}if(value==='speedDemo'){const speed=S.create([c.entries[0].id]);S.grade(speed,false);round={mode:'speed',direction:J.directions[0],speed,revealed:false};s.page='learning';}if(value==='jsonDemo'){jsonText=JSON.stringify({format:'piko-vocabulary',schemaVersion:1,collections:[{targetLanguage:c.targetLanguage,nativeLanguage:c.nativeLanguage,entries:[{targetText:'',nativeText:'Apfel'}]}]},null,2);jsonResult=J.analyze(jsonText,c,collections);s.page='import';}render();},
    navigate(page){if(editor&&!saveEditor())return;if(s.page==='entry'&&entry?.draft&&(entry.draft.targetText||entry.draft.nativeText)){R2.show('entryExit',{destination:page});return;}if(s.page==='learning'){round=null;previous=null;game=null;}editor=null;s.page=page;s.modal='';render();scrollTo(0,0);},
    open(index){s.book=index;editor=null;entry=null;R2.navigate('detail');},
    show(key,data={}){if(!s.modal){dialogFocus=document.activeElement;dialogFocusAction=dialogFocus?.getAttribute('onclick');}s.modal='r2.'+key;modalData=data;if(key==='assign'){const assigned=(editor?.draft||entry.draft).categoryAssignments.find(a=>a.dimensionId===data.dimension)?.valueIds||[];modalData.original=clone(assigned);modalData.selected=clone(assigned);}if(key==='filters'){modalData.original=clone(V().filters);modalData.filters=clone(V().filters);}modalR2();},
    close(){if(s.modal==='r2.deleteCategory'){R2.cancelCategoryDelete();return;}s.modal='';document.getElementById('overlay').innerHTML='';render();const target=dialogFocus?.isConnected?dialogFocus:[...app.querySelectorAll('button')].find(b=>b.getAttribute('onclick')===dialogFocusAction);target?.focus({preventScroll:true});},
    quick(index){s.book=index;const directions=J.directions.filter(d=>due(C(),d).length);if(directions.length===1)R2.startReview(directions[0],false);else if(directions.length)R2.show('direction');},
    defaultName(){const el=document.getElementById('r2-name');if(!el.dataset.custom)el.value=raw('language.'+language(document.getElementById('r2-target').value));},
    collectionDraft(value){if(s.modal==='r2.rename')document.getElementById('r2-collection-actions').hidden=value===C().name;fitDialog();},
    createCollection(){const target=document.getElementById('r2-target').value,native=document.getElementById('r2-native').value,name=document.getElementById('r2-name').value.trim();if(target===native||!name){document.getElementById('r2-modal-error').textContent=raw(target===native?'collection.sameLanguage':'collection.requiredName');return;}const c={id:id(),name,targetLanguage:target,nativeLanguage:native,entries:[],categoryDimensions:[],reviewScopes:{targetToNative:{ordinal:0,revision:0},nativeToTarget:{ordinal:0,revision:0}}};collections.push(c);views.set(c.id,{search:'',filters:{}});s.book=collections.length-1;emptyCollections=false;R2.navigate('detail');},
    beginRename(){renaming=true;render();document.getElementById('r2-name').focus();},
    cancelRename(){renaming=false;render();},
    rename(){const name=document.getElementById('r2-name').value.trim();if(name){C().name=name;renaming=false;R2.close();}},
    deleteCollection(){collections.splice(s.book,1);s.book=0;R2.navigate('collections');},
    search(value){if(editor&&!saveEditor())return;V().search=value;editor=null;document.getElementById('r2-clear-search').hidden=!value;document.getElementById('r2-wordlist').innerHTML=listMarkup();document.getElementById('r2-review-actions').innerHTML=learningActions();bindVocabularySwipe();},
    clearSearch(){if(editor&&!saveEditor())return;R2.search('');const search=document.getElementById('r2-search');search.value='';search.focus({preventScroll:true});},
    filter(d,v,checked){const values=new Set(modalData.filters[d]||[]);checked?values.add(v):values.delete(v);modalData.filters[d]=[...values];refreshModalActions();},
    clearFilters(){if(s.modal==='r2.filters'){modalData.filters={};modalR2();}else{V().filters={};render();}},
    edit(eid){if(editor&&!saveEditor())return;const e=word(eid);editor={id:eid,original:clone(e),draft:clone(e)};render();},
    updateText(index,value){editor.draft[index?'nativeText':'targetText']=value;saveEditor();const changed=JSON.stringify(editor.draft)!==JSON.stringify(editor.original);document.getElementById('r2-discard').innerHTML=changed?icon('vocab.inlineDiscard','discard()','cancel'):'';document.getElementById('r2-finish').innerHTML=icon(changed?'vocab.inlineFinish':'vocab.inlineCollapse','finish()',changed?'check':'cancel');},
    nextField(event,index){if(event.key==='Enter'){event.preventDefault();if(!index)document.getElementById('r2-edit-1').focus();else R2.finish();}},
    finish(){if(saveEditor()){editor=null;if(entry)entry.active=null;render();}},
    discard(){if(!validEntry(editor.original)){document.getElementById('r2-editor-error').textContent=raw('vocab.inlineDuplicate');return;}Object.assign(word(editor.id),clone(editor.original));editor=null;if(entry)entry.active=null;render();},
    assign(d,v,checked){const dimension=C().categoryDimensions.find(x=>x.id===d);modalData.selected=checked?(dimension.mode==='single'?[v]:[...new Set([...modalData.selected,v])]):modalData.selected.filter(x=>x!==v);for(const row of document.querySelectorAll('[data-value]'))row.querySelector('input').checked=modalData.selected.includes(row.dataset.value);refreshModalActions();},
    applySelection(){if(!selectionChanged())return;if(s.modal==='r2.filters')V().filters=clone(modalData.filters);else {const draft=editor?.draft||entry.draft;draft.categoryAssignments=draft.categoryAssignments.filter(a=>a.dimensionId!==modalData.dimension);if(modalData.selected.length)draft.categoryAssignments.push({dimensionId:modalData.dimension,valueIds:clone(modalData.selected)});if(editor)saveEditor();}R2.close();},
    findValue(el){modalData.query=el.value;const query=J.key(el.value),list=document.querySelector('.r2-value-options');for(const label of list.children)label.hidden=!J.key(label.textContent).includes(query);document.querySelector('.r2-value-empty').hidden=[...list.children].some(row=>!row.hidden);},
    categoryDraft(key,value){modalData[key]=value;refreshModalActions();},
    changeCategoryMode(mode){modalData.mode=mode;document.getElementById('r2-modal-error').textContent='';refreshModalActions();},
    expandCategories(){modalData={expanded:!modalData.expanded};modalR2();document.querySelector('.r2-menu-row').focus({preventScroll:true});},
    expandDimension(dimension){modalData={expanded:true,dimension:modalData.dimension===dimension?null:dimension};modalR2();document.getElementById('r2-category-name')?.focus({preventScroll:true});},
    newDimension(){modalData={expanded:true,newDimension:true};modalR2();document.getElementById('r2-category-name').focus();},
    beginValue(value){const d=C().categoryDimensions.find(d=>d.id===modalData.dimension);modalData.adding=true;modalData.value=value;modalData.valueName=d.values.find(v=>v.id===value)?.name||'';modalR2();document.getElementById('r2-value-name').focus();},
    cancelValue(){modalData.adding=false;delete modalData.value;delete modalData.valueName;modalR2();document.querySelector('.r2-value-create button').focus({preventScroll:true});},
    saveValue(){const d=C().categoryDimensions.find(d=>d.id===modalData.dimension),existing=d.values.find(v=>v.id===modalData.value),name=document.getElementById('r2-value-name').value.trim();if(existing?.name===name)return;if(!name||d.values.some(v=>v!==existing&&J.key(v.name)===J.key(name))){document.getElementById('r2-modal-error').textContent=raw('r2.valueInvalid');return;}if(existing)existing.name=name;else d.values.push({id:id(),name});R2.cancelValue();},
    saveCategory(){const d=C().categoryDimensions.find(d=>d.id===modalData.dimension),name=document.getElementById('r2-category-name').value.trim(),mode=modalData.mode||d?.mode||'single',list=C().categoryDimensions;if(d&&name===d.name&&mode===d.mode)return;const drafts=[...C().entries,...(editor?[editor.draft]:[]),...(entry?[entry.draft]:[])];if(!name||list.some(x=>x!==d&&J.key(x.name)===J.key(name))||(d&&mode==='single'&&drafts.some(e=>e.categoryAssignments.some(a=>a.dimensionId===d.id&&a.valueIds.length>1)))){document.getElementById('r2-modal-error').textContent=raw('r2.categoryInvalid');return;}const saved=d||{id:id(),values:[]};Object.assign(saved,{name,mode});if(!d)list.push(saved);if(s.modal==='r2.menu'){modalData={expanded:true,dimension:saved.id};modalR2();document.getElementById('r2-category-name').focus({preventScroll:true});}else R2.close();},
    confirmCategoryDelete(value){const returnTo=clone(modalData);R2.show('deleteCategory',{dimension:modalData.dimension,value,returnTo});},
    cancelCategoryDelete(){const data=modalData.returnTo;R2.show('menu',data);},
    deleteCategory(){const d=C().categoryDimensions.find(d=>d.id===modalData.dimension),value=modalData.value,returnTo=modalData.returnTo;if(value)d.values=d.values.filter(v=>v.id!==value);else C().categoryDimensions=C().categoryDimensions.filter(x=>x!==d);const clean=e=>e.categoryAssignments=value?e.categoryAssignments.map(a=>a.dimensionId===d.id?{...a,valueIds:a.valueIds.filter(v=>v!==value)}:a):e.categoryAssignments.filter(a=>a.dimensionId!==d.id);C().entries.forEach(clean);if(editor){clean(editor.original);clean(editor.draft);}if(entry)clean(entry.draft);if(value)V().filters[d.id]=(V().filters[d.id]||[]).filter(v=>v!==value);else delete V().filters[d.id];R2.show('menu',value?{...returnTo,adding:false,value:null}:{expanded:true});},
    removeWord(eid){const index=C().entries.findIndex(e=>e.id===eid);undo={collection:C(),entry:C().entries[index],index,expires:Date.now()+8000};C().entries.splice(index,1);editor=null;reviewRounds.clear();render();setTimeout(()=>{if(previewRound===2&&undo&&Date.now()>=undo.expires){undo=null;render();}},8000);},
    undoDelete(){if(undo&&Date.now()<undo.expires){undo.collection.entries.splice(undo.index,0,undo.entry);undo=null;render();}},
    jsonEdit(value){jsonText=value;jsonResult=null;document.getElementById('r2-json-result').innerHTML='';},
    group(group,checked){groups=checked?[...new Set([...groups,group])]:groups.filter(x=>x!==group);jsonResult=null;document.getElementById('r2-json-result').innerHTML='';},
    analyze(){jsonResult=J.analyze(jsonText,C(),collections,groups);jsonMessage='';render();},
    applyJson(){const fresh=J.analyze(jsonText,C(),collections,groups);if(!fresh.next){jsonResult=fresh;render();return;}collections[s.book]=fresh.next;jsonResult=null;jsonMessage=raw('r2.jsonApplied');reviewRounds.clear();render();},
    async copy(example){const collection=clone(C());if(example)collection.entries=collection.entries.slice(0,1);const text=JSON.stringify(J.envelope(collection),null,2);try{await navigator.clipboard.writeText(text);jsonMessage=raw('json.copied');}catch{jsonText=text;jsonMessage=raw('json.clipboardFailed');}render();},
    async paste(){try{jsonText=await navigator.clipboard.readText();jsonResult=null;jsonMessage='';}catch{jsonMessage=raw('json.clipboardFailed');}render();},
    async file(control){const file=control.files[0];if(!file)return;try{if(file.size>1000000)throw Error();jsonText=await file.text();jsonResult=null;jsonMessage='';}catch{jsonMessage=raw('r2.jsonInvalid');}render();},
    download(){const url=URL.createObjectURL(new Blob([JSON.stringify(J.envelope(C()),null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='piko-vocabulary.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);},
    draftText(index,value){entry.draft[index?'nativeText':'targetText']=value;},
    draftNext(event,index){if(event.key==='Enter'){event.preventDefault();if(!index)document.getElementById('r2-draft-1').focus();else R2.saveEntry();}},
    saveEntry(){if(!validEntry(entry.draft)){document.getElementById('r2-entry-error').textContent=raw(entry.draft.targetText.trim()&&entry.draft.nativeText.trim()?'vocab.inlineDuplicate':'entry.required');return false;}C().entries.push(clone(entry.draft));entry=null;editor=null;render();document.getElementById('r2-draft-0').focus({preventScroll:true});return true;},
    completeEntry(){if(editor&&!saveEditor())return;if(entry.draft.targetText||entry.draft.nativeText){if(!R2.saveEntry())return;}entry=null;R2.navigate('detail');},
    discardEntryExit(){const destination=modalData.destination;entry=null;editor=null;R2.navigate(destination);},
    activateEntry(eid){if(editor&&!saveEditor())return;entry.active=eid;R2.edit(eid);},
    setupSpeed(direction){if(editor&&!saveEditor())return;if(!J.directions.includes(direction)||!speedIds(direction).length)return;poolSize=5;speedDirection=direction;R2.show('speed');},
    pool(value){poolSize=Number(value);},
    startSpeed(){const ids=speedIds();if(!ids.length||!Number.isSafeInteger(poolSize)||poolSize<1){document.getElementById('r2-modal-error').textContent=raw('r2.poolInvalid');return;}round={mode:'speed',direction:speedDirection,speed:S.create(ids,poolSize),revealed:false};game=null;s.modal='';s.page='learning';render();},
    number(value){if(value!==game.next)return;game.next++;if(game.next===11){S.finishGame(round.speed);game=null;}render();},
    startReview(direction,useFilter){const entries=due(C(),direction,useFilter?filtered():C().entries);if(!entries.length){R2.close();return;}const key=C().id+direction;round=reviewRounds.get(key);if(!round){round={mode:'long',direction,queue:entries.map(e=>e.id),pending:[],ordinal:C().reviewScopes[direction].ordinal,completed:0,total:entries.length,correct:0,revealed:false,hard:false};reviewRounds.set(key,round);}round.revealed=false;previous=null;s.modal='';s.page='learning';render();},
    reveal(){if(!reviewCurrent()||(round.mode==='speed'&&S.needsGame(round.speed)))return;round.revealed=true;render();},
    hard(value){round.hard=value;},
    grade(correct){if(!round?.revealed)return;const eid=reviewCurrent(),e=word(eid);if(!e)return;
      if(round.mode==='speed'){const result=S.grade(round.speed,correct);if(result.finished){const state=e.learning[round.direction];if(result.reset){const fresh=J.freshLearning()[round.direction];e.learning[round.direction]={...fresh,id:state.id,generation:state.generation+1,reviewRevision:state.reviewRevision+1,reviews:state.reviews};}e.learning[round.direction].speedCompleted=true;}if(!S.current(round.speed)){round=null;R2.navigate('detail');return;}}
      else {previous={round:clone(round),entry:clone(e),scopes:clone(C().reviewScopes)};const pending=round.pending.find(p=>p.id===eid);if(!pending){const state=e.learning[round.direction];state.reviews.push({id:state.reviews.length+1,generation:state.generation,reviewedAt:new Date().toISOString(),rating:correct?(round.hard?'hard':'good'):'again'});state.reviewRevision++;state.card.lastReview=new Date().toISOString();}round.queue=round.queue.filter(x=>x!==eid);round.pending=round.pending.filter(p=>p.id!==eid);round.ordinal++;C().reviewScopes[round.direction].ordinal++;C().reviewScopes[round.direction].revision++;if(correct){round.completed++;if(!pending)round.correct++;e.learning[round.direction].card.lastReview=new Date().toISOString();e.learning[round.direction].retry=null;}else {const errors=(pending?.errors||0)+1,obligation={id:eid,errors,ordinal:round.ordinal,gap:[20,10,5,3,1][Math.min(errors-1,4)],deadline:null};round.pending.push(obligation);const state=e.learning[round.direction],expiry=new Date();expiry.setHours(4,0,0,0);if(expiry.getTime()<=Date.now())expiry.setDate(expiry.getDate()+1);state.retry={id:null,generation:state.generation,revision:errors,originReviewId:state.reviews.at(-1)?.id||null,createdAt:new Date().toISOString(),expiresAt:expiry.toISOString(),waitEligibleAt:null,errorCount:errors,dueOrdinal:round.ordinal+obligation.gap};}if(round.completed===round.total){summaryCounts={completed:round.completed,correct:round.correct};reviewRounds.delete(C().id+round.direction);round=null;s.page='detail';s.modal='summary.title';render();return;}}
      round.revealed=false;round.hard=false;render();},
    correctPrevious(){if(!previous)return;const restored=clone(previous.round);Object.assign(word(previous.entry.id),clone(previous.entry));C().reviewScopes=clone(previous.scopes);round=restored;round.revealed=true;reviewRounds.set(C().id+round.direction,round);previous=null;render();}
  };
  render=()=>{document.documentElement.dataset.round=String(previewRound);document.documentElement.dataset.embedded=String(parent!==window);if(previewRound===2)renderR2();else{baseRender();toolbar();}};
  closeSessionSummary=()=>{if(previewRound===2)cleanupDialog();baseCloseSummary();};
  go=page=>previewRound===2?R2.navigate(page):baseGo(page);
  const config=PIKO_DESIGN.previews.round2;
  for(const [name,value] of Object.entries(config))document.documentElement.style.setProperty('--r2-'+name.replace(/[A-Z]/g,c=>'-'+c.toLowerCase()),String(value)+(typeof value==='number'&&!['gameColumns','entrySettleMs'].includes(name)?'px':''));
  window.addEventListener('message',event=>{if(event.source!==parent||parent===window||event.data?.type!=='piko-design-preview')return;if(event.data.round===1||event.data.round===2)R2.setRound(event.data.round);if(previewRound===2&&event.data.scenario&&event.data.scenario!==scenario)R2.scenario(event.data.scenario);});
  initialize();render();
})();
