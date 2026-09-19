import {InputError, JEV_MODEL, buildJevRequest, enrichTrustedSenseOptions, parseDecisions, resolveRoute, validateTurn} from './decision-gate.mjs';
import {DEFAULT_MEMORY} from './memory.mjs';

export const BACKEND_VERSION = 'native-backend/1';
export const BODY_LIMIT_BYTES = 16 * 1024;
export const MAX_PROVIDER_ATTEMPTS = 2;
export const HARD_LIMITS = Object.freeze({userDaily: 10, globalDaily: 60, globalMonthly: 300});

export class AuthError extends Error {
  constructor(code = 'invalid_access_token', message = 'A valid anonymous app session is required.', status = 401) { super(message); this.name = 'AuthError'; this.code = code; this.status = status; }
}
export class QuotaError extends Error {
  constructor(code = 'quota_exceeded', message = 'The request limit has been reached.') { super(message); this.name = 'QuotaError'; this.code = code; }
}
export class ServiceError extends Error {
  constructor(code = 'service_unavailable', message = 'The service is not ready.') { super(message); this.name = 'ServiceError'; this.code = code; }
}
export class ConflictError extends Error {
  constructor(code = 'request_already_processed', message = 'This user action has already been processed.') { super(message); this.name = 'ConflictError'; this.code = code; }
}
export class RequestCancelledError extends Error {
  constructor() { super('The request was cancelled.'); this.name = 'RequestCancelledError'; this.code = 'request_cancelled'; }
}

const ACTION_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function throwIfCancelled(signal) {
  if (signal?.aborted) throw new RequestCancelledError();
}

function idempotencyKey(request, fallback) {
  const value = request.headers.get('idempotency-key');
  if (value === null) return fallback;
  if (!ACTION_UUID.test(value)) throw new InputError('Idempotency-Key must be a UUID.');
  return value.toLowerCase();
}

export function reducedLimit(value, hardLimit, name) {
  if (value === undefined || value === null || value === '') return hardLimit;
  const parsed = typeof value === 'number' ? value : Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > hardLimit) throw new Error(`${name} must be an integer between 1 and ${hardLimit}; it may only reduce the database cap.`);
  return parsed;
}

export function normalizeLimits(input = {}) {
  return Object.freeze({
    userDaily: reducedLimit(input.userDaily, HARD_LIMITS.userDaily, 'userDaily'),
    globalDaily: reducedLimit(input.globalDaily, HARD_LIMITS.globalDaily, 'globalDaily'),
    globalMonthly: reducedLimit(input.globalMonthly, HARD_LIMITS.globalMonthly, 'globalMonthly'),
  });
}

const responseHeaders = Object.freeze({
  'Cache-Control': 'no-store',
  'Content-Type': 'application/json; charset=utf-8',
  'Referrer-Policy': 'no-referrer',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
});

function json(status, body) {
  return new Response(JSON.stringify(body), {status, headers: responseHeaders});
}

function routeFor(pathname, functionName) {
  const direct = new Set(['/health', '/interpret', '/delete-session']);
  if (direct.has(pathname)) return pathname.slice(1);
  const marker = `/${functionName}/`;
  const index = pathname.lastIndexOf(marker);
  if (index === -1) return '';
  const route = pathname.slice(index + marker.length);
  return route === 'health' || route === 'interpret' || route === 'delete-session' ? route : '';
}

function bearerToken(request) {
  const value = request.headers.get('authorization') ?? '';
  const match = /^Bearer ([^\s]+)$/i.exec(value);
  if (!match) throw new AuthError();
  return match[1];
}

async function readBoundedBytes(request, limit = BODY_LIMIT_BYTES) {
  const declaredHeader = request.headers.get('content-length');
  if (declaredHeader !== null) {
    const declared = Number(declaredHeader);
    if (!Number.isInteger(declared) || declared < 0 || declared > limit) throw new InputError('Request body exceeds 16 KB.');
  }
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > limit) {
        await reader.cancel();
        throw new InputError('Request body exceeds 16 KB.');
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return bytes;
}

async function readTurn(request) {
  if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get('content-type') ?? '')) throw new InputError('Send JSON content.');
  const bytes = await readBoundedBytes(request);
  let input;
  try { input = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes)); }
  catch { throw new InputError('Request body is not valid JSON.'); }
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new InputError('Send a turn object.');
  const allowed = new Set(['text', 'context', 'source', 'target', 'senseOptions']);
  if (Object.keys(input).some(key => !allowed.has(key))) throw new InputError('The turn contains unsupported fields.');
  return validateTurn(input);
}

async function requireEmptyBody(request) {
  const bytes = await readBoundedBytes(request);
  if (bytes.byteLength !== 0) throw new InputError('Do not send a request body to delete-session.');
}

function elapsed(clock, start) {
  const value = Number(clock()) - start;
  return Number.isFinite(value) ? Math.max(0, Math.round(value)) : 0;
}

function validateMemory(memory) {
  if (!Array.isArray(memory) || memory.length > 32 || new Set(memory.map(item => item?.id)).size !== memory.length || memory.some(item => !item || !/^[a-z][a-z0-9_]{0,31}$/.test(item.id) || ['constructor', 'prototype', '__proto__'].includes(item.id) || typeof item.english !== 'string' || typeof item.dutch !== 'string' || !item.english || !item.dutch || item.english.length > 1000 || item.dutch.length > 1000)) throw new Error('Memory must contain up to 32 uniquely identified English/Dutch phrases.');
  return structuredClone(memory);
}

export function createNativeBackendHandler({
  auth,
  quota,
  providers,
  accounts,
  clock = () => performance.now(),
  requestId = () => crypto.randomUUID(),
  memory = DEFAULT_MEMORY,
  model = JEV_MODEL,
  limits = HARD_LIMITS,
  readiness = {auth: true, quota: true, jev: true, qwen: true, deletion: true},
  functionName = 'native-backend',
} = {}) {
  const phrases = validateMemory(memory);
  const configuredLimits = normalizeLimits(limits);
  const authReady = Boolean(auth) && readiness.auth === true;
  const interpretReady = authReady && Boolean(quota && providers) && readiness.quota === true && readiness.jev === true && readiness.qwen === true;
  const deletionReady = authReady && Boolean(accounts) && readiness.deletion === true;
  const ready = interpretReady && deletionReady;

  async function authenticate(request) {
    const token = bearerToken(request);
    const user = await auth.getUser(token, {signal: request.signal});
    if (!user || typeof user.id !== 'string' || !user.id) throw new AuthError();
    return user;
  }

  async function interpret(request, id, user) {
    throwIfCancelled(request.signal);
    const turn = enrichTrustedSenseOptions(await readTurn(request));
    const actionKey = idempotencyKey(request, id);
    throwIfCancelled(request.signal);
    await quota.reserve({userId: user.id, idempotencyKey: actionKey, maxProviderAttempts: MAX_PROVIDER_ATTEMPTS, limits: configuredLimits});
    throwIfCancelled(request.signal);

    const started = Number(clock());
    let decisions;
    let actualModel = model;
    let decisionMs = 0;
    let translationMs = 0;
    const base = () => ({
      mode: 'live',
      sourceText: turn.text,
      route: 'review',
      reason: '',
      translatedText: '',
      clarification: '',
      decisions: decisions ?? {},
      model: actualModel,
      timing: {decisionMs, translationMs, totalMs: elapsed(clock, started)},
      usedTranslator: false,
      requestId: id,
    });

    const jevRequest = buildJevRequest(turn, phrases, model);
    const decisionStart = Number(clock());
    try {
      const result = await providers.decide(jevRequest, {signal: request.signal});
      decisions = parseDecisions(result, jevRequest.questions);
      actualModel = typeof result.model === 'string' ? result.model : model;
    } catch (error) {
      if (request.signal.aborted || error?.code === 'cancelled') throw new RequestCancelledError();
      decisionMs = elapsed(clock, decisionStart);
      return {...base(), reason: 'The decision gate is unavailable or returned invalid data. Nothing was translated or approved.'};
    }
    decisionMs = elapsed(clock, decisionStart);
    throwIfCancelled(request.signal);

    const outcome = resolveRoute(decisions, phrases);
    if (outcome.route !== 'translate') return {...base(), ...outcome};

    const translationStart = Number(clock());
    try {
      const translatedText = await providers.translate(turn, decisions, {signal: request.signal});
      translationMs = elapsed(clock, translationStart);
      if (typeof translatedText !== 'string' || !translatedText.trim() || translatedText.length > 8000) throw new Error('Invalid translation.');
      return {...base(), route: 'translate', usedTranslator: true, translatedText: translatedText.trim(), reason: 'Generated by Qwen using the Jev routing decisions. Review before playback; this is not a certified translation.'};
    } catch (error) {
      if (request.signal.aborted || error?.code === 'cancelled') throw new RequestCancelledError();
      translationMs = elapsed(clock, translationStart);
      return {...base(), route: 'review', usedTranslator: !['not_configured'].includes(error?.code), reason: 'A new translation is needed, but the translator is unavailable or returned invalid data. Nothing is approved for playback.'};
    }
  }

  return async function handle(request) {
    const route = routeFor(new URL(request.url).pathname, functionName);
    if (route === 'health') {
      if (request.method !== 'GET') return json(405, {code: 'method_not_allowed', error: 'Method not allowed.'});
      return json(ready ? 200 : 503, {version: BACKEND_VERSION, ready, routes: {interpret: interpretReady, deleteSession: deletionReady}, configuration: {...readiness}, limits: configuredLimits});
    }
    if (!route) return json(404, {code: 'not_found', error: 'Not found.'});
    if (request.method !== 'POST') return json(405, {code: 'method_not_allowed', error: 'Method not allowed.'});
    const id = requestId();
    if (route === 'interpret' && !interpretReady) return json(503, {code: 'not_ready', error: 'The interpretation service is not configured.', requestId: id});
    if (route === 'delete-session' && !deletionReady) return json(503, {code: 'not_ready', error: 'Account deletion is not configured.', requestId: id});

    try {
      const user = await authenticate(request);
      if (route === 'interpret') return json(200, await interpret(request, id, user));
      await requireEmptyBody(request);
      throwIfCancelled(request.signal);
      await accounts.deleteUser(user.id, {signal: request.signal});
      return json(200, {
        deleted: true,
        requestId: id,
        removed: {authIdentity: true, accountMetadata: true},
        retained: {pseudonymousQuotaUntilCounterExpiry: true, globalAggregateCaps: true},
      });
    } catch (error) {
      if (error instanceof InputError) return json(400, {code: 'invalid_input', error: error.message, requestId: id});
      if (error instanceof AuthError) return json(error.status, {code: error.code, error: error.message, requestId: id});
      if (error instanceof QuotaError) return json(429, {code: error.code, error: error.message, requestId: id});
      if (error instanceof ConflictError) return json(409, {code: error.code, error: error.message, requestId: id});
      if (error instanceof RequestCancelledError || request.signal.aborted) return json(499, {code: 'request_cancelled', error: 'The request was cancelled.', requestId: id});
      if (error instanceof ServiceError) return json(503, {code: error.code, error: 'The service is temporarily unavailable.', requestId: id});
      return json(502, {code: 'service_unavailable', error: 'The service could not complete this request.', requestId: id});
    }
  };
}
