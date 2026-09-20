# Claim ledger for native BYOK build3

Use customer-facing claims only when the final build3 behavior has been verified. Build3 is in progress, not QA-passed, uploaded, submitted, approved, or released.

| Claim or fact | Current status | Approved use |
|---|---|---|
| Native English-to-Dutch BYOK app | Planned design; final implementation pending | Internal planning only until verified |
| User supplies own TypeSafe/Jev and optional Nebius keys | Required planned design | Draft copy, subject to final verification |
| User manages provider billing, spending, and revocation | Required planned design | Draft copy, subject to provider/account verification |
| Keys use `WhenUnlockedThisDeviceOnly`, are not bundled/shown back, and buffers clear | Implementation requirement; unverified | Not release claim until signed-device verification |
| Direct fixed HTTPS endpoints; matching Authorization only | Implementation requirement; unverified | Not release claim until network/binary verification |
| Save makes no network/key validation; consented Translate is live | Implementation requirement; unverified | Not release claim until verification |
| At most one Jev plus optional one Qwen, no retries | Implementation requirement; unverified | Not performance/availability claim |
| No developer-funded usage, shared key/quota, or owner-funded fallback | Required design; final verification pending | Draft copy, subject to verification |
| No anonymous Supabase identity or operator cloud identity | Required design; final verification pending | Draft copy, subject to verification |
| No GPS, ads, analytics SDKs, or tracking | Design/policy statement; final SDK/runtime audit pending | Do not strengthen until audit |
| Six conservative App Privacy labels | Existing declaration: App Functionality, linked, no tracking | Internal disclosure baseline only, not a full audit |
| No provider retention, active ZDR, or Data Not Collected | Unsupported | Prohibited |
| Build3 QA, upload, submission, approval, or release | Unsupported | Prohibited |
| Build2 review status proves build3 readiness | False | Prohibited |
| Legacy relay disabled | Last observed after removal of two specified secrets: health 503/ready false; deleteSession true | Historical operational fact only |
| Reviewer needs no credentials or has supplied keys | Unsupported; live access blocker exists | Prohibited |
| Free credits, included usage, purchase/signup link, price estimate | Unsupported or intentionally absent | Prohibited |

## Historical evidence boundary

Build2 App Review was canceled while Apple processing cancellation was last observed. No public release occurred and manual release was preserved. Keep build2 evidence as historical context only; do not convert it into a build3 claim.
