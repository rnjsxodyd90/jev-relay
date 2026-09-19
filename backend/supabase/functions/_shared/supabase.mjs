import {AuthError, ConflictError, MAX_PROVIDER_ATTEMPTS, QuotaError, RequestCancelledError, ServiceError, normalizeLimits} from './handler.mjs';
import {combineAbortSignals} from './providers.mjs';

const RESPONSE_LIMIT = 65536;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function boundedJson(response) {
  const declared = Number(response.headers?.get?.('content-length') ?? 0);
  if (Number.isFinite(declared) && declared > RESPONSE_LIMIT) throw new ServiceError();
  const reader = response.body?.getReader();
  if (!reader) throw new ServiceError();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > RESPONSE_LIMIT) {
        await reader.cancel();
        throw new ServiceError();
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  try { return JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes)); }
  catch { throw new ServiceError(); }
}

async function request(fetchImpl, url, options, timeoutMs, callerSignal) {
  try {
    const signal = combineAbortSignals(callerSignal, AbortSignal.timeout(timeoutMs));
    return await fetchImpl(url, {...options, signal});
  } catch {
    if (callerSignal?.aborted) throw new RequestCancelledError();
    throw new ServiceError();
  }
}

function serviceHeaders(serviceRoleKey, extra = {}) {
  return {apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}`, ...extra};
}

async function subjectHash(userId, quotaPepper, cryptoImpl) {
  const encoder = new TextEncoder();
  const key = await cryptoImpl.subtle.importKey('raw', encoder.encode(quotaPepper), {name: 'HMAC', hash: 'SHA-256'}, false, ['sign']);
  const signature = new Uint8Array(await cryptoImpl.subtle.sign('HMAC', key, encoder.encode(userId)));
  return Array.from(signature, byte => byte.toString(16).padStart(2, '0')).join('');
}

export function createSupabaseAdapters({
  supabaseUrl,
  serviceRoleKey,
  anonKey = '',
  publishableKey = '',
  quotaPepper,
  fetchImpl = fetch,
  cryptoImpl = crypto,
  timeoutMs = 8000,
} = {}) {
  if (!supabaseUrl || !serviceRoleKey) throw new Error('Supabase URL and service role key are required.');
  if (!Number.isInteger(timeoutMs) || timeoutMs < 1000 || timeoutMs > 30000) throw new Error('Supabase timeout must be between 1,000 and 30,000 ms.');
  const base = supabaseUrl.replace(/\/+$/, '');
  const deniedPublicTokens = new Set([anonKey, publishableKey].filter(Boolean));

  const auth = {
    async getUser(token, {signal} = {}) {
      if (!token || token.startsWith('sb_publishable_') || deniedPublicTokens.has(token)) throw new AuthError();
      const response = await request(fetchImpl, `${base}/auth/v1/user`, {
        method: 'GET',
        headers: {apikey: serviceRoleKey, Authorization: `Bearer ${token}`, Accept: 'application/json'},
      }, timeoutMs, signal);
      if (response.status === 401 || response.status === 403) { await response.body?.cancel(); throw new AuthError(); }
      if (!response.ok) { await response.body?.cancel(); throw new ServiceError(); }
      const user = await boundedJson(response);
      if (!UUID.test(user?.id ?? '')) throw new AuthError();
      if (user.is_anonymous !== true) throw new AuthError('anonymous_session_required', 'An authenticated anonymous app session is required.', 403);
      return {id: user.id};
    },
  };

  const quota = {
    async reserve({userId, idempotencyKey, maxProviderAttempts, limits}) {
      if (typeof quotaPepper !== 'string' || quotaPepper.length < 32 || !UUID.test(userId) || !UUID.test(idempotencyKey) || maxProviderAttempts !== MAX_PROVIDER_ATTEMPTS) throw new ServiceError('quota_configuration_invalid');
      const safeLimits = normalizeLimits(limits);
      const pseudonym = await subjectHash(userId, quotaPepper, cryptoImpl);
      const response = await request(fetchImpl, `${base}/rest/v1/rpc/reserve_native_backend_quota`, {
        method: 'POST',
        headers: serviceHeaders(serviceRoleKey, {'Content-Type': 'application/json', Accept: 'application/json'}),
        body: JSON.stringify({
          p_auth_user_id: userId,
          p_subject_hash: pseudonym,
          p_request_id: idempotencyKey,
          p_reserved_provider_attempts: MAX_PROVIDER_ATTEMPTS,
          p_user_daily_limit: safeLimits.userDaily,
          p_global_daily_limit: safeLimits.globalDaily,
          p_global_monthly_limit: safeLimits.globalMonthly,
        }),
      }, timeoutMs);
      if (response.ok) { await response.body?.cancel(); return; }
      let code = '';
      try { code = (await boundedJson(response))?.message ?? ''; } catch {}
      if (code === 'quota_user_daily' || code === 'quota_global_daily' || code === 'quota_global_monthly') {
        throw new QuotaError(code, 'The request limit has been reached.');
      }
      if (code === 'request_already_processed') throw new ConflictError();
      if (code === 'quota_configuration_invalid') throw new ServiceError('quota_configuration_invalid');
      throw new ServiceError();
    },
  };

  const accounts = {
    async deleteUser(userId, {signal} = {}) {
      if (!UUID.test(userId)) throw new ServiceError();
      const response = await request(fetchImpl, `${base}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
        method: 'DELETE',
        headers: serviceHeaders(serviceRoleKey, {'Content-Type': 'application/json', Accept: 'application/json'}),
        body: JSON.stringify({should_soft_delete: false}),
      }, timeoutMs, signal);
      if (!response.ok) { await response.body?.cancel(); throw new ServiceError('account_deletion_failed'); }
      await response.body?.cancel();
    },
  };

  return {auth, quota, accounts};
}
