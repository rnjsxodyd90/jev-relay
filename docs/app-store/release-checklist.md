# Release checklist

Status: **pre-submission candidate 1.0 (1), not submitted.** Checked items describe only the stated evidence; unsigned builds and backend tests do not establish signed or physical-device validation. This is a gate, not a final attestation.

## Product and App Review

- [x] Confirm the unsigned AppStore-configuration build is native SwiftUI with bundle ID `com.taekwon.jevrelay`, version 1.0 (1), and configured Team `53R7M78MLK`. Signing remains unverified.
- [ ] Verify the production path: editable English text -> user taps Interpret -> one Jev four-decision call -> Qwen only for novel wording.
- [ ] Verify no network request occurs from typing, opening the app, recording, editing, viewing a phrase, or playback.
- [ ] Verify uncertain, malformed, failed, timed-out, quota-limited, or unavailable cloud results fail closed to review/clarification, with no approved guess or auto-play.
- [ ] Verify manual Dutch-only `AVSpeechSynthesizer` playback and no automatic spoken result.
- [ ] Verify phrasebook save is explicit, local, inspectable, and deletable in-app; check iCloud/device backup and migration behavior.
- [ ] Verify no fake AI replay, demo result, or recorded benchmark output can be mistaken for a live result.
- [ ] Keep the backend live and accessible during review; test it from a clean reviewer-like device/network and document rate-limit behavior.
- [ ] Enter review notes from `review-notes.md`, with no credentials required.

## Permissions and device validation

- [ ] Verify microphone and Speech Recognition prompts occur only after the record tap, with clear purpose strings.
- [ ] Verify the selected speech recognizer requires on-device support and test a physical device with the expected locale.
- [ ] Capture network evidence that voice audio does not leave the device; inspect temporary files and backups to confirm it is not saved.
- [ ] Test typed input and every denied/restricted permission path.
- [ ] Test VoiceOver, Dynamic Type, offline/poor network, interruption, cancellation, stale result, and accessibility of review/clarification controls.

## Privacy, account, and security

- [ ] Audit release-binary dependencies, SDK privacy manifests, entitlement use, analytics, crash reporting, and outbound domains.
- [ ] Document actual payloads, headers, response handling, logs, retention, regions, processors, and subprocessors for backend, hosting, Supabase, TypeSafe, Nebius, CDN/WAF, and error reporting.
- [ ] Verify anonymous Supabase auth, device credential storage in Keychain only, durable user/global quotas, Row Level Security, and no client/provider secret in the binary.
- [ ] Verify first-party transcript/output logging and storage are absent, including debug, analytics, crash, proxy, and backup paths.
- [ ] Verify in-app cloud-identity deletion end to end: user action, authentication state, backend/quota rows, Supabase identity, retries/errors, backups/retention exceptions, and user-facing explanation.
- [ ] Confirm TypeSafe input retention/terms for the actual plan. Do not infer zero retention from no-training language.
- [ ] Confirm active Nebius organization-level ZDR. If it is not enabled and documented, treat inputs/outputs as provider-retained for speculative decoding under the public guide.
- [ ] Verify endpoint type/region and provider/host IP-address and request-log retention. Resolve all `Unknown` rows in `privacy-assessment.md`.
- [ ] Obtain privacy/legal review appropriate to the launch jurisdictions and publish an accurate policy.

## App Store Connect and public pages

- [x] Publish and independently open the HTTPS privacy-policy URL: https://rnjsxodyd90.github.io/jev-relay/privacy.html (19 September 2026).
- [ ] Publish a monitored public support channel, such as GitHub Issues, and independently open it. Do not list a private home address or personal phone number.
- [ ] Verify Free pricing, no ads, no IAP, age rating, category, availability, copyright, and export-compliance responses.
- [ ] Reconcile App Privacy answers with the final data-flow audit. At minimum, resolve User ID, Other User Content, Other Usage Data, diagnostics, device IDs, and IP logging.
- [ ] Do not choose `Data Not Collected` on current facts.
- [ ] Use `metadata.md` only after its factual claims are release-verified; check field character limits in App Store Connect.
- [ ] Archive screenshots/video of core flow, permission timing, account deletion, local phrase deletion, and failure-closed behavior for review/support evidence.

## Research and claims

- [ ] Keep the 12-case × 3 decision benchmark out of storefront performance/accuracy claims.
- [ ] If technical material references the research, preserve its scope: synthetic authored cases, one evaluation window, distributions/counts, Qwen faster on single decisions, and no production guarantees.
- [ ] Confirm no CC BY-NC 4.0 research text/content is copied into the app, screenshots, metadata, or policy.
