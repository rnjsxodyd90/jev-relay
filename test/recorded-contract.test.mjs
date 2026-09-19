import test from 'node:test';import assert from 'node:assert/strict';import{readFile}from'node:fs/promises';import{buildJevRequest,parseDecisions,validateTurn}from'../src/decision-gate.mjs';
test('the reusable gate accepts all 36 recorded native four-decision responses',async()=>{
 const evidence=JSON.parse(await readFile(new URL('../public/evidence.json',import.meta.url),'utf8'));
 const rows=evidence.results.filter(r=>r.task==='decision_bundle'&&r.provider==='jev');assert.equal(rows.length,36);
 for(const row of rows){const c=evidence.cases.find(c=>c.id===row.id);const input=validateTurn({text:c.state.source,context:c.state.context,senseOptions:c.state.senseOptions});const request=buildJevRequest(input,c.state.memory);const decisions=parseDecisions({answers:row.jevAnswers},request.questions);assert.deepEqual(Object.fromEntries(Object.entries(decisions).map(([k,v])=>[k,v.choice])),c.gold);}
});
