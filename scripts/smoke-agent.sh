#!/usr/bin/env bash
# Smoke test: prove the Hermes agent answers from the LOCAL model AND calls a
# tool (no cloud anywhere). The task (list /work, read notes.md, quote the
# coffee line) is only solvable by actually invoking a tool.
set -uo pipefail
cd "$(dirname "$0")/.."

echo "== 1. Ollama reachable from the hermes container =="
docker compose exec hermes sh -c 'curl -s http://local-ollama:11434/v1/models' | python3 -c 'import sys,json;print("served:",[m["id"] for m in json.load(sys.stdin).get("data",[])])'

echo
echo "== 2. The agent performs a TOOL-REQUIRING task on the local model =="
docker compose exec hermes hermes chat -q \
  "List files in /work and read notes.md, then quote the EXACT coffee blend and EXACT brew temperature it mentions. You may use tools."

echo
echo "== 3. Confirm the model is on the GPU =="
docker compose exec ollama ollama ps
