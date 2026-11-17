# Recording checklist — every shot's command, pre-verified on this machine
# Each entry was actually run and produced the output shown. Re-run in order
# during recording so the demo is 100% real.

## 0. Pre-flight (once)
- [x] `git clone` the local-hermes repo; `cd local-hermes`
- [x] User in docker group → no sudo needed. (On a new machine:
      `sudo usermod -aG docker $USER` then re-login.)
- [x] Confirm GPU present: `lspci | grep -iE 'vga|3d|display'` → Radeon 8060S
- [x] Confirm device nodes exist: `ls /dev/kfd /dev/dri` → kfd, card1, renderD128
- [x] Group IDs match: `getent group video render` → 44, 990 (used in compose)

## 1. Boot
- [ ] `docker compose up -d --build`
- [ ] Wait for model auto-pull (first boot ~20 GB for the two models). Verify:
      `docker compose exec ollama ollama list` → `qwen3.8-27b:q4km`, `qwen3-4b:128k`
- [ ] Stack healthy:
      `docker compose ps` → `hermes Up`, `ollama Up`

## 2. Gotcha #1 (context floor) — optional but recommended for the video
- [ ] Show the failure with a STOCK qwen3.8/qwen tag (clamps at ~40K → the
      "below the minimum 64,000" error), then the fix: the unsloth extended-context
      GGUF aliased as `qwen3.8-27b:q4km` (262K native). Either is truthful.

## 3. Gotcha #2 (Hermes model not agentic) — optional
- [ ] `docker compose exec hermes hermes chat -q "…"` and capture the banner
      "Hermes 3 & 4 models are NOT agentic … lack tool-calling."

## 4. The money shot — on-device tool calling
- [ ] `bash scripts/smoke-agent.sh`
- [ ] Expect: `🔎 Find` → `📖 Read notes.md` → "Kona blend … 200F"
- [ ] Tool-call count in the session footer (e.g. "4 tool calls")

## 5. Proof it's local + on GPU
- [ ] `docker compose exec ollama ollama ps`
      → `qwen3.8-27b:q4km … 24 GB … 100% GPU … 131072`
- [ ] `docker compose logs ollama | grep -i "inference compute"`
      → `library=ROCm … gfx1151 … Radeon 8060S Graphics`
- [ ] `docker compose exec hermes grep -A4 '^model:' /opt/data/config.yaml`
      → only `http://local-ollama:11434/v1`

## 6. Close
- [ ] `docker compose exec ollama ollama list` → the two aliased models, clean
- [ ] README scrolled; show the "architecture" ASCII + troubleshooting table

---
## Pitfalls you will hit if this is re-made on another machine
1. **Docker socket permission** — user must be in `docker` group (re-login;
   a fresh tab from the same login session does NOT pick it up — use `newgrp docker`).
2. **Hermes needs ≥64K context** — stock Ollama `qwen` tags clamp at ~40K and are
   rejected; use an extended-context GGUF aliased via `ollama create` (here
   qwen3.8-27b:q4km, 262K native) with `OLLAMA_CONTEXT_LENGTH=131072`.
3. **s6 gateway usually must not boot on a no-platform local install** — keep
   the agent on-demand via `docker compose exec hermes hermes chat -q`, not an
   always-on supervised gateway (issue #42675).
4. **Model removal for a clean single-model story:** `docker compose exec ollama
   ollama rm <old>`.
