---
layout: default
title: Jev Relay privacy policy
---

# Jev Relay privacy policy

Effective date: 20 September 2026. This policy describes the planned native BYOK build3 client. Build3 is still being implemented and tested; this page is not a release or QA attestation.

Jev Relay is operated by **Tae yong Kwon**. Contact **[rnjsxodyd@gmail.com](mailto:rnjsxodyd@gmail.com?subject=Jev%20Relay%20privacy)** with privacy questions or requests.

## On your device

- You may type English source text and optional context. Unsaved text and results remain in the current app session unless you choose to save a phrase locally.
- Optional microphone input is intended to use on-device speech recognition only. The app does not use GPS, a device-location API, or location permission.
- The app is designed to store your TypeSafe/Jev and optional Nebius API keys in iOS Keychain with `WhenUnlockedThisDeviceOnly` accessibility. Keys are not bundled with the app and are not shown back to you after saving.
- Secure key-entry buffers are intended to clear after saving, when the app backgrounds, and when the entry screen disappears.
- The app has no advertising or analytics SDKs and does not use data for cross-app tracking.

## Your provider keys and live translation

Jev Relay is bring-your-own-key (BYOK). Each user supplies and pays for their own TypeSafe/Jev API key and, if using Qwen, their own Nebius API key. The app provides no developer-funded usage, shared developer keys, owner-funded fallback, quota, anonymous Supabase signup/refresh, operator cloud identity, or shared service allowance.

Saving a key does not validate it or make a network request. After you explicitly consent and choose **Translate**, the app may make at most one Jev request and, only when needed for the result, one Qwen request. It does not automatically retry. Fixed source-text and output limits apply.

The TypeSafe/Jev key is sent only as Authorization to TypeSafe's fixed HTTPS endpoint. The Nebius key is sent only as Authorization to Nebius's fixed HTTPS endpoint. A key for one provider is not sent to the other provider. Keys are not sent to the app operator, Supabase, or an app-operated relay. Do not enter a key in any place other than the app's provider-key entry screen.

Your translated content and any optional context are sent to the provider needed for the live request. Text you enter may contain personal information. Do not send confidential, sensitive, or high-stakes material unless you are authorized to do so.

## Billing, retention, and provider controls

You manage billing, spending limits, key revocation, and any available retention or account settings through your own provider accounts. The app contains no purchase or provider-signup links and does not promise free credits or a particular price.

Provider content retention and account controls are governed by the applicable provider terms and settings. No provider-wide zero-data-retention arrangement has been verified for this app. Do not treat direct routing or a no-training statement as a promise of no retention.

- [TypeSafe AI privacy policy](https://typesafe.ai/legal/privacy-policy)
- [TypeSafe data-processing information](https://typesafe.ai/legal/data-processing)
- [Nebius Token Factory privacy policy](https://docs.tokenfactory.nebius.com/legal/privacy-policy)
- [Nebius Token Factory terms](https://docs.tokenfactory.nebius.com/legal/terms-of-service)
- [Nebius data-handling guide](https://docs.tokenfactory.nebius.com/legal/legal-quick-guide)

## Infrastructure and historical legacy data

The direct native build is designed without operator cloud identity or a live relay. The legacy Jev Relay Supabase backend was confirmed disabled after its `TYPESAFE_API_KEY` and `NEBIUS_API_KEY` secrets were removed: the health endpoint returned `503` with `ready: false`, and its legacy `deleteSession` operation returned true. No other provider project keys were revoked as part of that action.

Removing a key from the new app does not erase metadata created during earlier legacy testing. Historical legacy authentication, quota, receipt, or infrastructure records remain subject to their applicable retention and deletion processes. Contact the operator for a privacy request concerning legacy app-held records. Provider processing already performed is controlled separately by the relevant provider.

Infrastructure and support systems may process operational records such as IP address, user agent, IP-derived approximate location, request timing/status, and diagnostics. This is not GPS collection, advertising, analytics, or a claim that every field is retained for every request. Retention, backups, logging, residency, and subprocessors require further verification.

## Existing App Privacy declaration

The existing conservative App Store declaration contains six data types, each labeled **App Functionality**, **linked to the user**, and **not used for tracking**: User ID, Other User Content, Other Usage Data, Coarse Location, Other Diagnostic Data, and Other Data Types. These labels are retained conservatively pending revalidation against the final build3 binary and operations. They are not a full privacy audit or a claim that all data is collected in the same way by build3.

## Your choices and rights

You can use local features without adding provider keys, choose not to use microphone features, review text before translating, avoid saving phrases, remove keys from the app, and revoke keys through the relevant provider dashboard. Depending on your location, you may have rights to access, correct, delete, restrict, object to, or receive a copy of applicable personal data. Email the contact above for help with an operator-held legacy-data request.

The public support website is hosted by GitHub Pages, which may process standard web connection logs under [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). No advertising or analytics scripts are added to these support pages.

## Changes

I will update this policy when the processing design or verified release behavior changes. Material changes to optional transmission require an appropriate in-app notice.

[Support](support.html) · [Back to Jev Relay](index.html)
