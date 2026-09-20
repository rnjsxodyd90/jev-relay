# App Review notes for native BYOK build3

Internal status: **do not submit these notes yet.** Build3 is in implementation and test. It has not passed QA, been uploaded, submitted, approved, or released. Build2 review was canceled while Apple processing cancellation was last observed; build2 remains historical evidence only, with no public release and manual release preserved.

## Planned app behavior

Jev Relay is a native SwiftUI English-to-Dutch BYOK app. A user must provide their own TypeSafe/Jev API key and, for optional Qwen use, their own Nebius API key. Keys are intended for iOS Keychain with `WhenUnlockedThisDeviceOnly` accessibility. They are not bundled, displayed back, sent to the operator/Supabase, or cross-sent between providers.

A user enters text, taps Translate, reviews a transmission notice, and consents before a live call. Save does not validate keys or use the network. A live turn is designed to make at most one Jev request and, only if needed, one Qwen request, with no automatic retry. Each key is sent only as Authorization directly to its provider's fixed HTTPS endpoint.

## Reviewer access blocker

**Live translation cannot be reviewed without a reviewer-controlled provider key with active provider access.** The app has no anonymous Supabase account, operator cloud identity, developer-funded credits, shared developer key, demo credential, or fake AI replay mode. Do not state that reviewer credentials are unnecessary, that Apple has been supplied keys, or that a live demo is available unless that becomes true and is separately verified.

Before submission, decide and document an Apple-compliant review path that does not expose an operator or user secret and does not misrepresent live functionality. Until then, this is a submission blocker.

## Permissions

Microphone and speech recognition, if included in the final build, must be requested only after the user starts voice entry. Speech recognition is intended to be on device; physical-device verification remains required. The app does not use GPS or location permission.

## Privacy and legacy status

The existing conservative App Privacy declaration has six data types labeled App Functionality, linked to user, and not used for tracking. It is not a complete privacy audit and must be revalidated for build3. Provider retention, ZDR, infrastructure logs, backups, residency, and subprocessors remain open audit items.

The old relay was disabled after only the `TYPESAFE_API_KEY` and `NEBIUS_API_KEY` secrets were removed from the JevRelay Supabase project. Last checked, health returned `503` with `ready: false`, and legacy `deleteSession` returned true. No other provider project keys were revoked.
