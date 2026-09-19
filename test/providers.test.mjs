import test from 'node:test';
import assert from 'node:assert/strict';
import {createInterpreter} from '../src/interpreter.mjs';
import {createBudget, createProviders, ProviderError, QWEN_MODEL} from '../src/providers.mjs';

const memory = [{id: 'greeting', english: 'Good morning', dutch: 'Goedemorgen'}];
const input = {text: 'Good morning', senseOptions: {greeting: 'a morning greeting'}};
function decisionsFor(request, selected = {}) {
  const defaults = {action: 'translate', memory: 'NONE', register: 'unspecified', sense: 'greeting'};
  return {model: 'jev-test', answers: Object.fromEntries(Object.entries(request.questions).map(([id, q]) => {
    const choice = selected[id] ?? defaults[id]; const ids = Object.keys(q.criteria); const rest = ids.filter(x => x !== choice);
    return [id, {type: 'choice', choice, confidence: .95, probabilities: Object.fromEntries(ids.map(x => [x, x === choice ? .95 : .05 / rest.length]))}];
  }))};
}

test('memory hit skips Qwen, while a miss invokes it exactly once', async () => {
  let hitDecides = 0; let hitTranslations = 0;
  const hit = createInterpreter({memory, providers: {
    async decide(request) { hitDecides++; return decisionsFor(request, {memory: 'greeting'}); },
    async translate() { hitTranslations++; throw new Error('must not run'); },
  }});
  const hitResult = await hit.interpret(input);
  assert.equal(hitDecides, 1); assert.equal(hitTranslations, 0);
  assert.equal(hitResult.route, 'memory'); assert.equal(hitResult.translatedText, 'Goedemorgen');

  let missTranslations = 0;
  const miss = createInterpreter({memory, providers: {
    async decide(request) { return decisionsFor(request); },
    async translate() { missTranslations++; return 'Goedemorgen'; },
  }});
  const missResult = await miss.interpret(input);
  assert.equal(missTranslations, 1); assert.equal(missResult.route, 'translate');
  assert.equal(missResult.translatedText, 'Goedemorgen'); assert.equal(missResult.usedTranslator, true);
});

test('rejects invalid language and invalid memory before calling a provider', async () => {
  let calls = 0;
  const interpreter = createInterpreter({memory, providers: {async decide() { calls++; }, async translate() { calls++; }}});
  await assert.rejects(interpreter.interpret({...input, target: 'de'}), /English to Dutch/);
  assert.equal(calls, 0);
  assert.throws(() => createInterpreter({memory: [{id: 'bad-id', english: 'x', dutch: 'y'}]}), /Memory/);
  assert.throws(() => createInterpreter({memory: [{id: 'same', english: 'x', dutch: 'y'}, {id: 'same', english: 'z', dutch: 'w'}]}), /Memory/);
});

test('decision and translation failures return review with no unverified playback text', async () => {
  const failedGate = createInterpreter({memory, providers: {async decide() { throw new Error('offline'); }, async translate() { throw new Error('unused'); }}});
  const gateResult = await failedGate.interpret(input);
  assert.equal(gateResult.route, 'review'); assert.equal(gateResult.translatedText, ''); assert.equal(gateResult.usedTranslator, false);

  const malformedGate = createInterpreter({memory, providers: {async decide() { return {answers: {}}; }, async translate() { throw new Error('unused'); }}});
  const malformedResult = await malformedGate.interpret(input);
  assert.equal(malformedResult.route, 'review'); assert.equal(malformedResult.translatedText, '');

  const failedQwen = createInterpreter({memory, providers: {async decide(request) { return decisionsFor(request); }, async translate() { throw new Error('bad output'); }}});
  const qwenResult = await failedQwen.interpret(input);
  assert.equal(qwenResult.route, 'review'); assert.equal(qwenResult.translatedText, ''); assert.equal(qwenResult.usedTranslator, true);
});

test('provider calls are capped, never retried, and do not expose keys', async () => {
  const budget = createBudget(1); let calls = 0; const secret = 'never-print-this-key';
  const providers = createProviders({jevKey: secret, qwenKey: secret, budget, fetchImpl: async (_url, options) => {
    calls++; assert.equal(options.headers.Authorization, `Bearer ${secret}`);
    return {ok: false, status: 500, async json() { throw new Error('unused'); }};
  }});
  await assert.rejects(providers.decide({questions: {}}), error => error instanceof ProviderError && error.code === 'provider_unavailable' && !error.message.includes(secret));
  assert.equal(calls, 1);
  await assert.rejects(providers.decide({questions: {}}), error => error.code === 'budget_exhausted');
  assert.equal(calls, 1);
  assert.throws(() => createBudget(0), /MAX_MODEL_CALLS/);
});

test('Qwen uses JSON-object mode and rejects truncated or malformed JSON without retrying', async () => {
  for (const result of [
    {choices: [{finish_reason: 'length', message: {content: '{"translation":"Goed'}}]},
    {choices: [{finish_reason: 'stop', message: {content: '{"translation":'}}]},
  ]) {
    let calls = 0; let captured;
    const providers = createProviders({qwenKey: 'qwen-key', fetchImpl: async (_url, options) => {
      calls++; captured = JSON.parse(options.body); return {ok: true, async json() { return result; }};
    }});
    await assert.rejects(providers.translate({text: 'Good morning', context: '', senseOptions: {}}, {}), error => error instanceof ProviderError && error.code === 'invalid_translation');
    assert.equal(calls, 1);
    assert.equal(captured.model, QWEN_MODEL); assert.equal(captured.temperature, 0); assert.equal(captured.max_tokens, 384);
    assert.deepEqual(captured.response_format, {type: 'json_object'}); assert.equal(captured.store, false);
  }
});
