# Optional AI service preparation

This is a prepared backend, not an activated public service. Ordinary Piko builds
leave AI unavailable. Local vocabulary storage and learning do not initialize
Supabase, require an identity or wait for generation.

The app uses pinned `supabase_flutter` 2.18.3. Voluntary activation explains the
processing before anonymous access is created or restored. Disconnect removes
local access without changing vocabulary or learning. Example/Hint responses are
reviewed and explicitly used in a new draft; the existing confirmation saves them.

## Configuration and activation

Use a dedicated eligible Supabase Free project in an EU region. Do not point
this configuration at an existing unrelated project. Before activation, review
actual account access, checkout, taxes/fees, hosting eligibility, provider prices,
abuse controls and the approved total budget. No paid upgrade, automatic recharge,
fallback model or deployment is implied by this directory.

Server-only environment values are `OPENAI_API_KEY`, the project's standard
`SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`, `PIKO_PUBLISHABLE_KEY` and a separate
random `PIKO_MAINTENANCE_TOKEN` of at least 32 characters. Keep credentials in
server secret storage. `PIKO_AI_LIVE_APPROVED=true` is a server activation gate.
Do not put provider, service-role or maintenance secrets in an APK, source,
test output or client configuration.

The app accepts only the reviewed public values `PIKO_AI_SUPABASE_URL`,
`PIKO_AI_PUBLISHABLE_KEY` and `PIKO_AI_LIVE_APPROVED=true`. Without them its
gateway is unavailable. These define names do not themselves establish approval.

Apply the migration only after reviewing its target and permissions. No enabled
budget row is created. A service operator must explicitly approve each UTC
month's row in `piko_ai.month_budget`, setting its USD micro-unit ceiling from
the approved gross spending budget after conservative tax/currency/fee margins.
No new month is automatically funded. The ceiling complements, rather than
replaces, verified payment and hosting constraints.

Configure anonymous Auth signup IP limits and provider-supported abuse controls;
verify their actual Android behavior. If enrollment needs a CAPTCHA challenge,
leave activation pending until that challenge works in the client. The present
client exposes enrollment failures without blocking manual entry.

## Request and accounting boundary

`piko-content` validates a six-field bounded payload and verifies every bearer
token with Supabase Auth before admission. Anonymous users cannot read/write the
private accounting schema or call its service-only RPC functions. Gateway JWT
verification is disabled in config because the function performs explicit Auth
verification compatible with current signing keys and publishable keys.

Admission locks the shared monthly budget before identity accounting. It permits
at most 100 admitted attempts per UTC day, two starts in a rolling minute and one
active backend request per identity. Paid failures count. UUIDv7 timestamps reject
expired request replays after request metadata cleanup. Identity rotation cannot
increase the shared cap. A two-minute crash lease exceeds the bounded provider
operation; timed-out attempts retain their conservative spending reservation.

The provider request fixes GPT-6 Luna, standard service tier, Structured Outputs,
no tools, reasoning `none`, `store:false` and 768 maximum output tokens. The
reservation covers the full documented context window at the conservative input
rate, including cache-write/long-context premiums, plus bounded output. Only
verified model/tier/token usage permits atomic release of unused reservation.
Uncertain failures retain the whole reservation. Prices and model limits must be
reverified before activation; there is no automatic paid retry or model fallback.

Piko stores no prompt/result history. Request accounting expires after 35 days;
inactive identity counters are cleared and anonymous identities are eligible for
deletion after 90 days. Schedule the separately protected `piko-maintenance`
function and monitor successful cleanup/backlog before activation. It claims up
to 100 eligible identities per run before Auth Admin deletion, blocking concurrent
reactivation; failed deletions remain eligible for retry. Do not log payloads,
responses, identities or secrets. Provider-side standard retention remains
separate; this is not a zero-retention or EU-only processing guarantee.

## Local checks and remaining acceptance

Run `npm ci` and `npm test` in this directory with Node.js 22 or newer. Tests use
pinned PGlite 0.5.10 to execute the migration and PostgreSQL functions. Its submitted
transactions are serialized: these tests do not prove contention across independent
hosted database connections. The core handler uses synthetic provider responses.
Run `deno check functions/piko-content/index.ts functions/piko-maintenance/index.ts`
for the Edge entry points.

Before activation, verify hosted grants/RLS/advisors, forged/expired credentials,
independent concurrent admissions and settlement, cleanup scheduling, public signup
abuse controls, service disable, real Android transport/offline/quota recovery and
a small synthetic bilingual quality evaluation. Inspect actual provider billing
and request usage. Test doubles, local SQL tests and a built APK do not complete
live-provider acceptance.

Relevant official documentation: [anonymous Auth](https://supabase.com/docs/guides/auth/auth-anonymous),
[Edge Function auth](https://supabase.com/docs/guides/functions/auth),
[GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna),
[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs),
[data processing](https://developers.openai.com/api/docs/guides/your-data).
