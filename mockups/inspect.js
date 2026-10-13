/* Prototype-only, non-blocking layout inspection. All measurements are CSS pixels. */
(()=>{
 let enabled=false,target=null,frame=0;
 const root=document.createElement('div');root.id='piko-inspector';root.hidden=true;root.setAttribute('aria-hidden','true');
 root.innerHTML='<div class="inspect-margin"></div><div class="inspect-padding"></div><div class="inspect-content"></div><svg class="inspect-guides"></svg><div class="inspect-tooltip"></div>';
 document.body.append(root);
 const [margin,padding,content,guides,tip]=root.children;
 const n=value=>parseFloat(value)||0,px=value=>Math.round(value*10)/10+'px';
 function box(el,x,y,w,h){Object.assign(el.style,{left:x+'px',top:y+'px',width:Math.max(0,w)+'px',height:Math.max(0,h)+'px'});}
 function textLine(text){const el=document.createElement('div');el.textContent=text;tip.append(el);}
 function line(x1,y1,x2,y2,label){const ns='http://www.w3.org/2000/svg',l=document.createElementNS(ns,'line');Object.entries({x1,y1,x2,y2}).forEach(([k,v])=>l.setAttribute(k,v));guides.append(l);const t=document.createElementNS(ns,'text');t.setAttribute('x',(x1+x2)/2+3);t.setAttribute('y',(y1+y2)/2-4);t.textContent=label;guides.append(t);}
 function draw(){frame=0;if(!enabled||!target?.isConnected){root.hidden=true;return;}const r=target.getBoundingClientRect(),s=getComputedStyle(target),p=target.parentElement,pr=p?.getBoundingClientRect(),ps=p?getComputedStyle(p):null;
 root.hidden=false;
 const pt=n(s.paddingTop),pb=n(s.paddingBottom),pl=n(s.paddingLeft),pp=n(s.paddingRight),bt=n(s.borderTopWidth),bb=n(s.borderBottomWidth),bl=n(s.borderLeftWidth),br=n(s.borderRightWidth),mt=n(s.marginTop),mb=n(s.marginBottom),ml=n(s.marginLeft),mr=n(s.marginRight);
 box(margin,r.left-ml,r.top-mt,r.width+ml+mr,r.height+mt+mb);box(padding,r.left+bl,r.top+bt,r.width-bl-br,r.height-bt-bb);box(content,r.left+bl+pl,r.top+bt+pt,r.width-bl-br-pl-pp,r.height-bt-bb-pt-pb);
 guides.replaceChildren();tip.replaceChildren();
 textLine(target.tagName.toLowerCase()+(target.id?'#'+target.id:'')+' · '+px(r.width)+' × '+px(r.height));
 textLine('Padding T/R/B/L: '+[pt,pp,pb,pl].map(px).join(' / '));textLine('Margin T/R/B/L: '+[mt,mr,mb,ml].map(px).join(' / '));
 textLine('Type: '+s.fontSize+' / line-height '+s.lineHeight+' · weight '+s.fontWeight);
 textLine('Element: '+s.display+' · position '+s.position+' · box-sizing '+s.boxSizing);
 if(pr&&ps){const left=pr.left+n(ps.borderLeftWidth)+n(ps.paddingLeft),right=pr.right-n(ps.borderRightWidth)-n(ps.paddingRight),top=pr.top+n(ps.borderTopWidth)+n(ps.paddingTop),bottom=pr.bottom-n(ps.borderBottomWidth)-n(ps.paddingBottom);
 textLine('Parent: '+ps.display+' · gap '+ps.gap+' · align '+ps.alignItems+' · justify '+ps.justifyContent);
 textLine('Parent content distances T/R/B/L: '+[r.top-top,right-r.right,bottom-r.bottom,r.left-left].map(px).join(' / '));
 line(left,r.top+r.height/2,r.left,r.top+r.height/2,px(r.left-left));line(r.right,r.top+r.height/2,right,r.top+r.height/2,px(right-r.right));line(r.left+r.width/2,top,r.left+r.width/2,r.top,px(r.top-top));
 }
 for(const [name,sibling] of [['Previous',target.previousElementSibling],['Next',target.nextElementSibling]])if(sibling&&getComputedStyle(sibling).display!=='none'){const sr=sibling.getBoundingClientRect();const vertical=name==='Previous'?r.top-sr.bottom:sr.top-r.bottom,horizontal=name==='Previous'?r.left-sr.right:sr.left-r.right;const overlapX=r.left<sr.right&&r.right>sr.left,overlapY=r.top<sr.bottom&&r.bottom>sr.top;if(overlapX&&vertical>=0)textLine(name+' sibling vertical gap: '+px(vertical));else if(overlapY&&horizontal>=0)textLine(name+' sibling horizontal gap: '+px(horizontal));}
 textLine('Orange = margin · green = padding · blue = content');textLine('Measured geometry, not Figma anchoring constraints · Esc exits');
 tip.style.left='8px';tip.style.top='8px';const tr=tip.getBoundingClientRect();tip.style.left=Math.max(8,Math.min(innerWidth-tr.width-8,r.right+12))+'px';tip.style.top=Math.max(8,Math.min(innerHeight-tr.height-8,r.bottom+10))+'px';
 }
 function schedule(){if(!frame)frame=requestAnimationFrame(draw);}
 function set(value){enabled=!!value;root.hidden=!enabled;control?.setAttribute('aria-pressed',String(enabled));if(!enabled)target=null;else schedule();if(parent!==window)parent.postMessage({type:'piko-inspect-state',enabled},'*');}
 document.addEventListener('pointermove',event=>{if(!enabled||event.target.closest('#piko-inspector,[data-dev-control]'))return;target=event.target;schedule();});document.addEventListener('focusin',event=>{if(enabled&&!event.target.closest('[data-dev-control]')){target=event.target;schedule();}});
 document.addEventListener('keydown',event=>{if(event.key==='Escape'&&enabled)set(false);});window.addEventListener('resize',schedule);document.addEventListener('scroll',schedule,true);
 window.addEventListener('message',event=>{if(event.source===parent&&parent!==window&&event.data?.type==='piko-design-preview'&&typeof event.data.inspect==='boolean')set(event.data.inspect);});
 let control=null;if(parent===window){control=document.createElement('button');control.type='button';control.dataset.devControl='true';control.className='inspect-toggle';control.textContent='Dev mode';control.setAttribute('aria-pressed','false');control.title='Inspect sizes, padding and spacing (CSS px)';control.onclick=()=>set(!enabled);document.body.append(control);}
 set(new URLSearchParams(location.search).get('inspect')==='1');
})();
