# Jev Relay

A native English-to-Dutch conversation assistant, a reusable decision gate, and a reproducible research workbench. Jev makes four typed choices in one request. Application code decides what happens next; Qwen writes new translations only when needed.

## Native iOS app

The SwiftUI app in [`ios/`](ios/) includes editable on-device English dictation, context and tone controls, explicit review before Dutch playback, and a local phrasebook. The build 3 candidate uses **each user's own TypeSafe/Jev and Nebius API credentials and credits**. Keys are stored in device-only iOS Keychain and sent only to the matching provider over fixed HTTPS endpoints. No developer key, included credit allowance, anonymous Supabase session, or owner-funded fallback is used by the new native client. Saving a key does not make a provider request; live transmission requires consent and an explicit Translate action.

The Supabase implementation in [`backend/`](backend/) is retained as legacy/reference code. Its deployed interpretation route was disabled by removing the two provider secrets; read-only health verification returned 503 with interpretation unavailable and account deletion still available. Do not restore shared provider keys merely to make that legacy health check green. The separate local research workbench below has its own opt-in server-funded design and is not the native BYOK app.

**Build 2's review submission was canceled for replacement; build 3 is under verification, not approved or publicly released.** Manual release remains required. Apple reviewer-access arrangements remain unresolved. See [native build evidence](ios/BUILD_EVIDENCE.md), [release checklist](docs/app-store/release-checklist.md), and [privacy assessment](docs/app-store/privacy-assessment.md). Compilation does not establish physical-device QA or Dutch human-quality review.

## Research workbench

The original browser interface is a research-backed integration starter. It starts in recorded replay mode, so no API key or model call is needed to inspect the evidence. It is not a claim that Jev generates translations or that the measured routing advantage generalizes to every request.

## Run the workbench

Node.js 22.9 or newer:

```sh
npm ci --ignore-scripts
npm test
npm run check
npm start
```

Open http://127.0.0.1:4431. Use Workbench to inspect actual recorded decisions, Evidence to compare both providers, and Integration for the application flow. No fabricated live activity or artificial replay timers.

For paid live calls, copy `.env.example` to `.env`, set `LIVE_MODE=1`, and configure `TYPESAFE_API_KEY` and `NEBIUS_API_KEY` using your secret manager. Restart the server. Keys never enter frontend JavaScript or repository files. The process permits at most 60 attempted provider requests by default, counting Jev and Qwen separately. This is a request cap, not a dollar budget; restart resets it.

## How to use it in another project

```js
import { createInterpreter } from './src/interpreter.mjs';

const relay = createInterpreter({
  jevKey: process.env.TYPESAFE_API_KEY,
  qwenKey: process.env.NEBIUS_API_KEY,
  maxCalls: 60,
});

const turn = await relay.interpret({
  text: 'Would you mind saying that again?',
  context: 'Formal singular address is required.',
  source: 'en',
  target: 'nl',
});

// turn.route: 'memory', 'translate', 'clarify', or 'review'
// The UI displays the result for review. It never automatically plays speech.
```

One Jev request answers:

- **Action:** translate now or ask for clarification?
- **Memory:** does a complete stored translation match?
- **Register:** formal, informal, plural or unspecified?
- **Sense:** which supplied lexical meaning applies?

The application then uses a stored Dutch phrase, asks for clarification, or requests new wording from Qwen. Invalid responses, low-confidence critical labels and failed providers produce a review state. Jev probabilities are not a safety guarantee; the thresholds are experimental.

Use this gate where multiple decisions are needed together. Do not automatically add it before every generative-model call and expect lower end-to-end latency. The earlier translation experiment showed that an unconditional extra stage can be slower and costlier.

Project tracking: [Jev Relay board](https://github.com/users/rnjsxodyd90/projects/1).

See [integration and API contracts](docs/integration.md), [architecture](docs/architecture.md) and [security](SECURITY.md).

## What was actually measured

All figures below concern complete API responses for the same requested decisions, not audio processing or translation generation.

| Task | Jev median | Qwen median | Outcome |
|---|---:|---:|---|
| One memory-match decision | 281 ms | 209.5 ms | Qwen faster |
| One word-sense decision | 285 ms | 221.5 ms | Qwen faster |
| Four routing decisions | 303 ms | 375 ms | Jev faster |

For the four-decision task: **19.2% lower median time**, p95 **378 vs 652 ms**, and fully correct bundles **36/36 vs 28/36**. There were **12 unique authored cases per task, each repeated three times**. This is one network/time window against Qwen3-30B-A3B-Instruct-2507, not universal evidence of speed or production accuracy. Six Qwen single-sense outputs used the correct description instead of its ID; semantic accuracy was 36/36 for both on that task.

Full inputs, frozen protocols, raw outputs, negative results, scoring caveats and reproducibility scripts are preserved in [research](research/) and the [research log](docs/research-log.md). The earlier 32-case translation study and failed open-ended Jev decoding experiment are included, not hidden.

## Voice and privacy

Optional voice preparation loads pinned Whisper-base weights and runs transcription in the browser using WebAssembly. Raw audio is not uploaded. The first model preparation downloads large public model assets if they are not cached. Their revision and SHA-256 hashes are pinned in `src/model-manifest.json`.

Transcription remains editable and is never automatically sent to a provider. In live mode, clicking the interpretation action sends text/context to TypeSafe and, on a memory miss, to Nebius. The server does not log or persist transcripts or keys. The browser does not use persistent storage for transcripts. Speech playback requires a user action and an available local Dutch voice; browser/OS support varies.

Physical microphone permission, native-Dutch human quality review and broad deployment validation remain open work. See [roadmap](docs/roadmap.md). This is turn-based, not simultaneous streaming interpretation.

## Layout

```text
src/             Pure decision contract, providers, interpreter, local server
public/          Workbench, recorded evidence and local speech worker
test/           Network-free policy/provider/HTTP tests
docs/           Integration, design rationale, decisions and research log
research/       Preserved experiments, including negative findings
.github/         Continuous integration
```

## Design provenance

The interface was redesigned using Anthropic's [frontend-design skill](https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md), with a project-specific design plan in [docs/design-system.md](docs/design-system.md). The skill is referenced, not presented as our own work.

This independent project is not affiliated with TypeSafe, Qwen, Nebius or Anthropic. Hosted models and third-party dependencies have their own licenses and terms. The source is public, but no open-source license grant is made at this stage; dependency licenses are unaffected.
