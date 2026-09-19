# Jev Relay App Store submission packet

Draft materials only. This packet is not an attestation, legal advice, or authorization to publish. It deliberately separates intended app behavior from unverified deployment and provider-retention facts.

| File | Purpose |
|---|---|
| [metadata.md](metadata.md) | Store name, subtitle, description, keywords, and unresolved URL fields |
| [review-notes.md](review-notes.md) | Reviewer path, permission timing, authentication, and test expectations |
| [release-checklist.md](release-checklist.md) | Required proof before a submission can be made |
| [claim-ledger.md](claim-ledger.md) | Allowed claims, evidence, limits, and claims to avoid |
| [privacy-assessment.md](privacy-assessment.md) | Provisional App Privacy answers and privacy-policy inputs |

## Scope and provenance

Jev Relay is implemented as a native SwiftUI English-to-Dutch, turn-based translation app (`com.taekwon.jevrelay`; Apple Developer Team `53R7M78MLK`). The intended flow is: editable English source text, explicit cloud send, one Jev call selecting action/memory/register/sense, then Qwen only for novel wording. Uncertainty, malformed output, and unavailable services fail closed to review or clarification. Dutch playback is manual using `AVSpeechSynthesizer`; saved phrasebook items are local and user-controlled.

The 12 authored synthetic decision cases, repeated three times, are research evidence only. They support a narrowly scoped internal design choice, not customer-facing speed or accuracy marketing. Academic research guidance was a high-level influence on the independent checklist and provenance approach; no licensed CC BY-NC 4.0 material is copied into the app or this packet.

## Current release status

- Privacy policy: https://rnjsxodyd90.github.io/jev-relay/privacy.html
- Support: https://rnjsxodyd90.github.io/jev-relay/support.html
- The isolated EU Supabase backend is deployed. All three migrations, RLS restrictions, signup hook, and hourly cleanup were applied. Readiness returned HTTP 200. Bounded synthetic live tests verified anonymous authentication, memory reuse, novel translation, duplicate rejection, and identity deletion. The initial ambiguous fixture held for review rather than the expected clarification; the failed expectation remains in the evidence instead of being hidden.
- The native `AppStore` configuration compiles unsigned with verified production public configuration. Simulator CI is configured, but its run must be inspected before claiming execution or screenshots.

## Remaining submission gates

1. Restore App Store Connect access, validate signing, and create/upload a signed release archive.
2. Complete simulator and physical-device QA, especially microphone permission races, on-device recognition, Dutch pronunciation, accessibility, and native networking/deletion.
3. Review provider retention configuration, platform/hosting logs, production spend limits, and pilot capacity before broader distribution. Request caps are not dollar budgets.
4. Reconcile App Privacy answers against actual network and retention behavior, obtain appropriate privacy review, and enter verified store metadata and screenshots.
5. Keep the backend available during review and confirm the public support channels are monitored.
