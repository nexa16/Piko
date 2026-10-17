const {test}=require('node:test'),assert=require('node:assert/strict'),M=require('./collection-header-model.js');
test('each learning mode resolves its own positive directions',()=>{const ds=[{id:'a',review:5,speed:0},{id:'b',review:2,speed:8}];assert.equal(M.route(ds,'review').kind,'choose');assert.equal(M.route(ds,'speed').kind,'direct');assert.equal(M.route(ds,'speed').choices[0].id,'b');assert.equal(M.route([],'review').kind,'none');});
test('zero and unavailable counts never become direction choices',()=>{assert.equal(M.route([{review:0},{review:NaN},{review:-1}],'review').kind,'none');});
test('scroll collapse is bounded and reversible',()=>{assert.equal(M.progress(-10,200),0);assert.equal(M.progress(100,200),.5);assert.equal(M.progress(500,200),1);assert.equal(M.progress(0,200),0);});

test("compact mode totals sum directional eligibility independently, retaining zero",()=>{const ds=[{review:12,speed:9},{review:7,speed:5}];assert.equal(M.total(ds,"review"),19);assert.equal(M.total(ds,"speed"),14);assert.equal(M.total(ds.slice(0,1),"review"),12);assert.equal(M.total([],"speed"),0);assert.equal(M.total([{review:0},{review:NaN},{review:-2}],"review"),0);});
