-- Private pilot is fail-closed until separately approved deployment/activation.
-- Raw content is isolated from accounting and NEVER exposed to app JWT roles.
alter table piko_ai_private.config
  add column pilot_started_at timestamptz,
  add column pilot_ends_at timestamptz,
  add column non_ai_usage_cents integer not null default 0 check(non_ai_usage_cents between 0 and 2000),
  add column new_cash_outlay_cents integer not null default 0 check(new_cash_outlay_cents between 0 and 2000),
  add column prepaid_available_cents integer not null default 0 check(prepaid_available_cents>=0),
  add column deployment_verified boolean not null default false,
  add column backup_max_days integer not null default 7 check(backup_max_days between 0 and 7),
  add column last_cleanup_at timestamptz,
  add column notice_version text not null default '',
  add column contact text not null default '',
  add column processor_details text not null default '',
  add constraint fixed_pilot_interval check(pilot_ends_at is null or (pilot_started_at is not null and pilot_ends_at=pilot_started_at+interval '14 days')),
  add constraint pilot_usage_ceiling check(allowance_cents+non_ai_usage_cents<=2000);
-- An old locally prepared monthly/owner-only configuration cannot activate r2.
update piko_ai_private.config set enabled=false;
alter table piko_ai_private.owner_access
  add column pilot_slot integer unique check(pilot_slot between 0 and 5),
  add column consent_version text,
  add column consent_at timestamptz,
  add column withdrawn_at timestamptz;
-- Slots are never recycled within a pilot; rebind an existing participant only
-- through explicit operator recovery, preserving that participant's accounting.
create table piko_ai_private.payloads (
 request_id uuid primary key references piko_ai_private.receipts(request_id) on delete cascade,
 user_id uuid not null references piko_ai_private.owner_access(user_id),
 captured_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null default clock_timestamp()+interval '22 days',
 sent jsonb not null,
 result jsonb,
 result_recorded boolean not null default false,
 outcome text,
 adoption jsonb,
 feedback text check(length(feedback)<=4000),
 check(expires_at<=captured_at+interval '22 days')
);
create index payloads_user on piko_ai_private.payloads(user_id);
create index payloads_expiry on piko_ai_private.payloads(expires_at);
create table piko_ai_private.regressions (
 id uuid primary key,
 created_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null,
 reviewed_deidentified boolean not null check(reviewed_deidentified),
 synthetic_or_aggregate jsonb not null,
 check(expires_at<=created_at+interval '82 days')
);
alter table piko_ai_private.payloads enable row level security;
alter table piko_ai_private.regressions enable row level security;
revoke all on piko_ai_private.payloads,piko_ai_private.regressions from public,anon,authenticated;
grant select,insert,update,delete on piko_ai_private.payloads to service_role;
-- Regression creation/review remains database-owner/explicit analysis tooling.
revoke all on piko_ai_private.regressions from service_role;

create function piko_ai_private.pilot_ready(t timestamptz) returns boolean
language sql stable security invoker set search_path='' as $$
 select coalesce((select enabled and deployment_verified and pilot_started_at<=t and pilot_ends_at>t
   and last_cleanup_at>t-interval '24 hours' and length(notice_version)>0
   and length(contact)>0 and length(processor_details)>0
   and allowance_cents+non_ai_usage_cents<=2000 and new_cash_outlay_cents<=2000
   and allowance_cents<=prepaid_available_cents
 from piko_ai_private.config where id=1),false)
$$;
revoke all on function piko_ai_private.pilot_ready(timestamptz) from public,anon,authenticated;
grant execute on function piko_ai_private.pilot_ready(timestamptz) to service_role;

-- The operator provisions only the six nonreusable slots. Neither the client nor
-- these RPCs can grant itself access or create/rotate an invitation.
create function public.piko_ai_pilot(p_user_id uuid,p_operation text,p_version text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare c piko_ai_private.config%rowtype; a piko_ai_private.owner_access%rowtype; t timestamptz:=clock_timestamp();
begin
 select * into c from piko_ai_private.config where id=1 for update;
 select * into a from piko_ai_private.owner_access where user_id=p_user_id;
 if not found or a.pilot_slot is null then raise exception 'access_denied'; end if;
 if p_operation='withdraw' then
   update piko_ai_private.owner_access set enabled=false,withdrawn_at=t,consent_version=null where user_id=p_user_id;
   delete from piko_ai_private.payloads where user_id=p_user_id;
   return jsonb_build_object('withdrawn',true,'livePayloadsDeleted',true,'backupExpiryDays',c.backup_max_days);
 end if;
 if not a.enabled or a.expires_at<=t or a.withdrawn_at is not null or not piko_ai_private.pilot_ready(t) then raise exception 'access_denied'; end if;
 if p_operation='consent' then
   if p_version is null or p_version<>c.notice_version then raise exception 'invalid_request'; end if;
   update piko_ai_private.owner_access set consent_version=p_version,consent_at=t where user_id=p_user_id;
 elsif p_operation<>'notice' then raise exception 'invalid_request'; end if;
 return jsonb_build_object('version',c.notice_version,'contact',c.contact,'processors',c.processor_details,
   'endsAt',c.pilot_ends_at,'consented',case when p_operation='consent' then true else a.consent_version=c.notice_version end);
end $$;

create or replace function public.piko_ai_admit(p_user_id uuid,p_request_id uuid,p_issued_at timestamptz,
  p_hash text,p_action text,p_input_bytes integer,p_scope text default 'ordinary',p_prior_cards integer default 0)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare c piko_ai_private.config%rowtype; r piko_ai_private.receipts%rowtype;
  t timestamptz:=clock_timestamp(); minimum_reserve integer;
begin
  if p_user_id is null or p_request_id is null or p_issued_at is null or p_hash is null or p_action is null or p_input_bytes is null or p_scope is null or p_prior_cards is null then raise exception 'invalid_request'; end if;
  if p_scope not in('ordinary','comprehensiveLevel') or (p_scope='comprehensiveLevel' and p_action<>'generate') then raise exception 'invalid_request'; end if;
  if p_prior_cards<0 or p_prior_cards>=(case when p_scope='comprehensiveLevel' then 1000 else 200 end) or (p_prior_cards>0 and p_action not in('generate','gaps')) then raise exception 'invalid_request'; end if;
  select * into c from piko_ai_private.config where id=1 for update;
  if not found or not c.enabled or not piko_ai_private.pilot_ready(t) then
    raise exception 'unavailable';
  end if;
  if not exists(select 1 from piko_ai_private.owner_access where user_id=p_user_id and enabled and expires_at>t and pilot_slot is not null and consent_version=c.notice_version and withdrawn_at is null) then
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
  if c.reserved_and_spent_cents+c.request_reserve_cents>least(c.allowance_cents,2000-c.non_ai_usage_cents) then raise exception 'limit'; end if;
  if (select count(*) from piko_ai_private.receipts where user_id=p_user_id and created_at>=date_trunc('day',t at time zone 'utc') at time zone 'utc')>=20
    or (select count(*) from piko_ai_private.receipts where user_id=p_user_id and created_at>t-interval '1 minute')>=2
    or exists(select 1 from piko_ai_private.receipts where user_id=p_user_id and status<>'settled')
    or (select count(*) from piko_ai_private.receipts where status<>'settled')>=c.max_inflight then raise exception 'limit'; end if;
  insert into piko_ai_private.receipts(request_id,user_id,issued_at,deadline,request_hash,action,status,reserve_cents,card_ceiling,
    input_nano_usd,output_nano_usd,eur_per_usd,max_output_tokens)
    values(p_request_id,p_user_id,p_issued_at,t+interval '10 minutes',p_hash,p_action,'admitted',c.request_reserve_cents,case when p_scope='comprehensiveLevel' then 1000 else 200 end-p_prior_cards,
      c.input_nano_usd,c.output_nano_usd,c.eur_per_usd,c.max_output_tokens);
  update piko_ai_private.config set reserved_and_spent_cents=reserved_and_spent_cents+request_reserve_cents where id=1;
  update piko_ai_private.owner_access set last_seen_at=t where user_id=p_user_id;
  return jsonb_build_object('new',true,'maxOutputTokens',c.max_output_tokens,'cardCeiling',case when p_scope='comprehensiveLevel' then 1000 else 200 end-p_prior_cards);
end $$;

create or replace function public.piko_ai_settle(p_user_id uuid,p_request_id uuid,p_input_tokens integer,p_output_tokens integer)
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
  -- The single pilot interval spans calendar months. No monthly reset/refund.
  if r.created_at>=c.pilot_started_at and r.created_at<c.pilot_ends_at then
    update piko_ai_private.config set reserved_and_spent_cents=reserved_and_spent_cents-r.reserve_cents+actual where id=1;
  end if;
  update piko_ai_private.receipts set status='settled',actual_cents=actual,
    input_tokens=p_input_tokens,output_tokens=p_output_tokens where request_id=p_request_id;
end $$;


create or replace function public.piko_ai_status(p_user_id uuid,p_request_id uuid,p_hash text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r piko_ai_private.receipts%rowtype; c piko_ai_private.config%rowtype; t timestamptz:=clock_timestamp();
begin
 select * into c from piko_ai_private.config where id=1;
 if not piko_ai_private.pilot_ready(t) or not exists(select 1 from piko_ai_private.owner_access
   where user_id=p_user_id and enabled and expires_at>t and pilot_slot is not null and withdrawn_at is null and consent_version=c.notice_version)
   then raise exception 'access_denied'; end if;
 select * into r from piko_ai_private.receipts where request_id=p_request_id and user_id=p_user_id and request_hash=p_hash;
 if not found or r.deadline<t then raise exception 'expired'; end if;
 return jsonb_build_object('status',r.status,'responseId',r.response_id,'action',r.action,'cardCeiling',r.card_ceiling);
end $$;

-- Serialized with consent withdrawal. Content never enters accounting receipts.
create function public.piko_ai_capture(p_user_id uuid,p_request_id uuid,p_stage text,p_payload jsonb)
returns void language plpgsql security invoker set search_path='' as $$
declare c piko_ai_private.config%rowtype; r piko_ai_private.receipts%rowtype; t timestamptz:=clock_timestamp();
begin
 select * into c from piko_ai_private.config where id=1 for update;
 if not piko_ai_private.pilot_ready(t) or not exists(select 1 from piko_ai_private.owner_access where user_id=p_user_id and enabled and pilot_slot is not null
   and withdrawn_at is null and consent_version=c.notice_version and expires_at>t) then raise exception 'access_denied'; end if;
 select * into r from piko_ai_private.receipts where request_id=p_request_id and user_id=p_user_id;
 if not found then raise exception 'access_denied'; end if;
 if p_payload is null or octet_length(p_payload::text)>2500000 then raise exception 'invalid_request'; end if;
 if p_stage='sent' then
   if not piko_ai_private.pilot_ready(t) or r.status<>'admitted' then raise exception 'access_denied'; end if;
   insert into piko_ai_private.payloads(request_id,user_id,sent) values(p_request_id,p_user_id,p_payload);
 elsif p_stage='result' then
   -- No rewrite/expiry extension on repeated polling; retain actual provider output.
   update piko_ai_private.payloads set result=p_payload,result_recorded=true,outcome='received'
    where request_id=p_request_id and user_id=p_user_id and not result_recorded and expires_at>t;
 elsif p_stage='error' then
   update piko_ai_private.payloads set outcome=p_payload->>'code'
    where request_id=p_request_id and user_id=p_user_id and expires_at>t and outcome is null;
 elsif p_stage='adoption' then
   update piko_ai_private.payloads set adoption=p_payload
    where request_id=p_request_id and user_id=p_user_id and expires_at>t and adoption is null;
 elsif p_stage='feedback' then
   if jsonb_typeof(p_payload->'text')<>'string' or length(p_payload->>'text')>4000 then raise exception 'invalid_request'; end if;
   update piko_ai_private.payloads set feedback=p_payload->>'text'
    where request_id=p_request_id and user_id=p_user_id and expires_at>t;
 else raise exception 'invalid_request'; end if;
end $$;

create or replace function public.piko_ai_cleanup() returns void language plpgsql security invoker set search_path='' as $$
begin
 -- 22 days live + at most 1 day scheduler delay + <=7 days backups = <=30.
 delete from piko_ai_private.payloads where expires_at<=clock_timestamp();
 delete from piko_ai_private.payloads p where exists(select 1 from piko_ai_private.owner_access a where a.user_id=p.user_id and (not a.enabled or a.withdrawn_at is not null));
 delete from piko_ai_private.regressions where expires_at<=clock_timestamp()
   or created_at>(select pilot_ends_at from piko_ai_private.config where id=1)
   or (select pilot_ends_at+interval '82 days' from piko_ai_private.config where id=1)<=clock_timestamp();
 delete from piko_ai_private.receipts where created_at<clock_timestamp()-interval '35 days';
 delete from piko_ai_private.owner_access a where a.last_seen_at<clock_timestamp()-interval '90 days'
   and not exists(select 1 from piko_ai_private.receipts r where r.user_id=a.user_id)
   and (select pilot_ends_at<clock_timestamp() from piko_ai_private.config where id=1);
 update piko_ai_private.config set last_cleanup_at=clock_timestamp() where id=1;
end $$;
-- Cleanup must run as owner because regression rows aren't readable by service_role.
revoke execute on function public.piko_ai_cleanup() from service_role;
revoke all on function public.piko_ai_pilot(uuid,text,text) from public,anon,authenticated;
revoke all on function public.piko_ai_capture(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.piko_ai_pilot(uuid,text,text) to service_role;
grant execute on function public.piko_ai_capture(uuid,uuid,text,jsonb) to service_role;

-- Six participants over the entire interval, not six concurrently recyclable slots.
create function piko_ai_private.preserve_pilot_slot() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if old.pilot_slot is not null and exists(select 1 from piko_ai_private.config where id=1 and pilot_started_at is not null and pilot_ends_at>clock_timestamp()) then
   if tg_op='DELETE' then raise exception 'pilot_slot_retained'; end if;
   if new.user_id<>old.user_id or new.pilot_slot is distinct from old.pilot_slot then raise exception 'pilot_slot_retained'; end if;
 end if;
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
revoke all on function piko_ai_private.preserve_pilot_slot() from public,anon,authenticated;
grant execute on function piko_ai_private.preserve_pilot_slot() to service_role;
create trigger preserve_pilot_slot before update or delete on piko_ai_private.owner_access for each row execute function piko_ai_private.preserve_pilot_slot();
