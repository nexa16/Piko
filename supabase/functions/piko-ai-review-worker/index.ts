import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { createReviewWorker } from '../piko-ai/review-jobs.mjs';
import { AiServiceError } from '../piko-ai/ai-service.mjs';

// Dedicated internal endpoint. It has no app JWT authorization path: an
// independently provisioned random secret is checked before any privileged RPC.
const url = Deno.env.get('SUPABASE_URL');
const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const client = url && key ? createClient(url, key, {
  auth: {persistSession: false, autoRefreshToken: false},
}) : null;
Deno.serve(createReviewWorker({
  enabled: client !== null && Deno.env.get('PIKO_AI_ENABLED') === 'true' && Deno.env.get('PIKO_AI_REVIEW_JOBS_ENABLED') === 'true',
  workerSecret: Deno.env.get('PIKO_AI_REVIEW_WORKER_SECRET'),
  providerKey: Deno.env.get('OPENAI_API_KEY'),
  rpc: async (name: string, args: Record<string, unknown>) => {
    const {data, error} = await client!.rpc(name, args);
    if (error) throw new AiServiceError('unavailable');
    return data;
  },
}));
