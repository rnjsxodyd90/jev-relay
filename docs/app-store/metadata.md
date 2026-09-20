# App Store metadata for native BYOK build3

Status: **draft only.** Build3 is being implemented and tested. It has not passed QA, been archived/uploaded, submitted to App Review, approved, or released. Build2 evidence is historical only; its review was canceled while Apple processing cancellation was last observed. No public release occurred and manual release was preserved.

## Proposed fields, subject to final binary verification

| Field | Draft value |
|---|---|
| App name | `Jev Relay` |
| Subtitle | `English to Dutch, with context` |
| Bundle ID | `com.taekwon.jevrelay` |
| Price | Free app; users pay providers directly for their own usage |
| Privacy Policy URL | `https://rnjsxodyd90.github.io/jev-relay/privacy.html` |
| Support URL | `https://rnjsxodyd90.github.io/jev-relay/support.html` |

## Promotional text

Translate English to Dutch with your own provider keys, then review the wording before optional playback.

## Description

Jev Relay is a native English-to-Dutch translation app that uses your own TypeSafe/Jev API key and, when needed, your own Nebius API key. You control the provider accounts, billing, spending limits, and key revocation.

Enter text, optionally add context or tone, and choose Translate. After consent, the app sends a live request directly to the required provider. It uses at most one Jev request and, only when needed, one Qwen request, with no automatic retries. Review the Dutch result before playback or saving a phrase locally.

Keys are designed to stay in iOS Keychain and are not included in the app or shown back after saving. The app does not provide developer-funded usage, shared keys, free credits, an owner-funded fallback, or a cloud account. Saving a key does not validate it or contact a provider.

Jev Relay is not for legal, medical, emergency, or other high-stakes use. Translation quality and provider availability are not guaranteed.

## Keywords

`English,Dutch,translation,phrasebook,context,speech,review,BYOK`

## Do not claim

- Offline live translation, free provider credits, included usage, a shared quota, or owner-funded fallback.
- That provider content is never retained, that ZDR is enabled, or that App Privacy is a full audit.
- Build3 QA, upload, App Review submission, approval, or release.
- Universal accuracy, speed, or high-stakes suitability.

## Before submission

Complete physical-device QA, independent Dutch review, detailed provider/privacy audit, final binary/network/keychain verification, App Store fields and privacy answers, and reviewer-access planning. Recheck all copy against the shipped build.
