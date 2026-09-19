# Jev open-ended decoding experiment

## Result

**These tested decoding methods do not make Jev a usable open-ended Dutch translator and do not show a speed advantage.** This is evidence about the implementations tested with Jev 1.13.0, not proof that every future decoder is impossible.

| Method | Test sentences | Meaning preserved (blinded AI review) | Median API/wall time |
| --- | ---: | ---: | ---: |
| Jev parallel characters | 12 | 0/12 | 698 ms |
| Jev hierarchical parallel words | 12 | 0/12 | 941 ms |
| Jev hierarchical sequential words | 3 | 0/3 | 628 ms* |
| MyMemory translation service | 12 | 11/12 | 546 ms |
| Qwen3-30B-A3B-Instruct-2507 via Nebius | 12 | 12/12 | 372 ms |

*The sequential word decoder stopped immediately on unavailable-token decisions. This is failure latency, NOT the time to produce a valid sentence. The same caveat applies to fast invalid character/parallel outputs.

The successful Qwen result was about 1.88x faster than the failed parallel-character result and 2.53x faster than the failed hierarchical parallel-word result by median wall time in this small run. These are not general model-speed rankings.

## What was tested

- **Parallel character decoding:** 72 independent typed-choice questions ask for the character at each target position. This can in principle form new strings without a word dictionary; the alphabet and output length are bounded.
- **Sequential character decoding:** append one chosen character per API call, conditioning on the emitted prefix. The development sentence `I am tired.` produced `ia` followed by spaces, reached the 28-call cap, and took 9,103 ms. It was stopped at the cap, not counted as a completed translation.
- **Hierarchical word decoding:** a fixed independent Dutch frequency vocabulary of 8,192 words is split into groups of up to 128. Jev first chooses an alphabetical group, then chooses the word. The parallel version asks 16 positions in two API stages. The sequential version conditions on the previous emitted tokens. Literal names/numbers and punctuation are also allowed. This word variant is vocabulary-constrained, not unrestricted language generation.
- **Positive control:** Jev chose `Ik ben moe.` for `I am tired.` from nine complete candidate translations, with reported confidence 1.0. This verifies that the key/model worked and that selection can succeed while construction fails. The control is NOT evidence of open-ended translation.

No MyMemory output, Qwen output, reference translation, or complete candidate translation was supplied to the open-ended Jev decoders. References were for review only. The whole-translation positive control was separate.

## Protocol and limitations

Twelve short, fixed English-to-Dutch cases exercise negation, tense, questions, word order, names, numbers, an idiom and temporal relationships. The test set was fixed before held-out outputs were observed. The development sentence `I am tired.` was separate. The first 3 held-out cases also ran through sequential word decoding; it failed immediately, so the remaining 9 were not run through that extra mode.

An initial 1,024-way direct word-choice attempt was rejected: the live API allows at most **255 choices per question**. An initial larger parallel-character request was also rejected with `max_tokens_exceeded`. The hierarchy and shorter prompts were adaptations to these observed API limits. These setup failures are preserved in `pilot-results.json`; they are not included in successful-call timing summaries.

Jev used `jev-latest`, with responses identifying `jev-1.13.0`. Qwen used the exact model ID shown in the table, temperature 0 and max 160 output tokens. One development warmup was excluded from each timing table. No reasoning model was deliberately chosen to inflate baseline latency.

Times are local wall-clock request-to-complete-response durations, including network, provider queueing and all decoder stages. They are **not hardware inference times**, and they exclude speech recognition, recording, and playback. A decoder must first produce valid text before any real-time voice-translation claim is meaningful. This was one small run, with different providers and unequal prompt shapes. There is no confidence interval or production-load guarantee.

The initial saved OpenAI comparison credential returned 429/no credits. No credits were purchased. A working saved Nebius credential was used for Qwen. MyMemory is an undisclosed translation-service backend, not a named-model benchmark; it is included because it was the original app's translator. Its development output for `I am tired.` was wrongly `Alstublieft.`, reinforcing that the original app's quality was not dependable.

Quality counts are from a **blinded AI review**, not a native Dutch human evaluation or proof of 100% accuracy. References are not exact-match rules. The Qwen idiom wording and voice pronunciation still warrant human review. This experiment does not verify or repair the prior app's physical microphone permission or Dutch playback.

The gateway reported 962,804 Jev input tokens over successful experiment calls, including development/control calls. At the documented $0.042 per million input tokens this is approximately $0.0404, an estimate rather than an invoice. Request counts include failed setup calls. Qwen usage is recorded separately in `comparison-results.json` and `comparison-warmup.json`.

## Reproduce

Requires Node.js 22.9+. No dependencies. Do not share `.env` or put API keys into source files.

1. Copy `.env.example` to `.env` and set your TypeSafe and Nebius keys.
2. Start the capped gateway in one terminal: `npm run gateway`.
3. In a second terminal run `node pilot-adapted.mjs`, then `npm run benchmark`.
4. Run `npm run comparison` for the Qwen comparison.

The local gateway listens at `127.0.0.1:4423`, holds keys in memory, accepts only local clients without a browser Origin header, caps Jev requests at 150 and reported input tokens at 1.5 million, caps optional OpenAI requests at 16, and expires after 45 minutes. It is a local test harness, not a public service. Live API calls may incur charges. The benchmark writes new JSON outputs, so preserve the included results before rerunning.

`pilot.mjs` and `decoder-initial.mjs` preserve the initial API-limit exploration; the main experiment is `decoder.mjs` and `run-benchmark.mjs`. `run-comparison.mjs` makes at most 13 Nebius calls (one warmup plus twelve cases) and stops on a provider error.

## Evidence files

- `test-cases.json`: fixed sources, example references and targeted phenomena
- `benchmark-results.json`: all held-out Jev/MyMemory outputs, timing, usage and confidence
- `comparison-results.json`: all Qwen outputs, timing and token usage
- `pilot-adapted-results.json`, `pilot-sequential-characters.json`: development results
- `positive-control.json`: complete typed-choice control response
- `latency-summary.json`: aggregated measured timing
- `blind-quality-input.json`, `quality-review.json`: blinded review material and verdicts
- `run-complete.json`: completion time and gateway counters
- `ATTRIBUTION.md`: vocabulary source and license

Official API/model references:
https://docs.typesafe.ai/api
https://docs.typesafe.ai/models
https://docs.tokenfactory.nebius.com/api-reference/inference/create-chat-completion
