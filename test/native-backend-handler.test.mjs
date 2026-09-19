import test from 'node:test';
import assert from 'node:assert/strict';
import {
  AuthError,
  BODY_LIMIT_BYTES,
  ConflictError,
  QuotaError,
  createNativeBackendHandler,
  normalizeLimits,
} from '../backend/supabase/functions/_shared/handler.mjs';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const REQUEST_ID = '22222222-2222-4222-8222-222222222222';
const memory = [{id: 'hello', english: 'Hello', dutch: 'Hallo'}];

function decisionsFor(request, selected = {}, confidence = .95) {
  const defaults = {action: 'translate', memory: 'NONE', register: 'unspecified', sense: 'NONE'};
  return {model: 'jev-native-test', answers: Object.fromEntries(Object.entries(request.questions).map(([id, question]) => {
    const choice = selected[id] ?? defaults[id];
    const choices = Object.keys(question.criteria);
    const rest = choices.filter(item => item !== choice);
    return [id, {type: 'choice', choice, confidence, probabilities: Object.fromEntries(choices.map(item => [item, item === choice ? .95 : .05 / rest.length]))}];
  }))};
}

function fixture(overrides = {}) {
  const events = [];
  const auth = overrides.auth ?? {async getUser(token) { events.push(['auth', token]); return {id: USER_ID}; }};
  const quota = overrides.quota ?? {async reserve(input) { events.push(['quota', input]); }};
  const providers = overrides.providers ?? {
    async decide(request) { events.push(['decide']); return decisionsFor(request, {memory: 'hello'}); },
    async translate() { events.push(['translate']); return 'Hallo'; },
  };
  const accounts = overrides.accounts ?? {async deleteUser(id) { events.push(['delete', id]); }};
  const handler = createNativeBackendHandler({auth, quota, providers, accounts, memory, requestId: () => REQUEST_ID, ...overrides});
  return {handler, events};
}

function interpretRequest(body, headers = {}, options = {}) {
  return new Request('https://project.invalid/functions/v1/native-backend/interpret', {
    method: 'POST',
    headers: {Authorization: 'Bearer user-token', 'Content-Type': 'application/json', ...headers},
    body: typeof body === 'string' ? body : JSON.stringify(body),
    ...options,
  });
}

async function body(response) { return await response.json(); }

test('health reports readiness without secrets or CORS', async () => {
  const {handler} = fixture();
  const response = await handler(new Request('https://project.invalid/functions/v1/native-backend/health'));
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('access-control-allow-origin'), null);
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const value = await body(response);
  assert.equal(value.version, 'native-backend/1');
  assert.equal(value.ready, true);
  assert.deepEqual(value.limits, {userDaily: 10, globalDaily: 60, globalMonthly: 300});
  assert.doesNotMatch(JSON.stringify(value), /user-token|service.role|api.key/i);
});

test('auth runs before body processing and invalid turns never reserve quota or call providers', async () => {
  let authCalls = 0;
  const denied = fixture({auth: {async getUser() { authCalls++; throw new AuthError(); }}});
  const unauthorized = await denied.handler(interpretRequest('x'.repeat(BODY_LIMIT_BYTES + 1)));
  assert.equal(unauthorized.status, 401);
  assert.equal(authCalls, 1);

  const invalid = fixture();
  const response = await invalid.handler(interpretRequest({text: '', userId: USER_ID, quotaOverride: 999}));
  assert.equal(response.status, 400);
  assert.deepEqual(invalid.events.map(event => event[0]), ['auth']);
});

test('reserves both possible attempts before Jev and skips Qwen on memory reuse', async () => {
  const {handler, events} = fixture();
  const response = await handler(interpretRequest({text: 'Hello'}));
  const value = await body(response);
  assert.equal(response.status, 200);
  assert.equal(value.route, 'memory');
  assert.equal(value.translatedText, 'Hallo');
  assert.equal(value.requestId, REQUEST_ID);
  assert.deepEqual(events.map(event => event[0]), ['auth', 'quota', 'decide']);
  assert.equal(events[1][1].userId, USER_ID);
  assert.equal(events[1][1].idempotencyKey, REQUEST_ID);
  assert.equal(events[1][1].maxProviderAttempts, 2);
  assert.deepEqual(events[1][1].limits, {userDaily: 10, globalDaily: 60, globalMonthly: 300});
});

test('Jev and Qwen each run at most once and failures fail closed without error leakage', async () => {
  let decisions = 0;
  let translations = 0;
  const {handler} = fixture({providers: {
    async decide(request) { decisions++; return decisionsFor(request); },
    async translate() { translations++; throw new Error('provider secret diagnostic'); },
  }});
  const response = await handler(interpretRequest({text: 'New wording'}));
  const value = await body(response);
  assert.equal(response.status, 200);
  assert.equal(decisions, 1);
  assert.equal(translations, 1);
  assert.equal(value.route, 'review');
  assert.equal(value.translatedText, '');
  assert.equal(value.usedTranslator, true);
  assert.doesNotMatch(JSON.stringify(value), /provider secret diagnostic/);
  assert.deepEqual(Object.keys(value).sort(), ['clarification', 'decisions', 'mode', 'model', 'reason', 'requestId', 'route', 'sourceText', 'timing', 'translatedText', 'usedTranslator'].sort());
});

test('quota rejection occurs before providers and still authenticates a real user', async () => {
  let providerCalls = 0;
  const {handler, events} = fixture({
    quota: {async reserve() { events.push(['quota']); throw new QuotaError('quota_global_daily'); }},
    providers: {async decide() { providerCalls++; }, async translate() { providerCalls++; }},
  });
  const response = await handler(interpretRequest({text: 'Hello'}));
  assert.equal(response.status, 429);
  assert.equal((await body(response)).code, 'quota_global_daily');
  assert.equal(providerCalls, 0);
});

test('body limit, content type, and unsupported client controls fail before quota', async () => {
  for (const request of [
    interpretRequest('x'.repeat(BODY_LIMIT_BYTES + 1)),
    new Request('https://project.invalid/interpret', {method: 'POST', headers: {Authorization: 'Bearer user-token', 'Content-Type': 'text/plain'}, body: '{}'}),
    interpretRequest({text: 'Hello', limits: {userDaily: 999}}),
  ]) {
    const {handler, events} = fixture();
    const response = await handler(request);
    assert.equal(response.status, 400);
    assert.deepEqual(events.map(event => event[0]), ['auth']);
  }
});

test('delete-session deletes only the verified identity, accepts no client identity, and does not touch quota', async () => {
  const {handler, events} = fixture();
  const response = await handler(new Request('https://project.invalid/functions/v1/native-backend/delete-session', {method: 'POST', headers: {Authorization: 'Bearer user-token'}}));
  assert.equal(response.status, 200);
  assert.deepEqual(events, [['auth', 'user-token'], ['delete', USER_ID]]);
  const value = await body(response);
  assert.equal(value.deleted, true);
  assert.equal(value.retained.pseudonymousQuotaUntilCounterExpiry, true);
  assert.equal(value.retained.globalAggregateCaps, true);

  const withBody = fixture();
  const rejected = await withBody.handler(new Request('https://project.invalid/delete-session', {method: 'POST', headers: {Authorization: 'Bearer user-token', 'Content-Type': 'application/json'}, body: JSON.stringify({userId: 'someone-else'})}));
  assert.equal(rejected.status, 400);
  assert.deepEqual(withBody.events.map(event => event[0]), ['auth']);
});

test('configuration limits can only reduce database hard caps', () => {
  assert.deepEqual(normalizeLimits({userDaily: '5', globalDaily: 40, globalMonthly: 200}), {userDaily: 5, globalDaily: 40, globalMonthly: 200});
  assert.throws(() => normalizeLimits({userDaily: 11}), /only reduce/);
  assert.throws(() => normalizeLimits({globalDaily: 0}), /only reduce/);
  assert.throws(() => normalizeLimits({globalMonthly: 300.5}), /only reduce/);
});


test('validated Idempotency-Key is reserved while an absent header uses the server request UUID', async () => {
  const actionId = '33333333-3333-4333-8333-333333333333';
  const explicit = fixture();
  assert.equal((await explicit.handler(interpretRequest({text: 'Hello'}, {'Idempotency-Key': actionId}))).status, 200);
  assert.equal(explicit.events.find(event => event[0] === 'quota')[1].idempotencyKey, actionId);

  const invalid = fixture();
  const rejected = await invalid.handler(interpretRequest({text: 'Hello'}, {'Idempotency-Key': 'not-a-uuid'}));
  assert.equal(rejected.status, 400);
  assert.deepEqual(invalid.events.map(event => event[0]), ['auth']);
});

test('duplicate action conflicts are returned as 409 before any provider call', async () => {
  let providerCalls = 0;
  const {handler} = fixture({
    quota: {async reserve() { throw new ConflictError(); }},
    providers: {async decide() { providerCalls++; }, async translate() { providerCalls++; }},
  });
  const response = await handler(interpretRequest({text: 'Hello'}, {'Idempotency-Key': '33333333-3333-4333-8333-333333333333'}));
  assert.equal(response.status, 409);
  assert.equal((await body(response)).code, 'request_already_processed');
  assert.equal(providerCalls, 0);
});

test('cancellation is checked before quota and after reservation between providers', async () => {
  const before = new AbortController();
  before.abort();
  const cancelledBefore = fixture();
  const beforeResponse = await cancelledBefore.handler(interpretRequest({text: 'Hello'}, {}, {signal: before.signal}));
  assert.equal(beforeResponse.status, 499);
  assert.deepEqual(cancelledBefore.events.map(event => event[0]), ['auth']);

  const between = new AbortController();
  let translations = 0;
  const cancelledBetween = fixture({providers: {
    async decide(request, {signal}) {
      assert.equal(signal.aborted, false);
      between.abort();
      assert.equal(signal.aborted, true);
      return decisionsFor(request);
    },
    async translate() { translations++; return 'unused'; },
  }});
  const betweenResponse = await cancelledBetween.handler(interpretRequest({text: 'New wording'}, {}, {signal: between.signal}));
  assert.equal(betweenResponse.status, 499);
  assert.equal((await body(betweenResponse)).code, 'request_cancelled');
  assert.deepEqual(cancelledBetween.events.map(event => event[0]), ['auth', 'quota']);
  assert.equal(translations, 0);
});

test('trusted ambiguity catalog enriches empty options for Jev and Qwen, preserving explicit options', async () => {
  let jevSenses;
  let qwenSenses;
  const automatic = fixture({providers: {
    async decide(request) {
      jevSenses = request.state.senseOptions;
      return decisionsFor(request, {sense: 'bank_finance'});
    },
    async translate(turn) { qwenSenses = turn.senseOptions; return 'Ik ga naar de bank.'; },
  }});
  const translated = await automatic.handler(interpretRequest({text: 'I am going to the bank.', senseOptions: {}}));
  assert.equal(translated.status, 200);
  assert.deepEqual(Object.keys(jevSenses), ['bank_finance', 'bank_river']);
  assert.deepEqual(qwenSenses, jevSenses);

  let explicitSenses;
  const explicit = fixture({providers: {
    async decide(request) {
      explicitSenses = request.state.senseOptions;
      return decisionsFor(request, {memory: 'hello', sense: 'bank_custom'});
    },
    async translate() { assert.fail('memory route must skip Qwen'); },
  }});
  const options = {bank_custom: 'a named bench in a fictional setting'};
  assert.equal((await explicit.handler(interpretRequest({text: 'bank', senseOptions: options}))).status, 200);
  assert.deepEqual(explicitSenses, options);
});

test('account deletion remains available when inference providers are unconfigured', async () => {
  const events = [];
  const handler = createNativeBackendHandler({
    auth: {async getUser() { events.push('auth'); return {id: USER_ID}; }},
    quota: null,
    providers: null,
    accounts: {async deleteUser(id) { events.push(id); }},
    memory,
    requestId: () => REQUEST_ID,
    readiness: {auth: true, quota: false, jev: false, qwen: false, deletion: true},
  });
  const deletion = await handler(new Request('https://project.invalid/delete-session', {method: 'POST', headers: {Authorization: 'Bearer user-token'}}));
  assert.equal(deletion.status, 200);
  assert.deepEqual(events, ['auth', USER_ID]);
  const interpret = await handler(interpretRequest({text: 'Hello'}));
  assert.equal(interpret.status, 503);
  assert.equal((await body(interpret)).code, 'not_ready');
});
