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
- Version 1.0 build 2, commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed local signed archive/export/strict signature verification on Xcode 27.0 (27A266a). Its IPA SHA-256 is `060a6704829da95b18e4a317ea305e74e8b3d4b89e51eadef5684334a54a9acb`. Apple upload exited 0 without errors (delivery UUID `c0a9ef01-e3bc-47f8-9cde-e7aee4f90408`); App Store Connect shows Complete and TestFlight Ready to Submit, expiring in 90 days. No testers/groups are invited, so availability to testers remains unsupported. Build 2 is selected and saved in the reopened version 1.0 App Store draft, still Prepare for Submission with manual release checked. See [signed distribution evidence](evidence/signed-distribution-verification.json), [store-draft verification evidence](evidence/store-draft-verification.json), and unchanged [build 1 evidence](evidence/signed-build1-verification.json).
- Final CI [run 35449925719](https://github.com/rnjsxodyd90/jev-relay/actions/runs/35449925719), commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed both iPhone 17 Pro Max and iPad Pro 13-inch (M5), Xcode 26.3 / iOS 26.2. Per device: 26 tests, 25 passed, one hardware-only file-protection skip, zero failures.
- Independent visual QA **PASS**: purpose/actions are clear, no iPhone navigation-header overlap is present, and iPad detail is a coherent single card. The initial iPhone next-card partial view behind the floating tab bar is normal scroll underlap, not a permanently obscured control: scroll fully reveals it and XCTest reachability passed. Two screenshots per family are uploaded in Translate, then Phrases order: iPhone 6.9-inch at 1320×2868 and iPad 13-inch at 2064×2752. See [visual verification](evidence/visual-verification.json).

## Remaining gates

Simulator screenshots are not physical-device QA, Dutch-quality proof, or live-service proof. Physical microphone/pronunciation, accessibility, file-protection, clean-install, and native network QA; human Dutch review; provider/platform retention, logs, backups, residency, and subprocessor verification; final privacy attestation; and remaining operator/content declarations including age rating, content rights, and territory availability remain incomplete. App Privacy is unstarted/unpublished and accessibility is unclaimed. Free pricing is saved; Mac and Vision availability are unchecked. No app has been submitted, approved, or released; manual release is retained and no testers/groups are invited. Preference screens containing research figures are QA evidence, not storefront marketing screenshots.
