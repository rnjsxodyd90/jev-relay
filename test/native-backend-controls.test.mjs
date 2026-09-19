import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFile} from 'node:fs/promises';
import {buildDashboardBundle} from '../backend/scripts/build-dashboard-bundle.mjs';

const quotaMigrationUrl = new URL('../backend/supabase/migrations/202609190001_native_backend_quota.sql', import.meta.url);
const controlsMigrationUrl = new URL('../backend/supabase/migrations/202609190002_native_backend_retention_and_signup_hook.sql', import.meta.url);
const idempotencyMigrationUrl = new URL('../backend/supabase/migrations/202609190003_native_backend_idempotency.sql', import.meta.url);
const readmeUrl = new URL('../backend/README.md', import.meta.url);

test('quota RPC rejects every nullable security and limit input explicitly', async () => {
  const sql = await readFile(quotaMigrationUrl, 'utf8');
  for (const field of [
    'p_request_id',
    'p_auth_user_id',
    'p_subject_hash',
    'p_reserved_provider_attempts',
    'p_user_daily_limit',
    'p_global_daily_limit',
    'p_global_monthly_limit',
  ]) assert.match(sql, new RegExp(`${field} is null`, 'i'));
});

test('Before User Created hook is anonymous-only, atomic, aggregate-only, and auth-admin scoped', async () => {
  const sql = await readFile(controlsMigrationUrl, 'utf8');
  assert.match(sql, /before_user_created_native_backend\(event jsonb\)/i);
  assert.match(sql, /security invoker/i);
  assert.match(sql, /event #>> '\{user,is_anonymous\}'/i);
  assert.match(sql, /only allows anonymous account creation/i);
  assert.match(sql, /signup_count between 0 and 30/i);
  assert.match(sql, /signup_count between 0 and 100/i);
  assert.match(sql, /pg_advisory_xact_lock/g);
  assert.match(sql, /grant execute[\s\S]*before_user_created_native_backend\(jsonb\)[\s\S]*supabase_auth_admin/i);
  assert.match(sql, /revoke all[\s\S]*before_user_created_native_backend\(jsonb\)[\s\S]*public, anon, authenticated, service_role/i);
  assert.match(sql, /to supabase_auth_admin[\s\S]*using \(true\)[\s\S]*with check \(true\)/i);

  const tableDefinitions = sql.match(/create table if not exists native_backend\.anonymous_signup_[\s\S]*?\);/gi) ?? [];
  assert.equal(tableDefinitions.length, 2);
  for (const definition of tableDefinitions) {
    assert.doesNotMatch(definition, /user_id|subject_hash|ip_address|request_id|email|phone/i);
    assert.match(definition, /signup_count/i);
  }
});

test('cleanup is bounded, keeps active UTC counters, and is scheduled hourly through pg_cron', async () => {
  const sql = await readFile(controlsMigrationUrl, 'utf8');
  assert.match(sql, /cleanup_native_backend_counters\(p_batch_size integer default 500\)/i);
  assert.match(sql, /p_batch_size is null or p_batch_size not between 1 and 1000/i);
  assert.equal((sql.match(/limit p_batch_size/gi) ?? []).length, 5);
  assert.equal((sql.match(/where utc_day < v_day/gi) ?? []).length, 3);
  assert.equal((sql.match(/where utc_month < v_month/gi) ?? []).length, 2);
  assert.doesNotMatch(sql, /where utc_(?:day|month) <= v_(?:day|month)/i);
  assert.match(sql, /create extension if not exists pg_cron/i);
  assert.match(sql, /native-backend-counter-cleanup-hourly/i);
  assert.match(sql, /'17 \* \* \* \*'/i);
  assert.match(sql, /cleanup_native_backend_counters\(500\)/i);
  assert.match(sql, /revoke all[\s\S]*cleanup_native_backend_counters\(integer\)[\s\S]*public, anon, authenticated, supabase_auth_admin/i);
  assert.match(sql, /grant execute[\s\S]*cleanup_native_backend_counters\(integer\)[\s\S]*service_role/i);
});

test('dashboard bundle is deterministic, dependency-free, syntax-valid, and preserves route behavior', async () => {
  const first = await buildDashboardBundle();
  const second = await buildDashboardBundle({write: false});
  assert.equal(first.output, second.output);
  assert.deepEqual(first.requiredRuntimeMarkers, second.requiredRuntimeMarkers);
  for (const marker of first.requiredRuntimeMarkers) assert.equal(first.output.includes(marker), true);
  assert.equal(await readFile(first.outputFile, 'utf8'), first.output);
  assert.doesNotMatch(first.output, /^\s*(?:import|export)\s/m);
  for (const route of ['/health', '/interpret', '/delete-session']) assert.match(first.output, new RegExp(route.replace('/', '\\/')));
  assert.match(first.output, /Deno\.serve\(handler\)/);
  execFileSync(process.execPath, ['--check', first.outputFile], {stdio: 'pipe'});

  const previousDeno = globalThis.Deno;
  let modularHandler;
  let bundledHandler;
  try {
    globalThis.Deno = {env: {get() { return undefined; }}, serve(handler) { modularHandler = handler; }};
    await import(`../backend/supabase/functions/native-backend/index.ts?controls=${Date.now()}`);
    globalThis.Deno = {env: {get() { return undefined; }}, serve(handler) { bundledHandler = handler; }};
    await import(`${new URL('../backend/dist/native-backend-dashboard.ts', import.meta.url).href}?controls=${Date.now()}`);
  } finally {
    if (previousDeno === undefined) delete globalThis.Deno;
    else globalThis.Deno = previousDeno;
  }

  assert.equal(typeof modularHandler, 'function');
  assert.equal(typeof bundledHandler, 'function');
  const modularHealth = await modularHandler(new Request('https://example.invalid/health'));
  const bundledHealth = await bundledHandler(new Request('https://example.invalid/health'));
  assert.equal(modularHealth.status, 503);
  assert.equal(bundledHealth.status, 503);
  assert.deepEqual(await bundledHealth.json(), await modularHealth.json());

  for (const route of ['/interpret', '/delete-session']) {
    const modular = await modularHandler(new Request(`https://example.invalid${route}`, {method: 'POST'}));
    const bundled = await bundledHandler(new Request(`https://example.invalid${route}`, {method: 'POST'}));
    assert.equal(bundled.status, modular.status);
    assert.equal((await bundled.json()).code, (await modular.json()).code);
  }
});

test('documentation states real retention lag, hook activation, MAU limits, rollback, and no CAPTCHA', async () => {
  const readme = await readFile(readmeUrl, 'utf8');
  assert.match(readme, /Authentication\s*>\s*Hooks/i);
  assert.match(readme, /30[^\n]*UTC day/i);
  assert.match(readme, /100[^\n]*UTC month/i);
  assert.match(readme, /supabase_auth_admin/i);
  assert.match(readme, /monthly active user|MAU/i);
  assert.match(readme, /roll(?:s|ed)? back/i);
  assert.match(readme, /less than one hour|under one hour|<\s*1 hour/i);
  assert.match(readme, /job failure/i);
  assert.match(readme, /CAPTCHA/i);
  assert.match(readme, /native-backend-dashboard\.ts/i);
  assert.match(readme, /Idempotency-Key/i);
  assert.match(readme, /request_already_processed/i);
  assert.match(readme, /current and previous UTC day/i);
  assert.match(readme, /bank.*charge.*right.*light.*letter/is);
  assert.match(readme, /Missing Jev, Qwen.*does not disable/is);
  assert.match(readme, /migrations 001, 002, and 003/i);
});


test('migration 003 atomically receipts HMAC subjects and cleans only expired receipt periods', async () => {
  const sql = await readFile(idempotencyMigrationUrl, 'utf8');
  assert.match(sql, /create table if not exists native_backend\.request_receipts/i);
  assert.match(sql, /primary key \(subject_hash, idempotency_key\)/i);
  assert.match(sql, /idempotency_key uuid not null/i);
  assert.match(sql, /request_already_processed/g);
  assert.match(sql, /native_backend:receipt:/i);
  assert.match(sql, /pg_advisory_xact_lock/i);
  assert.ok(sql.indexOf('request_already_processed') < sql.indexOf('insert into native_backend.global_monthly_quota'));
  assert.match(sql, /reserved_provider_attempt_count[\s\S]*p_reserved_provider_attempts/i);
  assert.match(sql, /where utc_day < \(v_day - 1\)/i);
  assert.equal((sql.match(/limit p_batch_size/gi) ?? []).length, 6);
  assert.match(sql, /revoke all on native_backend\.request_receipts from public, anon, authenticated, supabase_auth_admin/i);
  assert.match(sql, /grant select, insert, delete on native_backend\.request_receipts to service_role/i);
  const receiptTable = sql.match(/create table if not exists native_backend\.request_receipts[\s\S]*?\);/i)?.[0] ?? '';
  assert.doesNotMatch(receiptTable, /auth_user_id|source|translation|context|transcript|result|error_body/i);
});
