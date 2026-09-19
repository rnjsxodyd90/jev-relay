# App Review notes

Internal status: the App Store Connect record and 1.0 bundle ID exist, but the app is not submitted or approved. A signed AppStore archive succeeded with the existing distribution identity. Export/upload, physical-device QA, privacy answers/attestation, and other release gates are not complete. The latest recorded CI run, 35444300584 (`edbbbfc`), failed three device tests; fixes are being published now. Do not describe CI as passed.

## Notes for App Review

Jev Relay is a native SwiftUI English-to-Dutch turn-based translation app. It is free, with no ads or in-app purchases.

**No reviewer credentials are required.** A consented live request creates an anonymous session as needed. There is no reviewer account, username, password, or subscription flow.

### Exact review flow

1. Launch the app on the **Translate** tab.
2. Enter English text, for example: `Could you repeat that?` Open **Optional context and tone** only if useful, and choose **Formal** when addressing one person politely.
3. Tap **Translate**. On the first live turn, read the **Transmission notice** and choose **I understand and consent** to proceed. An anonymous session is created/refreshed only for this explicit cloud request. **Try an example** only fills editable text; typing, recording, and opening do not send text.
4. Jev selects action, phrasebook reuse/miss, register, and word sense. Qwen is requested only for new wording; an appropriate stored phrase can be reused instead.
5. Invalid, uncertain, unavailable, or malformed responses fail closed to clarification, a review-required result, or a visible error, not an approved guess. Bounded smoke retained an ambiguous fixture that safely returned review instead of expected clarification.
6. For an eligible Dutch result, tap **Review, then play Dutch**. In the sheet, confirm the wording and choose **Reviewed, play Dutch**. Playback is manual and Dutch-only; it never auto-plays.
7. **Save locally** explicitly saves an eligible result. **Settings → Delete cloud identity** offers a confirmed deletion flow with a separate choice about local phrases. **Phrases** manages saved local wording.

### Permissions

Microphone and Speech Recognition are requested only after voice-recording is tapped. Voice is optional and requires on-device recognition support. Audio is not intentionally uploaded or saved; typed input remains available if permission is denied.

### Review environment

- Live backend: `https://iliuldjetbxxsjykoqxm.supabase.co/functions/v1/native-backend`
- Availability and reviewer allowance: confirm before submission; client behavior states 10 turns/user/UTC day and shared limits may apply
- Privacy: https://rnjsxodyd90.github.io/jev-relay/privacy.html
- Support: https://rnjsxodyd90.github.io/jev-relay/support.html

The build has no fake AI replay mode. Preference screens with research figures are QA evidence, not storefront performance/accuracy marketing. Do not claim provider retention/ZDR/logging facts, physical-device microphone/pronunciation validation, or final privacy attestation until independently complete.
