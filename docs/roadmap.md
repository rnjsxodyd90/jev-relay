# Jev Relay roadmap

[Research log](research-log.md) · [ADRs](decisions.md) · [Research archive](../research/README.md)

Tracked on the [private GitHub Project](https://github.com/users/rnjsxodyd90/projects/1).

## Completed

- [x] Archive the local Whisper repair and interpreter prototype source without models or dependencies.
- [x] Record the negative open-ended Jev decoding result with raw outputs and review artifacts.
- [x] Record selective translation-memory/context evidence and the always-on latency/cost tradeoff.
- [x] Record the same-task four-decision benchmark, including single-task counterexamples.
- [x] Adopt a native four-decision gate, novel-translation fallback, server-side keys, conservative review, and research/live separation.

- [x] Build the redesigned workbench, evidence explorer and integration guide using the documented frontend-design skill.
- [x] Pass 19 automated tests and three real provider-route smoke probes.

## To do

- [ ] Verify phone-width layouts on actual target devices.
- [ ] Test real microphone permission, recording, and playback on target browsers/devices.
- [ ] Obtain blinded native Dutch human review for meaning, register, naturalness, and clarification wording.
- [ ] Run the decision and pipeline benchmarks in target deployment regions under varied cache and load conditions.
- [ ] Validate controlled translation-memory quality, miss handling, and confidence thresholds with non-synthetic data and approved privacy controls.
- [ ] Evaluate a production translation provider and candidate-generation strategy before any live-use claim.
- [ ] Define review UX, escalation rules, telemetry minimization, retention, authentication, quotas, HTTPS, and privacy policy before deployment.
- [ ] Re-run frozen protocols before publishing any numeric performance or cost statement.
