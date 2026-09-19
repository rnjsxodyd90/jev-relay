# Build and test evidence

Observed locally with Xcode 27.0 (build 27A266a), Apple Swift 6.4 in Swift 5 language mode, and iOS SDK 27.0.

## Focused privacy fixes verified in source and tests

- Recording startup now uses an invalidatable generation, exposes a single pending-start state, checks active lifecycle after each permission await and immediately before audio activation, and ignores stale recognition/timeout callbacks. Tests cover cancellation during speech permission, cancellation during microphone permission, and background/inactive state after permission.
- Source, context, and tone edits all use the same invalidation path, cancel in-flight work, stop speech, and clear the result. Tests specifically cover context and tone invalidation and speech-stop invocation.
- Interpretation sends one UUID `Idempotency-Key` per explicit action. A backend 401 refreshes or clears credentials for the next action but never repeats interpretation. Deletion uses only an existing identity, has an empty body and no content type, treats 401 as unconfirmed, and never signs up solely to delete. Mock HTTP tests cover these cases.
- Default networking uses an ephemeral URL session with no URL cache or persistent cookie storage. Injected sessions remain supported for tests.
- Saved phrases now use an atomic JSON file in Application Support with `NSFileProtectionComplete`, backup exclusion, explicit delete behavior, and surfaced read/write/delete errors. No migration was added because there is no released user data. Tests cover persistence, deduplication, protection, backup exclusion, deletion, and failed mutation behavior.
- The app-icon generation script exits successfully without invoking Quick Look when the existing PNG is already a valid 1024 × 1024 image.

## Passed

- `./Scripts/generate-app-icon.sh`: confirmed the existing 1024 × 1024 icon and exited successfully.
- Unsigned Debug generic-device build after the focused fixes: `** BUILD SUCCEEDED **`.
- Unsigned generic-device `build-for-testing` after the focused fixes: `** TEST BUILD SUCCEEDED **` for the app, standalone core unit-test bundle, and UI-test runner.
- The successful build and test compilation emitted no project compiler warnings. Xcode only reported that App Intents metadata extraction was skipped because AppIntents is not used.
- `plutil -lint` passed for `Info.plist` and `PrivacyInfo.xcprivacy`.
- Project identity remains bundle ID `com.taekwon.jevrelay`, team `53R7M78MLK`, iOS 17.0, Swift 5.0, device family `1,2`.
- Production public client configuration is populated for the isolated Supabase service and published HTTPS support/privacy pages. No provider or signing secrets are present.
- On 2026-09-19, the unsigned `AppStore` generic-device configuration built successfully. The produced binary's expanded Info.plist was checked against all five expected service values, including the public client key, backend URL, privacy URL, and support URL. All matched. This is not a signed archive or App Store upload.

## Simulator blocker

A local test run targeting `iPhone 16 Pro Max` was attempted. CoreSimulatorService became invalid, no simulator runtimes could be discovered, and xcodebuild could not find a matching destination. Unit and UI tests therefore compiled but did not execute locally. The GitHub `Native iOS verification` workflow dynamically selects an installed stable Xcode 26+, iPhone and iPad simulators, runs offline unit/UI tests, and exports genuine XCTest screenshot attachments. Its actual run result must be checked before claiming simulator execution.

The separate deployed-backend smoke evidence is in `backend/evidence/`; it does not establish the native app's on-device network behavior. No physical-device, microphone, Dutch-voice, or signed-distribution testing is claimed.
