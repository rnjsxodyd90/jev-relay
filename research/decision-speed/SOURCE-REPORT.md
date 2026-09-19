# Where Jev provided faster useful decisions

## Supported result

On **12 synthetic four-decision routing cases, repeated three times**, Jev 1.13.0 returned the same requested decision fields faster than Qwen3-30B-A3B-Instruct-2507 via Nebius:

| Four-decision routing metric | Jev | Qwen |
| --- | ---: | ---: |
| Median complete API response | 303 ms | 375 ms |
| Empirical p95 | 378 ms | 652 ms |
| Fully correct bundles | 36/36 | 28/36 |
| Correct individual labels | 144/144 | 136/144 |
| Estimated token cost, 36 requests | $0.002093238 | $0.0034497 |

That is **1.24x median speed**, or **19.2% less median time**, with **42.0% lower p95** and **39.3% lower estimated token cost** for this task in this run. Do not call 1.24x speed “24% less latency”; those are different calculations.

The practical use case is a **multi-decision gate** that returns, in one call:
1. Translate now or ask for clarification?
2. Reuse a stored translation or declare a memory miss?
3. Which formality/register is required?
4. Which lexical sense is intended?

This is not Jev generating free-form translations. It is a native typed-decision service performing a job that would otherwise be assigned to a generative model. The downstream translator can still run when new wording is needed.

## The negative results are included

| Same-task median | Jev | Qwen | Faster provider |
| --- | ---: | ---: | --- |
| One memory-match decision | 281 ms | 209.5 ms | Qwen |
| One word-sense decision | 285 ms | 221.5 ms | Qwen |
| Four routing decisions | 303 ms | 375 ms | Jev |

Do not claim that Jev was universally faster. In this test its best case was multiple useful decisions in one request, not isolated one-label classification.

## Correctness and representation

- Memory matching: both providers selected the gold label in all 36 measured trials.
- Word sense: Jev returned correct valid IDs in 36/36. Qwen returned correct IDs in 30/36 and the exact correct criterion description rather than its ID in 6/36. Therefore **semantic word-sense accuracy was 36/36 for both**. The six description outputs are contract errors, not six wrong meanings.
- Four-decision bundles: both providers returned valid labels in all trials. Jev matched all gold labels in all 36 bundles; Qwen missed 8 labels across 8 bundles. These failures are decision differences, not format failures.
- Qwen bundle label counts: action 33/36, memory 34/36, register 33/36, sense 36/36. Jev: 36/36 on each field.

Gold labels were authored from the explicit source/context. An independent pre-run AI sanity check flagged one qualifier mismatch; “a bit” was removed from two source inputs before any benchmark calls. The adjustment is documented in `gold-review.json`. This is not native-human-certified ground truth, and 100% on 12 cases is not a production accuracy guarantee.

## Fairness and timing

Both providers receive exactly the same `state`, question instructions, and choice criteria. Jev receives these as its native typed API fields. Qwen receives their JSON serialization plus a minimal adapter asking for a compact map of question IDs to selected choice IDs. **Qwen was not asked for explanations, probabilities or confidence scores.** Gold labels and reasons are never sent to either provider.

Qwen uses temperature 0, JSON-object response mode and max 128 output tokens. Its largest measured completion used **21 tokens**; all 108 measured Qwen calls finished normally with `stop`. No truncation occurred. The four-decision accuracy difference is not caused by JSON validity errors.

This is a comparison of **usable provider APIs**, not identical internal representations or intrinsic GPU inference. Qwen was not tested with enum-constrained JSON Schema decoding; that could change contract behavior and timing. Input assembly before fetch is outside the measured interval. Timing includes request serialization performed inside the fetch call, networking, provider queueing, full response body arrival and JSON parsing. It excludes audio, speech recognition, translation generation and playback.

There are 36 unique cases: 12 memory, 12 word-sense and 12 decision-bundle cases. Each is repeated 3 times, yielding 108 measured requests per provider, plus 3 excluded warmups per provider. Cases are shuffled with a fixed seed each round and provider order alternates within pairs.

## Robustness checks

- Jev was faster in 30/36 four-decision pairs.
- On the 28 pairs where both providers were fully correct, medians were Jev 303.5 ms and Qwen 368 ms. The advantage was not solely faster wrong answers.
- Bundle median by round: Jev 288.5 / 307 / 309 ms; Qwen 379 / 351.5 / 572.5 ms.
- Jev-first bundle pairs (n=18): medians 302.5 vs 396.5 ms. Qwen-first bundle pairs (n=18): medians 307 vs 368 ms.
- A case-cluster bootstrap for the bundle median speed ratio gives a descriptive 95% interval of **1.17x to 1.32x**. Repetitions were clustered by unique case, not treated as independent samples.

Limits: small selected synthetic cases adapted from prior work; one location and time window; one fast comparison model; repeated prompts/provider caching; only 36 trials per task for the coarse p95 estimate. These results establish a measured example, not a universal model ranking or a 100x/200x inference-speed claim. Reproduce on your intended workload and deployment region before making a production promise.

## Costs

Estimated using observed token usage and rates: Jev $0.042 per million input tokens, output free; Qwen $0.10 per million input tokens and $0.30 per million output tokens. These are token-price estimates, not billing invoices, and exclude warmups and local compute. Cost accounting is in `cost-summary.json`.

## Inspect the evidence

Open **dashboard.html** for a standalone recorded-results visualization. It has no external dependencies and makes no live API calls. It shows every tested task, including where Qwen was faster, and lets you inspect every case’s outputs across all three rounds.

- `cases.json`, `protocol.json`, `gold-review.json`: frozen inputs and gold policy
- `results.json`, `run-order.json`, `warmup-results.json`, `completed.json`: raw run evidence
- `summary.json`: task/round latency, exact and semantic correctness, paired checks and clustered bootstrap
- `supported-claim.json`: the scoped four-decision result
- `validation-audit.json`: token-limit, finish-reason and format checks
- `order-check.json`, `cost-summary.json`: additional checks

## Reproduce

Requires Node.js 22.9+. No dependencies.

1. Copy `.env.example` to `.env` and set your TypeSafe and Nebius keys. Do not commit or share `.env`.
2. Preserve included result files before rerunning; the scripts overwrite them.
3. Run `npm run benchmark` then `npm run analyze`.
4. `npm run dashboard` rebuilds the viewer from recorded files. The original supported-claim/cost summaries are snapshots of the included run and must be recalculated before representing another run.

The runner caps each provider at 120 calls; this run used 111 each including warmups. It stops after three consecutive provider/format failures and does not silently retry. Live calls may incur charges. No credentials are included in the bundle.

References:
https://docs.typesafe.ai/api
https://docs.typesafe.ai/models
https://docs.tokenfactory.nebius.com/api-reference/inference/create-chat-completion
