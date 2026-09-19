# Jev Relay for iPhone and iPad

Native SwiftUI English-to-Dutch turn assistant for iOS 17+. Open `JevRelay.xcodeproj` and use the shared `JevRelay` scheme.

## Configuration and build

`Config/Service.xcconfig` contains public configuration for deployed Supabase project `iliuldjetbxxsjykoqxm`, its `native-backend` Edge Function, and published support/privacy pages. It has no provider or signing secrets.

Version 1.0 build 2, commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed signed archive, IPA export, and strict signature verification locally on Xcode 27.0 (27A266a). Apple upload exited 0 with no errors, delivery UUID `c0a9ef01-e3bc-47f8-9cde-e7aee4f90408`; App Store Connect now shows Complete and TestFlight Ready to Submit, expiring in 90 days. No testers or groups are invited, so it is not established as available to testers. Build 2 is selected and saved in the reopened version 1.0 App Store draft, still Prepare for Submission with manual release checked. `ITSAppUsesNonExemptEncryption=false` is set because the app uses only Apple OS encryption, including TLS, Keychain, and file protection. No app has been submitted, approved, or released.

## Verification

Final automated simulator CI [run 35449925719](https://github.com/rnjsxodyd90/jev-relay/actions/runs/35449925719), commit `783c77112a48fa4111aa46cefcde2f4c21762229`, passed iPhone 17 Pro Max and iPad Pro 13-inch (M5) on Xcode 26.3 / iOS 26.2. Per device: 26 total, 25 passed, one hardware-only file-protection skip, zero failed. Final 12 genuine offline screenshots are RGB, without alpha, at 1320×2868 (iPhone) or 2064×2752 (iPad); see structured evidence.

Independent visual QA passed: the English-to-Dutch purpose/actions are clear, the iPhone navigation header does not overlap content, and the iPad detail is a coherent single card. The initial iPhone view's next-card partial display behind the floating tab bar is normal scroll underlap: the scrolled screenshot fully reveals it and XCTest reachability passed. These simulator screenshots are not physical-device QA, Dutch-quality proof, or live-service proof.

Physical-device testing, Dutch human review, provider/platform/log/backups/residency/subprocessor verification, privacy attestation, remaining operator/content declarations including age rating, content rights, and territory availability, and App Store submission/review remain open. App Privacy is unstarted/unpublished and accessibility is unclaimed. Free pricing is saved; Mac and Vision availability are unchecked.
