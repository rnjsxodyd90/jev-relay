---
layout: default
title: Jev Relay privacy policy
---

# Jev Relay privacy policy

Effective date: 19 September 2026.

Jev Relay is operated by **Tae yong Kwon**. Contact **[rnjsxodyd@gmail.com](mailto:rnjsxodyd@gmail.com?subject=Jev%20Relay%20privacy)** with privacy questions or requests.

## On your device

- Optional microphone input is transcribed using on-device speech recognition. If on-device recognition is unavailable, the app keeps typed input available rather than uploading audio for recognition.
- The app does not upload or save microphone recordings.
- Unsaved source text, context, and results are kept in the current app session rather than automatically added to a cloud history.
- Phrases are saved locally only when you choose to save them. You can delete individual saved phrases or clear them all.
- Transmission preferences are stored locally. Anonymous service credentials are protected by the device's Keychain. Provider API keys are never included in the app.

## When you choose live interpretation

Before the first live request, the app identifies the external services and asks for your permission. Choosing **Translate** sends the edited English text, context, and relevant routing information over HTTPS to the Jev Relay backend, hosted by **Supabase**. The relay database is in Ireland. This does not establish the processing location of every Supabase Edge Function or AI provider.

The backend sends the text, context, supplied word-meaning choices, and library phrase candidates to **TypeSafe AI (Jev)** to choose the next action, phrase reuse, tone, and word meaning. When new Dutch wording is needed, the relevant text, context, and decisions are also sent to **Nebius Token Factory (Qwen)**.

Your microphone recording is not included. Your anonymous app identity is not deliberately included in the prompts sent to either AI provider. Text you type may itself contain personal information, so avoid sending confidential, sensitive, or high-stakes material.

## Anonymous identity and service limits

The first permitted live use creates an anonymous Supabase identity. The app does not ask you for a name, email address, phone number, or social login. Random authentication identifiers and protected access/refresh credentials allow the backend to authenticate requests.

The backend keeps limited account metadata, pseudonymous usage counters, short-lived request receipts to prevent duplicate processing, and global aggregate counters to enforce service limits and protect against abuse. These records are not a conversation history. They do not contain source text, context, audio, translations, or model decisions.

## Retention and deletion

Our application code does not log or persist the text of interpretation requests or responses. This is not a claim that every infrastructure or AI provider retains nothing. Hosting and authentication systems may retain operational, connection, security, and authentication records under their own policies.

TypeSafe's policy covers retention of input as reasonably necessary for its service and states that it does not train or fine-tune models on customer input. Nebius provides an optional Zero Data Retention setting; unless that setting is enabled for the service account, its policy permits retention of inputs and outputs for speculative decoding. Do not assume that selecting a non-storage API option is equivalent to a provider-wide zero-retention agreement.

In **Settings**, **Delete cloud identity** requests hard deletion of the current anonymous authentication identity and its linked app account metadata. The app clears its local credentials only after the service confirms deletion. This identity cannot be recovered. Current pseudonymous quota counters and non-identifying global totals remain through the applicable UTC quota period so deletion does not erase service limits. Duplicate-request receipts cover the current and previous UTC day. Expired counter and receipt data is scheduled for bounded hourly cleanup; paused hosting, a failed job, or a backlog can extend that period. Local saved phrases are deleted separately when you choose that option.

Deletion does not reverse processing already performed by an AI provider or automatically erase records that a provider must retain. Contact us for assistance with a privacy request. Support messages are used to handle your request and retained only as reasonably needed for that purpose or applicable legal obligations.

## Your choices and rights

You can use the local phrasebook without permitting live interpretation, decline microphone or speech permissions, type instead of dictating, review text before sending it, stop playback, revoke permission for future cloud transmissions, and delete local phrases or the cloud identity.

Depending on your location, you may have rights to access, correct, delete, restrict, or object to processing of personal data, receive a copy of relevant data, withdraw consent for future optional processing, or complain to a data-protection authority. Email the contact above for help. We may need enough information to identify the relevant request without collecting unnecessary additional data.

Processing is used to provide the features you request, with consent for optional microphone access and AI transmission where applicable, and to maintain service security and usage limits. We do not include advertising or analytics SDKs and do not use app data for cross-app advertising tracking. No personal information is sold by the app operator.

## Providers and international processing

An EU database location does not guarantee that all request processing remains in the EU. Supabase Edge Functions, AI providers, and their subprocessors may process data internationally under their applicable terms and safeguards. Their policies describe their own obligations, retention, and contacts:

- [Supabase privacy policy](https://supabase.com/privacy)
- [TypeSafe AI privacy policy](https://typesafe.ai/legal/privacy-policy)
- [TypeSafe data-processing addendum](https://typesafe.ai/legal/data-processing)
- [Nebius Token Factory privacy policy](https://docs.tokenfactory.nebius.com/legal/privacy-policy)
- [Nebius data-handling and retention guide](https://docs.tokenfactory.nebius.com/legal/legal-quick-guide)

The public support website is hosted by GitHub Pages, which may process standard web connection logs under [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). No advertising or analytics scripts are added to these support pages.

## Changes

We will update this page when the app's processing changes. A materially different optional transmission purpose will require an appropriate updated in-app notice rather than relying only on a website change.

[Support](support.html) · [Back to Jev Relay](index.html)
