# Architecture decision records

[Research log](research-log.md) · [Research archive](../research/README.md) · [Roadmap](roadmap.md)

## ADR-001: Use Jev as a native four-decision gate

**Status:** Accepted

**Decision:** Use Jev for a single typed routing request that decides translate versus clarify, controlled-memory reuse versus miss, required register, and lexical sense.

**Why:** In the recorded 12-case, three-round same-task benchmark, this bundle was 303 ms median with 36/36 fully correct bundles, versus Qwen's 375 ms and 28/36. This is not a claim that Jev is generally faster.

**Evidence:** [benchmark summary](../research/decision-speed/summary.json), [scope](../research/decision-speed/supported-claim.json).

## ADR-002: Use Qwen only when translation is novel

**Status:** Accepted

**Decision:** Call Qwen for novel wording after the gate, not for a controlled-memory hit or an adequate clarification route.

**Why:** The translation pilot found selected memory/context benefit, while an always-on Jev-assisted path was slower and costlier overall. Qwen was also faster on isolated single decisions in the decision benchmark.

**Evidence:** [pilot final summary](../research/translation-benefit/final-summary.json), [decision summary](../research/decision-speed/summary.json).

## ADR-003: Keep provider keys server-side

**Status:** Accepted

**Decision:** Store and use provider API keys only in server-side runtime configuration. Do not ship keys to the browser, repository, recorded artifacts, or client storage.

**Why:** The archived prototype treats keys as process-memory configuration and the research harnesses use local private environment configuration. The archive intentionally excludes environment files/templates.

**Evidence:** [prototype report](../research/interpreter-prototype/SOURCE-REPORT.md), [server source](../research/interpreter-prototype/server.mjs).

## ADR-004: Review conservatively on uncertainty

**Status:** Accepted

**Decision:** Do not auto-play or automatically act on uncertain, malformed, unavailable, or low-confidence decisions. Route to review or clarification instead.

**Why:** Candidate selection cannot repair bad candidates; the prototype's recorded 0.76-confidence review remained paused. Clarification is safer than speaking a guess when essential context is missing.

**Evidence:** [prototype report](../research/interpreter-prototype/SOURCE-REPORT.md), [pipeline](../research/interpreter-prototype/pipeline.mjs).

## ADR-005: Keep recorded research separate from live operation

**Status:** Accepted

**Decision:** Keep frozen cases, result JSON, review artifacts, and analysis scripts in `research/`; keep live runtime behavior and credentials out of those recordings.

**Why:** Recorded evidence is reproducible provenance, not live telemetry or a production promise. It must remain immutable enough to audit while live calls can vary with region, cache, load, and provider behavior.

**Evidence:** [research archive policy](../research/README.md), [research log limits](research-log.md#shared-known-gaps-and-interpretation-limits).
