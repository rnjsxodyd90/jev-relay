-- Run only in the isolated Jev Relay project after migrations and hook activation.
-- All test mutations are rolled back. No Auth identities are created.
-- This verifies hook logic as the Dashboard database owner, not Auth-role RLS.
-- Hosted Supabase forbids that owner from SET ROLE supabase_auth_admin.
-- Actual Auth-role execution is covered separately by real anonymous-signup smoke tests.
BEGIN;
DO $checks$
DECLARE
  day_key date := (clock_timestamp() AT TIME ZONE 'UTC')::date;
  month_key date := date_trunc('month', clock_timestamp() AT TIME ZONE 'UTC')::date;
  answer jsonb;
  anonymous_event jsonb := '{"metadata":{"name":"before-user-created"},"user":{"is_anonymous":true}}'::jsonb;
BEGIN
  -- Take the hook's locks in its own order before touching counter rows.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:anonymous_signup_month:' || month_key::text, 0));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:anonymous_signup_day:' || day_key::text, 0));

  answer := public.before_user_created_native_backend('{"metadata":{"name":"before-user-created"},"user":{"is_anonymous":false}}'::jsonb);
  IF answer #>> '{error,http_code}' IS DISTINCT FROM '403' THEN
    RAISE EXCEPTION 'Permanent-account denial failed';
  END IF;
  answer := public.before_user_created_native_backend('{}'::jsonb);
  IF answer #>> '{error,http_code}' IS DISTINCT FROM '400' THEN
    RAISE EXCEPTION 'Malformed-event denial failed';
  END IF;

  INSERT INTO native_backend.anonymous_signup_daily VALUES (day_key, 30)
    ON CONFLICT (utc_day) DO UPDATE SET signup_count = 30;
  INSERT INTO native_backend.anonymous_signup_monthly VALUES (month_key, 0)
    ON CONFLICT (utc_month) DO UPDATE SET signup_count = 0;
  answer := public.before_user_created_native_backend(anonymous_event);
  IF answer #>> '{error,http_code}' IS DISTINCT FROM '429'
     OR (SELECT signup_count FROM native_backend.anonymous_signup_monthly WHERE utc_month = month_key) <> 0 THEN
    RAISE EXCEPTION 'Daily signup cap or no-increment-on-denial failed';
  END IF;

  UPDATE native_backend.anonymous_signup_daily SET signup_count = 0 WHERE utc_day = day_key;
  UPDATE native_backend.anonymous_signup_monthly SET signup_count = 100 WHERE utc_month = month_key;
  answer := public.before_user_created_native_backend(anonymous_event);
  IF answer #>> '{error,http_code}' IS DISTINCT FROM '429'
     OR (SELECT signup_count FROM native_backend.anonymous_signup_daily WHERE utc_day = day_key) <> 0 THEN
    RAISE EXCEPTION 'Monthly signup cap or no-increment-on-denial failed';
  END IF;

  UPDATE native_backend.anonymous_signup_monthly SET signup_count = 0 WHERE utc_month = month_key;
  answer := public.before_user_created_native_backend(anonymous_event);
  IF answer IS DISTINCT FROM '{}'::jsonb
     OR (SELECT signup_count FROM native_backend.anonymous_signup_daily WHERE utc_day = day_key) <> 1
     OR (SELECT signup_count FROM native_backend.anonymous_signup_monthly WHERE utc_month = month_key) <> 1 THEN
    RAISE EXCEPTION 'Valid anonymous signup or atomic counter increment failed';
  END IF;
END;
$checks$;
ROLLBACK;

SELECT 'PASS: hook logic assertions; all test mutations rolled back' AS verification,
  (SELECT count(*) FROM auth.users) AS remaining_auth_identities,
  (SELECT count(*) FROM native_backend.account_metadata) AS remaining_account_metadata,
  (SELECT signup_count FROM native_backend.anonymous_signup_daily WHERE utc_day = (clock_timestamp() AT TIME ZONE 'UTC')::date) AS current_daily_signups,
  (SELECT request_count FROM native_backend.global_daily_quota WHERE utc_day = (clock_timestamp() AT TIME ZONE 'UTC')::date) AS current_daily_turns;
