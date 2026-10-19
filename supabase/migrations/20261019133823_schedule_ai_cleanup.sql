-- Database-owner maintenance continues after paid dispatch is disabled.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule(
  'piko-ai-private-cleanup',
  '17 */6 * * *',
  $job$select public.piko_ai_cleanup(); select piko_ai_private.purge_inactive_anonymous_identities();$job$
);
select public.piko_ai_cleanup();
select piko_ai_private.purge_inactive_anonymous_identities();