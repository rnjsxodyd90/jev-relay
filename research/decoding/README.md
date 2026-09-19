# Decoding archive

[Back to research index](../README.md) · [Recorded report](SOURCE-REPORT.md) · [Cases](test-cases.json) · [Benchmark results](benchmark-results.json) · [Quality review](quality-review.json)

## What this preserves

This archive preserves the fixed test cases, vocabulary and source attribution, all decoder/comparison outputs, warmups and pilots, positive control, blinded-review materials and verdicts, latency summary, completion counters, and all scripts for the initial and adapted decoding attempts.

## Reproduction and portability

Use Node.js 22.9+ and private local provider keys as documented in the recorded report. Start the local capped gateway before live runs. The source scripts use paths relative to the archive; no local hardcoded-directory edits or algorithm changes were required. Reruns make live calls and overwrite recorded JSON.

## Interpretation boundary

The tested Jev open-ended decoding methods produced no usable held-out Dutch translations and showed no speed advantage. This is a result about the tested implementations, not proof that a future decoder is impossible.
