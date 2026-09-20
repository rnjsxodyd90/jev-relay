# Claim ledger

Use only claims marked **release-verified** in customer-facing copy. Automated CI, visual simulator QA, upload acceptance, TestFlight status, and internal signed-distribution status are not marketing approval.

| Claim or fact | Status | Evidence / required verification | Approved use |
|---|---|---|---|
| English-to-Dutch, turn-based app | Simulator UI and signed archive verified; reviewer-device live flow pending | Final CI `783c77112a48fa4111aa46cefcde2f4c21762229`; build 2 local signing | Prepared metadata, subject to gates |
| English-to-Dutch purpose/actions, corrected iPad detail, and iPhone header layout | Independent visual simulator QA passed | `visual-verification.json`; iPhone next-card partial view is normal scroll underlap, not a permanently obscured control | Internal QA only; not physical-device, Dutch-quality, or live-service proof |
| Local phrasebook has explicit save/delete | Simulator tests passed | Physical file-protection metadata remains the sole simulator-only skip | Prepared copy, retaining hardware limitation |
| Voice recognition is on device and optional | Code/tests; physical runtime pending | Device microphone/network check needed | Final wording after device verification |
| Audio is not uploaded or saved by app | Inspected behavior; physical audit pending | Device/network audit remains outstanding | App-code claim only |
| App uses only OS-provided encryption | Local build configuration verified | `ITSAppUsesNonExemptEncryption=false`; TLS, Keychain, file protection only | App Store compliance context, not privacy guarantee |
| Build 2 uploaded and processed | Verified internal distribution status | App Store Connect: Complete; TestFlight: Ready to Submit, expires in 90 days; build 2 is selected/saved in the reopened version 1.0 draft | Internal status only |
| Build 2 available to testers | Unsupported | No testers or groups are invited | Prohibited |
| App Store submitted | Release-verified internal status | Authenticated receipt: version 1.0 build 2, one submitted item, Waiting for Review, submission ID `290fbf06-0bc9-469f-ab2d-19e23d0baf7b` | Internal status only; not marketing approval |
| App Store approved or released | Unsupported | Submission is Waiting for Review; manual release remained checked after confirmation | Prohibited |
| Published App Privacy declaration | Release-verified internal status | Six types published for App Functionality, linked, and not tracking at `2026-09-20T07:00:35.227Z` | Internal status only; not a provider/compliance audit |
| No provider retention or Data Not Collected | Unsupported | Detailed retention, logs, backups, residency, subprocessors, and ZDR remain unresolved | Prohibited |
| Accessibility support | Unsupported | Accessibility is unclaimed; physical accessibility QA remains open | Prohibited |
| Age rating 18+ and content-rights responses saved | Release-verified internal status | Prior App Store Connect verification | Internal store status only; not broader legal/compliance proof |
| Territory availability | Unsupported | Territory selection remains a pre-release follow-up | Prohibited |
| Universal speed, accuracy, privacy, or offline translation | Unsupported | No suitable evidence | Prohibited |

## Research provenance boundary

The synthetic decision benchmark is not Dutch translation-quality, native-device, or live-service performance evidence and must not be used in App Store copy.
