# Jev Relay for iPhone and iPad

Native SwiftUI English-to-Dutch BYOK client for iOS 17+. Open `JevRelay.xcodeproj` and use the shared `JevRelay` scheme.

## Build3 design boundary

Build3 is being implemented and tested. This document does not claim build3 passed QA, was archived/uploaded, submitted to App Review, approved, or released.

The intended client flow is direct BYOK: a user enters their own TypeSafe/Jev API key and optional Nebius API key. Keys must be stored in iOS Keychain using `WhenUnlockedThisDeviceOnly`; they must never be bundled, displayed back, sent to the app operator/Supabase, or sent to the other provider. Secure-entry buffers must clear after save, app backgrounding, and entry-screen disappearance.

Save must not validate a key or use the network. Only after consent and Translate may the client make a live call: at most one Jev call and, where needed, one Qwen call. Each key must be sent only as Authorization directly to its respective fixed HTTPS provider endpoint. No automatic retries; fixed source-text and output limits apply.

There is no developer-funded usage, developer key, shared key/quota, owner-funded fallback, anonymous Supabase signup/refresh, operator cloud identity, or app-operated relay. Users manage provider billing, spending, and key revocation with their own provider accounts.

## Legacy and evidence boundary

The legacy Jev Relay backend was disabled after only `TYPESAFE_API_KEY` and `NEBIUS_API_KEY` were removed from the JevRelay Supabase project. Last observed, health was `503` with `ready: false` and legacy `deleteSession` returned true. No other provider project keys were revoked. This does not erase legacy testing metadata or prove provider retention/deletion behavior.

Build2 evidence remains historical. Its App Review was canceled while Apple processing cancellation was last observed; no public release occurred and manual release was preserved. Do not use build2 archive, upload, CI, or review material as build3 readiness evidence.

## Still required before release

Physical-device QA, independent Dutch review, direct-network and Keychain verification, detailed provider/privacy audit, legacy-data rights/deletion review, App Privacy revalidation, and an Apple-review access plan are open gates. See [BUILD_EVIDENCE.md](BUILD_EVIDENCE.md) and `../docs/app-store/`.
