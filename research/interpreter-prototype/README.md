# Interpreter prototype archive

[Back to research index](../README.md) · [Source report](SOURCE-REPORT.md) · [Pipeline](pipeline.mjs) · [Tests](test/pipeline.test.mjs)

## Status and purpose

This is an archived experimental local voice-interpreter prototype. Version 0.2 replaced the prior browser speech-recognition path with local browser Whisper, preserving Jev as a translation-candidate selector and review gate rather than a free-form translator. It is included as implementation provenance, not as a production component.

## Retained source

The archive retains the server, gateway, pipeline, browser audio/Whisper source, frontend assets, package manifest/lockfile, launcher, and unit tests. It excludes `node_modules`, the downloaded Whisper `.models` cache, and environment files/templates. Install dependencies locally if reproduction is required, then provide keys through a private local mechanism. The source uses relative paths; no portability or algorithm edits were made.

## Known unverified boundary

A public uploaded audio clip exercised local Whisper and a live Jev review path, but physical microphone permission remained `prompt`. Real microphone capture and Dutch human review were not completed.
