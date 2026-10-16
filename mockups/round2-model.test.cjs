const {test} = require('node:test'), assert = require('node:assert/strict');
const json = require('./round2-json.js'), speed = require('./round2-speed.js');
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const collection = () => ({id:id(1),name:'Korean',targetLanguage:'ko',nativeLanguage:'de',reviewScopes:{targetToNative:{ordinal:7,revision:2}},categoryDimensions:[],entries:[{id:id(2),targetText:'학교',nativeText:'Schule',categoryAssignments:[],learning:json.freshLearning('2026-10-14T10:00:00Z')}]});
test('malformed envelope or category definitions produce atomic errors, never throw',()=>{
 const c=collection();
 for(const incoming of [null,{}, {targetLanguage:'ko',nativeLanguage:'de',entries:[{targetText:'a',nativeText:'b',categoryAssignments:[{dimensionId:id(10),valueIds:[]}]}],categoryDimensions:[{id:id(10)}]}]){
  const result=json.analyze(JSON.stringify({format:'piko-vocabulary',schemaVersion:1,collections:[incoming]}),c,[c]);
  assert.equal(result.next,null);assert.ok(result.errors.length);assert.equal(c.entries.length,1);
 }
});
test('empty assignments clear only the selected content group; missing groups preserve values',()=>{
 const c=collection();c.categoryDimensions=[{id:id(10),name:'Topic',mode:'single',values:[{id:id(11),name:'School'}]}];c.entries[0].categoryAssignments=[{dimensionId:id(10),valueIds:[id(11)]}];
 const doc=json.envelope(c);doc.collections[0].entries[0].categoryAssignments=[];
 assert.deepEqual(json.analyze(JSON.stringify(doc),c,[c]).next.entries[0].categoryAssignments,[]);
 assert.deepEqual(json.analyze(JSON.stringify(doc),c,[c],['nativeText']).next.entries[0].categoryAssignments,c.entries[0].categoryAssignments);
 delete doc.collections[0].entries[0].categoryAssignments;assert.deepEqual(json.analyze(JSON.stringify(doc),c,[c]).next.entries[0].categoryAssignments,c.entries[0].categoryAssignments);
});
test('UUID update preserves complete learning and collection scope counters',()=>{
 const c=collection(),doc=json.envelope(c); doc.collections[0].entries[0].nativeText='die Schule'; doc.collections[0].entries[0].learning={malicious:'ignored'};
 const r=json.analyze(JSON.stringify(doc),c,[c]); assert.equal(r.counts.updated,1); assert.deepEqual(r.next.entries[0].learning,c.entries[0].learning); assert.deepEqual(r.next.reviewScopes,c.reviewScopes);assert.equal(c.entries[0].nativeText,'Schule');
});
test('own full export is unchanged on reimport; empty collection roundtrip works',()=>{
 const c=collection();assert.equal(json.analyze(JSON.stringify(json.envelope(c)),c,[c]).counts.unchanged,1);
 c.entries=[];assert.deepEqual(json.analyze(JSON.stringify(json.envelope(c)),c,[c]).next,c);
});
test('missing ID creates fresh learning; incoming learning is never restored',()=>{
 const c=collection(),doc=json.envelope(c);doc.collections[0].entries=[{targetText:'물',nativeText:'Wasser',learning:{bad:1}}];
 const r=json.analyze(JSON.stringify(doc),c,[c],undefined,()=>id(3));assert.equal(r.counts.new,1);assert.equal(r.next.entries[1].id,id(3));assert.equal(r.next.entries[1].learning.targetToNative.reviews.length,0);
});
test('duplicate pairs, duplicate IDs and foreign ownership reject the whole batch',()=>{
 const c=collection(),doc=json.envelope(c);doc.collections[0].entries.push({...doc.collections[0].entries[0],id:id(3)});
 assert.equal(json.analyze(JSON.stringify(doc),c,[c]).next,null);
 doc.collections[0].entries[1].id=id(2);assert.equal(json.analyze(JSON.stringify(doc),c,[c]).next,null);
 const other={...collection(),id:id(4)};assert.equal(json.analyze(JSON.stringify(json.envelope(other)),{...c,entries:[]},[other]).next,null);
});
test('partial groups and omission keep data; ß remains distinct from ss',()=>{
 const c=collection(),doc=json.envelope(c);doc.collections[0].entries[0].targetText='changed';doc.collections[0].entries[0].nativeText='Schule!';
 const r=json.analyze(JSON.stringify(doc),c,[c],['nativeText']);assert.equal(r.next.entries[0].targetText,'학교');assert.equal(r.next.entries[0].nativeText,'Schule!');assert.notEqual(json.key('Maße'),json.key('Masse'));
});
test('category imports preserve existing metadata and validate cardinality',()=>{
 const c=collection();c.categoryDimensions=[{id:id(10),name:'Topic',mode:'single',values:[{id:id(11),name:'School'}]}];
 const doc=json.envelope(c);doc.collections[0].categoryDimensions[0].name='Rename ignored';doc.collections[0].entries[0].categoryAssignments=[{dimensionId:id(10),valueIds:[id(11)]}];
 const r=json.analyze(JSON.stringify(doc),c,[c]);assert.equal(r.next.categoryDimensions[0].name,'Topic');assert.ok(r.keptCategoryMetadata);
 doc.collections[0].entries[0].categoryAssignments[0].valueIds.push(id(12));assert.equal(json.analyze(JSON.stringify(doc),c,[c]).next,null);
});
test('foreign category ownership and reusing a value ID as a dimension reject import',()=>{
 const c=collection(),other={...collection(),id:id(50),entries:[],categoryDimensions:[{id:id(10),name:'Topic',mode:'single',values:[{id:id(11),name:'School'}]}]};
 const doc=json.envelope(c);doc.collections[0].categoryDimensions=other.categoryDimensions;doc.collections[0].entries[0].categoryAssignments=[{dimensionId:id(10),valueIds:[id(11)]}];
 assert.equal(json.analyze(JSON.stringify(doc),c,[c,other]).next,null);
 c.categoryDimensions=other.categoryDimensions;doc.collections[0].categoryDimensions=[{id:id(11),name:'New',mode:'single',values:[]}];doc.collections[0].entries[0].categoryAssignments=[{dimensionId:id(11),valueIds:[]}];assert.equal(json.analyze(JSON.stringify(doc),c,[c]).next,null);
});
test('default pool rotates four other answers and replaces a completed slot',()=>{
 const r=speed.create(['a','b','c','d','e','f']);assert.equal(speed.current(r),'a');speed.grade(r,false);
 for(const word of ['b','c','d','e']){assert.equal(speed.current(r),word);speed.grade(r,false);}
 assert.equal(speed.current(r),'a');assert.equal(speed.needsGame(r),false);speed.grade(r,true);
 for(let i=0;i<4;i++)speed.grade(r,false);const result=speed.grade(r,true);assert.equal(result.finished,true);assert.equal(result.reset,true);assert.ok(r.pool.includes('f'));
});
test('one remaining word receives one game between attempts and none after completion',()=>{
 const r=speed.create(['a','b']);speed.grade(r,false);speed.grade(r,true);assert.ok(speed.needsGame(r));assert.throws(()=>speed.grade(r,true));speed.finishGame(r);assert.ok(!speed.needsGame(r));speed.grade(r,true);assert.ok(speed.needsGame(r));speed.finishGame(r);speed.grade(r,true);assert.equal(speed.current(r),null);
 assert.equal(speed.needsGame(r),false);assert.equal(r.completed,2);assert.equal(r.ordinal,4);
});
test('pool 1 needs no game; streak requirement caps at four',()=>{
 const r=speed.create(['a'],1);for(let i=0;i<6;i++)speed.grade(r,false);for(let i=0;i<3;i++){assert.ok(!speed.needsGame(r));assert.equal(speed.grade(r,true).finished,false);}assert.equal(speed.grade(r,true).finished,true);
});

test('short-pool example follows complete passes 4 → 3 → 3 → 1 → 1 → 0',()=>{
 const r=speed.create(['a','b','c','d']),sizes=[r.pool.length];let games=0;
 const passes=[[['a',true],['b',false],['c',false],['d',false]],[['b',true],['c',true],['d',false]],[['b',true],['c',true],['d',true]],[['d',true]],[['d',true]]];
 for(const [index,pass] of passes.entries()){
  if(index){assert.equal(speed.needsGame(r),true);assert.equal(speed.finishGame(r),true);games++;}
  assert.deepEqual(r.pass.ids,pass.map(([word])=>word));
  for(const [word,correct] of pass){assert.equal(speed.current(r),word);assert.equal(speed.needsGame(r),false);speed.grade(r,correct);}
  sizes.push(r.pool.length);
 }
 assert.deepEqual(sizes,[4,3,3,1,1,0]);assert.equal(games,4);assert.equal(r.ordinal,12);assert.equal(r.completed,4);assert.equal(speed.current(r),null);assert.equal(speed.needsGame(r),false);
});

test('starting below N presents every word once before the first game',()=>{
 const r=speed.create(['a','b','c'],5);
 for(const [index,word] of ['a','b','c'].entries()){
  assert.equal(speed.needsGame(r),false);assert.equal(speed.current(r),word);speed.grade(r,false);
  assert.equal(speed.needsGame(r),index===2);
 }
 assert.deepEqual(r.pass.ids,['a','b','c']);assert.equal(r.ordinal,3);
});

test('shrinking during a pass does not insert a game before its remaining words',()=>{
 const r=speed.create(['a','b','c','d','e']);
 for(const [word,correct] of [['a',true],['b',false],['c',true],['d',false],['e',false]]){
  assert.equal(speed.current(r),word);assert.equal(speed.needsGame(r),false);speed.grade(r,correct);
 }
 assert.deepEqual(r.pool,['b','d','e']);assert.deepEqual(r.pass.ids,['b','d','e']);assert.equal(speed.needsGame(r),true);
 speed.finishGame(r);
 for(const word of ['b','d','e']){assert.equal(speed.current(r),word);assert.equal(speed.needsGame(r),false);speed.grade(r,true);}
 assert.equal(speed.needsGame(r),true);assert.equal(r.completed,2);
});

test('completed slots are replaced in order but replacements wait for the next rotation',()=>{
 const r=speed.create(['a','b','c','d','e','f'],3);
 assert.deepEqual(r.pass.ids,['a','b','c']);speed.grade(r,false);speed.grade(r,true);
 assert.deepEqual(r.pool,['a','d','c']);assert.deepEqual(r.pass.ids,['a','b','c']);assert.equal(speed.current(r),'c');speed.grade(r,true);
 assert.deepEqual(r.pool,['a','d','e']);assert.deepEqual(r.pass.ids,['a','d','e']);assert.deepEqual(r.waiting,['f']);assert.equal(speed.needsGame(r),false);
 speed.grade(r,true);speed.grade(r,true);assert.equal(speed.current(r),'e');assert.deepEqual(r.pool,['a','f','e']);speed.grade(r,false);
 assert.deepEqual(r.pass.ids,['a','f','e']);assert.equal(speed.needsGame(r),false);assert.equal(r.items.f.last,null);
});

test('the short-pool transition at a replacement boundary still waits for the pass to end',()=>{
 const r=speed.create(['a','b','c','d'],3);
 speed.grade(r,true);assert.deepEqual(r.pool,['d','b','c']);assert.equal(speed.current(r),'b');assert.equal(speed.needsGame(r),false);
 speed.grade(r,true);assert.equal(speed.current(r),'c');assert.equal(speed.needsGame(r),false);speed.grade(r,true);
 assert.deepEqual(r.pool,['d']);assert.deepEqual(r.pass.ids,['d']);assert.equal(speed.needsGame(r),true);assert.equal(r.items.d.last,null);
 speed.finishGame(r);assert.equal(speed.grade(r,true).reset,false);assert.equal(speed.current(r),null);assert.equal(speed.needsGame(r),false);
});

test('a full pool rotates without games and one completed game authorizes a whole short pass',()=>{
 const full=speed.create(['a','b','c'],3);
 for(let pass=0;pass<4;pass++)for(const word of ['a','b','c']){assert.equal(speed.current(full),word);assert.equal(speed.needsGame(full),false);speed.grade(full,false);}
 const short=speed.create(['a','b','c'],5);for(let i=0;i<3;i++)speed.grade(short,false);assert.equal(speed.finishGame(short),true);
 for(const word of ['a','b','c']){assert.equal(speed.current(short),word);assert.equal(speed.needsGame(short),false);speed.grade(short,true);}
 assert.equal(speed.needsGame(short),true);assert.equal(short.ordinal,6);
});

test('games cannot be banked or change answers, errors, streaks, completion or pool membership',()=>{
 const r=speed.create(['a','b'],5),initial=structuredClone(r);assert.equal(speed.finishGame(r),false);assert.deepEqual(r,initial);
 speed.grade(r,false);const midpass=structuredClone(r);assert.equal(speed.finishGame(r),false);assert.deepEqual(r,midpass);speed.grade(r,false);
 const pending=structuredClone(r);assert.throws(()=>speed.grade(r,true));assert.deepEqual(r,pending);assert.equal(speed.finishGame(r),true);
 assert.deepEqual(r,{...pending,gamePending:false});const granted=structuredClone(r);assert.equal(speed.finishGame(r),false);assert.deepEqual(r,granted);
 speed.grade(r,true);speed.grade(r,true);assert.equal(speed.needsGame(r),true);
});

test('pool size one rotates replacements without games and leaves completed words out',()=>{
 const r=speed.create(['a','b','c'],1);assert.equal(speed.grade(r,true).finished,true);assert.equal(speed.current(r),'b');assert.equal(speed.needsGame(r),false);
 speed.grade(r,false);assert.equal(speed.current(r),'b');assert.equal(speed.grade(r,true).finished,false);assert.equal(speed.needsGame(r),false);assert.equal(speed.grade(r,true).reset,true);
 assert.equal(speed.current(r),'c');assert.equal(speed.grade(r,true).finished,true);assert.equal(r.completed,3);assert.equal(speed.current(r),null);assert.equal(speed.needsGame(r),false);
 const complete=structuredClone(r);assert.equal(speed.finishGame(r),false);assert.throws(()=>speed.grade(r,true));assert.deepEqual(r,complete);
});

test('reading or revealing the current item cannot advance its pass',()=>{
 const r=speed.create(['a','b']),before=structuredClone(r);
 for(let i=0;i<10;i++){assert.equal(speed.current(r),'a');assert.equal(speed.needsGame(r),false);}
 assert.deepEqual(r,before);speed.grade(r,false);assert.equal(r.pass.index,1);assert.equal(speed.current(r),'b');
});

test('an incorrect answer resets the streak and completion retains the capped reset outcome',()=>{
 const r=speed.create(['a'],1);speed.grade(r,false);speed.grade(r,false);speed.grade(r,true);speed.grade(r,true);
 assert.equal(r.items.a.streak,2);assert.equal(r.completed,0);speed.grade(r,false);assert.equal(r.items.a.streak,0);assert.equal(r.items.a.errors,3);
 for(let i=0;i<3;i++){assert.equal(speed.grade(r,true).finished,false);assert.equal(r.completed,0);}
 assert.deepEqual(speed.grade(r,true),{id:'a',finished:true,reset:true});assert.equal(r.completed,1);
});
