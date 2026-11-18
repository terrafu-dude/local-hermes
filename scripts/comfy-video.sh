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
rm -f "$OUTDIR/${NAME}_00001_.webm"
# Wait for THIS prompt_id to appear in history — the authoritative completion
# signal (the queue can sit in flows/VAE between steps; a transient empty queue
# is NOT completion).
ok=0
for i in $(seq 1 800); do
  H=$(curl -s "$BASE/history/$PID")
  if [ "$(echo "$H" | grep -c "\"$PID\"")" -gt 0 ]; then ok=1; break; fi
  sleep 3
done
[ "$ok" -eq 1 ] || { echo "ERROR: timed out waiting for prompt $PID" >&2; exit 1; }
sleep 6   # let SaveWEBM finalize + close the file
# SaveWEBM auto-increments the filename when one already exists, so never fetch
# a hardcoded index — take the NEWEST hermes_video_*.webm from ComfyUI output.
NF=$(docker compose exec -T comfyui sh -c 'ls -t /opt/ComfyUI/output/hermes_video_*.webm 2>/dev/null | head -1' 2>/dev/null | xargs -r basename 2>/dev/null)
[ -n "$NF" ] || NF="hermes_video_00001_.webm"
OUT="$OUTDIR/${NAME}_00001_.webm"
curl -s -o "$OUT" "$BASE/view?filename=$NF&type=output"
SZ=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
if file "$OUT" 2>/dev/null | grep -qi "matroska\|webm\|video" && [ "$SZ" -gt 80000 ]; then
  echo "OK -> $OUT (from $NF, $(du -h "$OUT" | cut -f1))"
else
  echo "WARN: output at $OUT is ${SZ}B / not a valid video (newest was $NF)" >&2
  exit 1
fi
