import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import { createAiHandler, AiServiceError } from './ai-service.mjs';
import { createAnonymousAuthenticator } from './ai-auth.mjs';

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

Deno.serve(createAiHandler({
  enabled: enabled && client !== null,
  providerKey,
  authenticate: createAnonymousAuthenticator(client),
  rpc: async (name: string, args: Record<string, unknown>) => {
    const { data, error } = await client!.rpc(name, args);
    if (error) throw new AiServiceError(safeCodes.has(error.message) ? error.message : 'unavailable');
    return data;
  },
}));
