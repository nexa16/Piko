const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
vm.runInThisContext(fs.readFileSync(require.resolve('./mockup.js'),'utf8').split('/* End prototype JSON helper. */')[0]);
const transfer=globalThis.PikoJsonTransfer;
const payload=pairs=>JSON.stringify(transfer.envelope('French',['FR','DE'],pairs));
test('word-only export round trips and detects existing/internal duplicates',()=>{
 const result=transfer.analyze(payload([['pomme','Apfel'],['eau','Wasser'],['eau','Wasser']]),['FR','DE'],[['pomme','Apfel']]);
 assert.deepEqual(result.rows.map(row=>row.duplicate),[true,false,true]);
});
test('invalid, unsupported and mismatched files cannot be applied',()=>{
 for(const text of ['bad','{}',payload([['','word']])])assert.throws(()=>transfer.analyze(text,['FR','DE'],[]));
 assert.throws(()=>transfer.analyze(payload([['a','b']]),['KO','DE'],[]),/json.languages/);
});
test('learning payload requires explicit vocabulary-only acknowledgement',()=>{
 const value=JSON.parse(payload([['pomme','Apfel']]));value.collections[0].entries[0].learning={targetToNative:{}};
 assert.equal(transfer.analyze(JSON.stringify(value),['FR','DE'],[]).hasLearning,true);
});
test('sharp s stays distinct and input arrays are never mutated',()=>{
 const existing=[['Maße','a']],before=JSON.stringify(existing);
 assert.equal(transfer.analyze(payload([['Masse','a']]),['FR','DE'],existing).rows[0].duplicate,false);
 assert.equal(JSON.stringify(existing),before);
});
