# Jev Relay App Store submission packet

Preparation material, not an attestation, legal advice, or authorization to publish. It separates verified evidence from open release gates.

| File | Purpose |
|---|---|
| [metadata.md](metadata.md) | Store metadata and URL fields |
| [review-notes.md](review-notes.md) | Reviewer path and evidence limits |
| [release-checklist.md](release-checklist.md) | Required proof before submission |
| [claim-ledger.md](claim-ledger.md) | Allowed claims and limits |
| [privacy-assessment.md](privacy-assessment.md) | Provisional App Privacy inputs |

## Verified current facts

- Privacy: https://rnjsxodyd90.github.io/jev-relay/privacy.html
- Support: https://rnjsxodyd90.github.io/jev-relay/support.html
- Supabase project `iliuldjetbxxsjykoqxm` is deployed with migrations, RLS, signup hook, readiness, and active hourly cleanup. Cleanup succeeded at 11:17 UTC on 19 September 2026.
- Bounded live smoke verified signup, deletion, quota/contract behavior, idempotency rejection, memory/novel routing, and old-token rejection. The original ambiguous-fixture clarification expectation safely returned review and is retained as a negative finding.
- Version 1.0 build 2 was submitted to App Review and is **Waiting for Review**. The authenticated submission receipt shows one submitted item, submission ID `290fbf06-0bc9-469f-ab2d-19e23d0baf7b`, displayed 20 September 2026 at 9:05 AM Europe/Amsterdam. It is not approved or released; manual release remained checked after submission. No testers/groups are invited. See [review-submission verification](evidence/review-submission-verification.json), [signed distribution evidence](evidence/signed-distribution-verification.json), [historical store-draft verification](evidence/store-draft-verification.json), and unchanged [build 1 evidence](evidence/signed-build1-verification.json).
- Final CI [run 35449925719](https://github.com/rnjsxodyd90/jev-relay/actions/runs/35449925719), commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed both iPhone 17 Pro Max and iPad Pro 13-inch (M5), Xcode 26.3 / iOS 26.2. Per device: 26 tests, 25 passed, one hardware-only file-protection skip, zero failures.
- Independent visual QA **PASS**: purpose/actions are clear, no iPhone navigation-header overlap is present, and iPad detail is a coherent single card. The initial iPhone next-card partial view behind the floating tab bar is normal scroll underlap, not a permanently obscured control: scroll fully reveals it and XCTest reachability passed. Two screenshots per family are uploaded in Translate, then Phrases order: iPhone 6.9-inch at 1320×2868 and iPad 13-inch at 2064×2752. Age rating 18+ and content-rights responses were saved in prior store verification. See [visual verification](evidence/visual-verification.json).

## Remaining gates

Simulator screenshots are not physical-device QA, Dutch-quality proof, or live-service proof. Physical microphone/pronunciation, accessibility, file-protection, clean-install, and native network QA; human Dutch review; and detailed provider/platform retention, logs, backups, residency, and subprocessor verification remain pre-release follow-ups. App Privacy was published conservatively for App Functionality, linked to identity, with no tracking, but this is not a full provider or compliance audit. Accessibility support and territory availability remain unverified or unselected. Age rating 18+ and content-rights responses are saved. The app is submitted and Waiting for Review, not approved or released; manual release is retained and no testers/groups are invited. Preference screens containing research figures are QA evidence, not storefront marketing screenshots.
