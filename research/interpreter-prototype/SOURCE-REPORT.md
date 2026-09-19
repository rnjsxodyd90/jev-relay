# Jev Interpreter

An experimental, turn-by-turn voice interpreter using TypeSafe's Jev as a fast **translation candidate selector**, not a text or audio generator.

## Run

Requires Node.js 22.9+. Run `npm install --ignore-scripts` once. The browser-based speech runtime does not need native module installation scripts.

```sh
npm install --ignore-scripts
npm start
```

Open **http://127.0.0.1:4419** in Chrome or Edge. Select **Connection** and paste your TypeSafe early-access API key. The local server retains it only in memory until it stops. The key is not validated until the first interpretation; a configured key does not mean a successful Jev call. Calls may incur TypeSafe usage charges.

Alternatively, copy `.env.example` to `.env` and set `TYPESAFE_API_KEY`. Keep `.env` private. The server also accepts `TYPESAFE_AI_API_KEY`. `TYPESAFE_MODEL` defaults to `jev-latest`. `PORT` defaults to 4418.

Type a short turn and press Interpret or Ctrl/Cmd+Enter. Press Start speaking to use your microphone; press Finish turn when done. Press Finish turn to submit the recorded audio. Recording stops after 29 seconds. Speech recognition is one turn at a time, not continuous streaming. Upload audio is also available for clips up to 30 seconds. Use the swap button for the other speaker's reply. Auto-play is opt-in and only plays Jev-approved turns. Review or baseline turns can be played manually, except clarification decisions, which contain no translated text. History is kept only in page memory; Export downloads a text file.

## Architecture

1. Browser getUserMedia + AudioWorklet captures audio and resamples it to 16 kHz. Whisper base runs locally in a browser worker using WebAssembly. No browser-vendor speech service is used. The multilingual model downloads once (about 77 MB plus runtime) and is cached locally. Audio does not leave the device.
2. The Node server requests translation from the public MyMemory API and collects up to four distinct candidate translations. Alternatives must have a reported match of at least 0.75. There may be only one candidate.
3. With a TypeSafe key, one `POST https://api.typesafe.ai/v1/systemone` request asks `jev-latest` to select a candidate or `clarify`, using the source utterance, language pair and recent conversation context.
4. A validated candidate selection with reported decision confidence >= 0.8 is labeled approved. Lower confidence, rejected candidates, malformed responses, rate limits, authentication failures and timeouts prevent automatic playback.
5. Browser speechSynthesis reads the selected translation using an installed target-language voice.

Without a key, translation works in **unverified baseline mode**, clearly labeled as not evaluated by Jev. No simulated Jev confidence is ever presented as real. Timing shows actual translation and Jev request time, not advertised model latency.

## Important limitations

- This is a prototype, **not a certified interpreter** and not suitable for medical, legal, emergency, or other high-stakes decisions.
- Jev does not accept audio or generate free-form translations. Its classification speed cannot remove speech-recognition and translation latency. It adds a decision call to the critical path. This prototype tests selection/quality gating, not a claim that end-to-end interpretation becomes faster.
- The 0.8 threshold is an experimental product rule, not a calibrated translation-quality guarantee. Jev's multilingual judgment needs evaluation on real source/target pairs. English is its strongest documented language; non-English performance varies.
- Classification cannot repair a bad candidate set. Even high-confidence selection can be wrong. When no candidate is adequate, clarification is preferable to speaking a guess.
- MyMemory is a public translation-memory service with free quotas and variable quality. The 450 UTF-8 byte input limit stays within its per-request limit. Long or CJK turns may reach this limit quickly. For production, replace it with a production translation provider and evaluate independent candidate generation.
- Microphone capture requires localhost or HTTPS and browser permission. The first model download requires an internet connection; transcription itself is local. Installed speech voices vary by operating system. Microphone capture and audible playback must be tested on your actual device.
- The source language is selected manually. This version does not do speaker diarization, simultaneous interpretation, or automatic language detection.

## Privacy and security

Audio is processed locally in the browser and is never sent to a transcription provider. Text is sent to MyMemory. When connected, source text, candidates and the last two conversation turns are sent to TypeSafe. Provider retention policies apply independently of this app. Do not submit confidential content. The app does not log transcripts or keys or save conversation history in browser storage. Google Fonts is used for typography, with system-font fallbacks.

Both servers bind only to `127.0.0.1`, restricts hosts/origins, limits request bodies and in-flight calls, serves a fixed file allowlist, and keeps the key out of frontend code. These are local-development protections, not production authentication. Do not expose this server publicly without adding authentication, quotas, HTTPS and a reviewed privacy policy. Other applications running as your local user may access the local service.

## Tests

```sh
npm test
```

19 zero-dependency unit tests cover the real request contract using mocked TypeSafe responses: candidate selection, clarification, review gating, invalid probabilities/confidence, HTTP errors, timeouts, quota handling, input validation, and unverified fallback. Tests never call a paid API.

The original browser speech-recognition service failed with a network error in Aside. Version 0.2 replaces that path with local Whisper and adds an audio-upload test path. See the in-app result for actual Jev status; configured credentials are not proof of valid API authorization.

## Files

- `launch.mjs`: starts/reuses the core and voice gateway
- `voice-server.mjs`: frontend, local model files and same-origin proxy to the core
- `server.mjs`: core API on port 4418 and server-side key handling (retained across the voice upgrade)
- `public/voice.js`, `speech-worker.js`, `recorder-worklet.js`: direct audio capture and local Whisper inference
- `pipeline.mjs`: translation retrieval, typed Jev request, response validation and decision gate
- `public/`: responsive frontend, microphone, speech playback, history and export
- `test/pipeline.test.mjs`: contract and failure-path tests

## References

- TypeSafe API: https://docs.typesafe.ai/api
- Jev capabilities: https://docs.typesafe.ai/concepts/system-one
- Models and language support: https://docs.typesafe.ai/models
- MyMemory API: https://mymemory.translated.net/doc/spec.php

## Version 0.2 repair

The UI is now at port 4419 (`VOICE_PORT`). The API core remains at 4418 (`PORT`) so the existing in-memory Jev key is preserved. `npm start` reuses the running core or starts it if necessary. If you restart the computer, reconnect your TypeSafe key or provide it through the private `.env` file. Model files under `.models/` are cached weights, never microphone recordings.

### Verified voice repair

A public spoken-audio clip was uploaded through the app, transcribed locally by Whisper, translated into Dutch, and evaluated by the configured live Jev account. Jev returned 0.76 confidence, which correctly kept auto-play paused for review. The browser microphone permission was `prompt`; physical microphone capture still requires Allow in the browser. The UI now explains that prompt and times out pending permission rather than remaining stuck.
