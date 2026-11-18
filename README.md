# local-hermes — a fully local AI agent on AMD ROCm

Run **Hermes Agent** (Nous Research's agent framework) with its own local
inference, entirely in Docker, on an AMD GPU. No cloud model, no API keys,
no data leaves your machine.

Runs **qwen3.8-27b:q4km** — the unsloth *Qwen3.8-27B UD-Q4_K_M* GGUF (262K
native context) — plus a lighter **qwen3-4b:128k** subagent for delegated
tasks. Both are served by a local Ollama (ROCm) container.

Verified on: **AMD Radeon 8060S/8050S ("Strix Halo"), 122 GB system RAM,
Linux + Docker**. Runs fully offline after first boot.

```
┌────────────────────────────────────────────────────────────┐
│  localhost                                                    │
│                                                              │
│  ┌──────────── hermes-net (bridge) ─────────────┐            │
│  │   local-hermes-agent       local-ollama      │            │
│  │   Hermes Agent framework   Ollama (ROCm)     │            │
│  │   ├─ /opt/data (config,    │  ┌─ qwen3.8-27b:q4km        │
│  │  │   sessions, skills)     │  │  qwen3-4b:128k           │
│  │   ├─ /work (files)         │  │  131072 ctx · 100% GPU   │
│  │   └─ →http://local-ollama  │  └── /dev/kfd + /dev/dri    │
│  │        :11434/v1 ◄─────────┘                              │
│  └──────────────────────────────────────────────────────────┘
│           ▲
│   web dashboard :9120 · OpenAI API :8642 · local ComfyUI :8188
│   Open WebUI :3000 · Piper TTS :5000 · services hub :8080
└──────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **An AMD GPU that ROCm supports.** Verified on Radeon 8060S/8050S (Strix
   Halo, gfx1151 — detected natively, no override needed). For another ASIC see
   "GPU not detected" in Troubleshooting.
2. **Docker** with GPU passthrough: your user must be in the `docker` group
   (`sudo usermod -aG docker $USER`, then re-login), and the container needs
   `/dev/kfd` and `/dev/dri`.
3. **~20 GB free** for the two models, plus ~4 GB for the base images.

## Quick start

```bash
git clone git@github.com:terrafu-dude/local-hermes.git && cd local-hermes
docker compose up -d --build   # first boot pulls both models (~20 GB)
bash scripts/verify-gpu.sh     # GPU detected + model served on-device
bash scripts/smoke-agent.sh    # tool-calling works on the local model
```

Everything after the first boot is **fully offline**.

## Surfaces

| Surface | URL | Auth |
|---|---|---|
| **Services portal** (start here) | http://localhost:**8080** | none |
| **Web dashboard** | http://localhost:**9120** | `local` / `local-demo-pass` (override via `DASHBOARD_USER`/`DASHBOARD_SECRET`) |
| **OpenAI API** | http://localhost:**8642** `/v1` | `Authorization: Bearer <key>` |
| **ComfyUI** (text-to-image) | http://localhost:**8188** | none |
| **Ollama WebUI** | http://localhost:**3000** | set once, then open |
| **Piper TTS** | http://localhost:**5000** | none |
| **CLI (tool calling)** | — | `docker compose exec hermes hermes chat -q "…"` |

The API key auto-generates on first boot (`/opt/data/.env` →
`API_SERVER_KEY=…`):

```bash
docker compose exec hermes grep '^API_SERVER_KEY=' /opt/data/.env
curl -s http://localhost:8642/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <key>" \
  -d '{"model":"qwen3.8-27b:q4km","messages":[{"role":"user","content":"Hi."}],"max_tokens":120}'
```

## Screenshots (highlight reel)

Live captures — a fully-local Hermes (qwen3.8-27b on ROCm) writing a story and
generating its illustration entirely on-device, plus the services portal.
All screenshots were taken from the running stack on a desktop viewport.
(The image files are stored with Git LFS.)

![The services portal — one page linking every local web UI](docs/screenshots/hub-portal.png)

![Hermes writing the 144-word "floating-island fox" story in the dashboard chat](docs/screenshots/chat-story-result.png)

![The 1024x1024 image the agent generated for the story via on-device ComfyUI (FLUX.1-schnell)](docs/screenshots/generated-fox-story-image.png)

![Dashboard Sessions/History view](docs/screenshots/sessions-history.png)

No cloud calls happen in any of these frames — the model is served by the local
Ollama container and the images by the local ComfyUI container, both on this
AMD ROCm box.

## How it works

Everything needed to deploy is in `docker-compose.yml` + the `./hermes` build
context — there is no manual `hermes setup` wizard.

| Piece | What it does |
|---|---|
| **`ollama`** (`ollama/ollama:rocm`) | Model server. Passes `/dev/kfd` + `/dev/dri`, joins the `video`/`render` groups, serves **131072** context. Auto-pulls and keeps warm the main model (qwen3.8-27b:q4km) + subagent (qwen3-4b:128k). |
| **`hermes`** (`nousresearch/hermes-agent` + `./hermes/Dockerfile`) | The agent + a stable always-on gateway. The Dockerfile bakes `config.yaml` into `/opt/data`, installs a fully-local video toolchain, ships the Services dashboard plugin, and removes the crashing profile-reconciler. |
| **`comfyui`** | FLUX.1-schnell text-to-image on the Radeon (native gfx1151). |
| **`piper`** | Local neural TTS (OpenAI-compatible). |
| **`openwebui`** | Browser front-end for Ollama. |
| **`hub`** | The services portal page. |

The only config that matters (`hermes/config.yaml`):

```yaml
model:                      # main agent model
  provider: custom          # talk to an OpenAI-compatible endpoint
  model: qwen3.8-27b:q4km   # unsloth Qwen3.8-27B UD-Q4_K_M, 262K native ctx
  base_url: http://local-ollama:11434/v1
  api_key: "none"           # local server sends the header but doesn't validate it

delegation:                 # lighter local model for subagent tasks (≥64K too)
  model: qwen3-4b:128k
  base_url: http://local-ollama:11434/v1
  api_key: "none"
```

### Why an extended-context GGUF, not a stock Ollama tag

1. **Hermes rejects any model with native context < 64,000 tokens.** Stock
   Ollama `qwen3`/`qwen3.8` tags clamp context at ~40K and can't be pushed past
   it — `OLLAMA_CONTEXT_LENGTH` never exceeds a model's *trained* cap. The fix:
   pull an **extended-context GGUF**, then alias it so the compose entrypoint
   can auto-pull it like any model:
   ```bash
   docker compose exec ollama ollama pull hf.co/unsloth/Qwen3.8-27B-GGUF:Qwen3.8-27B-UD-Q4_K_M
   # Modelfile (stdin):  FROM hf.co/unsloth/Qwen3.8-27B-GGUF:Qwen3.8-27B-UD-Q4_K_M
   docker compose exec ollama ollama create qwen3.8-27b:q4km -f -
   ```
   Verify with `ollama show qwen3.8-27b:q4km` (context length) and `ollama ps`
   (CONTEXT 131072).
2. **"Hermes" the name ≠ agentic.** The `hermes3`/`hermes4` models are not
   tool-callers; use a genuinely tool-capable model (qwen3.8-27b here). If
   model downloads hit Hugging Face rate limits, provide `HF_TOKEN` (repo
   `.env`, git-ignored).

### Why the gateway is stable here (the dashboard needs a live gateway)

The image's `/etc/cont-init.d/02-reconcile-profiles` reads the persisted
`gateway_state` and auto-spawns a **second** s6-supervised `gateway --replace`
that SIGTERMs the primary gateway seconds after ready — a forever crash-loop on
a no-messaging-platform local install (hermes-agents issue #42675). The seeded
Dockerfile removes that script, so `command: gateway run` + a main-process
gateway (Docker `restart: unless-stopped`) continuously serves the dashboard
and API.

## Verifying it's local + on the GPU

```bash
docker compose exec ollama ollama ps
#   NAME               ID          SIZE     PROCESSOR  CONTEXT ...
#   qwen3.8-27b:q4km   …           24 GB    100% GPU   131072
#   qwen3-4b:128k      …            4 GB    100% GPU   131072

docker compose logs ollama | grep -i "inference compute"
#   ... library=ROCm compute=gfx1151 name=ROCm0 description="Radeon 8060S Graphics"

docker compose exec hermes grep -A4 '^model:' /opt/data/config.yaml
#   base_url: http://local-ollama:11434/v1   ← the ONLY endpoint
```

`bash scripts/verify-gpu.sh` bundles the above.

## Local media generation (image + audio)

Two more local services ride the same `hermes-net` — both fully on-device:

| Service | Image | Gives you | Endpoint |
|---|---|---|---|
| **ComfyUI** | `ignatberesnev/comfyui-gfx1151` | FLUX.1-schnell images on the Radeon (native gfx1151) | http://localhost:8188 (GUI + `/prompt` API) |
| **Piper** | `kamilkrawiec/piper-openai-tts` | WAV narration, CPU, OpenAI-compatible | http://localhost:5000 `/v1/audio/speech` |

```bash
# generate an image (FLUX.1-schnell, configured workflow) → host-workspace/gallery/
bash scripts/comfy-image.sh "a red fox on a floating island under the stars, cinematic"

# generate a ~15 s text-to-video clip (Wan 2.1 T2V 1.3B) → host-workspace/videos/
bash scripts/comfy-video.sh "a red fox on a floating island under the stars, cinematic" 15 fox_story

# synthesize narration → <out>.wav
bash scripts/piper-tts.sh "I am a fully local AI agent on an AMD machine." out.wav
```

Video generation uses **Wan 2.1 T2V 1.3B** (Apache-2.0) through the same on-device
ComfyUI (832×480, VP9 WebM). The `local-media-studio` skill teaches the agent both
image and video, so you can ask it to *"write a short story and make a 15 second
video"* and it will render it offline.

**VRAM note:** the two hot Ollama models hold ~35 GB of the ~61 GB pool. To give
ComfyUI room to render, unload them first (they reload on demand):
```bash
docker compose exec ollama ollama stop qwen3.8-27b:q4km
docker compose exec ollama ollama stop qwen3-4b:128k
# ...generate image... then warm them again (24h keep-alive):
docker compose exec ollama ollama run qwen3.8-27b:q4km --keepalive 24h "ok"
docker compose exec ollama ollama run qwen3-4b:128k --keepalive 24h "ok"
```

## Making the tutorial video entirely on-device

The Hermes container ships a **fully-local video toolchain**, so the local
agent itself can produce the YouTube tutorial (no cloud):

- **Render** — `ascii-video` skill (numpy + scipy + PIL + ffmpeg present).
- **Animation** — `manim-video` skill (install `manim` inside the container).
- **Narration** — local TTS: `espeak-ng` (installed) or `piper-tts` for a
  smoother neural voice.
- **Assembly** — `ffmpeg` (ships in the image).

Give the job to the local agent:
```bash
docker compose exec hermes hermes chat "$(cat video/BUILD-PROMPT.md)" --in /work
```
Put any assets the agent needs in `./host-workspace` first (visible at `/work`).

## Customising

- **Model:** set `OLLAMA_LOCAL_MODEL` / `OLLAMA_SUBAGENT_MODEL` (defaults
  `qwen3.8-27b:q4km` / `qwen3-4b:128k`), then
  `docker compose exec hermes hermes config set model.default <name>`.
  Any local model with **≥64K native context** and tool-calling works.
- **Agent's working files:** whatever you drop in `./host-workspace` (mounted at
  `/work`) is what the agent can touch.

## Troubleshooting

- **GPU not detected / falls back to CPU:** confirm `ls /dev/kfd /dev/dri`
  exists and the compose `group_add` IDs match (`getent group video render`).
  On 8060S/8050S it's detected natively; for an unsupported ASIC uncomment
  `HSA_OVERRIDE_GFX_VERSION`.
- **"context window … below the minimum 64,000"** → the model's native context
  is <64K. Use the extended-context GGUF + `ollama create` aliasing above
  (never a stock ~40K Qwen tag) or pick another ≥64K model.
- **Tool calls fail with `tool_call requires 'calls'`** → the model isn't
  emitting valid tool calls on Ollama's OpenAI endpoint. Use a genuinely
  tool-capable ≥64K model (qwen3.8-27b:q4km here); `hermes3`/`hermes4` are not
  tool-callers.
- **HF download 403s for the model** → put the HF token in the repo `.env`
  (`HF_TOKEN=…`, git-ignored); compose passes `${HF_TOKEN}` into the services.
- **`docker: permission denied`** → add your user to the docker group and
  re-login (a fresh tab from an existing login session may keep stale groups —
  use `newgrp docker`).
- **Dashboard/API unreachable** → the gateway is the container's main process;
  `docker compose ps` should show `local-hermes-agent Up`. It restarts on
  crash automatically.
