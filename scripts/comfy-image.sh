#!/usr/bin/env bash
# Generate an image LOCALLY via ComfyUI using the configured FLUX workflow
# (host-workspace/workflows/flux-txt2img.json), saved to host-workspace/gallery/.
# Usage:  scripts/comfy-image.sh "<prompt>" [seed] [base_url]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="$ROOT/host-workspace/workflows/flux-txt2img.json"
[ -f "$WORKFLOW" ] || { echo "ERROR: workflow not found: $WORKFLOW" >&2; exit 1; }

BASE="${COMFY_BASE:-${3:-http://localhost:8188}}"
OUTDIR="$ROOT/host-workspace/gallery"
mkdir -p "$OUTDIR"
PROMPT="${1:?usage: comfy-image.sh \"<prompt>\" [seed] [base]}"
SEED="${2:-$RANDOM}"

# Inject prompt + seed into the configured workflow, then POST it.
BODY="$(SEED=$SEED PROMPT="$PROMPT" WORKFLOW="$WORKFLOW" python3 - <<'PY'
import json, os
wf = json.load(open(os.environ["WORKFLOW"]))
wf["prompt"]["2"]["inputs"]["text"] = os.environ["PROMPT"]
wf["prompt"]["3"]["inputs"]["seed"]  = int(os.environ["SEED"])
wf["prompt"]["7"]["inputs"]["filename_prefix"] = "hermes"
print(json.dumps({"prompt": wf["prompt"], "client_id": "hermes-local"}))
PY
)"
PID=$(curl -s -X POST "$BASE/prompt" -H 'Content-Type: application/json' -d "$BODY" | python3 -c 'import sys,json;print(json.load(sys.stdin)["prompt_id"])' 2>/dev/null)
[ -z "$PID" ] && { echo "ERROR: ComfyUI rejected the prompt (up? checkpoint loaded?)" >&2; exit 1; }
echo "queued prompt_id=$PID; polling..."
for i in $(seq 1 150); do
  H=$(curl -s "$BASE/history/$PID")
  if echo "$H" | grep -q "\"$PID\""; then
    FL=$(echo "$H" | python3 -c 'import sys,json
d=json.load(sys.stdin); r=d.get(list(d)[0],{}).get("outputs",{})
for v in r.values():
  for im in v.get("images",[]):
    print(im["filename"]); break' 2>/dev/null)
    [ -n "$FL" ] && { curl -s -o "$OUTDIR/$FL" "$BASE/view?filename=$FL" && echo "OK -> $OUTDIR/$FL"; exit 0; }
  fi
  sleep 2
done
echo "ERROR: timed out waiting for image" >&2; exit 1
