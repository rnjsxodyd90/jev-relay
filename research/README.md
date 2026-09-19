# Jev Relay research archive

This directory is the project-local provenance archive for the experiments that informed Jev Relay. It contains recorded evidence and reproducibility sources only. No live calls are made by opening these files.

| Archive | Scope | Entry point |
| --- | --- | --- |
| [decision-speed](decision-speed/README.md) | Same-task typed routing benchmark: Jev versus Qwen | [report](decision-speed/SOURCE-REPORT.md), [results](decision-speed/results.json), [protocol](decision-speed/protocol.json) |
| [translation-benefit](translation-benefit/README.md) | Selective Jev assistance in a synthetic English-to-Dutch pipeline | [report](translation-benefit/SOURCE-REPORT.md), [results](translation-benefit/results.json), [frozen protocol](translation-benefit/frozen-protocol.json) |
| [decoding](decoding/README.md) | Open-ended Jev decoding attempts and comparison baselines | [report](decoding/SOURCE-REPORT.md), [benchmark results](decoding/benchmark-results.json), [cases](decoding/test-cases.json) |
| [interpreter-prototype](interpreter-prototype/README.md) | Archived local Whisper repair and candidate-selection prototype | [source report](interpreter-prototype/SOURCE-REPORT.md) |

## Archive policy

- Raw result JSON, review artifacts, run orders, frozen protocols, cases, and reproducibility scripts were copied from the supplied local artifacts.
- `cases.json` in decision-speed and translation-benefit were copied byte-for-byte. Their hash-bearing metadata files were copied unchanged.
- Excluded: `.env` material and templates, `node_modules`, downloaded `.models` weights, generated HTML dashboard, logs, and ZIP duplicates. This keeps the repository free of credentials and heavy or redundant artifacts.
- No source algorithm required a local-directory change: the inspected scripts use paths relative to their own directory. No algorithm was changed. See each archive's `README.md`.
- The recorded results are historical evidence, not live status, a vendor promise, or a production guarantee.

See [docs/research-log.md](../docs/research-log.md) for the narrative chronology, [docs/decisions.md](../docs/decisions.md) for adopted decisions, and [docs/roadmap.md](../docs/roadmap.md) for follow-up work.
