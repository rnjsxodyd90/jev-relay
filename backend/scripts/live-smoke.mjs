#!/usr/bin/env node
/**
 * Bounded production smoke test for the native backend.
 *
 * Run only with explicit approval:
 *   LIVE_SMOKE=1 NATIVE_PUBLIC_CONFIG=/absolute/path/native-public-config.json \
 *     node backend/scripts/live-smoke.mjs
 *
 * Uses one disposable anonymous Auth identity and at most three valid turns.
 * It never prints or writes tokens, user IDs, API keys, or provider output.
 */
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const backendDirectory = resolve(scriptDirectory, '..');
const evidencePath = process.env.LIVE_SMOKE_EVIDENCE
  ? resolve(process.env.LIVE_SMOKE_EVIDENCE)
  : resolve(backendDirectory, 'evidence/live-smoke.json');
const configPath = process.env.NATIVE_PUBLIC_CONFIG;

if (process.env.LIVE_SMOKE !== '1') {
  throw new Error('Refusing live traffic. Set LIVE_SMOKE=1 after deliberate review.');
}
if (!configPath) throw new Error('Set NATIVE_PUBLIC_CONFIG to the public client configuration JSON file.');

const config = JSON.parse(await readFile(resolve(configPath), 'utf8'));
const supabaseURL = typeof config.supabaseURL === 'string' ? config.supabaseURL.replace(/\/+$/, '') : '';
const backendURL = typeof config.backendURL === 'string' ? config.backendURL.replace(/\/+$/, '') : '';
const publishableKey = typeof config.publishableKey === 'string' ? config.publishableKey : '';
if (!supabaseURL || !backendURL || !publishableKey) throw new Error('Public configuration must include supabaseURL, backendURL, and publishableKey.');

const startedAt = new Date().toISOString();
const evidence = {
  schemaVersion: 1,
  checkedAt: null,
  scope: 'Explicit opt-in bounded live smoke: one disposable anonymous identity, three synthetic interpretation turns maximum. This is not a provider-count audit, performance benchmark, translation certification, or universal availability claim.',
  fixtures: {
    memory: {text: 'Could you repeat that?', context: 'Formal singular address is required.', source: 'en', target: 'nl'},
    novel: {text: 'The train leaves at 16:10.', context: 'A neutral station announcement. Preserve the exact departure time.', source: 'en', target: 'nl'},
    ambiguous: {text: 'Which bank should I use?', context: '', source: 'en', target: 'nl'},
  },
  results: [],
  cleanup: {attempted: false, deleted: false, oldTokenRejected: false},
  overall: {pass: false, notes: []},
};

let token = '';
let createdIdentity = false;
let fatalError = null;
const nowMs = () => performance.now();
const elapsedMs = start => Math.max(0, Math.round(performance.now() - start));
const jsonHeaders = {Accept: 'application/json', 'Content-Type': 'application/json'};

async function safeJson(response) {
  try { return await response.json(); } catch { return {}; }
}
function addResult(id, response, body, elapsed, expectations = {}) {
  const passed = Object.entries(expectations).every(([key, expected]) => itemValue({status: response.status, body}, key) === expected);
  const item = {
    id,
    status: response.status,
    elapsedMs: elapsed,
    code: typeof body?.code === 'string' ? body.code : null,
    route: typeof body?.route === 'string' ? body.route : null,
    model: typeof body?.model === 'string' ? body.model : null,
    timing: body?.timing && typeof body.timing === 'object'
      ? {decisionMs: body.timing.decisionMs ?? null, translationMs: body.timing.translationMs ?? null, totalMs: body.timing.totalMs ?? null}
      : null,
    usedTranslator: typeof body?.usedTranslator === 'boolean' ? body.usedTranslator : null,
    passed,
  };
  evidence.results.push(item);
  return item;
}
function itemValue({status, body}, key) {
  if (key === 'status') return status;
  return body?.[key];
}
async function request(path, options = {}) {
  const start = nowMs();
  const response = await fetch(`${backendURL}${path}`, options);
  return {response, body: await safeJson(response), elapsed: elapsedMs(start)};
}
async function authenticatedInterpret(fixture, idempotencyKey) {
  return request('/interpret', {
    method: 'POST',
    headers: {...jsonHeaders, Authorization: `Bearer ${token}`, 'Idempotency-Key': idempotencyKey},
    body: JSON.stringify(fixture),
  });
}

try {
  // Public readiness is safe to call before identity creation.
  {
    const {response, body, elapsed} = await request('/health');
    addResult('health', response, body, elapsed, {status: 200, ready: true});
  }
  // A missing bearer credential must be rejected before request processing.
  {
    const {response, body, elapsed} = await request('/interpret', {
      method: 'POST', headers: jsonHeaders, body: JSON.stringify(evidence.fixtures.memory),
    });
    addResult('missing_bearer_rejected', response, body, elapsed, {status: 401, code: 'invalid_access_token'});
  }
  // A project public key is not an application session credential.
  {
    const {response, body, elapsed} = await request('/interpret', {
      method: 'POST', headers: {...jsonHeaders, Authorization: `Bearer ${publishableKey}`}, body: JSON.stringify(evidence.fixtures.memory),
    });
    addResult('public_key_bearer_rejected', response, body, elapsed, {status: 401, code: 'invalid_access_token'});
  }
  // Exactly one anonymous signup. Do not retry capacity or signup failures.
  {
    const start = nowMs();
    const response = await fetch(`${supabaseURL}/auth/v1/signup`, {
      method: 'POST', headers: {apikey: publishableKey, ...jsonHeaders}, body: JSON.stringify({data: {}}),
    });
    const body = await safeJson(response);
    token = typeof body?.access_token === 'string' ? body.access_token : '';
    createdIdentity = response.ok && Boolean(token);
    evidence.results.push({id: 'anonymous_signup', status: response.status, elapsedMs: elapsedMs(start), code: typeof body?.code === 'string' ? body.code : null, passed: createdIdentity});
    if (!createdIdentity) throw new Error(`Anonymous signup did not yield a disposable session (HTTP ${response.status}).`);
  }
  // This uses valid auth but invalid input. The source contract validates before quota/provider calls.
  {
    const {response, body, elapsed} = await request('/interpret', {
      method: 'POST', headers: {...jsonHeaders, Authorization: `Bearer ${token}`}, body: JSON.stringify({text: ''}),
    });
    addResult('invalid_body_rejected_before_inference', response, body, elapsed, {status: 400, code: 'invalid_input'});
  }

  const memoryKey = crypto.randomUUID();
  const novelKey = crypto.randomUUID();
  const ambiguousKey = crypto.randomUUID();
  {
    const {response, body, elapsed} = await authenticatedInterpret(evidence.fixtures.memory, memoryKey);
    addResult('memory_turn', response, body, elapsed, {status: 200, route: 'memory', usedTranslator: false});
  }
  {
    const {response, body, elapsed} = await authenticatedInterpret(evidence.fixtures.novel, novelKey);
    addResult('novel_translation_turn', response, body, elapsed, {status: 200, route: 'translate', usedTranslator: true});
  }
  // Reuses the novel action key once. A 409 is the backend's no-second-provider-call contract.
  {
    const {response, body, elapsed} = await authenticatedInterpret(evidence.fixtures.novel, novelKey);
    addResult('duplicate_idempotency_key', response, body, elapsed, {status: 409, code: 'request_already_processed'});
  }
  {
    const {response, body, elapsed} = await authenticatedInterpret(evidence.fixtures.ambiguous, ambiguousKey);
    addResult('ambiguous_clarification_turn', response, body, elapsed, {status: 200, route: 'clarify', usedTranslator: false});
  }
} catch (error) {
  fatalError = error instanceof Error ? error.message : 'Unknown smoke-test error.';
} finally {
  if (createdIdentity && token) {
    evidence.cleanup.attempted = true;
    try {
      const {response, body, elapsed} = await request('/delete-session', {method: 'POST', headers: {Authorization: `Bearer ${token}`, Accept: 'application/json'}});
      evidence.cleanup.deleted = response.status === 200 && body?.deleted === true;
      addResult('delete_session_empty_body', response, body, elapsed, {status: 200, deleted: true});
      if (evidence.cleanup.deleted) {
        const {response: oldResponse, body: oldBody, elapsed: oldElapsed} = await request('/interpret', {
          method: 'POST', headers: {...jsonHeaders, Authorization: `Bearer ${token}`}, body: JSON.stringify({text: ''}),
        });
        evidence.cleanup.oldTokenRejected = oldResponse.status === 401 && oldBody?.code === 'invalid_access_token';
        addResult('old_token_rejected_after_deletion', oldResponse, oldBody, oldElapsed, {status: 401, code: 'invalid_access_token'});
      }
    } catch (error) {
      evidence.cleanup.error = error instanceof Error ? error.message : 'Cleanup request failed.';
    }
  }
  token = '';
  evidence.checkedAt = new Date().toISOString();
  const failed = evidence.results.filter(result => !result.passed).map(result => result.id);
  evidence.overall.pass = !fatalError && evidence.cleanup.deleted && evidence.cleanup.oldTokenRejected && failed.length === 0;
  evidence.overall.notes = [
    'Only response metadata and the synthetic fixtures are recorded. No access token, user ID, API key, request ID, translation text, clarification text, or provider response is retained.',
    'The invalid-input and duplicate-idempotency checks establish observed HTTP contract behavior. Their no-provider-call properties follow the inspected backend contract; this script does not instrument hosted provider traffic.',
    ...(fatalError ? [`Stopped: ${fatalError}`] : []),
    ...(failed.length ? [`Failed checks: ${failed.join(', ')}.`] : []),
    ...(!evidence.cleanup.deleted ? ['Disposable identity deletion was not confirmed.'] : []),
    ...(!evidence.cleanup.oldTokenRejected ? ['Old-token rejection after deletion was not confirmed.'] : []),
  ];
  await mkdir(dirname(evidencePath), {recursive: true});
  await writeFile(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`, {mode: 0o600});
}

if (!evidence.overall.pass) process.exitCode = 1;
console.log(`Live smoke ${evidence.overall.pass ? 'passed' : 'failed'}; sanitized evidence: ${evidencePath}`);
