-- Only the trusted AI service can verify a token's live Auth session.
-- JWT validation alone does not revoke an already-issued access token on sign-out.
grant usage on schema auth to service_role;
grant select(id,user_id,not_after) on auth.sessions to service_role;

create function public.piko_ai_session_active(p_user_id uuid,p_session_id uuid)
returns boolean language sql stable security invoker set search_path='' as $$
  select p_user_id is not null and p_session_id is not null and exists (
    select 1 from auth.sessions s
    where s.id=p_session_id and s.user_id=p_user_id
      and (s.not_after is null or s.not_after>now())
  );
$$;
revoke all on function public.piko_ai_session_active(uuid,uuid) from public,anon,authenticated;
grant execute on function public.piko_ai_session_active(uuid,uuid) to service_role;