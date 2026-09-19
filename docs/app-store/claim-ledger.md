# Claim ledger

Use only claims marked **release-verified** in customer-facing copy. “Intended” is not proof. Research results are not App Store marketing claims.

| Claim or fact | Status | Evidence / required verification | Approved use |
|---|---|---|---|
| English-to-Dutch, turn-based app | Intended | Product specification; native release build check pending | Draft metadata after build check |
| Explicit editable text before cloud send | Intended | Native UI and network capture pending | Description/review notes after verified |
| One Jev call makes action, memory, register, and sense decisions | Intended; prototype evidence only | `docs/integration.md`; deployed/native path pending | Review notes after verified, not performance marketing |
| Qwen generates only novel wording | Intended; prototype evidence only | ADR-002 and integration contract; deployed path pending | Review notes after verified |
| Uncertain/unavailable/invalid results fail closed to review or clarify | Supported by prototype policy; native pending | ADR-004 and integration contract | Description/review notes after native test |
| Manual Dutch-only playback | Intended | Native implementation test pending | Store copy after verified |
| Local phrasebook has explicit save/delete | Intended | Native storage and deletion test pending | Store copy after verified |
| Voice speech recognition is on device and optional | Intent plus Info.plist strings; runtime pending | `ios/JevRelay/Resources/Info.plist`; physical-device test needed | Store/review copy only after enforcement test |
| Audio is not uploaded or saved by app | Info.plist assertion; runtime/network pending | Info.plist; capture/network/storage audit needed | Privacy policy/review note only after audit |
| Anonymous Supabase auth and Keychain-only device credential | Client-code supported; deployment pending | `ios/JevRelay/Core/APIClient.swift` signs up/refreshes anonymously; `KeychainStore.swift` uses a device-only Keychain item. Supabase configuration and release tests remain pending. | Privacy materials after audit |
| In-app cloud identity deletion | Client endpoint supported; end-to-end pending | `APIClient.swift` posts to `/delete-session` and clears Keychain only on success. UI, backend/Supabase deletion, retention, and end-to-end proof remain pending. | Store/review copy after verified |
| No own transcript logging or storage | Intended | Backend logs, database, observability, and error reporting audit pending | Privacy policy only after audit |
| Free, no ads, no IAP | Provided | App Store Connect monetization and SDK audit pending | Metadata after verified |
| Jev: 303 ms median vs Qwen: 375 ms median | Recorded research only | 12 authored synthetic four-decision cases × 3; `docs/research-log.md` | Do not use in App Store copy |
| Jev 36/36 vs Qwen 28/36 fully correct bundles | Recorded research only | Same benchmark; synthetic labels, not Dutch-human validation | Do not use in App Store copy |
| Qwen faster on single decisions | Recorded research only | Same benchmark | Context/technical documentation only |
| No provider retention | Unsupported | TypeSafe and Nebius policies say otherwise or need settings verification | Prohibited |
| Data Not Collected | Unsupported | Cloud text, linked anonymous ID, and durable quota behavior require disclosure review | Prohibited |
| Universal speed, accuracy, privacy, or offline translation | Unsupported | No suitable evidence | Prohibited |

## Research provenance boundary

The decision benchmark comprises 12 authored synthetic cases, repeated three times in one recorded evaluation window. It measures a four-decision routing task, not Dutch translation quality, native-device behavior, or live service performance. It reports distributions (median and empirical p95) alongside counts, and its source report records comparison conditions and limitations. Academic-research guidance was used only as high-level influence for this independent provenance/checklist approach. No CC BY-NC 4.0 text or content is copied into the app.
