---
layout: default
title: Jev Relay support
---

# Jev Relay support

Contact **[rnjsxodyd@gmail.com](mailto:rnjsxodyd@gmail.com?subject=Jev%20Relay%20support)** for help or a privacy request. Do not send API keys, private conversations, authentication tokens, or personal documents by email or in a public issue.

## Set up your own provider access

Jev Relay's native BYOK build3 is in progress. It requires your own TypeSafe/Jev API key and, if you choose the optional Qwen path, your own Nebius API key. The app does not include developer-funded usage, shared keys, free credits, an owner-funded fallback, or an app-operated cloud account.

Create, fund, limit, and revoke keys in your provider account dashboards. Use the providers' current account and billing documentation for setup:

- [TypeSafe AI](https://typesafe.ai/)
- [Nebius Token Factory](https://tokenfactory.nebius.com/)

Enter each key only in the matching provider-key screen in the app. The app is designed to store keys in iOS Keychain and never display them back. Saving a key does not check it or contact a provider.

## Translate

1. Open **Translate**, enter English text, and optionally add context or tone.
2. Review the text, then choose **Translate**.
3. On the first live request, review the transmission notice and give consent.
4. The app sends a live request directly to the needed provider using your own key. A turn uses at most one Jev request and, if needed, one Qwen request. It does not retry automatically.
5. Review the Dutch result before optional playback or local saving.

The app is not for legal, medical, emergency, or other high-stakes use. Provider availability, billing, key permissions, and account limits can affect a request.

## Common issues

- **A key does not work:** confirm it belongs to the correct provider, is active, and has any required billing or permissions in that provider's dashboard. Save does not validate keys; an error may occur only on a live, consented Translate request.
- **A provider reports a spending or account issue:** manage it directly in that provider account. Jev Relay cannot add credits, change provider billing, or recover a revoked key.
- **You want to stop access:** remove the key from the app and revoke or rotate it in the provider dashboard. Removing a key does not undo provider processing already performed.
- **Microphone or speech is unavailable:** use typed input. The app is intended not to fall back to remote speech recognition.

For data handling and historical legacy-data requests, see the [privacy policy](privacy.html).

[Back to Jev Relay](index.html)
