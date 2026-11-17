#!/usr/bin/env bash
# Synthesize LOCAL neural TTS via the Piper OpenAI-compatible endpoint.
# Usage:  scripts/piper-tts.sh "<text>" [out.wav]
set -uo pipefail
BASE="${PIPER_BASE:-http://localhost:5000}"
TEXT="${1:?usage: piper-tts.sh \"<text>\"}"
OUT="${2:-$(pwd)/speech-$(date +%s).wav}"

curl -s -X POST "$BASE/v1/audio/speech" \
  -H 'Content-Type: application/json' \
  -d "$(python3 -c 'import json,sys;print(json.dumps({"model":"en_US-lessac-medium","input":sys.argv[1],"voice":"en_US-lessac-medium","response_format":"wav"}))' "$TEXT")" \
  -o "$OUT"
echo "OK -> $OUT ($(wc -c < "$OUT") bytes)"
