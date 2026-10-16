const {test} = require('node:test');
const assert = require('node:assert/strict');
const {parse, matchesRound, normalizeRound} = require('./requirements-parser.js');
test('round deltas retain original round, revision and separate implementation status', () => {
  const rows = parse('- **UX-COLL-008 [Confirmed]:** [Round: 1] [Revision: 2] [Updated: 2] [Implementation: Planned] [Flow: collection, review] Current rule.\n\nSecond paragraph.\n- **CARD-UI-026 [Confirmed]:** [Round: 1] [Fix: 2] Existing rule.');
  assert.equal(rows.length, 2); assert.equal(rows[0].revision, 2);
  assert.equal(rows[0].round, '1'); assert.equal(rows[0].implementation, 'Planned');
  assert.equal(rows[0].body, 'Current rule.\n\nSecond paragraph.');
  assert.ok(rows.every(x => matchesRound(x, '2')));
  assert.ok(rows.every(x => matchesRound(x, '1')));
  assert.equal(rows[1].revision, 1); assert.ok(!matchesRound(rows[0], 'Later'));
});
test('old release tags and bookmarked names map to implementation rounds', () => {
  const [row] = parse('- **REVIEW-001 [Confirmed]:** [Release: First] [Updated: Second] Legacy rule.');
  assert.equal(normalizeRound('First'), '1'); assert.equal(normalizeRound('Second'), '2');
  assert.equal(row.round, '1'); assert.equal(row.updated, '2');
  assert.ok(matchesRound(row, 'Second')); assert.ok(matchesRound(row, '2'));
  assert.equal(row.body, 'Legacy rule.');
});
test('JSON examples and paragraphs survive blank lines; headings end the record', () => {
  const [row] = parse('- **IMPORT-JSON-001 [Confirmed]:** [Release: Second] Envelope.\n\n```json\n{"collections": []}\n```\n\nRules.\n## Other\nNot part of it');
  assert.match(row.body, /"collections"/); assert.match(row.body, /Rules/); assert.doesNotMatch(row.body, /Other/);
});
test('resolved technical decisions are not inferred to be open from their IDs', () => {
  const [row] = parse('- **OPEN-LEARN-001 [Resolved product behavior]:** [Release: Second] Settled.');
  assert.equal(row.status, 'Resolved product behavior');
});
test('canonical round 2 includes its features and fixes without unresolved product questions', () => {
  const fs=require('node:fs'),path=require('node:path');
  const sources=['piko-functional.md','piko-ux.md'].map(file=>fs.readFileSync(path.join(__dirname,'../docs',file),'utf8'));
  for(const source of sources)assert.doesNotMatch(source,/\[Release:/);
  const rows=sources.flatMap(source=>parse(source));
  assert.equal(new Set(rows.map(r=>r.id)).size,rows.length);
  const selected=rows.filter(r=>matchesRound(r,'2'));
  assert.equal(selected.length,56);assert.equal(rows.filter(r=>matchesRound(r,'1')).length,90);
  for(const id of ['MASCOT-001','UX-BRAND-001','UX-MASCOT-001'])assert.ok(selected.some(r=>r.id===id),id);
  for(const id of ['MASCOT-002','MASCOT-003','MASCOT-004','UX-MASCOT-002','UX-MASCOT-003','UX-MASCOT-004']){
    assert.ok(!selected.some(r=>r.id===id),id);
    assert.ok(matchesRound(rows.find(r=>r.id===id),'Later'),id);
  }
  assert.ok(!selected.some(r=>r.id==='SPEED-004'));
  assert.ok(matchesRound(rows.find(r=>r.id==='SPEED-004'),'Later'));
  for(const id of ['IMPORT-JSON-001','IMPORT-JSON-002','SPEED-001','CAT-001','FILTER-003','ENTRY-001','ENTRY-005','UX-ENTRY-001','UX-ENTRY-003','UX-ENTRY-004','UX-VOCAB-DELETE-001','UX-DIALOG-001','UX-CARD-012','RETRY-005','UX-LAB-001'])assert.ok(selected.some(r=>r.id===id),id);
  assert.ok(selected.every(r=>r.status!=='Open'&&r.status!=='Proposed'));
  assert.equal(selected.find(r=>r.id==='REVIEW-001').round,'1');
  assert.equal(selected.find(r=>r.id==='UX-CARD-012').revision,1);
  assert.ok(selected.find(r=>r.id==='IMPORT-JSON-001').body.includes('"schemaVersion": 1'));
  for(const id of ['SPEED-001','SPEED-002','SPEED-007','SPEED-010','SPEED-012','SPEED-013'])assert.equal(selected.find(r=>r.id===id).revision,2,id);
  assert.match(selected.find(r=>r.id==='SPEED-007').body,/one complete pass through all remaining words/);
  assert.match(selected.find(r=>r.id==='SPEED-007').body,/five attempts have four games/);
  assert.match(selected.find(r=>r.id==='SPEED-010').body,/Acceptance example/);
});
test('prototype literal copy references exist in the shared bilingual catalog',()=>{
  const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),context={};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../shared/copy.js'),'utf8'),context);
  const source=fs.readFileSync(path.join(__dirname,'round2.js'),'utf8');
  for(const match of source.matchAll(/\b(?:t|raw|btn|icon|field)\('([a-z][a-zA-Z0-9.]+)'/g)){
    const key=match[1];if(key.endsWith('.'))continue;
    assert.ok(context.PIKO_COPY.entries[key]?.en,key);assert.ok(context.PIKO_COPY.entries[key]?.de,key);
  }
});
