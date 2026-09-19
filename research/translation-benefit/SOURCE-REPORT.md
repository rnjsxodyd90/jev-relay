# Does Jev provide a benefit in a translation pipeline?

## Bottom line

**Yes, selectively, in this pilot.** Jev sped up reuse of stored phrases and corrected some context decisions. **No, not as an always-on speed/cost optimization:** median full-pipeline latency and estimated token cost both increased across this selected case mix.

| Measured outcome | Qwen alone | Jev-assisted pipeline |
| --- | ---: | ---: |
| Meaning/context passes, reviewer A | 24/32 | 27/32 |
| Meaning/context passes, reviewer B | 25/32 | 28/32 |
| Natural Dutch, each reviewer’s aggregate | 29/32 | 29/32 |
| Median response latency, all cases | 739 ms | 936 ms |
| Mean response latency, all cases | 735.5 ms | 835.8 ms |
| Median latency, 8 memory-eligible cases | 730 ms | 283 ms |
| Appropriate clarify action, 4 required cases | 1/4 | 4/4 |
| Translation-model calls | 32 | 23 |
| Jev calls | 0 | 32 |
| Estimated token cost for 32 cases | $0.0011916 | $0.002009872 |

The strict primary outcome is correct action AND meaning preservation AND context/register compliance. Naturalness is assessed separately. On the same three cases, both raters marked baseline failure and assisted success; neither marked an assisted regression. This is **+3/32, or +9.4 percentage points**, not proof of a population-wide improvement (exact paired McNemar p=0.25).

The reviewers differed on one deadline interpretation in both arms. Their absolute score range is retained instead of forcing a favorable tie-break. Other disagreements concerned subdimensions or naturalness, not which arm won. This adjudication does not change the comparative three-case benefit.

## Concrete gains

1. Wildlife context: `Keep the bat inside until sunset.` Baseline translated bat as `knuppel` (a club). Jev-assisted output correctly used `vleermuis`.
2. Plumbing context: `The seal is damaged.` Baseline used `zegel` (a stamp/seal). Jev-assisted output used `afdichting` (a gasket/seal).
3. Missing gestures: `Send the file to him, not him.` Baseline emitted an equally ambiguous translation. The assisted system asked which recipient was meant. The question’s phrasing still needs polish.

Seven of eight eligible phrase-memory cases bypassed the generative translator. The median for all eight memory-eligible cases fell by **61.2%**. Neither of the two deliberately negated near-matches incorrectly selected a positive stored phrase.

Two clarification cases used generic canned questions. These chose a safer action, but the blind reviewers did not count them as full primary successes because they did not ask specifically for the missing information. Thus “4/4 appropriate clarify actions” must NOT be presented as four fully adequate clarifications.

## Tradeoffs

Across the whole run, assisted median latency was **26.7% higher**, and estimated token cost was **68.7% higher**. The paired mean latency delta was +100.3 ms, with a case-bootstrap 95% interval of [-34.5, 225.9] ms. The set is selected, not a random sample of conversations, so this interval is descriptive and does not establish a production effect.

Jev reduced Qwen cost from $0.0011916 to $0.0008752, but its own estimated $0.001134672 made total cost higher. Both totals are tiny because the set is small. The estimate excludes audio services, app hosting, warmups and the separate AI-review sessions; it is not a billing invoice.

Rates used: Qwen $0.10 per million input tokens and $0.30 per million output tokens, from the live provider’s saved `pricing` fields; Jev $0.042 per million input tokens from the TypeSafe model documentation. `provider-model-metadata.json` and all usage counters are included.

A separately labeled **counterfactual replay**, not another live experiment, uses Jev only when memory candidates are present. Recombining those recorded rows yields mean 663 ms instead of baseline 735.5 ms, but cost is still about 17.1% higher. Do not present this replay as a measured production deployment.

## Fairness and protocol

- 32 synthetic fixed English-to-Dutch cases: 8 memory paraphrases, 8 terminology senses, 4 register cases, 6 meaning/negation/number cases, 2 negated memory near-matches, and 4 required clarifications.
- Cases and protocol were frozen and SHA-256 hashed before the live run (`frozen-protocol.json`). No output-driven case deletion or threshold tuning was performed.
- Both arms receive **identical source, context, sense options and memory candidates**. Neither receives the gold/reference fields.
- Both use Qwen/Qwen3-30B-A3B-Instruct-2507, temperature 0, JSON output, max 256 tokens, and the same base instructions.
- The assisted arm asks Jev for action/register and, where relevant, memory/sense choices. High-confidence memory matches (>=0.90 plus translate confidence >=0.75) or clarification decisions (>=0.80) may skip Qwen. Other turns pass advisory labels to the same translator. Qwen is explicitly told to check the advice, not blindly obey it.
- No false cache hits or false abstentions are counted as successes. Invalid Jev responses would be logged and fall back to Qwen with their latency included; no such fallback occurred in the measured run.
- Deterministic shuffled case order, alternating within-pair arm order, one excluded warmup per arm. Every API stage is included in assisted latency.
- Timings are complete text-response wall times, not hardware inference time or time-to-first-token. Microphone, ASR, TTS and Dutch pronunciation are **not tested here**.
- Two independent blinded AI sessions scored randomized anonymized outputs. These are not native Dutch human raters; judgments may share model biases. See both raw reviews and disagreement details.

The effect is of the **combined assisted pipeline**, not proof that any one label type is uniquely beneficial. The memory is curated test data, not independently professionally certified material. There is no comparison against cheaper fuzzy matching, embeddings, or deterministic routing. One fast inexpensive translation model is not representative of every possible baseline.

## Recommendation

Use Jev selectively for semantic matching against controlled translation memory and for context-sensitive routing where errors matter. Do not put a mandatory Jev call in front of every novel utterance on the strength of this test. Do not market the result as Jev generating translations or universally accelerating live interpretation.

## Reproduce

Requires Node.js 22.9+, no dependencies.

1. Copy `.env.example` to `.env` and provide TypeSafe and Nebius keys. Never commit or share `.env`.
2. Start `npm run gateway` in one terminal (localhost port 4423). It has request/token caps and expires after 45 minutes.
3. In a second terminal run `npm run benchmark` and then `npm run summary`.
4. Preserve original JSON results before rerunning; new runs overwrite them and may incur API charges.
5. Use the supplied rubric for independent blind reviews. `combine-reviews.mjs` and `finalize.mjs` reproduce review aggregation with the included reviews.

The run makes at most 72 Qwen calls and 40 Jev calls. Actual run counts, including warmups, are in `completed.json`. The core gateway’s broader cap is 150 Jev calls and 1.5 million reported input tokens. Keys are held only in process memory; the source package includes no credentials.

## Evidence

- `cases.json`, `frozen-protocol.json`, `run-order.json`
- `results.json`, `warmup-results.json`, `completed.json`
- `provider-model-metadata.json`, `performance-summary.json`, `paired-results.json`
- `blind-review-input.json`, `REVIEW-RUBRIC.md`, `review-a.json`, `review-b.json`
- `review-summary.json`, `quality-changes.json`, `final-summary.json`
- `selective-replay.json` (modeled replay, NOT a second live run)

References:
https://docs.typesafe.ai/models
https://docs.typesafe.ai/api
https://docs.tokenfactory.nebius.com/api-reference/models/list-models
https://docs.tokenfactory.nebius.com/api-reference/inference/create-chat-completion
