# Research log

[Research archive](../research/README.md) · [ADRs](decisions.md) · [Roadmap](roadmap.md)

This log records the sequence of inspected local research artifacts. Results are recorded observations, not live measurements or production guarantees.

## 1. Local Whisper repair in the interpreter prototype

The legacy prototype first depended on browser speech recognition, which failed with a network error in the recorded environment. Version 0.2 replaced that path with local browser Whisper: audio was captured in the browser, resampled to 16 kHz, and transcribed by a WebAssembly worker. A public uploaded-audio clip exercised this repair; the recorded Jev review confidence was 0.76, so auto-play correctly stayed paused for review.

The repair did **not** verify physical microphone capture. Browser permission was still `prompt`, so a real device must grant permission and be tested. Dutch human review and audible Dutch playback validation also remain open.

Evidence: [prototype report](../research/interpreter-prototype/SOURCE-REPORT.md), [voice gateway](../research/interpreter-prototype/voice-server.mjs), [browser worker](../research/interpreter-prototype/public/speech-worker.js), [pipeline tests](../research/interpreter-prototype/test/pipeline.test.mjs).

## 2. Open-ended Jev translation decoding: negative result

The next experiment tested whether Jev could construct open-ended English-to-Dutch translations through typed choices. The tested decoders were not usable translators and did not show a speed advantage: parallel characters preserved meaning in 0/12 cases at a 698 ms median, hierarchical parallel words 0/12 at 941 ms, and the sequential-word attempt 0/3 at 628 ms failure latency. The sequential character development attempt hit its 28-call cap after 9,103 ms rather than completing a translation.

The positive control matters: Jev selected a complete candidate translation for `I am tired.` when that candidate was offered. That verifies constrained selection, not free-form generation. The comparison outputs were MyMemory 11/12 at 546 ms and Qwen 12/12 at 372 ms, based on blinded AI review. This does not prove that every future decoder is impossible; it rejects only the tested implementations.

Evidence: [decoding report](../research/decoding/SOURCE-REPORT.md), [fixed cases](../research/decoding/test-cases.json), [benchmark outputs](../research/decoding/benchmark-results.json), [comparison outputs](../research/decoding/comparison-results.json), [review](../research/decoding/quality-review.json), [positive control](../research/decoding/positive-control.json).

## 3. Selective translation-memory benefit, but no always-on speed/cost benefit

A 32-case synthetic English-to-Dutch pilot then evaluated a Qwen-only pipeline against a Jev-assisted one. The assisted route improved selected context outcomes: reviewer A marked meaning/context passes 27/32 versus 24/32, reviewer B 28/32 versus 25/32, and three cases changed from failure in baseline to success in assisted output. For the eight memory-eligible cases, seven bypassed the translation model and the median fell from 730 ms to 283 ms. Required clarification actions improved from 1/4 to 4/4, although two canned questions were not specific enough to count as complete primary successes.

That is not an always-on optimization. Across the whole selected case mix, median latency increased from 739 ms to 936 ms and estimated token cost increased from $0.0011916 to $0.002009872. The recorded selective replay is a counterfactual recombination, not a second live experiment. The supported conclusion is selective use for controlled translation memory and context-sensitive routing, not universal live-interpretation acceleration.

Evidence: [translation report](../research/translation-benefit/SOURCE-REPORT.md), [frozen protocol and hashes](../research/translation-benefit/frozen-protocol.json), [paired outputs](../research/translation-benefit/results.json), [performance summary](../research/translation-benefit/performance-summary.json), [blind reviews](../research/translation-benefit/review-a.json) and [B](../research/translation-benefit/review-b.json), [review summary](../research/translation-benefit/review-summary.json), [selective replay](../research/translation-benefit/selective-replay.json).

## 4. Same-task typed decision benchmark

The final benchmark isolated the proposed role for Jev: one native typed request returning four routing decisions, namely translate/clarify, translation-memory reuse/miss, register, and lexical sense. It used 12 unique synthetic cases repeated three times. In the recorded four-decision task, Jev had a 303 ms median complete response versus Qwen's 375 ms, empirical p95 378 ms versus 652 ms, and 36/36 fully correct bundles versus 28/36. This is a scoped same-task result, not an inference-speed claim.

The important boundary is that Qwen was faster on singles: 209.5 ms versus 281 ms for one memory-match decision, and 221.5 ms versus 285 ms for one word-sense decision. Qwen returned the exact word-sense ID in 30/36 trials but returned the correct criterion description rather than its ID in six others; semantic word-sense credit was therefore 36/36 for both providers, while the six outputs remain contract errors. Do not represent this as a broader Jev speed claim.

Evidence: [decision benchmark report](../research/decision-speed/SOURCE-REPORT.md), [frozen cases](../research/decision-speed/cases.json), [protocol](../research/decision-speed/protocol.json), [raw results](../research/decision-speed/results.json), [summary](../research/decision-speed/summary.json), [gold review](../research/decision-speed/gold-review.json), [claim scope](../research/decision-speed/supported-claim.json), [validation audit](../research/decision-speed/validation-audit.json), [cost summary](../research/decision-speed/cost-summary.json).

## Shared known gaps and interpretation limits

- Real microphone permission/capture remains unverified on a physical device.
- The quality reviews were blinded AI reviews, not Dutch human review.
- Timing is sensitive to region, network/cache state, provider queueing, and load.
- Gold labels and translation-memory material were authored synthetic test material.
- None of these experiments guarantees production quality, latency, availability, privacy, cost, or safety.
