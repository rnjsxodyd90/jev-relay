# Build and test evidence

## Current evidence boundaries

- **Final automated simulator CI:** [run 35449925719](https://github.com/rnjsxodyd90/jev-relay/actions/runs/35449925719), commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed separate iPhone 17 Pro Max and iPad Pro 13-inch (M5) jobs on Xcode 26.3 / iOS 26.2. Each reported **26 total: 25 passed, one hardware-only file-protection skip, zero failed**.
- **Final screenshots:** 12 genuine offline XCTest PNGs are listed in `screenshot-provenance.json`; iPhone images are RGB 1320×2868 and iPad images RGB 2064×2752, all without alpha. This evidence does not invoke inference or Record.
- **Independent visual QA:** **PASS**. The English-to-Dutch purpose and actions are clear; there is no iPhone navigation-header overlap; and the iPad detail presentation is a coherent single card. The initial iPhone view partly shows the next card behind the floating tab bar, but the scrolled screenshot fully reveals it and XCTest reachability passed. This is normal scroll underlap, not a permanently obscured control. See `../docs/app-store/evidence/visual-verification.json`.
- **Build 2 distribution:** version 1.0 build 2, commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed local archive, export, and strict signature verification on Xcode 27.0 (27A266a), then Apple upload exited 0 with no errors (delivery UUID `c0a9ef01-e3bc-47f8-9cde-e7aee4f90408`). Its IPA SHA-256 is `060a6704829da95b18e4a317ea305e74e8b3d4b89e51eadef5684334a54a9acb`. App Store Connect shows upload **Complete** and TestFlight **Ready to Submit**, expiring in 90 days; no testers or groups are invited, so availability to testers is not established. Build 2 is selected and saved in the reopened version 1.0 App Store draft, which remains Prepare for Submission with manual release checked. `ITSAppUsesNonExemptEncryption=false` reflects use only of Apple OS encryption (TLS, Keychain, and file protection), not app-implemented cryptography.
- **Build 1 evidence:** preserved unchanged in `../docs/app-store/evidence/signed-build1-verification.json`. Build 1 upload was Complete and its encryption answer was saved; no testers were invited. This is not App Store submission, approval, or release.

## Preserved automated history

The structured simulator evidence retains all prior results, including the c6 pass, the failed `edbbbfc` model/context checks, and the failed `c33cc75` context-expansion UI check. Failed results remain failed evidence, not relabeled as passing.

## Remaining gates

Physical-device speech, accessibility, complete file-protection metadata, clean-install, and native network QA; Dutch human review; provider/platform/log/backups/residency/subprocessor verification; final privacy attestation; remaining App Store operator/content declarations, including age rating, content rights, and territory availability; and submission remain open. App Privacy is unstarted/unpublished, accessibility is unclaimed, and Free pricing is saved with Mac and Vision availability unchecked. Simulator screenshots are not physical QA, Dutch-quality proof, or live-service proof. Manual release is retained.
