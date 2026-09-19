-- Native Jev backend quotas. All periods are derived from the database clock in UTC.
create schema if not exists native_backend;
revoke all on schema native_backend from public, anon, authenticated;
grant usage on schema native_backend to service_role;

create table if not exists native_backend.account_metadata (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists native_backend.user_daily_quota (
  subject_hash text not null check (subject_hash ~ '^[0-9a-f]{64}$'),
  utc_day date not null,
  request_count integer not null check (request_count between 0 and 10),
  reserved_provider_attempt_count integer not null check (
    reserved_provider_attempt_count >= 0
    and reserved_provider_attempt_count = request_count * 2
  ),
  primary key (subject_hash, utc_day)
);

create table if not exists native_backend.global_daily_quota (
  utc_day date primary key,
  request_count integer not null check (request_count between 0 and 60),
  reserved_provider_attempt_count integer not null check (
    reserved_provider_attempt_count >= 0
    and reserved_provider_attempt_count = request_count * 2
  )
);

create table if not exists native_backend.global_monthly_quota (
  utc_month date primary key check (utc_month = date_trunc('month', utc_month)::date),
  request_count integer not null check (request_count between 0 and 300),
  reserved_provider_attempt_count integer not null check (
    reserved_provider_attempt_count >= 0
    and reserved_provider_attempt_count = request_count * 2
  )
);

alter table native_backend.account_metadata enable row level security;
alter table native_backend.user_daily_quota enable row level security;
alter table native_backend.global_daily_quota enable row level security;
alter table native_backend.global_monthly_quota enable row level security;

revoke all on all tables in schema native_backend from public, anon, authenticated;
grant select, insert, update, delete on all tables in schema native_backend to service_role;

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
  -- p_request_id is validated by PostgreSQL's uuid cast but deliberately is not
  -- retained: quota storage contains aggregate counts only.
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

  -- A consistent lock order prevents deadlocks. Hash collisions only serialize
  -- unrelated subjects; they cannot weaken a cap.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:global_month:' || v_month::text, 0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:global_day:' || v_day::text, 0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:user_day:' || p_subject_hash || ':' || v_day::text, 0));

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

  return jsonb_build_object(
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

revoke all on function public.reserve_native_backend_quota(uuid, text, uuid, integer, integer, integer, integer) from public, anon, authenticated;
grant execute on function public.reserve_native_backend_quota(uuid, text, uuid, integer, integer, integer, integer) to service_role;
