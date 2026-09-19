# Jev Relay for iPhone and iPad

Native SwiftUI English-to-Dutch turn assistant for iOS 17 and later. The project has no third-party dependencies and is self-contained under `ios/`.

## Open and build

Open `JevRelay.xcodeproj` and use the shared `JevRelay` scheme. Debug and Release builds compile with empty service configuration so the offline phrasebook can be developed safely. The `AppStore` archive configuration refuses to build until every production service value is supplied.

```sh
xcodebuild -project JevRelay.xcodeproj \
  -scheme JevRelay -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## Product behavior

- Editable English source and situational context with automatic, formal, informal, and plural register choices.
- Explicit Interpret action. Editing or cancelling invalidates an in-flight response so late output cannot replace a newer turn.
- First-transmission consent names TypeSafe/Jev and Nebius/Qwen and explains that text/context leave the phone, audio remains local, and provider retention policies may apply.
- Apple on-device speech recognition only, guarded by `supportsOnDeviceRecognition`, limited to 30 seconds, and requested only after Record is tapped. No audio files, uploads, or remote fallback.
- Dutch `nl-NL` or `nl-BE` system voice only, manual playback only, with no English fallback. Review, clarify, and error states cannot play.
- Strict response decoding and source matching for memory, translate, clarify, and review routes. Incomplete decision bundles are accepted only for fail-closed review responses.
- One accessible four-decision rail with expanded distribution detail and an explicit warning that native confidence is not calibrated accuracy.
- Eight built-in offline phrases from `src/memory.json`; explicit local saving in protected Application Support storage excluded from backups, with per-item/all deletion and surfaced storage errors. Turns and transcripts are not automatically persisted.
- Anonymous Supabase tokens stored in Keychain with a ThisDeviceOnly accessibility class. No provider keys exist in the app.
- No analytics, tracking, ads, IAP, or account wall.

## Configuration

`Config/Service.xcconfig` contains the public configuration for the isolated pilot service and published support/privacy site. Change these values when deploying your own service; never add provider or signing secrets. The `https:/$()/` spelling preserves URL slashes in Xcode configuration syntax.

Required values:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `RELAY_BACKEND_URL`
- `PRIVACY_POLICY_URL`
- `SUPPORT_URL`

The app expects `RELAY_BACKEND_URL` to be `https://iliuldjetbxxsjykoqxm.supabase.co/functions/v1/native-backend`; it appends `/interpret` and `/delete-session`.

## Tests

`JevRelayTests` covers input validation, strict response routing, review fail-closed behavior, protected phrase persistence/deletion, recording permission races, first-use consent, all turn-edit invalidation, 401 recovery, idempotency, empty identity-deletion requests, and ephemeral networking. `JevRelayUITests` captures the genuine offline Interpret, built-in phrasebook, and privacy/preferences screens without recording, calling AI services, or fabricating an inference result. `.github/workflows/ios.yml` runs both test suites on dynamically selected iPhone and iPad simulators and retains logs, results, and screenshots. See `BUILD_EVIDENCE.md` for the distinction between compiled tests, executed tests, and physical-device validation.
