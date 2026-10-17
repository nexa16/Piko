/* Ephemeral selection only; deliberately independent of learning and list preferences. */
(function(root){
  function initial(){return {active:false,ids:[]};}
  function toggle(selection,id){selection.active=true;selection.ids=selection.ids.includes(id)?selection.ids.filter(x=>x!==id):[...selection.ids,id];}
  function all(selection,entries){selection.active=true;selection.ids=[...new Set([...selection.ids,...entries.map(e=>e.id)])];}
  function clear(selection){selection.active=false;selection.ids=[];}
  function hidden(selection,entries){const matching=new Set(entries.map(e=>e.id));return selection.ids.filter(id=>!matching.has(id)).length;}
  const api={initial,toggle,all,clear,hidden};root.PikoSelectionModel=api;if(typeof module!=='undefined')module.exports=api;
})(globalThis);
