# Architecture

```text
Typed text / local Whisper transcription
                |
           Review source text
                |
     POST /api/interpret (same origin)
                |
         Validate bounded input
                |
       One native Jev request
      /       |        |       \
   action   memory  register   sense
      \       |        |       /
      Validate all typed answers
                |
        Deterministic route policy
        /        |          \
   clarify    memory hit    memory miss
   template   stored Dutch  Qwen translation
        \        |          /
        Display for human review
                |
      Explicit local Dutch playback
```

`src/decision-gate.mjs` is pure policy/contract code. `src/providers.mjs` owns HTTP requests and the per-process request budget. `src/interpreter.mjs` orchestrates these with injected adapters for testing. `src/server.mjs` is a replaceable loopback-only HTTP adapter. It does not expose credential configuration endpoints.

Recorded replay reads immutable prior experimental data. It does not call providers, fabricate translation output, or imply that old timings are current live measurements. The production-oriented routing policy adds confidence thresholds and review behavior beyond the benchmark's label scoring, so benchmark correctness is not a measured production approval rate.

The live starter intentionally focuses on English-to-Dutch. Other languages require task-specific evaluation, memory curation, voice availability checks and new gold cases. The archived prototype explored more language selectors; that is not evidence of equal quality across languages.

The workbench does not certify translations. A native choice bundle can improve routing without establishing that generated downstream wording is correct. User-facing high-stakes workflows need independent domain and native-speaker evaluation.

## Model assets

Whisper weights are pinned to a revision and local hashes. Downloads are bounded, verified before use, deduplicated and atomically cached. Only declared asset names are served. Model files, dependencies, recordings and credentials are excluded from Git.

## Deployment boundary

This server is for a trusted local workstation. A public service needs authenticated sessions, tenant isolation, TLS, durable per-user quotas, explicit retention policy, abuse controls, monitoring without sensitive text, and load testing. Host/origin validation is not authentication against local software.
