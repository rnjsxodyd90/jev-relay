-- Bounded aggregate retention and anonymous identity creation controls.
-- Hook contract: https://supabase.com/docs/guides/auth/auth-hooks/before-user-created-hook

create table if not exists native_backend.anonymous_signup_daily (
  utc_day date primary key,
  signup_count integer not null check (signup_count between 0 and 30)
);

create table if not exists native_backend.anonymous_signup_monthly (
  utc_month date primary key check (utc_month = date_trunc('month', utc_month)::date),
  signup_count integer not null check (signup_count between 0 and 100)
);

alter table native_backend.anonymous_signup_daily enable row level security;
alter table native_backend.anonymous_signup_monthly enable row level security;

revoke all on native_backend.anonymous_signup_daily from public, anon, authenticated;
revoke all on native_backend.anonymous_signup_monthly from public, anon, authenticated;
grant select, insert, update, delete on native_backend.anonymous_signup_daily to service_role;
grant select, insert, update, delete on native_backend.anonymous_signup_monthly to service_role;

-- Supabase Auth invokes Postgres hooks as supabase_auth_admin. Keep the hook as
-- security invoker, grant only the aggregate tables it needs, and add explicit
-- RLS policies for that role.
grant usage on schema native_backend to supabase_auth_admin;
grant select, insert, update on native_backend.anonymous_signup_daily to supabase_auth_admin;
grant select, insert, update on native_backend.anonymous_signup_monthly to supabase_auth_admin;

drop policy if exists anonymous_signup_daily_auth_hook on native_backend.anonymous_signup_daily;
create policy anonymous_signup_daily_auth_hook
  on native_backend.anonymous_signup_daily
  for all
  to supabase_auth_admin
  using (true)
  with check (true);

drop policy if exists anonymous_signup_monthly_auth_hook on native_backend.anonymous_signup_monthly;
create policy anonymous_signup_monthly_auth_hook
  on native_backend.anonymous_signup_monthly
  for all
  to supabase_auth_admin
  using (true)
  with check (true);

create or replace function public.before_user_created_native_backend(event jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_day date := (v_now at time zone 'UTC')::date;
  v_month date := date_trunc('month', v_now at time zone 'UTC')::date;
  v_is_anonymous text;
  v_day_count integer;
  v_month_count integer;
begin
  if event is null
     or pg_catalog.jsonb_typeof(event) is distinct from 'object'
     or event #>> '{metadata,name}' is distinct from 'before-user-created'
     or pg_catalog.jsonb_typeof(event->'user') is distinct from 'object' then
    return pg_catalog.jsonb_build_object(
      'error', pg_catalog.jsonb_build_object(
        'http_code', 400,
        'message', 'The account creation request is invalid.'
      )
    );
  end if;

  v_is_anonymous := event #>> '{user,is_anonymous}';
  if v_is_anonymous is null or v_is_anonymous not in ('true', 'false') then
    return pg_catalog.jsonb_build_object(
      'error', pg_catalog.jsonb_build_object(
        'http_code', 400,
        'message', 'The account creation request is missing its anonymous-user status.'
      )
    );
  end if;

  if v_is_anonymous <> 'true' then
    return pg_catalog.jsonb_build_object(
      'error', pg_catalog.jsonb_build_object(
        'http_code', 403,
        'message', 'This app only allows anonymous account creation.'
      )
    );
  end if;

  -- Consistent ordering makes concurrent signup checks atomic and deadlock-safe.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:anonymous_signup_month:' || v_month::text, 0));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('native_backend:anonymous_signup_day:' || v_day::text, 0));

  select signup_count into v_month_count
    from native_backend.anonymous_signup_monthly
    where utc_month = v_month;
  select signup_count into v_day_count
    from native_backend.anonymous_signup_daily
    where utc_day = v_day;

  if coalesce(v_day_count, 0) >= 30 then
    return pg_catalog.jsonb_build_object(
      'error', pg_catalog.jsonb_build_object(
        'http_code', 429,
        'message', 'The anonymous signup limit for today has been reached. Try again after the next UTC day begins.'
      )
    );
  end if;

  if coalesce(v_month_count, 0) >= 100 then
    return pg_catalog.jsonb_build_object(
      'error', pg_catalog.jsonb_build_object(
        'http_code', 429,
        'message', 'The anonymous signup limit for this month has been reached. Try again after the next UTC month begins.'
      )
    );
  end if;

  insert into native_backend.anonymous_signup_monthly (utc_month, signup_count)
    values (v_month, 1)
    on conflict (utc_month) do update set
      signup_count = native_backend.anonymous_signup_monthly.signup_count + 1;

  insert into native_backend.anonymous_signup_daily (utc_day, signup_count)
    values (v_day, 1)
    on conflict (utc_day) do update set
      signup_count = native_backend.anonymous_signup_daily.signup_count + 1;

  return '{}'::jsonb;
end;
$$;

grant usage on schema public to supabase_auth_admin;
revoke all on function public.before_user_created_native_backend(jsonb) from public, anon, authenticated, service_role;
grant execute on function public.before_user_created_native_backend(jsonb) to supabase_auth_admin;

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
    'signupDailyDeleted', v_signup_daily,
    'signupMonthlyDeleted', v_signup_monthly
  );
end;
$$;

revoke all on function public.cleanup_native_backend_counters(integer) from public, anon, authenticated, supabase_auth_admin;
grant execute on function public.cleanup_native_backend_counters(integer) to service_role;
grant execute on function public.cleanup_native_backend_counters(integer) to postgres;

-- Hosted Supabase supports pg_cron through the Cron Postgres Module. The job is
-- bounded to 500 rows per counter table and never deletes an active UTC period.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule(
  'native-backend-counter-cleanup-hourly',
  '17 * * * *',
  $cron$select public.cleanup_native_backend_counters(500);$cron$
);
