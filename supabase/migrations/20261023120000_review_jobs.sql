-- Private bounded review jobs. Applying this migration does NOT activate a
-- scheduler, enable dispatch, change pilot dates or increase any allowance.
-- PGMQ_SETUP_BEGIN
create extension if not exists pgmq;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;
select pgmq.create('piko_ai_review');
grant usage on schema pgmq to service_role;
grant select,insert,update,delete on pgmq.q_piko_ai_review to service_role;
grant usage,select on sequence pgmq.q_piko_ai_review_msg_id_seq to service_role;
grant execute on function pgmq.send(text,jsonb,integer),pgmq.read(text,integer,integer),pgmq.delete(text,bigint) to service_role;
-- PGMQ_SETUP_END

alter table piko_ai_private.config add column review_jobs_enabled boolean not null default false;
create table piko_ai_private.review_cancellations(
 job_id uuid primary key,user_id uuid not null,created_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null default clock_timestamp()+interval '35 days'
);
alter table piko_ai_private.review_cancellations enable row level security;
revoke all on piko_ai_private.review_cancellations from public,anon,authenticated;
grant select,insert,update,delete on piko_ai_private.review_cancellations to service_role;
create table piko_ai_private.review_jobs(
 id uuid primary key, user_id uuid not null references piko_ai_private.owner_access(user_id),
 installation_id text not null check(length(installation_id) between 1 and 120),
 collection_id uuid not null, idempotency_key text not null check(length(idempotency_key) between 1 and 120),
 snapshot_digest text not null check(snapshot_digest ~ '^[a-f0-9]{64}$'), snapshot_version text not null,
 scope_ids jsonb not null check(jsonb_typeof(scope_ids)='array'), metadata jsonb not null,
 state text not null default 'preparing' check(state in('preparing','running','paused','unknown','completed','failed','cancelling','cancelled','expired')),
 generation integer not null default 0, created_at timestamptz not null default clock_timestamp(),
 expires_at timestamptz not null, content_expires_at timestamptz not null default clock_timestamp()+interval '22 days',
 max_cost_cents integer not null check(max_cost_cents>0), reserved_and_spent_cents integer not null default 0,
 maximum_cost_cents integer, pricing jsonb, total integer not null check(total between 1 and 10000),
 processed integer not null default 0, phase text not null default 'preparing',
 error jsonb, result jsonb, conflicts jsonb, uploaded_bytes integer not null default 0,
 unique(user_id,idempotency_key), check(expires_at<=created_at+interval '7 days')
);
create table piko_ai_private.review_chunks(
 job_id uuid not null references piko_ai_private.review_jobs(id) on delete cascade,
 chunk_index integer not null check(chunk_index>=0), entries jsonb not null,
 primary key(job_id,chunk_index)
);
create table piko_ai_private.review_steps(
 id uuid primary key,job_id uuid not null references piko_ai_private.review_jobs(id) on delete cascade,
 ordinal integer not null,phase text not null check(phase in('detail','consistency')),
 ids jsonb not null,input jsonb not null,body jsonb not null,input_bytes integer not null,
 reserve_cents integer not null check(reserve_cents>0),
 state text not null default 'queued' check(state in('queued','claimed','dispatched','pending','completed','unknown','failed')),
 token uuid,lease_until timestamptz,response_id text,provider_poll_expires_at timestamptz,result jsonb,
 unique(job_id,ordinal)
);
create index review_jobs_cleanup on piko_ai_private.review_jobs(content_expires_at);
create index review_jobs_owner on piko_ai_private.review_jobs(user_id,state);
create index review_steps_job on piko_ai_private.review_steps(job_id,ordinal);
alter table piko_ai_private.review_jobs enable row level security;
alter table piko_ai_private.review_chunks enable row level security;
alter table piko_ai_private.review_steps enable row level security;
revoke all on piko_ai_private.review_jobs,piko_ai_private.review_chunks,piko_ai_private.review_steps from public,anon,authenticated;
grant select,insert,update,delete on piko_ai_private.review_jobs,piko_ai_private.review_chunks,piko_ai_private.review_steps to service_role;

create function piko_ai_private.review_status(j piko_ai_private.review_jobs) returns jsonb
 language sql immutable security invoker set search_path='' as $$
 select jsonb_build_object('jobId',j.id,'snapshotDigest',j.snapshot_digest,'snapshotVersion',j.snapshot_version,
 'state',j.state,'generation',j.generation,'expiresAt',j.expires_at,'processed',j.processed,'total',j.total,
 'phase',j.phase,'maxCostCents',j.max_cost_cents,'reservedAndSpentCents',j.reserved_and_spent_cents,
 'maximumCostCents',j.maximum_cost_cents,'resultAvailable',j.state='completed' and j.result is not null,
 'error',j.error,'skipped',0,'failed',case when j.state in('failed','unknown') then j.total-j.processed else 0 end)
$$;
create function piko_ai_private.review_access(uid uuid,t timestamptz) returns boolean
 language sql stable security invoker set search_path='' as $$
 select coalesce((select piko_ai_private.pilot_ready(t) and c.review_jobs_enabled and exists(
 select 1 from piko_ai_private.owner_access a where a.user_id=uid and a.enabled and a.expires_at>t
 and a.pilot_slot is not null and a.withdrawn_at is null and a.consent_version=c.notice_version)
 from piko_ai_private.config c where c.id=1),false)
$$;

-- Conservative scheduler capacity: a background step needs dispatch + polling
-- at the one-minute cron cadence, plus a finalization tick. Count actual UTC
-- day boundaries and today's consumed attempts, not rolling 24-hour blocks.
create function piko_ai_private.review_capacity(uid uuid,starts timestamptz,ends timestamptz) returns integer
language plpgsql stable security invoker set search_path='' as $$
declare d timestamptz:=(date_trunc('day',starts at time zone 'utc') at time zone 'utc');
 window_start timestamptz;window_end timestamptz;used integer;slots integer:=0;recent integer;retry timestamptz;
begin
 select count(*)::integer,min(created_at)+interval '1 minute' into recent,retry from piko_ai_private.receipts where user_id=uid and created_at>starts-interval '1 minute';
 if recent>=2 then starts:=greatest(starts,retry); end if;
 while d<ends loop
  window_start:=greatest(starts,d);window_end:=least(ends,d+interval '1 day');
  select count(*)::integer into used from piko_ai_private.receipts where user_id=uid and created_at>=d and created_at<d+interval '1 day';
  slots:=slots+least(greatest(0,20-used),greatest(0,floor((extract(epoch from(window_end-window_start))-60)/120)::integer));
  d:=d+interval '1 day';
 end loop;
 return slots;
end $$;

-- Read-only protocol negotiation happens before the app creates its local
-- lock. No enrollment, receipt, job, reservation or provider dispatch occurs.
create function public.piko_ai_review_capabilities(p_user_id uuid) returns jsonb
language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('reviewJobsAvailable',piko_ai_private.review_access(p_user_id,clock_timestamp()))
$$;
revoke all on function public.piko_ai_review_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.piko_ai_review_capabilities(uuid) to service_role;

create function public.piko_ai_review_job(p_user_id uuid,p_job_id uuid,p_action text,p_data jsonb)
 returns jsonb language plpgsql security invoker set search_path='' as $$
declare j piko_ai_private.review_jobs%rowtype;c piko_ai_private.config%rowtype;
 t timestamptz:=clock_timestamp(); payload jsonb; all_entries jsonb; s jsonb; n integer; cost integer; a timestamptz;
begin
 if p_user_id is null or p_job_id is null or p_data is null then raise exception 'invalid_request'; end if;
 select * into c from piko_ai_private.config where id=1 for update;
 if not exists(select 1 from piko_ai_private.owner_access where user_id=p_user_id) then raise exception 'access_denied'; end if;
 if exists(select 1 from piko_ai_private.review_jobs where id=p_job_id and (user_id<>p_user_id or installation_id is distinct from p_data->>'installationId')) then raise exception 'access_denied'; end if;
 if p_action='cancel' then
  insert into piko_ai_private.review_cancellations(job_id,user_id) values(p_job_id,p_user_id) on conflict do nothing;
 end if;
 if exists(select 1 from piko_ai_private.review_cancellations where job_id=p_job_id and user_id<>p_user_id) then raise exception 'access_denied'; end if;
 if p_action='prepare' then
  if exists(select 1 from piko_ai_private.review_cancellations where job_id=p_job_id) then raise exception 'replay'; end if;
  if not piko_ai_private.review_access(p_user_id,t) then raise exception 'access_denied'; end if;
  select * into j from piko_ai_private.review_jobs where id=p_job_id for update;
  if found then
   if j.user_id<>p_user_id or j.snapshot_digest<>p_data->>'snapshotDigest'
    or j.idempotency_key<>p_data->>'idempotencyKey' or j.max_cost_cents<>(p_data->>'maxCostCents')::integer then raise exception 'replay'; end if;
   return piko_ai_private.review_status(j);
  end if;
  if exists(select 1 from piko_ai_private.review_jobs where user_id=p_user_id and installation_id=p_data->>'installationId'
   and collection_id=(p_data->'metadata'->'collection'->>'id')::uuid and state in('preparing','running','paused','unknown','cancelling') and expires_at>t) then raise exception 'replay'; end if;
  select expires_at into a from piko_ai_private.owner_access where user_id=p_user_id;
  insert into piko_ai_private.review_jobs(id,user_id,installation_id,collection_id,idempotency_key,snapshot_digest,snapshot_version,scope_ids,metadata,expires_at,max_cost_cents,total)
   values(p_job_id,p_user_id,p_data->>'installationId',(p_data->'metadata'->'collection'->>'id')::uuid,p_data->>'idempotencyKey',p_data->>'snapshotDigest',p_data->>'snapshotVersion',p_data->'scopeIds',p_data->'metadata',least(t+interval '7 days',c.pilot_ends_at,a,coalesce((p_data->>'expiresAt')::timestamptz,t+interval '7 days')),(p_data->>'maxCostCents')::integer,jsonb_array_length(p_data->'scopeIds')) returning * into j;
  return piko_ai_private.review_status(j);
 end if;
 select * into j from piko_ai_private.review_jobs where id=p_job_id and user_id=p_user_id for update;
 if not found then
  if p_action in('cancel','status') and exists(select 1 from piko_ai_private.review_cancellations where job_id=p_job_id and user_id=p_user_id) then
   return jsonb_build_object('jobId',p_job_id,'state','cancelled','generation',0,'expiresAt',t,'processed',0,'total',0,'resultAvailable',false);
  end if;
  raise exception 'access_denied';
 end if;
 if j.expires_at<=t and j.state in('preparing','running','paused','unknown','cancelling') then
  update piko_ai_private.review_jobs set state='expired',generation=generation+1,phase='expired' where id=j.id returning * into j;
 end if;
 if p_action='cancel' then
  update piko_ai_private.review_jobs set state=case when state='expired' then state else 'cancelled' end,
   generation=generation+1,phase='cancelled' where id=j.id returning * into j;
  -- Dispatch is forbidden immediately; any already sent provider request may
  -- still settle. Cancellation never refunds an uncertain reservation.
  update piko_ai_private.receipts set deadline=least(deadline,t) where request_id in(select id from piko_ai_private.review_steps where job_id=j.id) and status<>'settled';
  return piko_ai_private.review_status(j);
 end if;
 if p_action='status' then
  if not exists(select 1 from piko_ai_private.owner_access where user_id=p_user_id and enabled and withdrawn_at is null) then raise exception 'access_denied'; end if;
  return piko_ai_private.review_status(j);
 end if;
 if p_action='result' then
  if not exists(select 1 from piko_ai_private.owner_access where user_id=p_user_id and enabled and withdrawn_at is null and expires_at>t and consent_version=c.notice_version) then raise exception 'access_denied'; end if;
  if j.state<>'completed' or j.result is null or j.content_expires_at<=t then raise exception 'expired'; end if;
  return j.result||jsonb_build_object('jobId',j.id,'snapshotDigest',j.snapshot_digest,'conflicts',coalesce(j.conflicts,'[]'::jsonb));
 end if;
 if not piko_ai_private.review_access(p_user_id,t) then raise exception 'access_denied'; end if;
 if j.expires_at<=t then raise exception 'expired'; end if;
 if p_action='upload' then
  if j.state<>'preparing' then raise exception 'replay'; end if;
  select entries into payload from piko_ai_private.review_chunks where job_id=j.id and chunk_index=(p_data->>'index')::integer;
  if found then
   if payload<>p_data->'entries' then raise exception 'replay'; end if;
   return piko_ai_private.review_status(j);
  end if;
  n:=octet_length((p_data->'entries')::text);
  if j.uploaded_bytes+n>20000000 then raise exception 'context_limit'; end if;
  if exists(select 1 from jsonb_array_elements(p_data->'entries') e where not j.scope_ids @> jsonb_build_array(e->>'id')) then raise exception 'invalid_request'; end if;
  insert into piko_ai_private.review_chunks values(j.id,(p_data->>'index')::integer,p_data->'entries');
  update piko_ai_private.review_jobs set uploaded_bytes=uploaded_bytes+n where id=j.id returning * into j;
  return piko_ai_private.review_status(j);
 end if;
 if p_action='manifest' then
  if j.state<>'preparing' then return jsonb_build_object('state',j.state,'status',piko_ai_private.review_status(j)); end if;
  select jsonb_agg(e order by e->>'id') into all_entries from piko_ai_private.review_chunks q cross join lateral jsonb_array_elements(q.entries) e where q.job_id=j.id;
  if jsonb_array_length(coalesce(all_entries,'[]'::jsonb))<>j.total or
   (select count(distinct e->>'id') from jsonb_array_elements(all_entries) e)<>j.total then raise exception 'invalid_request'; end if;
  return jsonb_build_object('state',j.state,'metadata',j.metadata,'entries',all_entries,'snapshotDigest',j.snapshot_digest,'maxCostCents',j.max_cost_cents,
   'config',jsonb_build_object('maxInputBytes',c.max_input_bytes,'maxOutputTokens',c.max_output_tokens,'inputNanoUsd',c.input_nano_usd,'outputNanoUsd',c.output_nano_usd,'eurPerUsd',c.eur_per_usd));
 end if;
 if p_action='start' then
  if j.state<>'preparing' then return piko_ai_private.review_status(j); end if;
  if j.snapshot_digest<>p_data->>'snapshotDigest' then raise exception 'replay'; end if;
  n:=jsonb_array_length(p_data->'steps');cost:=(p_data->>'maximumCostCents')::integer;
  if n<1 or n>256 or cost>j.max_cost_cents then raise exception 'limit'; end if;
  if n>piko_ai_private.review_capacity(j.user_id,t,j.expires_at) then raise exception 'limit'; end if;
  n:=0;
  for s in select value from jsonb_array_elements(p_data->'steps') loop
   insert into piko_ai_private.review_steps(id,job_id,ordinal,phase,ids,input,body,input_bytes,reserve_cents)
    values((s->>'requestId')::uuid,j.id,n,s->>'phase',s->'ids',s->'input',s->'body',(s->>'inputBytes')::integer,(s->>'reserveCents')::integer);
   n:=n+1;
  end loop;
  if (select sum(reserve_cents) from piko_ai_private.review_steps where job_id=j.id)<>cost then raise exception 'invalid_request'; end if;
  if p_data->'pricing'<>jsonb_build_object('maxInputBytes',c.max_input_bytes,'maxOutputTokens',c.max_output_tokens,'inputNanoUsd',c.input_nano_usd,'outputNanoUsd',c.output_nano_usd,'eurPerUsd',c.eur_per_usd) then raise exception 'replay'; end if;
  update piko_ai_private.review_jobs set state='running',phase='detail',maximum_cost_cents=cost,pricing=p_data->'pricing',generation=generation+1 where id=j.id returning * into j;
  perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),0);
  return piko_ai_private.review_status(j);
 end if;
 if p_action='resume' then
  if j.state='unknown' then raise exception 'replay'; end if;
  if j.state='paused' then
   if j.error->>'retryAt' is not null and (j.error->>'retryAt')::timestamptz>t then return piko_ai_private.review_status(j); end if;
   update piko_ai_private.review_jobs set state='running',error=null,generation=generation+1 where id=j.id returning * into j;
   perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),0);
  end if;
  return piko_ai_private.review_status(j);
 end if;
 raise exception 'invalid_request';
end $$;

-- Ordinary request recovery also serves its already captured provider response
-- from Piko storage. No new provider GET is needed after its short polling TTL.
create or replace function public.piko_ai_status(p_user_id uuid,p_request_id uuid,p_hash text)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r piko_ai_private.receipts%rowtype;c piko_ai_private.config%rowtype;t timestamptz:=clock_timestamp();cached jsonb;
begin
 select * into c from piko_ai_private.config where id=1;
 if not piko_ai_private.pilot_ready(t) or not exists(select 1 from piko_ai_private.owner_access
  where user_id=p_user_id and enabled and expires_at>t and pilot_slot is not null and withdrawn_at is null and consent_version=c.notice_version) then raise exception 'access_denied'; end if;
 select * into r from piko_ai_private.receipts where request_id=p_request_id and user_id=p_user_id and request_hash=p_hash;
 if not found then raise exception 'expired'; end if;
 if exists(select 1 from piko_ai_private.review_steps where id=p_request_id) then raise exception 'invalid_request'; end if;
 select result into cached from piko_ai_private.payloads where request_id=r.request_id and user_id=p_user_id and result_recorded and expires_at>t;
 if cached is null and r.deadline<t then raise exception 'expired'; end if;
 return jsonb_build_object('status',r.status,'responseId',r.response_id,'action',r.action,'cardCeiling',r.card_ceiling,'cachedResponse',cached);
end $$;

create function public.piko_ai_review_claim() returns jsonb
 language plpgsql security invoker set search_path='' as $$
declare q record;j piko_ai_private.review_jobs%rowtype;s piko_ai_private.review_steps%rowtype;
 c piko_ai_private.config%rowtype;t timestamptz:=clock_timestamp(); claim_token uuid:=gen_random_uuid();retry timestamptz;kind text;
begin
 select * into c from piko_ai_private.config where id=1 for update;
 if not c.review_jobs_enabled then return null; end if;
 for q in select * from pgmq.read('piko_ai_review',90,1) loop
  perform pgmq.delete('piko_ai_review',q.msg_id);
  select * into j from piko_ai_private.review_jobs where id=(q.message->>'jobId')::uuid for update;
  if not found or j.state<>'running' then continue; end if;
  if j.expires_at<=t or not piko_ai_private.review_access(j.user_id,t) then
   update piko_ai_private.review_jobs set state='expired',phase='expired',generation=generation+1 where id=j.id;
   continue;
  end if;
  select * into s from piko_ai_private.review_steps where job_id=j.id and state<>'completed' order by ordinal limit 1 for update;
  if not found then
   perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),91);
   return jsonb_build_object('jobId',j.id,'finalize',true,'token',claim_token,'steps',(
    select jsonb_agg(jsonb_build_object('requestId',x.id,'ids',x.ids,'input',x.input,'phase',x.phase,'result',x.result) order by x.ordinal)
    from piko_ai_private.review_steps x where x.job_id=j.id));
  end if;
  if s.state='dispatched' and s.lease_until<=t then
   update piko_ai_private.review_steps set state='unknown' where id=s.id;
   update piko_ai_private.receipts set status='uncertain',deadline=t where request_id=s.id and status<>'settled';
   update piko_ai_private.review_jobs set state='unknown',error='{"code":"provider_outcome_unknown"}',generation=generation+1 where id=j.id;
   continue;
  end if;
  if s.state in('unknown','failed') then continue; end if;
  if s.response_id is not null and s.provider_poll_expires_at<=t then
   update piko_ai_private.review_steps set state='failed',lease_until=t where id=s.id;
   update piko_ai_private.receipts set deadline=t where request_id=s.id and status<>'settled';
   update piko_ai_private.review_jobs set state='failed',error='{"code":"provider_result_expired"}',generation=generation+1 where id=j.id;
   continue;
  end if;
  if s.lease_until>t then
   perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),15);continue;
  end if;
  if s.state in('queued','claimed') and s.response_id is null and not exists(select 1 from piko_ai_private.receipts where request_id=s.id) then
   kind:=null;retry:=null;
   if j.reserved_and_spent_cents+s.reserve_cents>j.max_cost_cents then kind:='jobBudget';
   elsif c.reserved_and_spent_cents+s.reserve_cents>least(c.allowance_cents,2000-c.non_ai_usage_cents) then kind:='sharedBudget';
   elsif (select count(*) from piko_ai_private.receipts where user_id=j.user_id and created_at>=date_trunc('day',t at time zone 'utc') at time zone 'utc')>=20 then
    kind:='day';retry:=(date_trunc('day',t at time zone 'utc')+interval '1 day') at time zone 'utc';
   elsif (select count(*) from piko_ai_private.receipts where user_id=j.user_id and created_at>t-interval '1 minute')>=2 then
    kind:='rate';select min(created_at)+interval '1 minute' into retry from piko_ai_private.receipts where user_id=j.user_id and created_at>t-interval '1 minute';
   elsif exists(select 1 from piko_ai_private.receipts where user_id=j.user_id and status<>'settled' and deadline>t and request_id<>s.id) or
    (select count(*) from piko_ai_private.receipts where status<>'settled' and deadline>t and request_id<>s.id)>=c.max_inflight then kind:='parallel';retry:=t+interval '1 minute';
   end if;
   if kind='rate' or kind='parallel' then
    perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),greatest(1,ceil(extract(epoch from(retry-t)))::integer));continue;
   elsif kind is not null then
    update piko_ai_private.review_jobs set state='paused',error=jsonb_build_object('code','limit','limitType',kind,'retryAt',retry,
     'limitMaximum',case when kind='jobBudget' then j.max_cost_cents when kind='sharedBudget' then least(c.allowance_cents,2000-c.non_ai_usage_cents) when kind='day' then 20 end,
     'limitRemaining',case when kind='jobBudget' then greatest(0,j.max_cost_cents-j.reserved_and_spent_cents) when kind='sharedBudget' then greatest(0,least(c.allowance_cents,2000-c.non_ai_usage_cents)-c.reserved_and_spent_cents) when kind='day' then 0 end,
     'limitUnit',case when kind in('jobBudget','sharedBudget') then 'cents' when kind='day' then 'requests' end),generation=generation+1 where id=j.id;continue;
   end if;
   -- Claim may be safely retried before dispatch; the same receipt/reserve is
   -- reused. Once dispatch is marked there is never another paid POST.
   if not exists(select 1 from piko_ai_private.receipts where request_id=s.id) then
    insert into piko_ai_private.receipts(request_id,user_id,issued_at,deadline,request_hash,action,status,reserve_cents,input_nano_usd,output_nano_usd,eur_per_usd,max_output_tokens)
     values(s.id,j.user_id,t,t+interval '90 seconds',j.snapshot_digest,'review','admitted',s.reserve_cents,(j.pricing->>'inputNanoUsd')::bigint,(j.pricing->>'outputNanoUsd')::bigint,(j.pricing->>'eurPerUsd')::numeric,(j.pricing->>'maxOutputTokens')::integer);
    update piko_ai_private.config set reserved_and_spent_cents=reserved_and_spent_cents+s.reserve_cents where id=1;
    update piko_ai_private.review_jobs set reserved_and_spent_cents=reserved_and_spent_cents+s.reserve_cents where id=j.id;
   end if;
  end if;
  update piko_ai_private.review_steps set state=case when response_id is null then 'claimed' else 'pending' end,token=claim_token,lease_until=t+interval '90 seconds' where id=s.id;
  update piko_ai_private.receipts set deadline=t+interval '90 seconds' where request_id=s.id and status<>'settled';
  update piko_ai_private.review_jobs set phase=s.phase where id=j.id;
  -- Recovery wake-up if the edge process disappears at any boundary.
  perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),91);
  return jsonb_build_object('jobId',j.id,'requestId',s.id,'phase',s.phase,'ids',s.ids,'input',s.input,'body',s.body,'responseId',s.response_id,'token',claim_token);
 end loop;
 return null;
end $$;

create function public.piko_ai_review_finish(p_job_id uuid,p_step_id uuid,p_token uuid,p_event text,p_data jsonb)
 returns void language plpgsql security invoker set search_path='' as $$
declare j piko_ai_private.review_jobs%rowtype;s piko_ai_private.review_steps%rowtype;
 r piko_ai_private.receipts%rowtype;t timestamptz:=clock_timestamp(); prior integer;current_cost integer;
begin
 perform 1 from piko_ai_private.config where id=1 for update;
 select * into j from piko_ai_private.review_jobs where id=p_job_id for update;
 if not found then raise exception 'expired'; end if;
 if p_event='complete' then
  if j.state<>'running' or exists(select 1 from piko_ai_private.review_steps where job_id=j.id and state<>'completed') then raise exception 'replay'; end if;
  if not piko_ai_private.review_access(j.user_id,t) or j.expires_at<=t then raise exception 'access_denied'; end if;
  update piko_ai_private.review_jobs set state='completed',phase='completed',processed=total,result=p_data->'result',conflicts=p_data->'conflicts',generation=generation+1 where id=j.id;
  return;
 end if;
 select * into s from piko_ai_private.review_steps where id=p_step_id and job_id=j.id for update;
 if not found or s.token is distinct from p_token then raise exception 'replay'; end if;
 if p_event='usage' then
  select * into r from piko_ai_private.receipts where request_id=s.id for update;
  prior:=coalesce(r.actual_cents,r.reserve_cents);
  perform public.piko_ai_settle(j.user_id,s.id,(p_data->>'inputTokens')::integer,(p_data->>'outputTokens')::integer);
  select coalesce(actual_cents,reserve_cents) into current_cost from piko_ai_private.receipts where request_id=s.id;
  update piko_ai_private.review_jobs set reserved_and_spent_cents=reserved_and_spent_cents-prior+current_cost where id=j.id;
  return;
 end if;
 if p_event='attached' then
  if p_data->>'responseId' !~ '^resp_[a-zA-Z0-9_-]+$' then raise exception 'invalid_response'; end if;
  update piko_ai_private.review_steps set response_id=p_data->>'responseId',state='pending',provider_poll_expires_at=t+interval '10 minutes' where id=s.id and state='dispatched';
  update piko_ai_private.receipts set response_id=p_data->>'responseId',status=case when status='settled' then status else 'started' end where request_id=s.id;
  return;
 end if;
 if j.state<>'running' or j.expires_at<=t or not piko_ai_private.review_access(j.user_id,t) then raise exception 'access_denied'; end if;
 if p_event='dispatch' then
  if s.state<>'claimed' or s.response_id is not null or s.lease_until<=t then raise exception 'replay'; end if;
  perform public.piko_ai_capture(j.user_id,s.id,'sent',jsonb_build_object('request',s.input,'providerBody',s.body,'jobId',j.id,'promptVersion','piko-review-job-v1','schemaVersion',1));
  update piko_ai_private.review_steps set state='dispatched' where id=s.id;
 elsif p_event='provider_result' then
  perform public.piko_ai_capture(j.user_id,s.id,'result',p_data->'response');
 elsif p_event='pending' then
  update piko_ai_private.review_steps set state='pending',lease_until=t where id=s.id;
  perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),10);
 elsif p_event='unknown' then
  if s.response_id is not null or p_data->>'responseId' ~ '^resp_[a-zA-Z0-9_-]+$' then
   update piko_ai_private.review_steps set state='pending',response_id=coalesce(response_id,p_data->>'responseId'),provider_poll_expires_at=coalesce(provider_poll_expires_at,t+interval '10 minutes'),lease_until=t where id=s.id;
   update piko_ai_private.receipts set status='started',response_id=coalesce(response_id,p_data->>'responseId') where request_id=s.id and status<>'settled';
   perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),10);
  else
   update piko_ai_private.review_steps set state='unknown',lease_until=t where id=s.id;
   update piko_ai_private.receipts set status='uncertain',deadline=t where request_id=s.id and status<>'settled';
   update piko_ai_private.review_jobs set state='unknown',error=p_data,generation=generation+1 where id=j.id;
  end if;
 elsif p_event='failed' then
  update piko_ai_private.review_steps set state='failed',lease_until=t where id=s.id;
  update piko_ai_private.receipts set deadline=t where request_id=s.id and status<>'settled';
  update piko_ai_private.review_jobs set state='failed',error=p_data,generation=generation+1 where id=j.id;
 elsif p_event='result' then
  if s.state='completed' then return; end if;
  if not exists(select 1 from piko_ai_private.receipts where request_id=s.id and status='settled') then raise exception 'invalid_response'; end if;
  update piko_ai_private.review_steps set state='completed',result=p_data->'result',lease_until=t where id=s.id;
  update piko_ai_private.review_jobs set processed=(select coalesce(sum(jsonb_array_length(ids)),0) from piko_ai_private.review_steps where job_id=j.id and phase='detail' and state='completed'),generation=generation+1 where id=j.id;
  perform pgmq.send('piko_ai_review',jsonb_build_object('jobId',j.id),0);
 else raise exception 'invalid_request';
 end if;
end $$;

-- Preserve the conservative legacy cost balance but stop counting an expired
-- unknown attempt as an active concurrency lease forever. No refund/replay.
create function piko_ai_private.limit_detail(uid uuid,reserve integer) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
declare c piko_ai_private.config%rowtype;t timestamptz:=clock_timestamp();retry timestamptz;
begin
 select * into c from piko_ai_private.config where id=1;
 if c.reserved_and_spent_cents+reserve>least(c.allowance_cents,2000-c.non_ai_usage_cents) then
  return jsonb_build_object('limitType','sharedBudget','remainingCents',greatest(0,least(c.allowance_cents,2000-c.non_ai_usage_cents)-c.reserved_and_spent_cents),
   'limitMaximum',least(c.allowance_cents,2000-c.non_ai_usage_cents),'limitRemaining',greatest(0,least(c.allowance_cents,2000-c.non_ai_usage_cents)-c.reserved_and_spent_cents),'limitUnit','cents');
 elsif (select count(*) from piko_ai_private.receipts where user_id=uid and created_at>=date_trunc('day',t at time zone 'utc') at time zone 'utc')>=20 then
  return jsonb_build_object('limitType','day','limit',20,'limitMaximum',20,'limitRemaining',0,'limitUnit','requests','retryAt',(date_trunc('day',t at time zone 'utc')+interval '1 day') at time zone 'utc');
 elsif (select count(*) from piko_ai_private.receipts where user_id=uid and created_at>t-interval '1 minute')>=2 then
  select min(created_at)+interval '1 minute' into retry from piko_ai_private.receipts where user_id=uid and created_at>t-interval '1 minute';
  return jsonb_build_object('limitType','rate','limit',2,'limitMaximum',2,'limitRemaining',0,'limitUnit','requests','retryAt',retry);
 else
  select min(deadline) into retry from piko_ai_private.receipts where status<>'settled' and deadline>t;
  return jsonb_build_object('limitType','parallel','retryAt',retry);
 end if;
end $$;
revoke all on function piko_ai_private.limit_detail(uuid,integer) from public,anon,authenticated;
grant execute on function piko_ai_private.limit_detail(uuid,integer) to service_role;
do $$ declare definition text;begin
 select pg_get_functiondef('public.piko_ai_admit(uuid,uuid,timestamptz,text,text,integer,text,integer)'::regprocedure) into definition;
 definition:=replace(definition,'status<>''settled'')','status<>''settled'' and deadline>t)');
 definition:=replace(definition,'raise exception ''limit'';','raise exception ''limit'' using detail=piko_ai_private.limit_detail(p_user_id,c.request_reserve_cents)::text;');
 execute definition;
end $$;

create function piko_ai_private.review_cleanup() returns void
 language plpgsql security invoker set search_path='' as $$
begin
 update piko_ai_private.review_jobs set state='expired',generation=generation+1 where expires_at<=clock_timestamp() and state in('preparing','running','paused','unknown','cancelling');
 delete from piko_ai_private.review_jobs j where content_expires_at<=clock_timestamp() or exists(
  select 1 from piko_ai_private.owner_access a where a.user_id=j.user_id and (not a.enabled or a.withdrawn_at is not null));
 delete from piko_ai_private.review_cancellations where expires_at<=clock_timestamp();
 if to_regclass('pgmq.q_piko_ai_review') is not null then
  execute 'delete from pgmq.q_piko_ai_review q where not exists(select 1 from piko_ai_private.review_jobs j where j.id=(q.message->>''jobId'')::uuid)';
 end if;
end $$;
create function piko_ai_private.review_revoked() returns trigger
 language plpgsql security invoker set search_path='' as $$
begin
 if not new.enabled or new.withdrawn_at is not null then
  delete from piko_ai_private.review_jobs where user_id=new.user_id;
 end if;
 return new;
end $$;
create trigger review_withdrawal after update of enabled,withdrawn_at on piko_ai_private.owner_access
 for each row execute function piko_ai_private.review_revoked();

-- Operator-only setup, deliberately NOT called by this migration. Provision
-- the URL and independent worker secret in Vault first. No user data in cron.
create function piko_ai_private.configure_review_worker(p_enabled boolean) returns void
language plpgsql security invoker set search_path='' as $$
declare schedule_id bigint;
begin
 for schedule_id in select jobid from cron.job where jobname='piko-ai-review-worker' loop
  perform cron.unschedule(schedule_id);
 end loop;
 if p_enabled then
  if not exists(select 1 from vault.decrypted_secrets where name='piko_ai_review_worker_url') or
   not exists(select 1 from vault.decrypted_secrets where name='piko_ai_review_worker_secret') then raise exception 'unavailable'; end if;
  perform cron.schedule('piko-ai-review-worker','* * * * *', $task$
   select net.http_post(
    url:=(select decrypted_secret from vault.decrypted_secrets where name='piko_ai_review_worker_url' limit 1),
    headers:=jsonb_build_object('Authorization','Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='piko_ai_review_worker_secret' limit 1),'Content-Type','application/json'),
    body:='{}'::jsonb,timeout_milliseconds:=30000)
   $task$);
 end if;
end $$;
revoke all on function piko_ai_private.configure_review_worker(boolean) from public,anon,authenticated,service_role;

-- Maintenance is folded into the existing owner-operated cleanup heartbeat;
-- its existing schedule is unchanged. No worker scheduler is activated here.
do $$ declare definition text;begin
 select pg_get_functiondef('public.piko_ai_cleanup()'::regprocedure) into definition;
 definition:=replace(definition,'begin','begin perform piko_ai_private.review_cleanup();');
 execute definition;
end $$;
revoke all on function piko_ai_private.review_status(piko_ai_private.review_jobs),piko_ai_private.review_access(uuid,timestamptz),piko_ai_private.review_capacity(uuid,timestamptz,timestamptz),piko_ai_private.review_cleanup(),piko_ai_private.review_revoked() from public,anon,authenticated;
grant execute on function piko_ai_private.review_status(piko_ai_private.review_jobs),piko_ai_private.review_access(uuid,timestamptz),piko_ai_private.review_capacity(uuid,timestamptz,timestamptz),piko_ai_private.review_revoked() to service_role;
revoke all on function public.piko_ai_review_job(uuid,uuid,text,jsonb),public.piko_ai_review_claim(),public.piko_ai_review_finish(uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.piko_ai_review_job(uuid,uuid,text,jsonb),public.piko_ai_review_claim(),public.piko_ai_review_finish(uuid,uuid,uuid,text,jsonb) to service_role;
