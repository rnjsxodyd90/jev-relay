# Privacy assessment draft

Status: **provisional and non-legal advice**. This is a working assessment for engineering, privacy review, and App Store Connect entry. It is not a final privacy attestation. Re-evaluate from the release binary, backend configuration, provider contracts/settings, Supabase configuration, and actual logs before submission.

## Actual-flow model to verify

### On device

- The user may type English source text and optional context. The text is editable before an explicit send.
- Optional microphone recording and Apple speech recognition should occur only after a user tap and with mandatory on-device speech recognition support. Audio should not be uploaded or persistently saved by the app.
- Dutch speech uses manual `AVSpeechSynthesizer` playback only.
- Phrasebook entries are intended to remain local until the user explicitly saves or deletes them.
- Client code stores the anonymous Supabase access/refresh tokens in a device-only Keychain item. Release-binary and configuration verification remain required.

### Off device

- An anonymous Supabase identity is intended to identify the user to the backend.
- On explicit send, source text/context and necessary routing state are sent to the backend. The backend is intended to make one TypeSafe/Jev routing request, then a Nebius/Qwen request only for novel wording.
- The backend is intended to enforce durable user and global quotas. Therefore a linked account-level identifier and usage/quota record may be stored.
- The product intent is no first-party transcript logging or transcript storage. This remains unverified and does not describe infrastructure, provider, or platform logs.
- Client code has a cloud-identity deletion request (`POST /delete-session`) and clears the local Keychain token only after a successful response. Its UI exposure, server/Supabase scope, propagation, and any retained abuse/billing/security records must be verified.

## Provider retention: do not collapse this into app behavior

| Provider / layer | Public statement inspected | What it means for this draft | Still needed |
|---|---|---|---|
| TypeSafe AI / Jev | Its privacy policy says it collects API input, does not train or fine-tune models on input, and retains personal data as reasonably necessary. | Do not say TypeSafe has zero retention. Treat routed source text/context as externally collected user content until a binding product-specific arrangement proves otherwise. | Confirm endpoint terms, DPA, retention, subprocessors, logging, and deletion path. |
| Nebius Token Factory / Qwen | Its guide says inputs/outputs may be stored for speculative decoding by default; organization-level Zero Data Retention (ZDR) can be enabled to avoid retained copies after in-flight processing. It says content is not used for training in either mode. | Do not say Qwen/Nebius has zero retention unless active account-level ZDR is verified. If ZDR is off or unknown, content is retained by the provider according to its policy. | Verify active organization ZDR, endpoint type/region, applicable DPA, provider logs, and support confirmation. |
| Supabase / backend / host | Anonymous auth, durable quotas, cloud identity deletion, backend logging, and hosting diagnostics are intended but unverified. | Anonymous does not mean unlinked for privacy labeling when an account-level ID and quota records identify a particular user/account. | Inspect schema, auth configuration, deletion implementation, observability, IP/request logs, retention, and subprocessors. |
| Apple on-device frameworks | On-device processing is intended for speech recognition; manual local playback is intended. | Data that never leaves the device is not “collected” for the App Privacy label, but this needs runtime verification. | Physical-device, network, and storage tests, including denied-permission path. |

## Conservative provisional App Privacy label

Enter these only after confirming the exact release flow. This is a conservative starting point, not a completed App Store Connect declaration.

| Apple data type | Collected? | Linked to user? | Tracking? | Purpose | Reasoning |
|---|---:|---:|---:|---|---|
| Identifiers: User ID | Yes, provisional | Yes | No | App Functionality | Anonymous Supabase/account-level identifier is used for authentication and durable per-user quota enforcement. |
| User Content: Other User Content | Yes, provisional | Yes | No | App Functionality | English text, context, and generated Dutch wording are transmitted for requested routing/translation. Provider retention makes optional-disclosure treatment unavailable on current facts. |
| Usage Data: Other Usage Data | Yes, provisional | Yes | No | App Functionality | Durable per-user quota/usage enforcement is described. Confirm exact stored fields; do not call it Analytics unless used for analytics. |
| User Content: Audio Data | No, if verified | n/a | n/a | n/a | Optional audio should stay on device and not be uploaded/saved. If any audio leaves the device or is retained, revisit. |
| Diagnostics / device identifiers / IP address | Unknown | Unknown | No known tracking | Unknown | Platform, provider, CDN, host, Supabase, and error-monitoring logs are not verified. Do not answer `No` until audited. |

Do **not** select “Data Not Collected.” Do **not** mark tracking absent as a final attestation until SDKs, providers, and data sharing are audited, though no advertising/tracking behavior is currently intended.

## Apple labeling basis

Apple defines “collect” as transmitting data off device so the developer or third-party partners can access it longer than needed to service a request in real time. Apple says data used solely for app functionality still needs declaration, and optional disclosure requires every listed condition. These facts make the cloud content, anonymous user ID, and durable quota records conservative disclosures on current information.

Primary references, accessed 2026-09-19:

- Apple, [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- Apple, [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- TypeSafe AI, [Privacy Policy](https://typesafe.ai/legal/privacy-policy)
- Nebius Token Factory, [Legal quick guide](https://docs.tokenfactory.nebius.com/legal/legal-quick-guide)

## Privacy-policy requirements before publication

The public privacy policy must accurately explain:

1. What is on device versus what is sent on explicit cloud send.
2. The anonymous account-level identifier, Keychain credential handling, quota data, and in-app cloud-identity deletion scope.
3. Each service provider/processor, actual retention, region/subprocessors where applicable, and no-training boundaries without converting them into no-retention claims.
4. Whether ZDR is enabled for the active Nebius organization. If not verified, disclose that provider retention may occur as documented by Nebius.
5. Whether TypeSafe input retention differs under the actual plan/contract from its public policy.
6. The actual backend, Supabase, hosting, CDN, security, and error-reporting log fields and retention, including IP-address handling.
7. Phrasebook local save/delete behavior and backup/sync behavior, if any.
8. Permission purpose and timing for microphone and speech recognition.
9. A real privacy contact and data-rights process. Do not expose a private personal street address or phone number; use an appropriate public contact channel.

## Facts still needed

- Production backend URL, hosting vendor(s), region(s), TLS and logging/retention settings.
- Supabase project settings, database tables, Row Level Security, anonymous-auth configuration, Keychain storage proof, deletion implementation, and retention/backups.
- Exact payloads sent to Jev and Qwen, whether outputs are persisted, and whether any error reports include content.
- TypeSafe plan/contract retention, data-processing terms, endpoint location, and subprocessors.
- Nebius organization ZDR status, endpoint type and region, DPA/subprocessors, and content/log retention.
- Release-binary SDK inventory, privacy manifests, analytics/crash reporting, CDN/WAF, and IP/request log policies.
- Physical-device proof that speech recognition is on device and that audio is neither uploaded nor retained.
- Published HTTPS privacy-policy URL and monitored public support channel.
