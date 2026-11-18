#!/usr/bin/env bash
# Generate a short text-to-video clip LOCALLY via ComfyUI + Wan 2.1 T2V 1.3B,
# using the configured workflow (host-workspace/workflows/wan-t2v.json).
# The result .webm is written next to an input image dir:
#   host-workspace/videos/<name>.webm
# Usage:  scripts/comfy-video.sh "<prompt>" [duration_seconds] [out_name] [base_url]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/host-workspace/workflows/wan-t2v.json"
[ -f "$WF" ] || { echo "ERROR: workflow not found: $WF" >&2; exit 1; }

BASE="${COMFY_BASE:-${4:-http://localhost:8188}}"
OUTDIR="$ROOT/host-workspace/videos"
mkdir -p "$OUTDIR"
PROMPT="${1:?usage: comfy-video.sh \"<prompt>\" [duration] [out_name] [base]}"
DUR="${2:-15}"
NAME="${3:-hermes_video}"
FPS="16"
WIDTH="832"; HEIGHT="480"
# length = duration*fps, rounded down to a multiple of 4 (ComfyUI step)
LENGTH=$(( (DUR * FPS) / 4 * 4 ))
[ "$LENGTH" -ge 4 ] || LENGTH=4
SEED=$(( RANDOM * RANDOM % 2147483647 ))

BODY="$(SEED=$SEED PROMPT="$PROMPT" LENGTH=$LENGTH FPS=$FPS WIDTH=$WIDTH HEIGHT=$HEIGHT WF="$WF" python3 - <<'PY'
import json, os
wf = json.load(open(os.environ["WF"]))
wf["prompt"]["3"]["inputs"]["text"] = os.environ["PROMPT"]
wf["prompt"]["7"]["inputs"]["seed"] = int(os.environ["SEED"])
wf["prompt"]["9"]["inputs"]["fps"]  = float(os.environ["FPS"])
wf["prompt"]["6"]["inputs"]["width"], wf["prompt"]["6"]["inputs"]["height"] = int(os.environ["WIDTH"]), int(os.environ["HEIGHT"])
wf["prompt"]["6"]["inputs"]["length"] = int(os.environ["LENGTH"])
print(json.dumps({"prompt": wf["prompt"], "client_id": "hermes-local"}))
PY
)"
PID=$(curl -s -X POST "$BASE/prompt" -H 'Content-Type: application/json' -d "$BODY" | python3 -c 'import sys,json;print(json.load(sys.stdin)["prompt_id"])' 2>/dev/null)
[ -z "$PID" ] && { echo "ERROR: ComfyUI rejected the prompt (Wan model loaded?)" >&2; exit 1; }
echo "queued prompt_id=$PID (${LENGTH} frames @ ${FPS}fps ≈ ${DUR}s); polling..."
for i in $(seq 1 400); do
  Q=$(curl -s -m8 "$BASE/queue")
  RUN=$(echo "$Q" | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("queue_running",())))' 2>/dev/null)
  if [ "$RUN" -eq 0 ] 2>/dev/null; then
    H=$(curl -s "$BASE/history/$PID")
    if echo "$H" | grep -q "\"$PID\""; then break; fi
  fi
  sleep 3
done
# Deterministic output name from SaveWEBM (filename_prefix → <prefix>_00001_.webm)
OUT="$OUTDIR/${NAME}_00001_.webm"
curl -s -o "$OUT" "$BASE/view?filename=hermes_video_00001_.webm&type=output"
if file "$OUT" 2>/dev/null | grep -qi "matroska\|webm\|video"; then
  echo "OK -> $OUT ($(du -h "$OUT" | cut -f1))"
else
  echo "WARN: output not a video at $OUT" >&2; rm -f "$OUT"; exit 1
fi
