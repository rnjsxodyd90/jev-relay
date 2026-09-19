# Verification record

- 19 network-free automated tests currently pass: pure gate validation, provider behavior, budgets, failure handling, HTTP origins/hosts, body bounds, concurrent turns, configuration privacy and evidence completeness.
- All 36 recorded native Jev bundle responses pass the new parser. This caught and corrected the invalid assumption that native confidence equals the chosen option probability.
- Frozen decision-case SHA-256 hash still matches its pre-run protocol.
- The new browser interface loaded pinned local Whisper assets and transcribed the existing public speech audio sample locally in 6,804 ms during this session. This is a smoke check, not a speech-latency benchmark.
- A truncated audio fixture was rejected without submitting text to a provider.
- Physical microphone capture was not exercised; browser permission and actual input-device validation remain open.
- An independent source audit found no blocking backend issues. This is not a professional security audit.

## Live provider smoke checks

All three synthetic routes passed using the actual server library and configured providers: stored-phrase reuse without Qwen, new wording through Qwen, and clarification without Qwen. Four total provider calls were used. Inputs, outputs and timings are in [live-smoke.json](live-smoke.json); these are integration probes, not another benchmark or native-human quality certification.

## Browser checks and remaining limits

Workbench, Evidence, Integration, case/task/repetition controls, live-disabled setup, pinned local speech loading and audio-file transcription were exercised. Desktop layout was inspected in the browser. Responsive CSS is included, but an actual phone-width/device check remains pending because the browser bridge does not expose viewport resizing. No claim of completed mobile-device QA is made.

The private GitHub repository and linked private Project board were created. Source and CI verification are recorded at publication.

The live browser form also completed a real stored-phrase request: Jev selected `repeat`, returned `Kunt u dat herhalen?`, and skipped the translator. A local Dutch voice (Ellen) was available, but auditory/native-speaker pronunciation assessment remains unverified. Editing source/context invalidates prior output; voice and live request operations reject stale completions.
