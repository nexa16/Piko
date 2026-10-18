-- Operator-only metadata. No vocabulary, examples, prompts or answers are stored.
create schema if not exists piko_ai_private;
revoke all on schema piko_ai_private from public, anon, authenticated;
grant usage on schema piko_ai_private to service_role;

create table piko_ai_private.config (
  id integer primary key check(id=1),
  enabled boolean not null default false,
  active_month date not null,
  allowance_cents integer not null default 0 check(allowance_cents>=0),
  reserved_and_spent_cents integer not null default 0 check(reserved_and_spent_cents>=0),
  request_reserve_cents integer not null default 0 check(request_reserve_cents>=0),
  -- Operator-reviewed worst-case prices and conversion; never client input.
  input_nano_usd bigint not null default 0 check(input_nano_usd>=0),
  output_nano_usd bigint not null default 0 check(output_nano_usd>=0),
  eur_per_usd numeric not null default 0 check(eur_per_usd>=0),
  max_input_bytes integer not null default 192000 check(max_input_bytes between 1 and 192000),
  max_output_tokens integer not null default 32000 check(max_output_tokens between 1 and 128000),
  max_inflight integer not null default 1 check(max_inflight between 1 and 2)
);
insert into piko_ai_private.config(id,active_month)
values(1,date_trunc('month',now() at time zone 'utc')::date);

create table piko_ai_private.owner_access (
  user_id uuid primary key,
  enabled boolean not null default false,
  expires_at timestamptz not null,
  last_seen_at timestamptz not null default now()
);
create table piko_ai_private.receipts (
  request_id uuid primary key,
  user_id uuid not null references piko_ai_private.owner_access(user_id),
  issued_at timestamptz not null,
  created_at timestamptz not null default now(),
  deadline timestamptz not null,
  request_hash text not null check(request_hash ~ '^[a-f0-9]{64}$'),
  action text not null check(action in('generate','gaps','hints','review')),
  card_ceiling integer not null default 200 check(card_ceiling between 1 and 1000),
  status text not null check(status in('admitted','started','settled','uncertain')),
  response_id text,
  reserve_cents integer not null check(reserve_cents>0),
  input_nano_usd bigint not null check(input_nano_usd>0),
  output_nano_usd bigint not null check(output_nano_usd>0),
  eur_per_usd numeric not null check(eur_per_usd>0),
  max_output_tokens integer not null check(max_output_tokens>0),
  actual_cents integer check(actual_cents>=0),
  input_tokens integer check(input_tokens>=0),
  output_tokens integer check(output_tokens>=0)
);
create index receipts_owner_time on piko_ai_private.receipts(user_id,created_at);
create index receipts_active on piko_ai_private.receipts(deadline) where status in('admitted','started','uncertain');
create index receipts_retention on piko_ai_private.receipts(created_at);
alter table piko_ai_private.config enable row level security;
alter table piko_ai_private.owner_access enable row level security;
alter table piko_ai_private.receipts enable row level security;
revoke all on all tables in schema piko_ai_private from public,anon,authenticated;
grant select,insert,update,delete on all tables in schema piko_ai_private to service_role;

-- SECURITY INVOKER and explicit qualification: only the server service role can
-- call these RPCs, while app JWTs have no execute or private-table privileges.
create function public.piko_ai_admit(p_user_id uuid,p_request_id uuid,p_issued_at timestamptz,
  p_hash text,p_action text,p_input_bytes integer,p_scope text default 'ordinary',p_prior_cards integer default 0)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare c piko_ai_private.config%rowtype; r piko_ai_private.receipts%rowtype;
  t timestamptz:=clock_timestamp(); minimum_reserve integer;
begin
  if p_user_id is null or p_request_id is null or p_issued_at is null or p_hash is null or p_action is null or p_input_bytes is null or p_scope is null or p_prior_cards is null then raise exception 'invalid_request'; end if;
  if p_scope not in('ordinary','comprehensiveLevel') or (p_scope='comprehensiveLevel' and p_action<>'generate') then raise exception 'invalid_request'; end if;
  if p_prior_cards<0 or p_prior_cards>=(case when p_scope='comprehensiveLevel' then 1000 else 200 end) or (p_prior_cards>0 and p_action not in('generate','gaps')) then raise exception 'invalid_request'; end if;
  select * into c from piko_ai_private.config where id=1 for update;
  if not found or not c.enabled or c.active_month<>date_trunc('month',t at time zone 'utc')::date then
    raise exception 'unavailable';
  end if;
  if not exists(select 1 from piko_ai_private.owner_access where user_id=p_user_id and enabled and expires_at>t) then
    raise exception 'access_denied';
  end if;
  if p_issued_at<t-interval '10 minutes' or p_issued_at>t+interval '30 seconds' then raise exception 'expired'; end if;
  if p_input_bytes<1 or p_input_bytes>c.max_input_bytes or p_hash !~ '^[a-f0-9]{64}$'
    or p_action not in('generate','gaps','hints','review') then raise exception 'invalid_request'; end if;
  -- UTF8 bytes conservatively bound input tokens; the server adds its actual
  -- instruction/schema bytes before calling this function. Extra framing margin.
  minimum_reserve:=ceil((((p_input_bytes+8192)::numeric*c.input_nano_usd)+
    c.max_output_tokens::numeric*c.output_nano_usd)*c.eur_per_usd/10000000)::integer;
  if c.input_nano_usd<=0 or c.output_nano_usd<=0 or c.eur_per_usd<=0 or c.request_reserve_cents<minimum_reserve
    or c.request_reserve_cents<=0 then raise exception 'unavailable'; end if;
  select * into r from piko_ai_private.receipts where request_id=p_request_id;
  if found then
    if r.user_id<>p_user_id or r.request_hash<>p_hash then raise exception 'replay'; end if;
    return jsonb_build_object('new',false,'status',r.status,'responseId',r.response_id,'cardCeiling',r.card_ceiling);
  end if;
  if c.reserved_and_spent_cents+c.request_reserve_cents>c.allowance_cents then raise exception 'limit'; end if;
  if (select count(*) from piko_ai_private.receipts where user_id=p_user_id and created_at>=date_trunc('day',t at time zone 'utc') at time zone 'utc')>=100
    or (select count(*) from piko_ai_private.receipts where user_id=p_user_id and created_at>t-interval '1 minute')>=2
    or exists(select 1 from piko_ai_private.receipts where user_id=p_user_id and status<>'settled' and deadline>t)
    or (select count(*) from piko_ai_private.receipts where status<>'settled' and deadline>t)>=c.max_inflight then raise exception 'limit'; end if;
  insert into piko_ai_private.receipts(request_id,user_id,issued_at,deadline,request_hash,action,status,reserve_cents,card_ceiling,
    input_nano_usd,output_nano_usd,eur_per_usd,max_output_tokens)
    values(p_request_id,p_user_id,p_issued_at,t+interval '10 minutes',p_hash,p_action,'admitted',c.request_reserve_cents,case when p_scope='comprehensiveLevel' then 1000 else 200 end-p_prior_cards,
      c.input_nano_usd,c.output_nano_usd,c.eur_per_usd,c.max_output_tokens);
  update piko_ai_private.config set reserved_and_spent_cents=reserved_and_spent_cents+request_reserve_cents where id=1;
  update piko_ai_private.owner_access set last_seen_at=t where user_id=p_user_id;
  return jsonb_build_object('new',true,'maxOutputTokens',c.max_output_tokens,'cardCeiling',case when p_scope='comprehensiveLevel' then 1000 else 200 end-p_prior_cards);
end $$;

create function public.piko_ai_attach(p_user_id uuid,p_request_id uuid,p_response_id text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_response_id is null or p_response_id !~ '^resp_[a-zA-Z0-9_-]+$' then raise exception 'invalid_response'; end if;
  update piko_ai_private.receipts set response_id=p_response_id,status='started'
    where request_id=p_request_id and user_id=p_user_id and status='admitted' and response_id is null;
  if not found then raise exception 'replay'; end if;
end $$;

create function public.piko_ai_status(p_user_id uuid,p_request_id uuid,p_hash text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r piko_ai_private.receipts%rowtype;t timestamptz:=clock_timestamp();
begin
  if not exists(select 1 from piko_ai_private.owner_access where user_id=p_user_id and enabled and expires_at>t) then raise exception 'access_denied'; end if;
  select * into r from piko_ai_private.receipts where request_id=p_request_id and user_id=p_user_id and request_hash=p_hash;
  if not found or r.deadline<t then raise exception 'expired'; end if;
  return jsonb_build_object('status',r.status,'responseId',r.response_id,'action',r.action,'cardCeiling',r.card_ceiling);
end $$;

create function public.piko_ai_settle(p_user_id uuid,p_request_id uuid,p_input_tokens integer,p_output_tokens integer)
returns void language plpgsql security invoker set search_path='' as $$
declare c piko_ai_private.config%rowtype;r piko_ai_private.receipts%rowtype; actual integer;
begin
  select * into c from piko_ai_private.config where id=1 for update;
  select * into r from piko_ai_private.receipts where request_id=p_request_id and user_id=p_user_id for update;
  if not found then raise exception 'expired'; end if;
  if r.status='settled' then return; end if;
  if p_input_tokens is null or p_output_tokens is null or p_input_tokens<0 or p_output_tokens<0 or p_output_tokens>r.max_output_tokens then raise exception 'invalid_usage'; end if;
  actual:=ceil((p_input_tokens::numeric*r.input_nano_usd+p_output_tokens::numeric*r.output_nano_usd)*r.eur_per_usd/10000000)::integer;
  if actual>r.reserve_cents then
    update piko_ai_private.config set enabled=false where id=1;
    update piko_ai_private.receipts set status='uncertain' where request_id=p_request_id;
    return;
  end if;
  -- Only settle against the same month's balance; no late refund to a new month.
  if c.active_month=date_trunc('month',r.created_at at time zone 'utc')::date then
    update piko_ai_private.config set reserved_and_spent_cents=reserved_and_spent_cents-r.reserve_cents+actual where id=1;
  end if;
  update piko_ai_private.receipts set status='settled',actual_cents=actual,
    input_tokens=p_input_tokens,output_tokens=p_output_tokens where request_id=p_request_id;
end $$;

create function public.piko_ai_cleanup() returns void language plpgsql security invoker set search_path='' as $$
begin
  delete from piko_ai_private.receipts where created_at<clock_timestamp()-interval '35 days';
  delete from piko_ai_private.owner_access a where a.last_seen_at<clock_timestamp()-interval '90 days'
    and not exists(select 1 from piko_ai_private.receipts r where r.user_id=a.user_id);
end $$;
revoke all on function public.piko_ai_admit(uuid,uuid,timestamptz,text,text,integer,text,integer) from public,anon,authenticated;
revoke all on function public.piko_ai_attach(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.piko_ai_status(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.piko_ai_settle(uuid,uuid,integer,integer) from public,anon,authenticated;
revoke all on function public.piko_ai_cleanup() from public,anon,authenticated;
grant execute on function public.piko_ai_admit(uuid,uuid,timestamptz,text,text,integer,text,integer) to service_role;
grant execute on function public.piko_ai_attach(uuid,uuid,text) to service_role;
grant execute on function public.piko_ai_status(uuid,uuid,text) to service_role;
grant execute on function public.piko_ai_settle(uuid,uuid,integer,integer) to service_role;
grant execute on function public.piko_ai_cleanup() to service_role;

-- Dedicated Piko project only. Run as the database owner after metadata cleanup;
-- app/server JWT roles cannot execute Auth identity deletion. No definer bypass.
create function piko_ai_private.purge_inactive_anonymous_identities()
returns integer language plpgsql security invoker set search_path='' as $$
declare doomed uuid[]; removed integer;
begin
  select array_agg(u.id) into doomed from auth.users u
    where u.is_anonymous is true
      and coalesce(u.last_sign_in_at,u.created_at)<clock_timestamp()-interval '90 days'
      and not exists(select 1 from piko_ai_private.owner_access a where a.user_id=u.id and a.last_seen_at>=clock_timestamp()-interval '90 days')
      and not exists(select 1 from piko_ai_private.receipts r where r.user_id=u.id);
  if doomed is null then return 0; end if;
  delete from piko_ai_private.owner_access where user_id=any(doomed);
  delete from auth.sessions where user_id=any(doomed);
  delete from auth.users where id=any(doomed);
  get diagnostics removed=row_count;
  return removed;
end $$;
revoke all on function piko_ai_private.purge_inactive_anonymous_identities() from public,anon,authenticated,service_role;
