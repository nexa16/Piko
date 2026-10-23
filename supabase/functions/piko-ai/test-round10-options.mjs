import test from 'node:test';
import assert from 'node:assert/strict';
import {validateInput,modelBody} from './ai-protocol.mjs';
const request=()=>({requestId:'00000000-0000-4000-8000-000000000001',issuedAt:new Date().toISOString(),action:'review',scope:'ordinary',goal:'',allowNewGroups:true,allowNewValues:true,
 context:{targetLanguage:'en',nativeLanguage:'de',groups:[],entries:[]},
 options:{level:'A1',goals:['travel'],checks:['categories'],categoryMode:'missing'}});
test('review options are validated separately from free text and protect fill-missing boundary',()=>{
 const input=request();assert.equal(validateInput(input),true);
 const body=modelBody(input,1000);
 assert.match(body.instructions,/missing only fills unassigned/);
 assert.match(body.instructions,/Do not propose changes in disabled fields/);
 assert.equal(body.store,false);assert.equal(body.max_output_tokens,1000);
 for(const options of [{...input.options,level:'C9'},{...input.options,checks:[]},{...input.options,categoryMode:'delete'},{...input.options,goals:['untrusted command']}])assert.equal(validateInput({...input,options}),false);
});
test('compact references remain opaque valid input and no pilot notice enters model body',()=>{
 const input=request();input.context.entries=[{id:'@0',target:'coffee',native:'Kaffee',hint:null,examples:[],assignments:{}}];
 assert.equal(validateInput(input),true);
 const body=modelBody(input,1000);assert.match(body.input[0].content,/@0/);
 assert.doesNotMatch(body.input[0].content,/consent|withdrawn|processors|pilot_ends/);
});
