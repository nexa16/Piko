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
function canonicalRows() {
  const fs=require('node:fs'),path=require('node:path');
  const sources=['piko-functional.md','piko-ux.md'].map(file=>fs.readFileSync(path.join(__dirname,'../docs',file),'utf8'));
  for(const source of sources)assert.doesNotMatch(source,/\[Release:/);
  const rows=sources.flatMap(source=>parse(source));
  assert.equal(new Set(rows.map(r=>r.id)).size,rows.length);
  return rows;
}
test('canonical round 2 retains its features and fixes after later revisions', () => {
  const rows=canonicalRows();
  const selected=rows.filter(r=>matchesRound(r,'2'));
  // Selection follows original/current delta metadata, not a historical row count.
  for(const id of ['MASCOT-001','UX-BRAND-001','UX-MASCOT-001'])assert.ok(selected.some(r=>r.id===id),id);
  for(const id of ['MASCOT-002','MASCOT-003','MASCOT-004','UX-MASCOT-002','UX-MASCOT-003','UX-MASCOT-004']){
    assert.ok(!selected.some(r=>r.id===id),id);
    assert.ok(matchesRound(rows.find(r=>r.id===id),'Later'),id);
  }
  assert.ok(!selected.some(r=>r.id==='SPEED-004'));
  assert.ok(matchesRound(rows.find(r=>r.id==='SPEED-004'),'Later'));
  for(const id of ['IMPORT-JSON-001','IMPORT-JSON-002','SPEED-001','CAT-001','FILTER-003','ENTRY-001','ENTRY-005','UX-ENTRY-001','UX-ENTRY-003','UX-ENTRY-004','UX-CARD-012','RETRY-005','UX-LAB-001'])assert.ok(selected.some(r=>r.id===id),id);
  // The accepted card-menu revision moves deletion's current delta from 2 to 5.
  const deletion=rows.find(r=>r.id==='UX-VOCAB-DELETE-001');
  assert.equal(deletion.round,'1');assert.equal(deletion.updated,'5');
  assert.equal(deletion.revision,4);assert.ok(matchesRound(deletion,'5'));
  assert.ok(!matchesRound(deletion,'2'));
  assert.ok(selected.every(r=>r.status!=='Open'&&r.status!=='Proposed'));
  assert.equal(selected.find(r=>r.id==='REVIEW-001').round,'1');
  assert.equal(selected.find(r=>r.id==='UX-CARD-012').revision,1);
  assert.ok(selected.find(r=>r.id==='IMPORT-JSON-001').body.includes('"schemaVersion": 1'));
  for(const id of ['SPEED-001','SPEED-002','SPEED-012','SPEED-013'])assert.equal(selected.find(r=>r.id===id).revision,2,id);
  for(const id of ['SPEED-007','SPEED-010'])assert.equal(selected.find(r=>r.id===id).revision,3,id);
  assert.match(selected.find(r=>r.id==='SPEED-007').body,/one complete pass through all remaining words/);
  assert.match(selected.find(r=>r.id==='SPEED-007').body,/five attempts have four games/);
  assert.match(selected.find(r=>r.id==='SPEED-007').body,/39/);
  assert.match(selected.find(r=>r.id==='SPEED-010').body,/Acceptance example/);
});
test('round 3 deltas retain original scope and distinguish specified work from verification', () => {
  const rows=canonicalRows();
  for(const id of ['UX-DIALOG-001','UX-I18N-001']){
    const row=rows.find(r=>r.id===id);
    assert.equal(row.round,'1',id);assert.equal(row.updated,'3',id);
    assert.ok(matchesRound(row,'1'),id);assert.ok(matchesRound(row,'3'),id);
    assert.ok(!matchesRound(row,'2'),id);
  }
  const localization=rows.find(r=>r.id==='UX-I18N-001');
  assert.equal(localization.revision,2);
  const completion=rows.find(r=>r.id==='UX-MASCOT-003');
  assert.equal(completion.round,'Later');assert.equal(completion.updated,'3');
  assert.ok(matchesRound(completion,'3'));assert.match(completion.body,/text-only/);
  assert.match(completion.implementation,/pending/);
});
test('round 4 implementation evidence retains owner acceptance and separately deferred learning features', () => {
  const rows=canonicalRows();
  const template=rows.find(r=>r.id==='IMPORT-JSON-003');
  assert.equal(template.revision,1);assert.equal(template.status,'Confirmed');
  assert.equal(template.round,'4');assert.match(template.implementation,/scope implemented/);assert.match(template.implementation,/owner acceptance pending/);
  for(const round of ['1','2','3'])assert.ok(!matchesRound(template,round),round);
  assert.match(template.body,/full export/);
  const brand=rows.find(r=>r.id==='UX-BRAND-001');
  assert.equal(brand.revision,3);assert.match(brand.implementation,/pending/);
  const header=rows.find(r=>r.id==='UX-HEADER-001');
  assert.equal(header.revision,1);assert.equal(header.round,'1');
  assert.equal(header.fix,'4');assert.ok(matchesRound(header,'4'));
  for(const id of ['ENTRY-012','COLL-008','GROUP-001','VOCAB-005','CARD-002','CARD-003','UX-COLL-001','UX-IMPORT-JSON-001']) {
    const row=rows.find(r=>r.id===id);
    assert.ok(matchesRound(row,'4'),id);assert.match(row.implementation,/pending|planned/i,id);
  }
  // Planning must retain complete acceptance paragraphs, not only the first line.
  const interchange=rows.find(r=>r.id==='UX-IMPORT-JSON-001');
  assert.equal(interchange.round,'2');assert.equal(interchange.updated,'4');
  assert.match(interchange.body,/Source inspection/);assert.match(interchange.body,/Acceptance pending/);
  for(const id of ['OPEN-FSRS-002','OPEN-LEARN-004','SPEED-004']) {
    assert.ok(matchesRound(rows.find(r=>r.id===id),'Later'),id);
    assert.ok(!matchesRound(rows.find(r=>r.id===id),'4'),id);
  }
  for(const id of ['LEARN-005','UX-LEARN-005'])assert.equal(rows.find(r=>r.id===id).revision,2,id);
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
