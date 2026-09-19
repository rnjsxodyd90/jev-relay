# Parent integration status and remaining needs

## Verified deployment contract

Public client configuration targets deployed Supabase project `iliuldjetbxxsjykoqxm` and `https://iliuldjetbxxsjykoqxm.supabase.co/functions/v1/native-backend`. Keep provider and signing secrets out of the app.

## Current verification status

- Final automated CI [run 35449925719](https://github.com/rnjsxodyd90/jev-relay/actions/runs/35449925719), commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed independent iPhone 17 Pro Max and iPad Pro 13-inch (M5) simulator jobs on Xcode 26.3 / iOS 26.2: per device 26 total, 25 passed, one hardware-only file-protection skip, zero failed.
- Independent visual QA **PASS**: English-to-Dutch purpose/actions are clear, no iPhone navigation-header overlap is present, and the iPad detail is one coherent card. The next card is partly visible behind the floating iPhone tab bar only in the initial position; scroll fully reveals it and XCTest reachability passed, so this is normal scroll underlap rather than a permanently obscured control.
- Version 1.0 build 2, commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed signed archive/export/strict signature verification on Xcode 27.0 (27A266a). Apple upload exited 0 with no errors, delivery UUID `c0a9ef01-e3bc-47f8-9cde-e7aee4f90408`; App Store Connect shows Complete and TestFlight Ready to Submit, expiring in 90 days. No testers or groups are invited, so availability to testers remains unsupported. Build 2 is selected and saved in the reopened version 1.0 App Store draft, still Prepare for Submission with manual release checked. The existing team/profile were used; the temporary Developer key was revoked, active team keys were verified at 0, and temporary private key/download/upload-cache files were removed.
- `ITSAppUsesNonExemptEncryption=false`: only Apple OS TLS, Keychain, and file protection are used. No app is submitted, approved, or released; manual release is retained and no testers are invited.

## Remaining gates

1. Physical-device speech, accessibility, file-protection metadata, clean-install, and native network QA.
2. Native Dutch human quality review.
3. Provider/platform retention, operational/request logs, backups, residency, subprocessors, TypeSafe terms, and Nebius organization-level ZDR.
4. Final privacy attestation/App Privacy reconciliation. App Privacy is unstarted/unpublished and accessibility is unclaimed.
5. Remaining App Store operator/content declarations, including age rating, content rights, and territory availability. Free pricing is saved; Mac and Vision availability are unchecked.
6. App Store submission only after the gates close.
