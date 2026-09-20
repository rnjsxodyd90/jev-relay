# Security and privacy

## Native iOS BYOK client (build 3 candidate)

- Each user supplies both provider credentials. There is no embedded developer key, shared-credit fallback, or native relay request.
- User keys are stored under separate provider accounts in iOS Keychain with `WhenUnlockedThisDeviceOnly` accessibility and synchronization disabled. Editors never prefill existing values and clear transient buffers after saving, leaving the view, or backgrounding.
- Direct provider requests use fixed HTTPS endpoints, matching-provider Authorization headers, an ephemeral no-cookie/no-cache session, no redirects, bounded response streaming, timeouts, and no automatic retries. Provider bodies and keys do not enter error messages or logs.
- Missing or rejected credentials fail closed. Key changes and consent revocation cancel pending work and invalidate playback approval. Consent must precede transmission, and each playback requires explicit review.
- Provider attempts already sent may incur charges in the user's provider accounts even if later canceled or unsuccessful. Removing a device key does not revoke it at its provider or erase provider-held data.
- Legacy Supabase inference is disabled without deleting auth metadata; old account deletion remains available. The new app does not use that service or create anonymous identities.
- These are source-level controls, not proof of complete physical-device QA, provider retention/ZDR, or an independent compliance audit.

## Separate local research workbench

- Local workstation starter only. The server binds to 127.0.0.1, validates Host/Origin, limits body size/concurrency, and serves an explicit asset allowlist. These controls do not authenticate another local process.
- Live calls are disabled by default. Keys come from server environment variables or an ignored local .env file. No frontend key variables, credential-update endpoint, transcript logs, or browser transcript persistence.
- Text and context leave the device only when the user explicitly runs a live interpretation. TypeSafe receives the decision state; Nebius receives source/context/decisions only when generating new wording. Provider retention is governed by provider terms, not by this app's no-local-logging policy.
- Raw audio stays in the browser. Public model assets download from Hugging Face; their revision and hashes are pinned, bounded and checked before atomic caching.
- Jev responses are untrusted until their full choice schema is validated. Source/context are framed as data. This reduces risk but is not proof of prompt-injection immunity.
- Unknown/invalid/low-confidence critical decisions lead to clarification or review. A high confidence value is not a correctness guarantee. Do not use this starter for medical, legal or safety-critical interpretation without qualified validation.
- Budgets are process-local request limits, not dollar ceilings or durable per-user quotas. Restart resets them. Do not expose this server publicly.
- Playback is explicit. A local Dutch voice is required; no English-voice fallback that misrepresents pronunciation.
- Keep .env, node_modules, .models, recordings, provider keys and private conversation transcripts out of commits and release archives.

Before hosting: add authentication/authorization, tenant separation, TLS, durable quotas, explicit consent/retention controls, dependency review, abuse prevention and security testing.
