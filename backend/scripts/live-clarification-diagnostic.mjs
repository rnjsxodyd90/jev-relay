#!/usr/bin/env node
/**
 * Explicitly authorized, bounded diagnostic for clarification routing.
 * Run only with LIVE_CLARIFICATION_DIAGNOSTIC=1 and a public config path.
 * It creates one disposable anonymous identity and sends exactly two turns.
 */
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const directory = dirname(fileURLToPath(import.meta.url));
const backendDirectory = resolve(directory, '..');
const output = process.env.LIVE_CLARIFICATION_EVIDENCE
  ? resolve(process.env.LIVE_CLARIFICATION_EVIDENCE)
  : resolve(backendDirectory, 'evidence/live-clarification-diagnostic.json');
if (process.env.LIVE_CLARIFICATION_DIAGNOSTIC !== '1') throw new Error('Refusing live traffic. Set LIVE_CLARIFICATION_DIAGNOSTIC=1 after deliberate review.');
if (!process.env.NATIVE_PUBLIC_CONFIG) throw new Error('Set NATIVE_PUBLIC_CONFIG to the public client configuration JSON file.');

const config = JSON.parse(await readFile(resolve(process.env.NATIVE_PUBLIC_CONFIG), 'utf8'));
const supabaseURL = typeof config.supabaseURL === 'string' ? config.supabaseURL.replace(/\/+$/, '') : '';
const backendURL = typeof config.backendURL === 'string' ? config.backendURL.replace(/\/+$/, '') : '';
const publishableKey = typeof config.publishableKey === 'string' ? config.publishableKey : '';
if (!supabaseURL || !backendURL || !publishableKey) throw new Error('Public configuration must include supabaseURL, backendURL, and publishableKey.');

const fixtures = {
  bank: {text: 'Which bank should I use?', context: '', source: 'en', target: 'nl'},
  interrupted: {text: 'Turn left, no, actually...', context: '', source: 'en', target: 'nl'},
};
const evidence = {
  schemaVersion: 1,
  checkedAt: null,
  scope: 'Second explicitly authorized diagnostic: one disposable anonymous identity and exactly two synthetic interpretation calls. This is not a translation certification, provider traffic audit, or universal behavior claim.',
  fixtures,
  results: [],
  cleanup: {attempted: false, deleted: false, oldTokenRejected: false},
  overall: {pass: false, notes: []},
};
let token = '';
let identityCreated = false;
let stopped = null;
const headers = {Accept: 'application/json', 'Content-Type': 'application/json'};
const elapsed = start => Math.max(0, Math.round(performance.now() - start));
async function json(response) { try { return await response.json(); } catch { return {}; } }
function validatedDecisionSummary(decisions) {
  const ids = ['action', 'memory', 'register', 'sense'];
  if (!decisions || typeof decisions !== 'object' || ids.some(id => !decisions[id] || typeof decisions[id].choice !== 'string' || !Number.isFinite(decisions[id].confidence) || !Number.isFinite(decisions[id].probabilities?.[decisions[id].choice]))) return null;
  return Object.fromEntries(ids.map(id => [id, {
    choice: decisions[id].choice,
    confidence: decisions[id].confidence,
    selectedProbability: decisions[id].probabilities[decisions[id].choice],
  }]));
}
async function interpret(id, fixture) {
  const start = performance.now();
  const response = await fetch(`${backendURL}/interpret`, {method: 'POST', headers: {...headers, Authorization: `Bearer ${token}`, 'Idempotency-Key': crypto.randomUUID()}, body: JSON.stringify(fixture)});
  const body = await json(response);
  const decisions = validatedDecisionSummary(body?.decisions);
  evidence.results.push({
    id, status: response.status, elapsedMs: elapsed(start), route: typeof body?.route === 'string' ? body.route : null,
    reason: typeof body?.reason === 'string' ? body.reason : null, decisions,
    timing: body?.timing && typeof body.timing === 'object' ? {decisionMs: body.timing.decisionMs ?? null, translationMs: body.timing.translationMs ?? null, totalMs: body.timing.totalMs ?? null} : null,
    usedTranslator: typeof body?.usedTranslator === 'boolean' ? body.usedTranslator : null,
    decisionBundleValidated: decisions !== null,
  });
}
try {
  const start = performance.now();
  const response = await fetch(`${supabaseURL}/auth/v1/signup`, {method: 'POST', headers: {apikey: publishableKey, ...headers}, body: JSON.stringify({data: {}})});
  const body = await json(response);
  token = typeof body?.access_token === 'string' ? body.access_token : '';
  identityCreated = response.ok && Boolean(token);
  evidence.signup = {status: response.status, elapsedMs: elapsed(start), created: identityCreated};
  if (!identityCreated) throw new Error(`Anonymous signup did not yield a disposable session (HTTP ${response.status}).`);
  await interpret('same_bank_fixture', fixtures.bank);
  await interpret('interrupted_wording_fixture', fixtures.interrupted);
} catch (error) {
  stopped = error instanceof Error ? error.message : 'Unknown diagnostic error.';
} finally {
  if (identityCreated && token) {
    evidence.cleanup.attempted = true;
    try {
      const start = performance.now();
      const response = await fetch(`${backendURL}/delete-session`, {method: 'POST', headers: {Authorization: `Bearer ${token}`, Accept: 'application/json'}});
      const body = await json(response);
      evidence.cleanup.deleted = response.status === 200 && body?.deleted === true;
      evidence.cleanup.deleteStatus = response.status;
      evidence.cleanup.deleteElapsedMs = elapsed(start);
      if (evidence.cleanup.deleted) {
        const oldStart = performance.now();
        const oldResponse = await fetch(`${backendURL}/delete-session`, {method: 'POST', headers: {Authorization: `Bearer ${token}`, Accept: 'application/json'}});
        const oldBody = await json(oldResponse);
        evidence.cleanup.oldTokenRejected = oldResponse.status === 401 && oldBody?.code === 'invalid_access_token';
        evidence.cleanup.oldTokenRejectionStatus = oldResponse.status;
        evidence.cleanup.oldTokenRejectionCode = typeof oldBody?.code === 'string' ? oldBody.code : null;
        evidence.cleanup.oldTokenRejectionElapsedMs = elapsed(oldStart);
      }
    } catch (error) { evidence.cleanup.error = error instanceof Error ? error.message : 'Cleanup request failed.'; }
  }
  token = '';
  evidence.checkedAt = new Date().toISOString();
  const bank = evidence.results.find(result => result.id === 'same_bank_fixture');
  evidence.observedClassification = bank?.route === 'review' && bank?.reason?.startsWith('A routing decision is below the experimental confidence threshold.')
    ? 'low_confidence_policy_hold'
    : bank?.route === 'review' && bank?.reason === 'The decision gate is unavailable or returned invalid data. Nothing was translated or approved.'
      ? 'decision_parse_or_provider_failure'
      : bank ? 'different_observation' : 'not_observed';
  evidence.overall.pass = !stopped && evidence.results.length === 2 && evidence.cleanup.deleted && evidence.cleanup.oldTokenRejected && evidence.results.every(result => result.status === 200 && result.decisionBundleValidated);
  evidence.overall.notes = [
    'Recorded only synthetic fixtures plus route, server reason, validated decision summaries, timing, and usedTranslator. No token, user ID, request ID, API key, translation, clarification text, or full provider response is retained.',
    'Old-token verification uses delete-session, not interpret, so the diagnostic remains bounded to two interpretation calls.',
    ...(stopped ? [`Stopped: ${stopped}`] : []),
    ...(!evidence.cleanup.deleted ? ['Disposable identity deletion was not confirmed.'] : []),
    ...(!evidence.cleanup.oldTokenRejected ? ['Old-token rejection after deletion was not confirmed.'] : []),
  ];
  await mkdir(dirname(output), {recursive: true});
  await writeFile(output, `${JSON.stringify(evidence, null, 2)}\n`, {mode: 0o600});
}
if (!evidence.overall.pass) process.exitCode = 1;
console.log(`Clarification diagnostic ${evidence.overall.pass ? 'passed' : 'failed'}; sanitized evidence: ${output}`);
