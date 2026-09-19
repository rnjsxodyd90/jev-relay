# App Store metadata

Status: **App Store Connect record and 1.0 bundle ID created; not submitted**. A signed AppStore archive succeeded with the existing distribution identity. Export/upload, physical-device QA, privacy answers, and remaining release gates are still incomplete.

## Required fields

| Field | Value | Validation |
|---|---|---|
| App name | `Jev Relay` | 9/30 characters |
| Subtitle | `English to Dutch, with context` | 30/30 characters |
| Bundle ID | `com.taekwon.jevrelay` | provided |
| Team ID | `53R7M78MLK` | provided |
| Price | Free | no ads; no in-app purchases |
| Privacy Policy URL | `https://rnjsxodyd90.github.io/jev-relay/privacy.html` | published HTTPS page |
| Support URL | `https://rnjsxodyd90.github.io/jev-relay/support.html` | published HTTPS page; operator monitoring remains a release responsibility |

## Promotional text

Translate English to Dutch, review the wording, then choose when to play it aloud.

## Description

Jev Relay helps you turn English into Dutch one clear step at a time.

Open Translate. Type English or tap Speak English, optionally add Context and Tone, then tap Translate. Review the Dutch result, save useful wording locally, or tap Review, then play Dutch. In the review sheet, playback starts only after you choose Reviewed, play Dutch.

Try an example only fills the editable English text. It does not translate, record, or send anything. You stay in control before anything is sent: live translation requires an internet connection, and the first live turn shows a Transmission notice before consent. The app is focused on one-way English-to-Dutch translation. Daily and shared service limits apply.

Speech recognition is optional and uses Apple on-device recognition only when supported. Live translation is not promised offline. Saved local phrases can be managed in Phrases; transmission and deletion controls are in Settings.

Jev Relay is not for legal, medical, emergency, or other high-stakes use, and output is not a certified or professional translation.

## Keywords

`English,Dutch,translation,phrasebook,register,clarification,speech,review`

Character count: 73/100, including commas.

## Intentional exclusions

- No claim that translations are always correct, instant, or available offline.
- No claim that Jev or Qwen is universally faster, more accurate, or superior.
- No claim that cloud services retain no data.
- No claim of human translation, professional certification, or suitability for high-stakes use.
- No claim of `Data Not Collected`.

## Before finalizing metadata

- Confirm age rating, category, copyright, availability, and localizations in App Store Connect.
- Recheck both public HTTPS pages without authentication before submission, and confirm support monitoring.
- Verify the final binary name, bundle ID, and price/IAP configuration in App Store Connect.
- Complete export/upload, physical-device QA, privacy answers/attestation, and remaining release gates.
- Recheck all functionality language against the release build and privacy policy.
- Do not treat CI as passed: the latest recorded run, 35444300584 (`edbbbfc`), failed three device tests; fixes are being published now.
