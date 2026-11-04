import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { createAiHandler, AiServiceError } from './ai-service.mjs';
import { createAnonymousAuthenticator } from './ai-auth.mjs';
import { createReviewJobHandler } from './review-jobs.mjs';

// Public app keys never grant AI access. Auth is verified against the project;
// the atomic service-role RPC separately checks the operator owner allowlist.
const url = Deno.env.get('SUPABASE_URL');
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const providerKey = Deno.env.get('OPENAI_API_KEY');
const enabled = Deno.env.get('PIKO_AI_ENABLED') === 'true';
const client = url && serviceKey
  ? createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })
  : null;
const safeCodes = new Set(['access_denied','limit','expired','replay','invalid_request','context_limit','invalid_response']);

const rpc = async (name: string, args: Record<string, unknown>) => {
  const { data, error } = await client!.rpc(name, args);
  if (error) {
    let details: Record<string, unknown> | undefined;
    if (error.message === 'limit') {
      try {
        const parsed = JSON.parse(error.details);
        const limitTypes = ['sharedBudget', 'day', 'rate', 'parallel'];
        if (limitTypes.includes(parsed.limitType)) {
          details = {limitType: parsed.limitType};
          if (typeof parsed.retryAt === 'string' && Number.isFinite(Date.parse(parsed.retryAt))) details.retryAt = parsed.retryAt;
          if (Number.isSafeInteger(parsed.limit) && parsed.limit >= 0) details.limit = parsed.limit;
          if (Number.isSafeInteger(parsed.remainingCents) && parsed.remainingCents >= 0) details.remainingCents = parsed.remainingCents;
          for (const key of ['limitMaximum', 'limitRemaining']) {
            if (Number.isSafeInteger(parsed[key]) && parsed[key] >= 0) details[key] = parsed[key];
          }
          if (['cents', 'requests', 'concurrent'].includes(parsed.limitUnit)) details.limitUnit = parsed.limitUnit;
        }
      } catch { /* Unknown limit detail remains explicitly unavailable. */ }
    }
    throw new AiServiceError(safeCodes.has(error.message) ? error.message : 'unavailable', details);
  }
  return data;
};
const authenticate = createAnonymousAuthenticator(client);
const ordinary = createAiHandler({
  enabled: enabled && client !== null,
  providerKey,
  authenticate, rpc,
});
const jobsEnabled = enabled && client !== null && Deno.env.get('PIKO_AI_REVIEW_JOBS_ENABLED') === 'true';
const jobs = createReviewJobHandler({enabled: jobsEnabled, authenticate, rpc});
Deno.serve((req: Request) => {
  const url = new URL(req.url);
  if (url.searchParams.has('job')) return jobs(req);
  return ordinary(req);
});
