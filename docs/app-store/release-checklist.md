# Release checklist

Status: **build 2 uploaded and processed, with the version 1.0 draft saved. Not submitted, approved, or released.** App Store Connect shows upload Complete and TestFlight Ready to Submit. Build 2 is selected in the draft, release remains manual, and no testers are invited.

## Verified evidence

- [x] Final automated CI [run 35449925719](https://github.com/rnjsxodyd90/jev-relay/actions/runs/35449925719), commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed separate iPhone 17 Pro Max and iPad Pro 13-inch (M5) jobs on Xcode 26.3 / iOS 26.2: per device 26 total, 25 passed, one hardware-only file-protection skip, zero failed.
- [x] Final screenshot provenance records 12 genuine offline RGB XCTest PNGs without alpha: 1320×2868 iPhone and 2064×2752 iPad. Compact artifact hashes are verified for iPhone `95490e72a7cc431ec41a1b6831e8b3bffcbb6be2b1eb1f3b254a8a590048f404` and iPad `815221a9faecb57b5e624baafe90d108721b220adef801a84ff060233b998cab`.
- [x] c6 is retained as an automated pass only. Visual QA identified and c7 corrected multi-column iPad expanded cards and translucent iPhone header overlay, with single-VStack/opaque-background geometry assertions.
- [x] Build 2 signed archive, IPA export, and strict signature verification passed locally on Xcode 27.0 (27A266a). `ITSAppUsesNonExemptEncryption=false` records only OS-provided TLS, Keychain, and file protection. Apple upload exited 0 with no errors; delivery UUID `c0a9ef01-e3bc-47f8-9cde-e7aee4f90408`. Apple processing is Complete and TestFlight is Ready to Submit.
- [x] Independent final visual QA passed: clear English-to-Dutch purpose and actions, no iPhone navigation-header obstruction, and one coherent iPad expanded detail card. The scrolled screenshot and XCTest confirm reachability of the card partially visible behind the initial floating tab bar.
- [x] Two genuine screenshots per family are uploaded, Translate followed by Phrases: iPhone 6.9-inch 1320×2868 and iPad 13-inch 2064×2752. No inference result was fabricated.
- [x] Store metadata, support/privacy URLs, reviewer instructions/contact, no reviewer sign-in, build 2 selection, and manual release are saved. Free pricing is saved; untested Mac and Vision Pro availability is disabled.
- [x] The temporary build 2 Developer key was revoked, active team keys were verified at zero, and private key/download/upload-cache files were removed.
- [x] Project syntax/evidence checks and all 51 JavaScript regression tests passed again. Runtime source was compared with published commit `783c77112a48fa4111aa46cefcde2f4c21762229`; tracked-file differences were documentation only.
- [x] Build 1 upload is Complete; encryption answer saved; TestFlight Ready to Submit, no testers invited.

## Remaining gates

- [ ] **[blocked: physical device and human reviewer]** Complete microphone, optional on-device recognition, Dutch voice/pronunciation, denied permissions, accessibility, complete-file-protection, clean-install, deletion, and native-network QA. Complete independent Dutch human quality review.
- [ ] **[blocked: operational/provider verification]** Verify TypeSafe and Nebius retention, organization ZDR if claimed, logs, backups, region/residency, processors, and deletion boundaries. Audit hosting/CDN/WAF/error/IP logs and backups. Ireland database hosting does not establish Edge Function or provider residency.
- [ ] **[blocked: final privacy attestation]** Reconcile the signed binary, providers, and operations before completing/publishing App Privacy. Do not select Data Not Collected. Current App Privacy is unstarted and unpublished; accessibility claims are also unstarted pending QA.
- [ ] **[blocked: final operator/content review]** Complete age-rating and content-rights answers, select release territories, and provide only verified accessibility information. These fields remain incomplete, rather than guessed or falsely attested.
- [ ] Invite testers only as a separate deliberate step. Ready to Submit is not a claim that anyone can already install the build.
- [ ] Submit only after every applicable gate closes. Keep release manual; do not approve or release as part of preparation.

See [signed distribution evidence](evidence/signed-distribution-verification.json), [visual evidence](evidence/visual-verification.json), and [store draft evidence](evidence/store-draft-verification.json).
