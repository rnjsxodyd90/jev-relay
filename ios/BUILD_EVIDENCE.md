# Build evidence: native BYOK build3

## Current status

**Build3 is being implemented and tested. No build3 QA pass, archive, upload, App Review submission, approval, or public release is evidenced here.**

## Required evidence before release

- Final signed binary contains no provider API keys and has no operator relay or Supabase identity/refresh path.
- TypeSafe/Jev and optional Nebius keys store in iOS Keychain with `WhenUnlockedThisDeviceOnly`; key values are never displayed back; secure-entry buffers clear after save, backgrounding, and screen disappearance.
- Saving does not validate keys or make network calls.
- After explicit consent and Translate, direct network capture proves: the Jev key is Authorization only to TypeSafe's fixed HTTPS endpoint; the Nebius key is Authorization only to Nebius's fixed HTTPS endpoint; neither key goes to the operator, Supabase, or the other provider.
- Network and behavior tests prove at most one Jev request plus optional one Qwen request per live turn, no retries, fixed text/output limits, and no developer-funded/shared-key/owner-funded fallback path.
- Physical-device QA covers clean install, Keychain behavior, key removal, voice permissions, on-device speech/no audio upload, Dutch playback, accessibility, file protection, and failure states.
- Independent Dutch review and detailed provider/infrastructure privacy audit are complete.

## Historical build2 evidence

Build2 artifacts and test records remain historical only. Parent canceled build2 review while Apple processing cancellation was last observed. No public release occurred and manual release was preserved. Historical build2 results must not be represented as build3 testing, upload, submission, approval, or release.

## Legacy backend observation

After removing only `TYPESAFE_API_KEY` and `NEBIUS_API_KEY` from the JevRelay Supabase project, the legacy backend was last observed with health `503`, `ready: false`, and `deleteSession: true`. No other provider project keys were revoked. This confirms disabled legacy live service at that observation, not deletion of old testing metadata or completion of provider retention/deletion review.
