/* Launch routing is shared by expanded and condensed prototype controls. */
(function(root){
  const available=(directions,mode)=>directions.filter(d=>Number.isFinite(d[mode])&&d[mode]>0);
  const route=(directions,mode)=>{const choices=available(directions,mode);return {kind:choices.length>1?'choose':choices.length===1?'direct':'none',choices};};
  const total=(directions,mode)=>available(directions,mode).reduce((sum,d)=>sum+d[mode],0);
  const api={available,route,total,progress:(offset,distance)=>Math.max(0,Math.min(1,offset/distance))};
  if(typeof module!=='undefined')module.exports=api;else root.PikoCollectionHeaderModel=api;
})(globalThis);
