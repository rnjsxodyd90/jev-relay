# App Review notes draft

Paste only after the release checklist is complete and the backend is live for review.

## Notes for App Review

Jev Relay is a native SwiftUI, English-to-Dutch, turn-based translation app. It is free, contains no ads, and has no in-app purchases.

**No credentials are required.** The app creates an anonymous session automatically. There is no reviewer account, username, password, or subscription flow to provide.

### Exact review flow

1. Launch the app. No reviewer account, username, or password is required.
2. Enter English text in the editable source field, for example: `Would you mind saying that again?`
3. Optionally add the available context, then tap the explicit **Send** control. The anonymous session is created or refreshed as needed for that cloud request. Text is not sent merely by typing, recording, or opening the app.
4. The service makes one Jev routing call for action, phrasebook reuse/miss, register, and word sense. When new wording is needed, it makes a Qwen translation call. A phrasebook match or clarification path does not need a Qwen wording call.
5. Review the returned Dutch wording. If the app cannot resolve context, receives uncertain or invalid decisions, or a service is unavailable, it presents clarification or review rather than presenting an approved guess.
6. Tap Dutch playback only if you want to hear it. Playback is manual and Dutch-only; the app does not auto-play a translation.
7. Save a phrase explicitly to the local phrasebook if desired. Use the in-app delete control to remove a saved phrase. Use the in-app account deletion control to delete the cloud identity.

### Permissions

The app requests microphone and Speech Recognition permission only after the reviewer taps the voice-recording control. Voice input is optional. Speech recognition is required to use on-device support; recorded audio is not intentionally uploaded or saved by the app. Typed input remains available if permission is denied.

### Review environment

- Live backend URL: `[VERIFY AND INSERT ONLY IF A NON-PUBLIC TEST ROUTE IS REQUIRED]`
- Expected availability during review: `[VERIFY]`
- If rate limits are active, reviewer allowance: `[VERIFY]`
- Support contact: `[INSERT PUBLISHED SUPPORT URL]`

The build contains no fake AI replay mode. Recorded research evidence, if present in the source repository, is not presented as a live translation response in the native app.
