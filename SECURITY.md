# Security and privacy

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
