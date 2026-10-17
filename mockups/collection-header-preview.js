/* Requested header experiment, composed around the existing approved list guide. */
(()=>{
  const host=document.getElementById('app'),M=PikoCollectionHeaderModel;
  let scenario='one',opener=null,mode='review';
  const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const t=(key,args={})=>esc(PIKO_COPY.entries[key][document.documentElement.lang==='en'?'en':'de'].replace(/\{(\w+)\}/g,(_,k)=>args[k]));
  const icon=name=>'<span class="lp-icon" aria-hidden="true" style="--lp-icon:url(assets/icons/lucide/'+name+'.svg)"></span>';
  const button=(label,action,cls='',glyph='')=>'<button type="button" class="hp-button '+cls+'" data-hp="'+action+'">'+(glyph?icon(glyph):'')+'<span>'+label+'</span></button>';
  const directions=()=>scenario==='none'?[]:[{id:'de-ko',label:'DE → KO',review:12,speed:9},...(scenario==='two'?[{id:'ko-de',label:'KO → DE',review:7,speed:5}]:[])];
  const compactAction=(ds,m)=>{const count=M.total(ds,m);return '<button type="button" class="hp-button hp-'+m+' hp-count-action" data-hp="'+m+'" aria-label="'+t('header.'+m+'Count',{count})+'" '+(!count?'disabled':'')+'>'+icon(m==='review'?'rotate-ccw':'zap')+'<span class="hp-action-count" aria-hidden="true">'+count+'</span></button>';};
  function mount(){
    const page=host.querySelector('.lp-page');if(!page||page.closest('.hp-phone'))return;
    host.dataset.headerScale=host.querySelector('[data-setting=scale]').value;
    document.title='Piko · '+t('header.preview');
    host.querySelector('.lp-preview-bar>span').textContent=PIKO_COPY.entries['header.preview'][document.documentElement.lang];
    host.querySelector('.lp-preview-note').textContent=PIKO_COPY.entries['header.note'][document.documentElement.lang];
    const controls=document.createElement('div');controls.className='hp-controls';
    controls.innerHTML='<label>'+t('header.scenario')+'<select id="hp-scenario">'+['one','two','none'].map(v=>'<option value="'+v+'" '+(scenario===v?'selected':'')+'>'+t('header.'+v)+'</option>').join('')+'</select></label>'+button(t('header.jump'),'jump')+button(t('header.top'),'top');
    page.before(controls);const phone=document.createElement('div');phone.className='hp-phone';phone.tabIndex=0;phone.setAttribute('aria-label',t('header.preview'));page.before(phone);phone.append(page);
    page.classList.add('hp-page');
    const header=page.querySelector('.lp-collection');header.className='hp-header';
    const ds=directions();
    const expanded=ds.map((d,i)=>'<button type="button" class="hp-button hp-review hp-card '+(i?'hp-secondary':'')+'" data-hp="review:'+d.id+'"><span>'+t('header.due',{direction:d.label,count:d.review})+'</span>'+(!i?'<img class="hp-mascot" src="../app/assets/brand/piko-reading.png" alt="">':'')+icon('rotate-ccw')+'</button>').join('')+'<div class="hp-speed-row">'+ds.map(d=>button(t('header.speed')+'<small>'+t('header.new',{direction:d.label,count:d.speed})+'</small>','speed:'+d.id,'hp-speed hp-card','zap')).join('')+'</div>';
    header.innerHTML='<nav>'+button(t('common.back'),'top','hp-icon-only','arrow-left')+button(t('header.options'),'options','hp-icon-only','ellipsis')+'</nav><div class="hp-title-row"><h1>'+t('language.korean')+'</h1><div class="hp-edit">'+button(t('header.edit'),'edit','hp-icon-only','pencil')+'</div></div><p class="hp-meta"><span class="hp-languages">'+t('language.korean')+' · '+t('language.german')+' · </span>'+t('header.entries',{count:PikoCollectionListModel.fixture().entries.length})+'</p><div class="hp-expanded">'+(ds.length?expanded:'<p>'+t('r2.caughtUp')+'</p>')+'</div><div class="hp-compact" inert>'+(['review','speed'].map(m=>compactAction(ds,m)).join(''))+'</div>';
    const expandedNode=header.querySelector('.hp-expanded'),compact=header.querySelector('.hp-compact');
    header.querySelector('.hp-title-row').append(compact);
    const actionWidth=[...compact.children].reduce((sum,b)=>sum+b.getBoundingClientRect().width,0)+PIKO_DESIGN.spacing['2'];
    header.style.setProperty('--hp-actions-width',actionWidth+'px');
    // Freeze the measured expanded height: scroll never depends on its shrinking geometry.
    const height=expandedNode.scrollHeight;header.style.setProperty('--hp-expanded-height',height+'px');
    const distance=height+PIKO_DESIGN.spacing['6'];
    function update(){const raw=M.progress(phone.scrollTop,distance),p=matchMedia('(prefers-reduced-motion: reduce)').matches?(raw>=.5?1:0):raw;const active=document.activeElement;const transfer=(p>=.5&&expandedNode.contains(active))||(p<.5&&compact.contains(active));const activeMode=active?.dataset?.hp?.split(':')[0];header.style.setProperty('--hp-progress',p);header.classList.toggle('hp-is-compact',p>=.5);expandedNode.inert=p>=.5;compact.inert=p<.5;header.querySelector('.hp-edit').inert=p>=.5;if(transfer&&activeMode){const target=(p>=.5?compact:expandedNode).querySelector('[data-hp^="'+activeMode+'"]');target?.focus({preventScroll:true});}}
    phone.addEventListener('scroll',update,{passive:true});update();
    controls.querySelector('select').addEventListener('change',e=>{scenario=e.target.value;globalThis.render();});
    // Ensure even collapsed groups leave enough room to inspect the persistent header.
    const tail=document.createElement('div');tail.className='hp-scroll-tail';tail.setAttribute('aria-hidden','true');page.append(tail);
    host.dataset.headerDistance=distance;
  }
  function close(){const dialog=host.querySelector('#hp-dialog');if(!dialog)return;dialog.close();dialog.remove();opener?.focus({preventScroll:true});}
  function dialog(title,body){
    host.querySelector('#hp-dialog')?.remove();const node=document.createElement('dialog');node.id='hp-dialog';node.className='hp-dialog';node.setAttribute('aria-labelledby','hp-dialog-title');
    node.innerHTML='<header><h2 id="hp-dialog-title">'+title+'</h2>'+button(t('common.close'),'close','hp-icon-only','x')+'</header><div class="hp-dialog-body">'+body+'</div>';
    host.append(node);node.addEventListener('cancel',e=>{e.preventDefault();close();});node.addEventListener('click',e=>{if(e.target===node){const r=node.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)close();}});node.showModal();
  }
  function launch(m,id){const d=M.available(directions(),m).find(d=>d.id===id);if(!d)return;dialog(t(m==='speed'?'header.speedSetup':'header.started'),'<p>'+t(m==='speed'?'header.speedContext':'header.simulated',{direction:d.label,count:d[m]})+'</p>');}
  host.addEventListener('click',e=>{
    const b=e.target.closest('[data-hp]');if(!b)return;const [action,id]=b.dataset.hp.split(':');
    if(action==='close'){close();return;}
    if(action==='top'||action==='jump'){const phone=host.querySelector('.hp-phone');phone.scrollTo({top:action==='top'?0:Number(host.dataset.headerDistance)+80,behavior:matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});return;}
    if(!host.querySelector('#hp-dialog'))opener=b;
    if(action==='edit'||action==='options'){dialog(t('header.'+action),'<p>'+t('header.'+(action==='edit'?'editNote':'optionsNote'))+'</p>');return;}
    if(action==='direction'){launch(mode,id);return;}
    if(!['review','speed'].includes(action))return;mode=action;
    if(id){launch(mode,id);return;}
    const result=M.route(directions(),mode);if(result.kind==='direct')launch(mode,result.choices[0].id);
    if(result.kind==='choose')dialog(t('header.choose'),result.choices.map(d=>button(t(mode==='review'?'header.due':'header.new',{direction:d.label,count:d[mode]}),'direction:'+d.id,'hp-choice')).join(''));
  });
  globalThis.PikoHeaderPreview={mount};mount();
})();
