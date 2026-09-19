# Translation-benefit archive

[Back to research index](../README.md) · [Recorded report](SOURCE-REPORT.md) · [Frozen protocol](frozen-protocol.json) · [Cases](cases.json) · [Raw results](results.json) · [Final summary](final-summary.json)

## What this preserves

This is the complete recorded pilot for a 32-case synthetic English-to-Dutch pipeline: cases and frozen hash metadata, paired run order and raw outputs, provider metadata, latency and cost analyses, blind-review input/rubric/mapping, both independent reviews, aggregation, quality-change analysis, and the selective-memory replay. The replay is labeled counterfactual rather than a second live experiment.

## Reproduction and portability

Run from this directory with Node.js 22.9+ and a private local environment file containing the required provider keys. Start the local capped gateway before the benchmark, as described in the recorded report. Scripts and paths were inspected: they are already relative and no algorithm or path adaptation was needed. Results are preserved recordings and may be overwritten by a rerun.

## Interpretation boundary

The pilot found benefit for selected translation-memory/context decisions, but its always-on assisted pipeline had a 936 ms versus 739 ms median and higher estimated token cost. It does not establish a production-wide latency, quality, or cost effect.
