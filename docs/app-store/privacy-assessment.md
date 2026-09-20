# Privacy assessment draft for native BYOK build3

Status: **working draft, not legal advice or final attestation.** Build3 is being implemented and tested. The existing conservative App Privacy declaration remains six types, all for App Functionality, linked to the user, and not used for tracking. That declaration is not a full privacy audit and must be revalidated against the final build3 binary and operational configuration.

## Intended data flow to verify

### On device

- Typed source text, optional context, and unsaved results remain in the active session unless a user saves a phrase locally.
- Optional speech recognition is intended to be on device. Audio is not intended to be uploaded or saved by the app. Physical-device and network verification remain open.
- TypeSafe/Jev and Nebius API keys are intended to be stored only in iOS Keychain with `WhenUnlockedThisDeviceOnly` accessibility. They are never bundled or shown back. Secure entry buffers should clear after save, app backgrounding, and screen disappearance.

### On explicit live translation

- Save performs no API-key validation and no network request.
- After consent and Translate, the TypeSafe/Jev key should be sent only as Authorization to its fixed HTTPS endpoint, directly from the client. The Nebius key should be sent only as Authorization to its fixed HTTPS endpoint, directly from the client.
- Keys must not be sent to the operator, Supabase, an app relay, or the other provider. A live turn is bounded to one Jev request plus an optional one Qwen request, with no automatic retries and fixed text/output limits.
- The user controls provider billing, spending, and revocation through provider accounts. There is no developer-funded usage, shared provider key, shared quota, anonymous Supabase identity, or operator cloud identity.

## Legacy boundary

The old backend is disabled after removal of only `TYPESAFE_API_KEY` and `NEBIUS_API_KEY` from the JevRelay Supabase project. Last observed: health `503`, `ready: false`; legacy `deleteSession`: true. This does not delete metadata from old testing, revoke other provider project keys, or establish provider deletion/retention terms.

Legacy backend-held authentication, quota, receipt, or infrastructure metadata needs accurate historical deletion and data-rights handling separate from a user removing a new local key.

## Conservative App Privacy labels retained

| Apple data type | Purpose | Linked | Tracking |
|---|---|---:|---:|
| Identifiers: User ID | App Functionality | Yes | No |
| User Content: Other User Content | App Functionality | Yes | No |
| Usage Data: Other Usage Data | App Functionality | Yes | No |
| Location: Coarse Location | App Functionality | Yes | No |
| Diagnostics: Other Diagnostic Data | App Functionality | Yes | No |
| Other Data Types | App Functionality | Yes | No |

Do not select Data Not Collected on the present record. The labels are conservative disclosures, not proof that the final BYOK design has been fully audited. The app does not use GPS, ads, analytics SDKs, or tracking.

## Open privacy gates

- Independently audit TypeSafe and Nebius content retention, no-training terms, ZDR status, deletion, regions, contracts, and subprocessors.
- Audit infrastructure logs, including possible IP address, user agent, IP-derived location, request status/timing, diagnostics, retention, backups, and residency.
- Verify the final signed build's Keychain accessibility, secure-buffer clearing, direct endpoint enforcement, Authorization-only key handling, request bounds, no-save network activity, and absence of secrets in the bundle.
- Complete physical-device microphone, on-device speech, storage, and network tests.
- Reconcile legacy metadata retention/deletion and data-rights support with the public policy.
