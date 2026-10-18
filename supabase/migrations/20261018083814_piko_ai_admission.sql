-- Server-only accounting. No vocabulary, prompts or generated results are stored.
create schema piko_ai;
revoke all on schema piko_ai from public, anon, authenticated;
grant usage on schema piko_ai to service_role;

create table piko_ai.month_budget (
  month date primary key check (extract(day from month) = 1),
  enabled boolean not null default false,
  limit_micro_usd bigint not null default 0 check (limit_micro_usd >= 0),
  reserved_micro_usd bigint not null default 0
    check (reserved_micro_usd >= 0 and reserved_micro_usd <= limit_micro_usd)
);
create table piko_ai.identity_usage (
  identity_id uuid primary key references auth.users(id) on delete cascade,
  last_seen timestamptz not null default now(),
  usage_day date not null,
  daily_count integer not null default 0 check (daily_count between 0 and 100),
  recent_starts timestamptz[] not null default '{}',
  active_request uuid,
  active_until timestamptz,
  deleting boolean not null default false
);
create table piko_ai.request_usage (
  request_id uuid primary key,
  identity_id uuid not null references auth.users(id) on delete cascade,
  admitted_at timestamptz not null default now(),
  reserved_micro_usd bigint not null check (reserved_micro_usd > 0),
  charged_micro_usd bigint check (charged_micro_usd >= 0 and charged_micro_usd <= reserved_micro_usd),
  outcome text not null default 'reserved'
    check (outcome in ('reserved','success','failed','uncertain'))
);
create index request_usage_retention on piko_ai.request_usage(admitted_at);
create index identity_usage_retention on piko_ai.identity_usage(last_seen);
alter table piko_ai.month_budget enable row level security;
alter table piko_ai.identity_usage enable row level security;
alter table piko_ai.request_usage enable row level security;
revoke all on all tables in schema piko_ai from public, anon, authenticated;
grant select, insert, update, delete on all tables in schema piko_ai to service_role;

create function public.piko_ai_admit(p_identity uuid, p_request uuid, p_reserve bigint)
returns text language plpgsql security invoker set search_path = '' as $$
declare
  stamp timestamptz := clock_timestamp();
  today date := (stamp at time zone 'UTC')::date;
  month_start date := date_trunc('month', stamp at time zone 'UTC')::date;
  request_time timestamptz;
  budget piko_ai.month_budget%rowtype;
  identity_row piko_ai.identity_usage%rowtype;
  starts timestamptz[];
begin
  -- UUIDv7 carries its creation time. Old request IDs cannot become new paid
  -- requests after the 35-day tombstone cleanup. No extra client timestamp.
  if p_request::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    or p_reserve <= 0 or p_reserve > 1000000 then return 'invalid'; end if;
  request_time := to_timestamp((('x' || substr(replace(p_request::text, '-', ''),1,12))::bit(48)::bigint)::numeric / 1000);
  if request_time < stamp - interval '5 minutes' or request_time > stamp + interval '1 minute'
    then return 'expired'; end if;
  if not exists(select 1 from auth.users where id=p_identity and is_anonymous=true)
    then return 'authentication'; end if;
  -- The shared row is the first lock in every admission. Reservations never get
  -- released without verified usage, including failures and uncertain timeouts.
  select * into budget from piko_ai.month_budget where month=month_start for update;
  if not found or not budget.enabled then return 'unavailable'; end if;
  insert into piko_ai.identity_usage(identity_id, usage_day)
    values(p_identity,today) on conflict do nothing;
  select * into identity_row from piko_ai.identity_usage where identity_id=p_identity for update;
  if identity_row.deleting then return 'authentication'; end if;
  if exists(select 1 from piko_ai.request_usage where request_id=p_request) then return 'duplicate'; end if;
  if identity_row.active_request is not null and identity_row.active_until > stamp then return 'busy'; end if;
  select coalesce(array_agg(s), '{}') into starts
    from unnest(identity_row.recent_starts) s where s > stamp - interval '1 minute';
  if cardinality(starts) >= 2 then return 'minute_limit'; end if;
  if identity_row.usage_day=today and identity_row.daily_count >= 100 then return 'day_limit'; end if;
  if p_reserve > budget.limit_micro_usd - budget.reserved_micro_usd then return 'budget_limit'; end if;
  insert into piko_ai.request_usage(request_id,identity_id,reserved_micro_usd)
    values(p_request,p_identity,p_reserve);
  update piko_ai.month_budget set reserved_micro_usd=reserved_micro_usd+p_reserve where month=month_start;
  update piko_ai.identity_usage set last_seen=stamp, usage_day=today,
    daily_count=case when usage_day=today then daily_count+1 else 1 end,
    recent_starts=array_append(starts,stamp), active_request=p_request,
    active_until=stamp+interval '2 minutes' where identity_id=p_identity;
  return 'admitted';
end $$;

create function public.piko_ai_finish(p_identity uuid,p_request uuid,p_outcome text,p_actual bigint default null)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  receipt piko_ai.request_usage%rowtype;
  month_start date;
begin
  if p_outcome not in ('success','failed','uncertain') then raise exception 'Invalid outcome'; end if;
  select * into receipt from piko_ai.request_usage where request_id=p_request and identity_id=p_identity;
  if not found then return; end if;
  month_start := date_trunc('month',receipt.admitted_at at time zone 'UTC')::date;
  perform 1 from piko_ai.month_budget where month=month_start for update;
  select * into receipt from piko_ai.request_usage where request_id=p_request and identity_id=p_identity for update;
  if receipt.outcome <> 'reserved' then return; end if;
  if p_actual is not null and (p_actual < 0 or p_actual > receipt.reserved_micro_usd)
    then raise exception 'Invalid actual charge'; end if;
  -- Only a verified provider usage result permits release of unused reservation.
  -- Unknown/paid failures keep the entire worst-case amount.
  if p_actual is not null then
    update piko_ai.month_budget set reserved_micro_usd=reserved_micro_usd-(receipt.reserved_micro_usd-p_actual)
      where month=month_start;
  end if;
  update piko_ai.request_usage set outcome=p_outcome,charged_micro_usd=p_actual where request_id=p_request;
  update piko_ai.identity_usage set active_request=null,active_until=null
    where identity_id=p_identity and active_request=p_request;
end $$;

-- Called by a separately authenticated daily maintenance job. Mark before the
-- Auth Admin deletion so a concurrent request cannot reactivate a claimed user.
create function public.piko_ai_cleanup_candidates()
returns table(identity_id uuid) language plpgsql security invoker set search_path = '' as $$
begin
  delete from piko_ai.request_usage where admitted_at < clock_timestamp()-interval '35 days';
  update piko_ai.identity_usage set daily_count=0,recent_starts='{}',active_request=null,active_until=null
    where last_seen < clock_timestamp()-interval '35 days';
  insert into piko_ai.identity_usage(identity_id,usage_day,last_seen,deleting)
    select id,(clock_timestamp() at time zone 'UTC')::date,
      greatest(created_at,coalesce(last_sign_in_at,created_at)),true
      from auth.users u where u.is_anonymous=true and
      greatest(u.created_at,coalesce(u.last_sign_in_at,u.created_at)) < clock_timestamp()-interval '90 days'
      and not exists(select 1 from piko_ai.identity_usage i where i.identity_id=u.id)
    order by u.created_at,u.id limit 100
    on conflict do nothing;
  return query with candidates as (
    select i.identity_id from piko_ai.identity_usage i
      where i.last_seen < clock_timestamp()-interval '90 days'
        and (i.active_until is null or i.active_until < clock_timestamp())
      order by i.last_seen,i.identity_id limit 100 for update skip locked
  ) update piko_ai.identity_usage i set deleting=true
      where i.identity_id in (select c.identity_id from candidates c)
      returning i.identity_id;
end $$;

revoke all on function public.piko_ai_admit(uuid,uuid,bigint) from public,anon,authenticated;
revoke all on function public.piko_ai_finish(uuid,uuid,text,bigint) from public,anon,authenticated;
revoke all on function public.piko_ai_cleanup_candidates() from public,anon,authenticated;
grant execute on function public.piko_ai_admit(uuid,uuid,bigint) to service_role;
grant execute on function public.piko_ai_finish(uuid,uuid,text,bigint) to service_role;
grant execute on function public.piko_ai_cleanup_candidates() to service_role;

-- Deliberately no enabled budget row. Each UTC month requires a reviewed cap.
