let catalog=globalThis.PIKO_COPY;
let locale=catalog.defaultLocale;
let scope='minimum';
const books=[['Korean Basics','Korean · German','한',128,24,16],['French A1','French · German','FR',64,8,6],['English Notes','English · German','EN',32,4,3]];
const words=[['사과','Apfel','Food'],['물','Wasser','Food'],['학교','Schule','Education'],['친구','Freund','People'],['책','Buch','Education']];
let s={page:'collections',book:0,mode:'long',direction:'KO → DE',answer:'Self',revealed:false,search:'',compact:false,modal:'',modalName:'',importStep:0};
const app=document.getElementById('app');
function esc(value){return String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function raw(key,params={}) {
  const entry=catalog.entries[key];
  if(!entry) throw new Error('Missing copy key: '+key);
  return (entry[locale]??entry.en).replace(/\{([a-z]+)\}/g,(_,name)=>String(params[name]??'{'+name+'}'));
}
function t(key,params){return esc(raw(key,params));}
function go(page){s.page=page;s.revealed=false;render();scrollTo(0,0);}
function change(key,value){s[key]=value;render();}
function learn(index,mode){s.book=index;s.mode=mode;go('learning');}
function popup(key,name=''){s.modal=key;s.modalName=name;overlay();}
function title(key,heading,description){return '<div class="eyebrow">'+t(key)+'</div><h1>'+heading+'</h1><div class="sub">'+description+'</div>';}
function back(page){return '<button class="back" onclick="go(\''+page+'\')">← '+t('common.back')+'</button>';}
function button(key,action,style='',icon=''){return '<button class="btn '+style+'" onclick="'+action+'">'+icon+t(key)+'</button>';}
function overview(){
 const cards=books.map((b,i)=>'<article class="card collection-card"><button class="collection-open" onclick="s.book='+i+';go(\'detail\')"><span class="cover">'+b[2]+'</span><span class="collection-info"><strong>'+esc(b[0])+'</strong><span class="meta">'+esc(b[1])+' · '+t('common.entries',{count:b[3]})+'</span></span><span class="chevron" aria-hidden="true">›</span></button><div class="collection-actions">'+button('action.review',"learn("+i+",'long')",'tint','↗ ').replace('</button>',' <span class="count">'+b[4]+'</span></button>')+(scope==='expanded'?button('action.speed',"learn("+i+",'speed')",'','⚡ ').replace('</button>',' <span class="count">'+b[5]+'</span></button>'):'')+'</div></article>').join('');
 const summary=scope==='expanded'?'<section class="summary"><div class="head"><h2>'+t('metric.today')+'</h2>'+button('action.activity',"go('stats')",'ghost','↗ ')+'</div>'+metrics([['36','metric.due'],['18','metric.reviewed'],['7','metric.streak']])+'</section>':'<section class="review-summary"><div class="summary-symbol" aria-hidden="true">↗</div><div><h1>'+t('home.reviewTitle')+'</h1><p>'+t('home.reviewSummary',{count:36})+'</p><span class="meta">'+t('home.reviewHint')+'</span></div></section>';
 return '<header class="home-header"><span class="home-brand">'+t('app.name')+'</span>'+button('nav.settings',"go('settings')",'ghost','⚙ ')+'</header>'+summary+'<div class="head collection-heading"><h2>'+t('home.collections')+'</h2>'+button('action.new',"popup('dialog.newCollection')",'ghost','+ ')+'</div><div class="stack">'+cards+'</div>';
}
function metrics(items){return '<div class="stats">'+items.map(([value,key])=>'<div class="stat"><strong>'+value+'</strong><span>'+t(key)+'</span></div>').join('')+'</div>';}
function detail(){
 const b=books[s.book];
 return back('collections')+title('collection.title',b[0],b[1]+' · '+t('common.entries',{count:b[3]}))+'<div class="actions">'+button('action.review',"learn("+s.book+",'long')",'primary','↗ ')+(scope==='expanded'?button('action.speed',"learn("+s.book+",'speed')",'tint','⚡ '):'')+'</div><div class="head"><h2>'+t('collection.vocabulary')+'</h2>'+(scope==='expanded'?button('action.categories',"go('categories')",'ghost'):'')+'</div>'+(scope==='expanded'?'<input class="input" aria-label="'+t('collection.search')+'" placeholder="'+t('collection.search')+'" value="'+esc(s.search)+'" oninput="s.search=this.value;drawWords()"><div class="tools">'+button('action.filters',"popup('action.filters')",'','☷ ')+button('action.group',"popup('action.group')",'','▤ ')+button(s.compact?'view.compact':'view.detailed',"change('compact',!s.compact)")+button('action.import',"go('import')",'','⇧ ')+'</div>':'')+'<div id="wordlist"></div><button class="fab" onclick="go(\'entry\')">+ '+t('action.addEntry')+'</button>';
}
function drawWords(){
 const el=document.getElementById('wordlist');if(!el)return;
 el.innerHTML='<div class="stack">'+words.filter(w=>scope==='minimum'||w.join(' ').toLowerCase().includes(s.search.toLowerCase())).map(w=>'<button class="card row click word-row" onclick="popup(\'dialog.detail\')"><span><strong>'+w[0]+'</strong><span class="meta">'+w[1]+'</span>'+(scope==='minimum'||s.compact?'':'<span class="pill">'+w[2]+'</span><span class="pill">'+t('category.unit')+' 2</span>')+'</span><span>›</span></button>').join('')+'</div>';
}
function learning(){
 if(scope==='minimum')s.answer='Self';
 const progress=s.mode==='long'?t('learn.progress',{completed:12,total:30,correct:9}):t('learn.pool',{count:5});
 let actions=s.revealed?button('action.previous',"popup('dialog.previous')",'','↶ ')+button('action.incorrect',"change('revealed',false)")+button('action.correct',"change('revealed',false)",'primary'):(s.answer==='Type'?'<input class="input" style="flex:1;min-width:120px" aria-label="'+t('learn.answerPlaceholder')+'" placeholder="'+t('learn.answerPlaceholder')+'">':'')+button('action.showAnswer',"change('revealed',true)",'primary')+button('action.skip',"popup('action.skip')");
 return back('detail')+title(s.mode==='long'?'learn.longTitle':'learn.speedTitle',books[s.book][0],s.direction+' · '+progress)+'<div class="progress"><div></div></div><div class="row"><span class="pill">'+s.direction+'</span>'+button(s.answer==='Self'?'learn.self':'learn.type',"change('answer',s.answer==='Self'?'Type':'Self')")+'</div><div class="card learning" onclick="change(\'revealed\',!s.revealed)"><div><div class="word">'+(s.revealed?'사과':'Apfel')+'</div><p class="sub">'+(s.revealed?'저는 사과를 먹어요.':'Ich esse einen Apfel.')+'</p></div><span class="meta">'+t(s.revealed?'learn.revealed':'learn.revealCue')+'</span></div><div class="actions">'+actions+'</div><p class="caption">'+t('learn.prototype')+'</p>';
}
function field(key,placeholder){return '<div class="field"><label>'+t(key)+'<input class="input" placeholder="'+t(placeholder)+'"></label></div>';}
function entry(){return back('detail')+title('collection.vocabulary',t('entry.title'),t('entry.description'))+'<div class="card">'+field('language.korean','entry.targetPlaceholder')+field('language.german','entry.nativePlaceholder')+'<div class="placeholder">'+t('entry.deferred')+'</div><div class="actions">'+button('action.saveNext',"popup('dialog.saved')",'primary')+button('action.finish',"go('detail')")+'</div></div>';}
function categories(){return back('detail')+title('category.settings',t('action.categories'),t('category.description'))+'<div class="stack">'+['topic','unit','source','difficulty'].map(key=>'<div class="card row click" onclick="popup(\'dialog.category\',\'category.'+key+'\')"><strong>'+t('category.'+key)+'</strong><span>›</span></div>').join('')+'</div><div class="actions">'+button('category.addDimension',"popup('dialog.newDimension')",'tint','+ ')+'</div>';}
function imports(){
 const start='<div class="placeholder" style="margin-top:16px">⇧<h3>'+t('import.upload')+'</h3><p>'+t('import.prototype')+'</p>'+button('import.sample',"change('importStep',1)",'tint')+'</div>';
 const review=metrics([['12','import.new'],['8','import.additions'],['2','import.conflicts']])+'<div class="card" style="margin-top:16px"><strong>사과 — Apfel</strong><p class="sub">'+t('import.proposed')+'</p>'+button('import.differences',"popup('import.differences')")+'</div><div class="actions">'+button('import.confirm',"popup('import.confirm')",'primary')+'</div>';
 return back('detail')+title('action.import',t('import.title'),t('import.description'))+'<div class="actions">'+button('import.select',"change('importStep',0)",s.importStep===0?'primary':'')+button('import.review',"change('importStep',1)",s.importStep===1?'primary':'')+'</div>'+(s.importStep===0?start:review);
}
function stats(){
 const dates=[t('metric.today')+' · Oct 13',t('stats.yesterday')+' · Oct 12','Oct 11'];
 return title('stats.eyebrow',t('nav.statistics'),t('stats.description'))+'<div style="margin-top:22px">'+metrics([['42','metric.average'],['7','metric.streak'],['86','metric.reviewedToday']])+'</div><div class="head"><h2>'+t('stats.activity')+'</h2>'+button('stats.speed',"popup('stats.speed')",'ghost')+'</div><div class="stack">'+[[86,63],[54,43],[31,24]].map(([reviewed,correct],i)=>'<div class="card"><strong>'+dates[i]+'</strong><p class="meta">'+t('stats.row',{reviewed,correct})+'</p></div>').join('')+'</div><div class="actions">'+button('stats.history',"popup('stats.history')")+'</div>';
}
function selectField(label,options){return '<div class="field"><label>'+t(label)+'<select class="input">'+options.map(key=>'<option>'+t(key)+'</option>').join('')+'</select></label></div>';}
function settings(){
 return title('settings.eyebrow',t('nav.settings'),t('settings.description'))+'<div class="stack" style="margin-top:23px"><div class="card"><h2>'+t('settings.general')+'</h2><div class="field"><label>'+t('settings.language')+'<select class="input" onchange="setLocale(this.value)"><option value="en" '+(locale==='en'?'selected':'')+'>English</option><option value="de" '+(locale==='de'?'selected':'')+'>Deutsch</option></select></label></div></div><div class="card"><h2>'+t('settings.learning')+'</h2>'+selectField('settings.direction',['direction.targetNative','direction.nativeTarget','direction.bothSeparate','direction.bothMixed'])+selectField('settings.answerMode',['learn.selfFull','learn.typeFull'])+'</div><div class="card row click" onclick="popup(\'dialog.ai\')"><strong>'+t('settings.ai')+'</strong><span>›</span></div><div class="card row click" onclick="popup(\'dialog.developer\')"><strong>'+t('settings.developer')+'</strong><span>›</span></div></div>';
}
function overlay(){
 const content=s.modal==='dialog.newCollection'?field('collection.name','collection.namePlaceholder')+selectField('collection.targetLanguage',['language.korean','language.french','language.english'])+selectField('collection.nativeLanguage',['language.german','language.english'])+'<p class="caption">'+t('prototype.noSave')+'</p><div class="actions">'+button('action.create',"popup('');s.book=0;go('detail')",'primary')+button('common.close',"popup('')")+'</div>':'<p class="sub">'+t('prototype.dialog')+'</p>'+button('common.close',"popup('')",'primary');
 document.getElementById('overlay').innerHTML=s.modal?'<div class="overlay" onclick="popup(\'\')"><div class="modal" role="dialog" aria-modal="true" aria-label="'+t(s.modal,{name:s.modalName?raw(s.modalName):''})+'" onclick="event.stopPropagation()"><h2>'+t(s.modal,{name:s.modalName?raw(s.modalName):''})+'</h2>'+content+'</div></div>':'';
}
function navigation(){document.getElementById('nav').innerHTML=[['collections','nav.collections','▦ '],...(scope==='expanded'?[['stats','nav.statistics','▥ ']]:[]),['settings','nav.settings','⚙ ']].map(([page,key,icon])=>'<button class="'+(s.page===page?'active':'')+'" onclick="go(\''+page+'\')">'+icon+t(key)+'</button>').join('');}
function setLocale(value){locale=value==='de'?'de':'en';render();}
function render(){document.documentElement.lang=locale;document.title=raw('app.name')+' — '+raw('prototype.caption');navigation();app.innerHTML=({collections:overview,detail,learning,entry,categories,import:imports,stats,settings}[s.page]||overview)();if(s.page==='detail')drawWords();if(s.page==='settings'||s.page==='stats')app.insertAdjacentHTML('afterbegin',back('collections'));if(scope==='minimum'){if(s.page==='learning'){app.querySelector('.row .btn')?.remove();for(const el of app.querySelectorAll('.actions .btn'))if(el.textContent.includes(raw('action.previous'))||el.textContent.includes(raw('action.skip')))el.remove();app.querySelector('.learning .sub')?.remove();}if(s.page==='entry')app.querySelector('.placeholder')?.remove();if(s.page==='settings'){const cards=app.querySelectorAll('.card');for(let i=1;i<cards.length;i++)cards[i].remove();}}overlay();document.querySelector('.brand').textContent=raw('app.name').toLowerCase();document.querySelector('aside .caption').textContent=raw('prototype.caption')+' · '+raw('prototype.data');}
function applyTheme(p){for(const [key,value] of Object.entries(p)){if(/^#[0-9a-f]{6}$/i.test(value))document.documentElement.style.setProperty('--piko-'+key,value);}}
applyTheme(globalThis.PIKO_THEME);
window.addEventListener('message',event=>{
 if(event.source!==parent||parent===window||event.data?.type!=='piko-design-preview')return;
 const data=event.data;
 if(data.scope==='minimum'||data.scope==='expanded'){scope=data.scope;if(scope==='minimum'&&!['collections','detail','learning','entry','settings'].includes(s.page))s.page='collections';if(scope==='minimum')s.mode='long';}
 if(data.catalog?.schemaVersion===1&&data.catalog.entries){catalog=data.catalog;locale=data.locale==='de'?'de':'en';}
 if(data.palette)applyTheme(data.palette);
 render();
});
render();if(parent!==window)parent.postMessage({type:'piko-preview-ready'},'*');
