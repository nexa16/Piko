/* Requested selection-only experiment on the existing vocabulary-list composition. */
(()=>{
  if(new URLSearchParams(location.search).get('preview')!=='collection-selection')return;
  const M=PikoSelectionModel,selection=M.initial();let context,timer=null,press=null,suppressClick=null,scrollTop=0;
  const cancel=()=>{clearTimeout(timer);timer=null;press=null;};
  function beforeRender(){const scroller=context?.host.querySelector(".lp-selection-scroll");if(scroller)scrollTop=scroller.scrollTop;}
  function redraw(focus){beforeRender();context.render();if(focus)context.host.querySelector(focus)?.focus({preventScroll:true});}
  function decorate(ctx){
    context=ctx;document.documentElement.dataset.selectionPreview="true";const {host,data,state,text}=ctx;
    const copy=(key,values)=>text('selection.'+key,values);
    const button=(key,action)=>{const b=document.createElement('button');b.type='button';b.className='lp-button';b.dataset.selectionAction=action;b.textContent=copy(key);return b;};
    document.title='Piko · '+copy('preview');host.querySelector('.lp-preview-bar>span').textContent=copy('preview');
    host.querySelector('.lp-preview-note').textContent=copy('note');
    const bar=document.createElement('div');bar.className='lp-selection-bar';bar.setAttribute('aria-label',copy('controls'));
    {
      const status=document.createElement('div');status.className='lp-selection-status';status.setAttribute('role','status');status.setAttribute('aria-live','polite');
      const count=document.createElement('strong');count.textContent=copy('count',{count:selection.ids.length});status.append(count);
      const hidden=M.hidden(selection,PikoCollectionListModel.filtered(data,state));
      if(hidden){const detail=document.createElement('small');detail.textContent=copy('hidden',{count:hidden});status.append(detail);}
      bar.append(status);const actions=document.createElement('div');actions.className='lp-selection-actions';
      const all=button('all','all'),matching=PikoCollectionListModel.filtered(data,state);all.disabled=!matching.some(e=>!selection.ids.includes(e.id));
      actions.append(all,button('clear','clear'));bar.append(actions);
      bar.inert=ctx.modalOpen||!selection.active;bar.style.visibility=selection.active?"visible":"hidden";host.append(bar);
    }
    host.querySelectorAll('.lp-word').forEach(row=>{
      if(!selection.active)return;
      const checked=selection.ids.includes(row.dataset.id);row.classList.toggle('lp-word-selected',checked);row.setAttribute('aria-pressed',String(checked));
      const mark=document.createElement('span');mark.className='lp-selection-check';mark.setAttribute('aria-hidden','true');mark.textContent=checked?'✓':'';row.prepend(mark);row.classList.add('lp-selection-word');
    });
    // Preview-only page exit proves that returning starts with a fresh selection.
    const nav=button('leave','leave');nav.classList.add('lp-selection-leave');host.querySelector('.lp-preview-bar').after(nav);
    let scroller=host.querySelector('.lp-selection-scroll');
    if(!scroller){scroller=document.createElement('div');scroller.className='lp-selection-scroll';for(const node of [...host.children])if(node!==bar&&node.id!=='lp-modal-host')scroller.append(node);host.prepend(scroller);}
    const inset=bar.getBoundingClientRect().height+2*PIKO_DESIGN.spacing['3'];
    scroller.style.bottom=inset+'px';scroller.scrollTop=scrollTop;
    if(!selection.active)bar.remove();
  }
  document.addEventListener('click',event=>{
    if(!context)return;if(event.target.closest('[data-action="reset"]'))M.clear(selection);const action=event.target.closest('[data-selection-action]')?.dataset.selectionAction,row=event.target.closest('.lp-word');
    if(row&&suppressClick===row.dataset.id){event.preventDefault();event.stopImmediatePropagation();suppressClick=null;return;}
    if(row&&selection.active){event.preventDefault();event.stopImmediatePropagation();M.toggle(selection,row.dataset.id);redraw('.lp-word[data-id="'+row.dataset.id+'"]');return;}
    if(!action)return;event.preventDefault();event.stopImmediatePropagation();cancel();
    if(action==='leave'){M.clear(selection);const url=new URL(location.href);url.searchParams.set('preview','collection-list');location.href=url;return;}
    if(action==='start')selection.active=true;
    if(action==='all')M.all(selection,PikoCollectionListModel.filtered(context.data,context.state));
    if(action==='clear')M.clear(selection);
    redraw(selection.active?'[data-selection-action="clear"]':'#lp-options');
  },true);
  document.addEventListener('pointerdown',event=>{
    cancel();suppressClick=null;const row=event.target.closest('.lp-word');if(!row||event.button!==0||selection.active)return;
    press={id:row.dataset.id,x:event.clientX,y:event.clientY};
    timer=setTimeout(()=>{const id=press?.id;if(!id)return;suppressClick=id;M.toggle(selection,id);cancel();redraw('.lp-word[data-id="'+id+'"]');},500);
  });
  document.addEventListener('pointermove',event=>{if(press&&Math.hypot(event.clientX-press.x,event.clientY-press.y)>10)cancel();});
  for(const event of ['pointerup','pointercancel','scroll'])document.addEventListener(event,cancel,true);
  document.addEventListener('contextmenu',event=>{if(event.target.closest('.lp-word'))event.preventDefault();});
  document.addEventListener('keydown',event=>{
    const row=event.target.closest('.lp-word');if(row&&event.shiftKey&&event.code==='Space'){event.preventDefault();M.toggle(selection,row.dataset.id);redraw('.lp-word[data-id="'+row.dataset.id+'"]');}
  });
  window.addEventListener('resize',()=>{if(context)redraw();});
  window.addEventListener('pageshow',event=>{if(event.persisted){M.clear(selection);if(context)redraw();}});
  globalThis.PikoSelectionPreview={decorate,beforeRender};
})();
