-- Privacy-preserving action idempotency. p_request_id is the client action UUID
-- (or a server-generated fallback), not the response requestId and not user data.
create table if not exists native_backend.request_receipts (
  subject_hash text not null check (subject_hash ~ '^[0-9a-f]{64}$'),
  idempotency_key uuid not null,
  utc_day date not null,
  created_at timestamptz not null default now(),
  primary key (subject_hash, idempotency_key)
);

alter table native_backend.request_receipts enable row level security;
revoke all on native_backend.request_receipts from public, anon, authenticated, supabase_auth_admin;
grant select, insert, delete on native_backend.request_receipts to service_role;

create or replace function public.reserve_native_backend_quota(
  p_auth_user_id uuid,
  p_subject_hash text,
  p_request_id uuid,
  p_reserved_provider_attempts integer,
  p_user_daily_limit integer,
  p_global_daily_limit integer,
  p_global_monthly_limit integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_day date := (v_now at time zone 'UTC')::date;
  v_month date := date_trunc('month', v_now at time zone 'UTC')::date;
  v_user_count integer;
  v_day_count integer;
  v_month_count integer;
begin
  if p_request_id is null
     or p_auth_user_id is null
     or p_subject_hash is null
     or p_subject_hash !~ '^[0-9a-f]{64}$'
     or p_reserved_provider_attempts is null
     or p_reserved_provider_attempts <> 2
     or p_user_daily_limit is null
     or p_user_daily_limit not between 1 and 10
     or p_global_daily_limit is null
     or p_global_daily_limit not between 1 and 60
     or p_global_monthly_limit is null
     or p_global_monthly_limit not between 1 and 300 then
    raise exception using errcode = 'P0001', message = 'quota_configuration_invalid';
  end if;

  if not exists (select 1 from auth.users where id = p_auth_user_id) then
    raise exception using errcode = 'P0001', message = 'quota_configuration_invalid';
  end if;

  -- Lock action receipt first, then all counters in one consistent order.
  -- The receipt key contains only the server HMAC subject and action UUID.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:receipt:' || p_subject_hash || ':' || p_request_id::text, 0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:global_month:' || v_month::text, 0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:global_day:' || v_day::text, 0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:user_day:' || p_subject_hash || ':' || v_day::text, 0));

  if exists (
    select 1 from native_backend.request_receipts
    where subject_hash = p_subject_hash and idempotency_key = p_request_id
  ) then
    raise exception using errcode = 'P0001', message = 'request_already_processed';
  end if;

  select request_count into v_month_count
    from native_backend.global_monthly_quota where utc_month = v_month;
  select request_count into v_day_count
    from native_backend.global_daily_quota where utc_day = v_day;
  select request_count into v_user_count
    from native_backend.user_daily_quota where subject_hash = p_subject_hash and utc_day = v_day;

  if coalesce(v_user_count, 0) >= p_user_daily_limit then
    raise exception using errcode = 'P0001', message = 'quota_user_daily';
  end if;
  if coalesce(v_day_count, 0) >= p_global_daily_limit then
    raise exception using errcode = 'P0001', message = 'quota_global_daily';
  end if;
  if coalesce(v_month_count, 0) >= p_global_monthly_limit then
    raise exception using errcode = 'P0001', message = 'quota_global_monthly';
  end if;

  insert into native_backend.account_metadata (auth_user_id)
    values (p_auth_user_id)
    on conflict (auth_user_id) do nothing;

  begin
    insert into native_backend.request_receipts (subject_hash, idempotency_key, utc_day)
      values (p_subject_hash, p_request_id, v_day);
  exception when unique_violation then
    raise exception using errcode = 'P0001', message = 'request_already_processed';
  end;

  insert into native_backend.global_monthly_quota (utc_month, request_count, reserved_provider_attempt_count)
    values (v_month, 1, p_reserved_provider_attempts)
    on conflict (utc_month) do update set
      request_count = native_backend.global_monthly_quota.request_count + 1,
      reserved_provider_attempt_count = native_backend.global_monthly_quota.reserved_provider_attempt_count + p_reserved_provider_attempts;

  insert into native_backend.global_daily_quota (utc_day, request_count, reserved_provider_attempt_count)
    values (v_day, 1, p_reserved_provider_attempts)
    on conflict (utc_day) do update set
      request_count = native_backend.global_daily_quota.request_count + 1,
      reserved_provider_attempt_count = native_backend.global_daily_quota.reserved_provider_attempt_count + p_reserved_provider_attempts;

  insert into native_backend.user_daily_quota (subject_hash, utc_day, request_count, reserved_provider_attempt_count)
    values (p_subject_hash, v_day, 1, p_reserved_provider_attempts)
    on conflict (subject_hash, utc_day) do update set
      request_count = native_backend.user_daily_quota.request_count + 1,
      reserved_provider_attempt_count = native_backend.user_daily_quota.reserved_provider_attempt_count + p_reserved_provider_attempts;

  return pg_catalog.jsonb_build_object(
    'reserved', true,
    'utcDay', v_day,
    'utcMonth', v_month,
    'userRequestCount', coalesce(v_user_count, 0) + 1,
    'globalDayRequestCount', coalesce(v_day_count, 0) + 1,
    'globalMonthRequestCount', coalesce(v_month_count, 0) + 1,
    'reservedProviderAttempts', p_reserved_provider_attempts
  );
end;
$$;

revoke all on function public.reserve_native_backend_quota(uuid, text, uuid, integer, integer, integer, integer) from public, anon, authenticated, supabase_auth_admin;
grant execute on function public.reserve_native_backend_quota(uuid, text, uuid, integer, integer, integer, integer) to service_role;

create or replace function public.cleanup_native_backend_counters(p_batch_size integer default 500)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_day date := (clock_timestamp() at time zone 'UTC')::date;
  v_month date := date_trunc('month', clock_timestamp() at time zone 'UTC')::date;
  v_user_daily integer := 0;
  v_global_daily integer := 0;
  v_global_monthly integer := 0;
  v_receipts integer := 0;
  v_signup_daily integer := 0;
  v_signup_monthly integer := 0;
begin
  if p_batch_size is null or p_batch_size not between 1 and 1000 then
    raise exception using errcode = 'P0001', message = 'cleanup_batch_invalid';
  end if;

  with doomed as (
    select ctid from native_backend.user_daily_quota
    where utc_day < v_day
    order by utc_day, subject_hash
    limit p_batch_size
  )
  delete from native_backend.user_daily_quota as target
    using doomed where target.ctid = doomed.ctid;
  get diagnostics v_user_daily = row_count;

  with doomed as (
    select ctid from native_backend.global_daily_quota
    where utc_day < v_day
    order by utc_day
    limit p_batch_size
  )
  delete from native_backend.global_daily_quota as target
    using doomed where target.ctid = doomed.ctid;
  get diagnostics v_global_daily = row_count;

  with doomed as (
    select ctid from native_backend.global_monthly_quota
    where utc_month < v_month
    order by utc_month
    limit p_batch_size
  )
  delete from native_backend.global_monthly_quota as target
    using doomed where target.ctid = doomed.ctid;
  get diagnostics v_global_monthly = row_count;

  -- Keep current and previous UTC-day receipts so late network retries remain
  -- idempotent across a day rollover. Older UUID receipts are boundedly removed.
  with doomed as (
    select ctid from native_backend.request_receipts
    where utc_day < (v_day - 1)
    order by utc_day, subject_hash, idempotency_key
    limit p_batch_size
  )
  delete from native_backend.request_receipts as target
    using doomed where target.ctid = doomed.ctid;
  get diagnostics v_receipts = row_count;

  with doomed as (
    select ctid from native_backend.anonymous_signup_daily
    where utc_day < v_day
    order by utc_day
    limit p_batch_size
  )
  delete from native_backend.anonymous_signup_daily as target
    using doomed where target.ctid = doomed.ctid;
  get diagnostics v_signup_daily = row_count;

  with doomed as (
    select ctid from native_backend.anonymous_signup_monthly
    where utc_month < v_month
    order by utc_month
    limit p_batch_size
  )
  delete from native_backend.anonymous_signup_monthly as target
    using doomed where target.ctid = doomed.ctid;
  get diagnostics v_signup_monthly = row_count;

  return pg_catalog.jsonb_build_object(
    'userDailyDeleted', v_user_daily,
    'globalDailyDeleted', v_global_daily,
    'globalMonthlyDeleted', v_global_monthly,
    'receiptDeleted', v_receipts,
    'signupDailyDeleted', v_signup_daily,
    'signupMonthlyDeleted', v_signup_monthly
  );
end;
$$;

revoke all on function public.cleanup_native_backend_counters(integer) from public, anon, authenticated, supabase_auth_admin;
grant execute on function public.cleanup_native_backend_counters(integer) to service_role;
grant execute on function public.cleanup_native_backend_counters(integer) to postgres;
