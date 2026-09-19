#!/bin/sh
cd "$(dirname "$0")" || exit 1
if ! command -v node >/dev/null 2>&1; then
  printf 'Install Node.js 22.9 or newer, then run this launcher again.\n'
  read -r _
  exit 1
fi
if [ ! -d node_modules/@huggingface/transformers ]; then npm install --ignore-scripts || exit 1; fi
printf 'Open http://127.0.0.1:4419 in Chrome or Edge. Press Control-C to stop.\n'
exec node --env-file-if-exists=.env launch.mjs
