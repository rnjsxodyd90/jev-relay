# Privacy assessment draft

Status: **provisional and non-legal advice**. This is a working assessment for engineering, privacy review, and App Store Connect entry. It is not a final privacy attestation. Re-evaluate from the release binary, backend configuration, provider contracts/settings, Supabase configuration, and actual logs before submission.

## Actual-flow model to verify

### On device

- The user may type English source text and optional context. The text is editable before an explicit send.
- Optional microphone recording and Apple speech recognition should occur only after a user tap and with mandatory on-device speech recognition support. Audio should not be uploaded or persistently saved by the app.
- Dutch speech uses manual `AVSpeechSynthesizer` playback only.
- Saving and deleting phrases are local actions. Built-in and saved phrase candidates can be included in a consented, explicit Interpret request for cloud matching; do not describe all saved phrases as permanently device-only.
- Client code stores the anonymous Supabase access/refresh tokens in a device-only Keychain item. Release-binary and configuration verification remain required.

### Off device

- An anonymous Supabase identity authenticates the user to the deployed backend.
- On explicit send, source text/context and necessary routing state are sent to the backend. Inspected code makes one TypeSafe/Jev routing request, then a Nebius/Qwen request only for novel wording. Bounded live tests exercised memory reuse, novel wording, review, and clarification.
- Deployed quota and receipt tables hold account metadata, pseudonymous usage data, and global counters. These are collected data even though they are not analytics or conversation history.
- Inspected application code does not log or persist request/response text. This does not establish infrastructure, provider, platform, or exception-log retention.
- `POST /delete-session` hard-deletes the anonymous Auth identity and linked account metadata. Two bounded smoke identities were deleted successfully. Current pseudonymous counters remain through their quota periods. Native code clears the Keychain tokens only on confirmed success; final signed-device verification remains required.

## Provider retention: do not collapse this into app behavior

| Provider / layer | Public statement inspected | What it means for this draft | Still needed |
|---|---|---|---|
| TypeSafe AI / Jev | Its privacy policy says it collects API input, does not train or fine-tune models on input, and retains personal data as reasonably necessary. | Do not say TypeSafe has zero retention. Treat routed source text/context as externally collected user content until a binding product-specific arrangement proves otherwise. | Confirm endpoint terms, DPA, retention, subprocessors, logging, and deletion path. |
| Nebius Token Factory / Qwen | Its guide says inputs/outputs may be stored for speculative decoding by default; organization-level Zero Data Retention (ZDR) can be enabled to avoid retained copies after in-flight processing. It says content is not used for training in either mode. | Do not say Qwen/Nebius has zero retention unless active account-level ZDR is verified. If ZDR is off or unknown, content is retained by the provider according to its policy. | Verify active organization ZDR, endpoint type/region, applicable DPA, provider logs, and support confirmation. |
| Supabase / backend / host | Anonymous auth, private-table RLS/grants, quota/receipt storage, signup controls, two identity deletions, and successful scheduled cleanup were verified in a bounded pilot. The Dashboard reports the database in Ireland. | Anonymous does not mean unlinked. Database region does not prove Edge Function execution location or provider residency. | Audit observability, IP/request logs, backups, retention, subprocessors, operational resilience, and signed-device behavior. |
| Apple on-device frameworks | On-device processing is intended for speech recognition; manual local playback is intended. | Data that never leaves the device is not “collected” for the App Privacy label, but this needs runtime verification. | Physical-device, network, and storage tests, including denied-permission path. |

## Conservative provisional App Privacy label

Enter these only after confirming the exact release flow. This is a conservative starting point, not a completed App Store Connect declaration.

| Apple data type | Collected? | Linked to user? | Tracking? | Purpose | Reasoning |
|---|---:|---:|---:|---|---|
| Identifiers: User ID | Yes, provisional | Yes | No | App Functionality | Anonymous Supabase/account-level identifier is used for authentication and durable per-user quota enforcement. |
| User Content: Other User Content | Yes, provisional | Yes | No | App Functionality | English text, context, and generated Dutch wording are transmitted for requested routing/translation. Provider retention makes optional-disclosure treatment unavailable on current facts. |
| Usage Data: Other Usage Data | Yes, provisional | Yes | No | App Functionality | Inspected deployed tables retain pseudonymous daily/monthly usage counts for quota enforcement. The native manifest declares Other Usage Data for App Functionality, not Analytics. |
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

## Verified engineering facts, 19 September 2026

- Public service: `https://iliuldjetbxxsjykoqxm.supabase.co/functions/v1/native-backend`; authentication uses the same Supabase project over HTTPS.
- Dashboard database region: **West EU (Ireland), `eu-west-1`**. No claim that all function or provider processing occurs there.
- All three native migrations were applied through the Dashboard in one transaction. Private-table RLS, role grants, the enabled signup hook, and bounded live/deletion tests were verified. CLI migration-ledger reconciliation is still separate work.
- The hourly cleanup job actually succeeded at `2026-09-19T11:17:00Z`; its single returned function-result row does not establish that any expired data existed in that run.
- Public [privacy](https://rnjsxodyd90.github.io/jev-relay/privacy.html) and [support](https://rnjsxodyd90.github.io/jev-relay/support.html) pages are published. Support monitoring remains an operator responsibility.
- See `backend/evidence/deployment-verification.json` and the live smoke evidence. The native manifest now declares User ID, Other User Content, and Other Usage Data, linked for App Functionality and not tracking. Final App Store Connect answers remain unentered and provisional.

## Facts still needed

- Edge Function execution regions and actual platform/IP/connection/security-log fields and retention.
- Signed-device Keychain/storage proof, deletion end-to-end UI verification, operational cleanup under backlog/failure, and backup retention.
- Independent network/log verification of exact release payloads and whether infrastructure error reports retain content.
- TypeSafe plan/contract retention, data-processing terms, endpoint location, and subprocessors.
- Nebius organization ZDR status, endpoint type and region, DPA/subprocessors, and content/log retention.
- Release-binary SDK inventory, privacy manifests, analytics/crash reporting, CDN/WAF, and IP/request log policies.
- Physical-device proof that speech recognition is on device and that audio is neither uploaded nor retained.
- Final confirmation of support monitoring, data-rights handling, and the public policy against the signed release.
