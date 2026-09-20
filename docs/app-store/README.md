# Jev Relay App Store packet: native BYOK build3

Preparation material only. Do not publish or submit from this packet. Build3 is still being implemented and tested.

| File | Purpose |
|---|---|
| [metadata.md](metadata.md) | Proposed store copy, bounded to verified final behavior |
| [review-notes.md](review-notes.md) | Planned reviewer flow and the current live-access blocker |
| [release-checklist.md](release-checklist.md) | Gates before any build3 submission |
| [claim-ledger.md](claim-ledger.md) | Claims allowed, prohibited, and still unverified |
| [privacy-assessment.md](privacy-assessment.md) | Conservative privacy baseline and audit gaps |

## Current boundary

Build3 is a planned native direct-provider BYOK design. Users supply their own TypeSafe/Jev and optional Nebius keys, pay providers directly, and manage billing and revocation in their provider accounts. There is no developer-funded usage, shared key, owner-funded fallback, relay, anonymous Supabase identity, operator cloud identity, or shared quota.

Build2 is historical. Its App Review was canceled while Apple processing cancellation was last observed. No public release occurred, and manual release was preserved. Do not represent historical build2 archive/upload/review material as evidence that build3 passed QA, uploaded, submitted, approved, or released.

## Pre-release gates

Physical-device QA, independent Dutch review, detailed provider/privacy audit, final binary and direct-network verification, accurate handling of legacy testing metadata, and an Apple review access plan are all open. The existing six conservative App Privacy labels remain App Functionality, linked, and no tracking, but they are not a full privacy audit.
