# Native BYOK build3 release checklist

Status: **not ready for submission.** Build3 is in implementation and testing. Do not claim it passed QA, was uploaded, was submitted, was approved, or was released.

## Historical build2 boundary

- [x] Historical only: build2 review was canceled while Apple processing cancellation was last observed.
- [x] Historical only: no public release occurred; manual release was preserved.
- [ ] Do not reuse build2 archive, upload, CI, review, or App Store status as build3 release evidence.

## Required build3 gates

- [ ] Verify final source and signed binary use direct fixed HTTPS provider endpoints only, with each API key sent only as Authorization to its matching provider.
- [ ] Verify TypeSafe/Jev and Nebius keys are stored with `WhenUnlockedThisDeviceOnly`, never bundled or shown back, and secure-entry buffers clear after save, background, and disappearance.
- [ ] Verify Save performs no API-key validation or network request; only consented Translate can issue live calls.
- [ ] Verify each live turn is bounded to one Jev request and optional one Qwen request, no retries, and fixed text/output limits.
- [ ] Verify no operator/Supabase transmission of provider keys; no anonymous Supabase signup/refresh, operator cloud identity, shared quota, developer key, included credit, or owner-funded fallback.
- [ ] Complete physical-device QA: clean install, key lifecycle, denied permissions, on-device speech/no audio upload, Dutch playback, accessibility, file protection, and direct-network inspection.
- [ ] Complete independent Dutch human review.
- [ ] Complete detailed provider privacy audit: retention, ZDR, account terms, deletion, regions, subprocessors, and no-training claims.
- [ ] Audit infrastructure/support logging, IP/user-agent/IP-derived location/diagnostics, backups, retention, residency, and legacy testing metadata deletion/rights handling.
- [ ] Revalidate the six conservative App Privacy labels and public privacy/support pages against the final build.
- [ ] Resolve the reviewer-access blocker without exposing a secret or inventing credentials/demo behavior.
- [ ] Complete current App Store Connect metadata, availability, age rating, content rights, privacy answers, and support monitoring only after final verification.
- [ ] Archive, upload, submit, and retain manual release only as separate deliberate post-gate actions.
