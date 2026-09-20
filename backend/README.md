# Native Jev Supabase backend

**Legacy/reference service, not the build 3 native BYOK route.** On 20 September 2026 the deployed Jev Relay project's `TYPESAFE_API_KEY` and `NEBIUS_API_KEY` secrets were removed without revoking provider-account keys elsewhere. Read-only health verification returned HTTP 503, `ready:false`, interpretation disabled, and `deleteSession:true`. Do not restore shared funding for the native app. Existing identity-deletion and retention obligations remain; no database records were deleted during this migration.

The new native client calls providers directly with each user's own device-Keychain credentials. The implementation below is retained for historical verification and local reference. It exposes only:

- `GET /health`
- `POST /interpret`
- `POST /delete-session`

There is intentionally no browser CORS policy. Native clients should call the Edge Function directly. Do not add permissive CORS unless a separately reviewed browser client requires it.

## Security and request flow

1. The handler requires `Authorization: Bearer <anonymous-user access token>`.
2. It rejects configured public anon/publishable keys, including `sb_publishable_...`, as user credentials.
3. It calls Supabase Auth `GET /auth/v1/user` and requires `is_anonymous: true`. No client-supplied user ID is accepted.
4. `/interpret` accepts at most 16 KiB of JSON and only `text`, `context`, `source`, `target`, and `senseOptions`. Native turn validation runs before quota or provider calls.
5. The optional `Idempotency-Key` header must be a UUID. The authenticated HMAC subject and UUID are atomically receipted with quota reservation. A duplicate returns HTTP 409 `request_already_processed` without another provider call. When the header is absent, the server-generated request UUID is used for backward compatibility.
6. Caller cancellation is checked before quota reservation and after Jev before any possible Qwen call. Once reservation starts it is allowed to finish, so failed or cancelled accepted requests still count. Provider fetches combine the caller signal with the fixed 12-second provider timeout.
7. Jev native four-decision inference runs once. Qwen runs once only when the route requires genuinely new wording. There are no automatic retries.
8. User text, provider responses, and error bodies are not logged or persisted by this code. Provider and Supabase platform logging and retention policies are not verified here, so do not claim zero vendor retention without separate contractual and configuration review.

The interpreter response preserves the existing contract and adds `requestId`:

```json
{
  "mode": "live",
  "sourceText": "Where is the station?",
  "route": "translate",
  "reason": "...",
  "translatedText": "Waar is het station?",
  "clarification": "",
  "decisions": {},
  "model": "jev-1.13.0",
  "timing": {"decisionMs": 120, "translationMs": 240, "totalMs": 360},
  "usedTranslator": true,
  "requestId": "server-generated-uuid"
}
```

## Inference request quotas

The database fixes hard request caps at:

- 10 turns per authenticated anonymous user per UTC day
- 60 turns globally per UTC day
- 300 turns globally per UTC month

Each accepted turn reserves two provider attempts and its idempotency receipt in the same transaction, even when memory reuse, clarification, provider failure, or post-reservation cancellation later avoids Qwen. Advisory transaction locks, primary keys, and row constraints make concurrent reservations and duplicate detection safe. The Edge environment switches may only reduce these hard caps; invalid or higher values make readiness fail.

These are request caps, **not monetary caps**. A paid live launch requires explicit budget approval if it has not already been authorized, plus provider-side spend limits and alerts.

Quota rows store only aggregate counts, UTC periods, and an HMAC pseudonym. Idempotency receipts store only that HMAC subject, the action UUID, and receipt timestamps. They do not store source text, context, translations, decisions, results, tokens, IP addresses, or provider error bodies.

## Counter retention and cleanup

`public.cleanup_native_backend_counters(batch_size)` deletes only expired counter periods. It never deletes the current UTC day or current UTC month, so active user and global caps remain intact. It retains idempotency receipts for the current and previous UTC day to cover late retries across rollover. The function validates a batch size from 1 through 1,000 and deletes at most that many rows from each of six counter or receipt tables per invocation.

The migration enables `pg_cron` and schedules `native-backend-counter-cleanup-hourly` at minute 17 of every hour with a batch size of 500. Under the fixed caps, one normal run can clear all rows that became eligible during the previous period. Expired rows are therefore normally removed in less than one hour after UTC day or month rollover. This is not an absolute retention guarantee: a paused Free project, disabled Cron module, job failure, or historical backlog extends retention until enough successful runs complete. Monitor `cron.job_run_details` and the Dashboard Cron integration.

This cleanup is why a deleted user's current pseudonymous daily quota remains until its UTC counter expires, rather than indefinitely. Global current-period counters also remain until their period expires. Action UUID receipts normally disappear within one successful hourly run after the retained previous-day window ends.

## Anonymous identity creation hook

Anonymous sign-in creates a persistent Auth user and can inflate monthly active user usage. Before exposing a publishable key, enable the migration's `public.before_user_created_native_backend` as the project's **Before User Created** Postgres Auth hook.

The hook:

- accepts only `event.user.is_anonymous = true` and denies all permanent/email/OAuth registrations because this app offers none;
- atomically caps successful anonymous identity creation at 30 per UTC day and 100 per UTC month;
- stores aggregate period counts only, with no user ID, IP address, email, phone, or request ID;
- never decrements signup counts when an account is deleted;
- returns a clear HTTP 429 error when the daily or monthly pilot capacity is full;
- executes as the documented `supabase_auth_admin` role using `security invoker`, narrowly granted table access, and explicit RLS policies;
- affects only creation of new users, not refresh or use of existing authenticated sessions.

Supabase documents Before User Created as available on Free and Pro. The official payload contains `metadata` and the pending `user`, including `user.is_anonymous`. Postgres hooks run transactionally. The hook performs limit checks before incrementing, so hook-denied signups do not consume a counter; if the surrounding accepted user-creation transaction later fails, its counter increment rolls back with that transaction.

These signup limits bound new anonymous identities, but are not a complete MAU guarantee because identities created in earlier months may still become active. Review abandoned-account lifecycle separately before moving beyond the pilot. We intentionally do not add CAPTCHA because the native app currently has no WebView dependency; the server-side hook is mandatory before public publishable-key launch.

### Enable the hook in the hosted Dashboard

After applying migrations:

1. Open **Authentication > Hooks** in the intended project.
2. Choose **Before User Created**.
3. Select the Postgres function option.
4. Select `public.before_user_created_native_backend`.
5. Save, then run controlled staging checks for anonymous allow, non-anonymous denial, and limit denial.

Do not expose the hook as a client RPC. Execute permission is revoked from `public`, `anon`, `authenticated`, and `service_role`; only `supabase_auth_admin` receives it.

## Trusted ambiguity catalog

When a validated turn has no explicit `senseOptions`, the backend checks a fixed English whole-word catalog for one lexical family, in deterministic order: `bank`, `charge`, `right`, `light`, or `letter`. A match adds only the catalog's predefined senses before building the existing Jev action, memory, register, and sense questions. At most one family is added. Explicit client options are preserved unchanged. The same trusted options are passed to Qwen only if new wording is required. This does not let Jev invent candidate words and introduces no new performance claim.

## Account deletion

`POST /delete-session` takes no body and depends only on Supabase Auth and admin deletion configuration. Missing Jev, Qwen, or inference quota configuration does not disable this mandatory route. After the same `getUser` verification, it hard-deletes only the calling Supabase Auth identity. The account metadata row is removed by its foreign-key cascade. The current pseudonymous quota aggregate is retained until UTC period expiry and the next successful cleanup run. Current global request and signup caps remain and account deletion never decrements them. The response states this explicitly.

Because the retained quota key is an HMAC of the deleted Auth UUID, deletion does not reset that identity's current counter. A newly created anonymous identity has a new UUID; the global anonymous-signup hook limits such churn, but stronger device-level abuse prevention would require a separately reviewed native attestation design rather than a client-provided identifier.

## Database setup

From `backend/`, after selecting the intended Supabase project:

1. In **Integrations > Cron**, enable the Supabase Cron Postgres Module. Hosted Supabase implements this with `pg_cron`; migration 002 also uses `create extension if not exists pg_cron`.
2. Apply migrations 001, 002, and 003 in order. Migration 003 upgrades the existing quota RPC with atomic privacy-preserving idempotency receipts and extends cleanup without rewriting migrations 001 or 002.
3. Enable the Before User Created hook using the Dashboard steps above.

```sh
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

The migrations create a private `native_backend` schema, enable RLS on every table, grant no table or RPC access to `anon` or `authenticated`, and grant the inference quota RPC only to `service_role`. The Auth hook has a separate narrow grant to `supabase_auth_admin`, as required by Supabase Auth. Do not expose the private schema through the Data API.

`supabase/config.toml` sets `verify_jwt = false` for the Edge Function because the function performs authoritative Auth-server validation and explicitly denies public API keys as bearer credentials. Do not remove that application-level validation.

## Secrets and configuration

Hosted Edge Functions provide `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_ANON_KEY` as default project secrets. Do not copy those values into source control. Set only the application secrets that are not supplied automatically:

```sh
supabase secrets set \
  APP_PUBLISHABLE_KEY='...' \
  QUOTA_PEPPER='at-least-32-random-characters' \
  TYPESAFE_API_KEY='...' \
  NEBIUS_API_KEY='...'
```

`APP_PUBLISHABLE_KEY` is optional, but configure it when the project uses a publishable key so it can be rejected explicitly. The `sb_publishable_` prefix is always denied as a bearer credential. The default `SUPABASE_ANON_KEY` is required for readiness. Generate `QUOTA_PEPPER` independently and rotate it only with a deliberate quota migration because rotation changes every pseudonym.

Optional inference request-limit reductions:

```sh
supabase secrets set \
  USER_DAILY_REQUEST_LIMIT='8' \
  GLOBAL_DAILY_REQUEST_LIMIT='40' \
  GLOBAL_MONTHLY_REQUEST_LIMIT='200'
```

Deploy only after migration, Auth hook activation, Cron verification, secret review, tests, and budget approval:

```sh
supabase functions deploy native-backend
```

Check readiness without exposing secret values:

```sh
curl "https://YOUR_PROJECT.supabase.co/functions/v1/native-backend/health"
```

## Dashboard Editor single-file bundle

The CLI entrypoint uses local shared modules. For the Supabase Dashboard Edge Function editor, generate a deterministic dependency-free single TypeScript file:

```sh
node backend/scripts/build-dashboard-bundle.mjs
node --check backend/dist/native-backend-dashboard.ts
```

Paste the complete contents of `backend/dist/native-backend-dashboard.ts` into the Dashboard editor for the `native-backend` function. The generator concatenates a fixed allowlist of local modules, removes only local module syntax and TypeScript-only annotations, adds no packages, timestamps, network reads, or environment values, and fails on unexpected import/export/type syntax. Do not edit the generated file directly. Rebuild and rerun tests after changing any source module.

## Native client integration

1. Create or restore a Supabase anonymous session with the official mobile Auth client.
2. Send the session access token, never the project anon/publishable key, as the bearer token.
3. Generate one UUID per user action and send it as `Idempotency-Key` on `POST .../native-backend/interpret` with `Content-Type: application/json`. Reuse that UUID only when retrying the same action. Older clients without the header remain compatible because the server generates a UUID.
4. Treat `clarify` and `review` as non-playback routes. Treat all generated and memory text as review-required, as indicated by the response reasons.
5. On mandatory app-account deletion, call `POST .../native-backend/delete-session` with an empty body, then clear the local session only after a successful response.
6. Do not retry inference automatically. If a network result is ambiguous, a deliberate same-action retry must reuse the same idempotency UUID and may receive HTTP 409 because the original request was already reserved.
7. Treat caller cancellation after reservation as counted. Cancellation before reservation does not create a receipt or consume quota.
8. Handle Auth hook HTTP 429 messages as pilot-capacity limits and do not loop anonymous signup attempts.

## Tests

From the repository root:

```sh
node --test test/native-backend*.test.mjs
npm test
```

No test or build step calls live providers, Supabase APIs, or the cloud project.
