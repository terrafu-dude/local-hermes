#!/usr/bin/env bash
# Verify the ROCm stack sees your AMD GPU and the local model is served.
set -uo pipefail
cd "$(dirname "$0")/.."

echo "== stack status =="
docker compose ps --format '{{.Name}}  {{.Status}}'

echo
echo "== AMD GPU discovered by ROCm (from ollama logs) =="
docker compose logs ollama 2>&1 | grep -iE 'inference compute|Radeon|gfx[0-9]+|total' | tail -3

echo
echo "== local models =="
docker compose exec ollama ollama list 2>/dev/null

echo
echo "== model currently loaded + GPU% (run a query first, then re-run) =="
docker compose exec ollama ollama ps 2>/dev/null
