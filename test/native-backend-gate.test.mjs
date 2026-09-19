import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {buildJevRequest, enrichTrustedSenseOptions, parseDecisions, validateTurn} from '../backend/supabase/functions/_shared/decision-gate.mjs';

test('Deno-compatible gate accepts all recorded native four-decision responses', async () => {
  const evidence = JSON.parse(await readFile(new URL('../public/evidence.json', import.meta.url), 'utf8'));
  const rows = evidence.results.filter(row => row.task === 'decision_bundle' && row.provider === 'jev');
  assert.equal(rows.length, 36);
  for (const row of rows) {
    const example = evidence.cases.find(item => item.id === row.id);
    const turn = validateTurn({text: example.state.source, context: example.state.context, senseOptions: example.state.senseOptions});
    const request = buildJevRequest(turn, example.state.memory);
    const decisions = parseDecisions({answers: row.jevAnswers}, request.questions);
    assert.deepEqual(Object.fromEntries(Object.entries(decisions).map(([id, decision]) => [id, decision.choice])), example.gold);
  }
});

test('native confidence is bounded independently from selected probability', () => {
  const turn = validateTurn({text: 'Hello'});
  const request = buildJevRequest(turn, [{id: 'hello', english: 'Hello', dutch: 'Hallo'}]);
  const response = {answers: Object.fromEntries(Object.entries(request.questions).map(([id, question]) => {
    const choices = Object.keys(question.criteria);
    const choice = id === 'action' ? 'translate' : id === 'memory' ? 'NONE' : id === 'register' ? 'unspecified' : 'NONE';
    const rest = choices.filter(item => item !== choice);
    return [id, {type: 'choice', choice, confidence: .61, probabilities: Object.fromEntries(choices.map(item => [item, item === choice ? .96 : .04 / rest.length]))}];
  }))};
  const parsed = parseDecisions(response, request.questions);
  assert.equal(parsed.action.confidence, .61);
  assert.equal(parsed.action.probabilities.translate, .96);

  response.answers.action.probabilities.translate = .2;
  response.answers.action.probabilities.clarify = .8;
  assert.throws(() => parseDecisions(response, request.questions), /Inconsistent probabilities/);
});


test('trusted ambiguity enrichment matches one deterministic whole-word family only', () => {
  const enriched = enrichTrustedSenseOptions(validateTurn({text: 'The BANK charge is unclear.', senseOptions: {}}));
  assert.deepEqual(Object.keys(enriched.senseOptions), ['bank_finance', 'bank_river']);
  const substring = enrichTrustedSenseOptions(validateTurn({text: 'The banker wrote back.', senseOptions: {}}));
  assert.deepEqual(substring.senseOptions, {});
  const explicit = {charge_custom: 'a custom supplied meaning'};
  assert.deepEqual(enrichTrustedSenseOptions(validateTurn({text: 'charge', senseOptions: explicit})).senseOptions, explicit);
});
