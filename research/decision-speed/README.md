# Decision-speed archive

[Back to research index](../README.md) · [Recorded report](SOURCE-REPORT.md) · [Protocol](protocol.json) · [Cases](cases.json) · [Raw results](results.json) · [Summary](summary.json)

## What this preserves

The recorded same-task benchmark compares native Jev typed decisions with Qwen JSON responses across 12 synthetic four-decision routing cases, repeated three times. It also retains the single memory-match and single word-sense tasks so the narrower result is not mistaken for a broad speed claim.

Evidence: `cases.json`, `seed-cases.json`, `protocol.json`, `gold-review.json`, `run-order.json`, `results.json`, `warmup-results.json`, `completed.json`, `summary.json`, `supported-claim.json`, `validation-audit.json`, `order-check.json`, `cost-summary.json`, provider/pricing metadata, and the scripts that created, ran, analyzed, and optionally rendered the results.

## Reproduction and portability

Run from this directory with Node.js 22.9+ after setting the required provider keys in an untracked local environment file. The source report lists the commands and warns that live calls can incur charges and overwrite result files. The archived scripts use relative paths; no hardcoded local-directory edits or algorithm changes were necessary. The generated HTML dashboard itself was intentionally excluded as redundant.

## Interpretation boundary

The recorded four-decision result is 303 ms Jev versus 375 ms Qwen median, with 36/36 versus 28/36 fully correct bundles. Single memory and word-sense tasks were faster with Qwen. This archive supports only that scoped recorded example.
