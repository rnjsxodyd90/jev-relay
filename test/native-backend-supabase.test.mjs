import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AuthError, ConflictError, QuotaError} from '../backend/supabase/functions/_shared/handler.mjs';
import {createProviders, ProviderError, QWEN_MODEL} from '../backend/supabase/functions/_shared/providers.mjs';
import {createSupabaseAdapters} from '../backend/supabase/functions/_shared/supabase.mjs';

const USER_ID = '11111111-1111-4111-8111-111111111111';
const REQUEST_ID = '22222222-2222-4222-8222-222222222222';
const SERVICE_KEY = 'service-role-secret';
const options = {supabaseUrl: 'https://project.supabase.co', serviceRoleKey: SERVICE_KEY, anonKey: 'legacy-anon-public', publishableKey: 'sb_publishable_public', quotaPepper: '0123456789abcdef0123456789abcdef'};
const jsonResponse = (body, init = {}) => new Response(JSON.stringify(body), {status: init.status ?? 200, headers: {'Content-Type': 'application/json'}});

test('public project keys are denied before the Supabase Auth server call', async () => {
  let calls = 0;
  const {auth} = createSupabaseAdapters({...options, fetchImpl: async () => { calls++; throw new Error('must not run'); }});
  for (const token of ['legacy-anon-public', 'sb_publishable_public', 'sb_publishable_any-project']) {
    await assert.rejects(auth.getUser(token), error => error instanceof AuthError);
  }
  assert.equal(calls, 0);
});

test('auth is validated by getUser and only authenticated anonymous identities pass', async () => {
  const seen = [];
  const {auth} = createSupabaseAdapters({...options, fetchImpl: async (url, request) => {
    seen.push({url, request});
    return jsonResponse({id: USER_ID, is_anonymous: true});
  }});
  assert.deepEqual(await auth.getUser('user-access-token'), {id: USER_ID});
  assert.equal(seen[0].url, 'https://project.supabase.co/auth/v1/user');
  assert.equal(seen[0].request.headers.Authorization, 'Bearer user-access-token');
  assert.equal(seen[0].request.headers.apikey, SERVICE_KEY);

  const regular = createSupabaseAdapters({...options, fetchImpl: async () => jsonResponse({id: USER_ID, is_anonymous: false})});
  await assert.rejects(regular.auth.getUser('user-access-token'), error => error instanceof AuthError && error.status === 403);
});

test('quota RPC receives a server HMAC pseudonym, two reserved attempts, and reduced limits', async () => {
  let captured;
  const {quota} = createSupabaseAdapters({...options, fetchImpl: async (url, request) => {
    captured = {url, request, body: JSON.parse(request.body)};
    return jsonResponse({reserved: true});
  }});
  await quota.reserve({userId: USER_ID, idempotencyKey: REQUEST_ID, maxProviderAttempts: 2, limits: {userDaily: 4, globalDaily: 20, globalMonthly: 100}});
  assert.equal(captured.url, 'https://project.supabase.co/rest/v1/rpc/reserve_native_backend_quota');
  assert.equal(captured.request.headers.Authorization, `Bearer ${SERVICE_KEY}`);
  assert.match(captured.body.p_subject_hash, /^[0-9a-f]{64}$/);
  assert.notEqual(captured.body.p_subject_hash, USER_ID);
  assert.equal(captured.body.p_auth_user_id, USER_ID);
  assert.equal(captured.body.p_request_id, REQUEST_ID);
  assert.equal(captured.body.p_reserved_provider_attempts, 2);
  assert.equal(captured.body.p_user_daily_limit, 4);
  assert.equal(captured.body.p_global_daily_limit, 20);
  assert.equal(captured.body.p_global_monthly_limit, 100);
});

test('quota errors are narrowly mapped and account deletion targets only the authenticated UUID', async () => {
  const limited = createSupabaseAdapters({...options, fetchImpl: async () => jsonResponse({message: 'quota_user_daily'}, {status: 400})});
  await assert.rejects(limited.quota.reserve({userId: USER_ID, idempotencyKey: REQUEST_ID, maxProviderAttempts: 2, limits: {userDaily: 10, globalDaily: 60, globalMonthly: 300}}), error => error instanceof QuotaError && error.code === 'quota_user_daily');

  let deletion;
  const deleting = createSupabaseAdapters({...options, fetchImpl: async (url, request) => {
    deletion = {url, request, body: JSON.parse(request.body)};
    return new Response(null, {status: 204});
  }});
  await deleting.accounts.deleteUser(USER_ID);
  assert.equal(deletion.url, `https://project.supabase.co/auth/v1/admin/users/${USER_ID}`);
  assert.equal(deletion.request.method, 'DELETE');
  assert.equal(deletion.body.should_soft_delete, false);
});

test('provider clients make one request per explicit call and never expose provider error bodies', async () => {
  let calls = 0;
  const providers = createProviders({jevKey: 'jev-secret', qwenKey: 'qwen-secret', fetchImpl: async () => {
    calls++;
    return jsonResponse({internal: 'sensitive provider text'}, {status: 500});
  }});
  await assert.rejects(providers.decide({questions: {}}), error => error instanceof ProviderError && error.code === 'provider_unavailable' && !error.message.includes('sensitive'));
  assert.equal(calls, 1);
});

test('Qwen receives only new-wording translation instructions and malformed output is not retried', async () => {
  let calls = 0;
  let payload;
  const providers = createProviders({qwenKey: 'qwen-secret', fetchImpl: async (_url, request) => {
    calls++;
    payload = JSON.parse(request.body);
    return jsonResponse({choices: [{finish_reason: 'stop', message: {content: '{"translation":'}}]});
  }});
  await assert.rejects(providers.translate({text: 'A new phrase', context: '', senseOptions: {}}, {}), error => error instanceof ProviderError && error.code === 'invalid_translation');
  assert.equal(calls, 1);
  assert.equal(payload.model, QWEN_MODEL);
  assert.equal(payload.store, false);
  assert.equal(payload.temperature, 0);
  assert.deepEqual(payload.response_format, {type: 'json_object'});
});

test('migration enforces RLS, service-role-only RPC, hard caps, UTC, and atomic locks', async () => {
  const sql = await readFile(new URL('../backend/supabase/migrations/202609190001_native_backend_quota.sql', import.meta.url), 'utf8');
  assert.match(sql, /enable row level security/gi);
  assert.match(sql, /revoke all on all tables[\s\S]*public, anon, authenticated/i);
  assert.match(sql, /revoke all on function[\s\S]*public, anon, authenticated/i);
  assert.match(sql, /grant execute on function[\s\S]*service_role/i);
  assert.match(sql, /request_count between 0 and 10/i);
  assert.match(sql, /request_count between 0 and 60/i);
  assert.match(sql, /request_count between 0 and 300/i);
  assert.match(sql, /reserved_provider_attempt_count = request_count \* 2/i);
  assert.match(sql, /at time zone 'UTC'/i);
  assert.match(sql, /pg_advisory_xact_lock/g);
  assert.match(sql, /security definer/i);
  assert.doesNotMatch(sql, /source_text|translated_text|context_text|transcript/i);
});


test('duplicate quota receipts map narrowly to an idempotency conflict', async () => {
  const duplicate = createSupabaseAdapters({...options, fetchImpl: async () => jsonResponse({message: 'request_already_processed'}, {status: 400})});
  await assert.rejects(
    duplicate.quota.reserve({userId: USER_ID, idempotencyKey: REQUEST_ID, maxProviderAttempts: 2, limits: {userDaily: 10, globalDaily: 60, globalMonthly: 300}}),
    error => error instanceof ConflictError && error.code === 'request_already_processed',
  );
});

test('provider calls combine caller cancellation with timeout without retrying', async () => {
  const controller = new AbortController();
  let calls = 0;
  let combinedSignal;
  const providers = createProviders({jevKey: 'jev-secret', fetchImpl: async (_url, request) => {
    calls++;
    combinedSignal = request.signal;
    return await new Promise((resolve, reject) => {
      request.signal.addEventListener('abort', () => reject(request.signal.reason ?? new Error('aborted')), {once: true});
    });
  }});
  const pending = providers.decide({questions: {}}, {signal: controller.signal});
  controller.abort(new Error('caller stopped'));
  await assert.rejects(pending, error => error instanceof ProviderError && error.code === 'cancelled');
  assert.equal(calls, 1);
  assert.equal(combinedSignal.aborted, true);
});


test('auth and deletion adapters remain usable when inference quota configuration is absent', async () => {
  const calls = [];
  const adapters = createSupabaseAdapters({...options, quotaPepper: '', fetchImpl: async (url, request) => {
    calls.push({url, request});
    if (request.method === 'GET') return jsonResponse({id: USER_ID, is_anonymous: true});
    return new Response(null, {status: 204});
  }});
  assert.deepEqual(await adapters.auth.getUser('user-access-token'), {id: USER_ID});
  await adapters.accounts.deleteUser(USER_ID);
  await assert.rejects(
    adapters.quota.reserve({userId: USER_ID, idempotencyKey: REQUEST_ID, maxProviderAttempts: 2, limits: {userDaily: 10, globalDaily: 60, globalMonthly: 300}}),
    error => error.code === 'quota_configuration_invalid',
  );
  assert.equal(calls.length, 2);
});
