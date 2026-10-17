/* Focused sample-data model for UX-COLL-001 r4; no app storage or learning. */
(function(root){
  function fixture(){
    const units=[['u1','Unit 1 · Familie'],['u2','Unit 2 · Unterwegs'],['u3','Unit 3 · Essen & Trinken'],['u4','Unit 4 · Alltag und Verabredungen']];
    const pairs=[
      ['할아버지','Großvater','u1','noun'],['할머니','Großmutter','u1','noun'],['가족','Familie','u1','noun'],['만나다','treffen','u1','verb'],
      ['기차','Zug','u2','noun'],['역','Bahnhof','u2','noun'],['표','Fahrkarte','u2','noun'],['가다','gehen','u2','verb'],['빠르다','schnell sein','u2','adjective'],
      ['물','Wasser','u3','noun'],['밥','Reis; Mahlzeit','u3','noun'],['커피','Kaffee','u3','noun'],['먹다','essen','u3','verb'],['맛있다','lecker sein','u3','adjective'],
      ['약속','Verabredung','u4','noun'],['시간','Zeit','u4','noun'],['오늘','heute','u4','adverb'],['내일','morgen','u4','adverb'],['기다리다','warten','u4','verb'],['바쁘다','beschäftigt sein','u4','adjective']
    ];
    return {name:'Korean Basics',dimensions:[
      {id:'unit',name:'Unit',values:units.map(([id,name])=>({id,name}))},
      {id:'type',nameKey:'list.wordType',values:['adjective','adverb','noun','verb'].map(id=>({id,nameKey:'list.'+id}))}
    ],entries:pairs.map(([target,native,unit,type],i)=>({id:'sample-'+i,target,native,assignments:{unit:[unit],type:[type]},addedAt:i<4?null:Date.UTC(2026,9,1+i),example:i===0?['할아버지를 만나요.','Ich treffe meinen Großvater.']:null}))};
  }
  const normalize=value=>value.normalize('NFC').toLowerCase();
  const filterCount=filters=>new Set(Object.values(filters).flat()).size;
  function initial(){return {search:'',filters:{},grouping:'unit',sort:'original',mode:'compact',targetFirst:true,expanded:[]};}
  function filtered(data,state){return data.entries.filter(e=>(!state.search||[e.target,e.native].some(t=>normalize(t).includes(normalize(state.search))))&&Object.entries(state.filters).every(([id,values])=>!values.length||values.some(v=>(e.assignments[id]||[]).includes(v))));}
  function sorted(entries,sort){return entries.map((e,index)=>({e,index})).sort((a,b)=>{
    if(sort==='original')return a.index-b.index;
    let value=0;
    if(sort==='newest'||sort==='oldest'){
      if(a.e.addedAt===null||b.e.addedAt===null)return a.e.addedAt===b.e.addedAt?a.index-b.index:a.e.addedAt===null?1:-1;
      value=(a.e.addedAt-b.e.addedAt)*(sort==='newest'?-1:1);
    }else{const field=sort.startsWith('target')?'target':'native';const left=normalize(a.e[field]),right=normalize(b.e[field]);value=(left<right?-1:left>right?1:0)*(sort.endsWith('Descending')?-1:1);}
    return value||a.index-b.index;
  }).map(x=>x.e);}
  function groups(data,state){const entries=sorted(filtered(data,state),state.sort);if(!state.grouping)return [{id:null,entries}];const dimension=data.dimensions.find(d=>d.id===state.grouping);if(!dimension)return [{id:null,entries}];const result=dimension.values.map(v=>({...v,entries:entries.filter(e=>(e.assignments[dimension.id]||[]).includes(v.id))})).filter(g=>g.entries.length);const unassigned=entries.filter(e=>!(e.assignments[dimension.id]||[]).length);if(unassigned.length)result.push({id:'unassigned',nameKey:'view.unassigned',entries:unassigned});return result;}
  function bulk(data,state){const ids=state.grouping?groups(data,state).map(g=>g.id):[];return {ids,enabled:ids.length>0,action:ids.some(id=>!state.expanded.includes(id))?'expand':'collapse'};}
  function expand(data,state,open){const ids=bulk(data,state).ids;state.expanded=open?[...new Set([...state.expanded,...ids])]:state.expanded.filter(id=>!ids.includes(id));}
  function clearFilters(state){state.filters={};}
  function sameFilters(a,b){const clean=x=>Object.fromEntries(Object.entries(x).filter(([,v])=>v.length).sort(([a],[b])=>a.localeCompare(b)).map(([id,v])=>[id,[...new Set(v)].sort()]));return JSON.stringify(clean(a))===JSON.stringify(clean(b));}
  const api={fixture,initial,filtered,sorted,groups,bulk,expand,filterCount,clearFilters,sameFilters};
  root.PikoCollectionListModel=api;if(typeof module!=='undefined')module.exports=api;
})(globalThis);
