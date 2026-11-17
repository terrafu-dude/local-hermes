# local-hermes — a fully local AI agent on AMD ROCm

Run **Hermes Agent** (Nous Research's agent framework) with its own local
inference, entirely in Docker, on an AMD GPU. No cloud model, no API keys, no
data leaves your machine.

Verified on: **AMD Radeon 8060S / 8050S ("Strix Halo"), 122 GB system RAM,
Linux + Docker 29.x**. Runs fully offline.

```
┌────────────────────────────────────────────────────────────┐
│  localhost                                                    │
│                                                              │
│  ┌──────────── hermes-net (bridge) ─────────────┐            │
│  │                                              │            │
│  │  local-hermes-agent        local-ollama      │            │
│  │  Hermes Agent framework    Ollama (ROCm)     │            │
│  │  ├─ /opt/data (config,     │  ┌─ llama3.1:8b │            │
│  │  │   sessions, skills)     │  │  llama.cpp   │            │
│  │  ├─ /work (files)          │  │  100% GPU    │            │
│  │  └─ →http://local-ollama   │  └── /dev/kfd   │            │
│  │        :11434/v1 ◄─────────┘  │  /dev/dri    │            │
│  └──────────────────────────────┴───────────────┘            │
│           ▲                                                  │
│   web dashboard :9120   ·  OpenAI API :8642   ·  CLI          │
└──────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **An AMD GPU that ROCm supports.** Verified on Radeon 8060S/8050S (Strix
   Halo). For a newer/unsupported ASIC see "GPU not detected".
2. **Docker** with GPU passthrough: your user must be able to run Docker
   (`sudo usermod -aG docker $USER`, re-login), and the container needs access
   to `/dev/kfd` and `/dev/dri`.
3. ~5 GB free for the model, plus a few GB for images.

## Quick start

```bash
git clone <this repo> local-hermes && cd local-hermes
docker compose up -d --build            # first boot pulls the model (~4.9 GB)
bash scripts/verify-gpu.sh              # GPU detected + model served on-device
bash scripts/smoke-agent.sh             # tool-calling works on the local model
```

Everything after the first boot is **fully offline**.

## Surfaces (all local, no port collisions with a host Hermes)

| Surface | URL | Auth |
|---|---|---|
| **Web dashboard** | http://localhost:**9120** | `local` / `local-demo-pass` (override via `DASHBOARD_USER`/`DASHBOARD_PASS`) |
| **OpenAI API** | http://localhost:**8642** `/v1` | `Authorization: Bearer <key>` |
| **CLI (tool calling)** | — | `docker compose exec hermes hermes chat -q "…"` |

The API key is auto-generated on first boot and written to `/opt/data/.env`
(`API_SERVER_KEY=…`):

```bash
docker compose exec hermes grep '^API_SERVER_KEY=' /opt/data/.env
curl -s http://localhost:8642/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"Hi."}],"max_tokens":120}'
```

## How it works

Everything needed to deploy is in `docker-compose.yml` + the `./hermes` build
context — there is no manual `hermes setup` wizard.

| Piece | What it does |
|---|---|
| **`ollama`** (`ollama/ollama:rocm`) | Model server. Passes `/dev/kfd` + `/dev/dri` to ROCm, joins the `video`/`render` groups. Serves a 64K context. Auto-pulls `$OLLAMA_LOCAL_MODEL`. |
| **`hermes`** (`nousresearch/hermes-agent` + `./hermes/Dockerfile`) | Agent + stable gateway. The Dockerfile bakes `config.yaml` into `/opt/data`, installs a local video toolchain, and disables the crashing profile-reconciler. |

The only config that matters (`hermes/config.yaml`):

```yaml
model:
  provider: custom      # talk to an OpenAI-compatible endpoint
  default: llama3.1:8b  # must match the model Ollama serves
  base_url: http://local-ollama:11434/v1
  api_key: "none"       # local server sends the header but doesn't validate it
```

### Two gotchas that silently break other setups

1. **The model must natively support ≥64K context.** Hermes rejects any model
   served under 64,000 tokens. Ollama's default context (32K) is below this, so
   compose sets `OLLAMA_CONTEXT_LENGTH: "65536"` — but that only helps models
   whose *trained* context is ≥64K. `qwen2.5` (native 32K) still fails. Use
   `llama3.1:8b` (131K native) or another ≥64K tool-caller.
2. **"Hermes" does not mean agentic.** The `hermes3` model — same family name —
   is **not** a tool-caller; the agent's own banner warns *"Hermes 3 & 4 models
   are NOT agentic… lack tool-calling."* For a working agent use a genuinely
   tool-capable model, hence `llama3.1:8b`.

### Why the gateway is stable here (the dashboard needs a live gateway)

The image's stock `/etc/cont-init.d/02-reconcile-profiles` reads the persisted
`gateway_state` (`desired_state: running`) and auto-spawns a **second**
s6-supervised `gateway … --replace` that SIGTERMs the primary gateway seconds
after it becomes ready — a forever crash-loop on a no-messaging-platform local
install (hermes-agents issue #42675). The seeded Dockerfile removes that one
script, so `command: gateway run` + `HERMES_GATEWAY_NO_SUPERVISE=1` is the
*only* gateway: the container's main process, kept alive by Docker's `restart:
unless-stopped`, continuously serving the dashboard and the OpenAI API.

## Verifying it's local + on the GPU

```bash
docker compose exec ollama ollama ps
#   NAME          SIZE   PROCESSOR  CONTEXT ...
#   llama3.1:8b   13 GB  100% GPU    65536

docker compose logs ollama | grep -i "inference compute"
#   ... library=ROCm compute=gfx1151 name=ROCm0 description="Radeon 8060S Graphics"

docker compose exec hermes grep -A4 '^model:' /opt/data/config.yaml
#   base_url: http://local-ollama:11434/v1   ← the ONLY endpoint
```

`bash scripts/verify-gpu.sh` bundles the above.

## Making the tutorial video entirely on-device

The Hermes container ships a **fully-local video toolchain**, so the local
agent itself can produce the YouTube tutorial (no cloud services):

- **Render** — `ascii-video` skill (numpy + scipy + PIL + ffmpeg present).
- **Animation** — `manim-video` skill (install `manim` inside the container;
  LaTeX only if you use math scenes).
- **Narration** — local TTS: `espeak-ng` (installed); add `piper-tts` for a
  smoother neural voice (model downloads once, then offline).
- **Assembly** — `ffmpeg` (ships in the image).

Give the job to the local agent:

```bash
docker compose exec hermes hermes chat "$(cat video/BUILD-PROMPT.md)" --in /work
```
Put any assets the agent needs in `./host-workspace` first (visible at `/work`).

## Local media generation (image + audio)
Two more local services ride the same `hermes-net` — both fully on-device:

| Service | Image | Gives you | Endpoint |
|---|---|---|---|
| **ComfyUI** (local text-to-image) | `ignatberesnev/comfyui-gfx1151` | FLUX.1-schnell images on the Radeon (native gfx1151) | http://localhost:8188 (GUI + `/prompt` API) |
| **Piper** (local neural TTS) | `kamilkrawiec/piper-openai-tts` | WAV narration, CPU, OpenAI-compatible | http://localhost:5000 `/v1/audio/speech` |

```bash
# generate an image (FLUX.1-schnell) → host-workspace/gallery/
bash scripts/comfy-image.sh "a red fox in a cyberpunk city, cinematic"

# synthesize narration → <out>.wav
bash scripts/piper-tts.sh "I am a fully local AI agent on an AMD machine." out.wav
```

**VRAM note:** the two Ollama models hold ~48 GB of the ~66 GB pool. To give
ComfyUI room to render an image, unload them first (they reload on demand):
```bash
docker compose exec ollama ollama stop qwen3.8-27b:q4km
docker compose exec ollama ollama stop qwen3-4b:128k
# ...generate image... then warm them again:
docker compose exec ollama ollama run qwen3.8-27b:q4km --keepalive 24h "ok"
docker compose exec ollama ollama run qwen3-4b:128k --keepalive 24h "ok"
```

**Models live in named volumes** (`comfyui_home`, `piper_data`), so a fresh
`docker compose up` keeps them. First ComfyUI boot copies in its bundled app
(that's why the volume must mount at `/opt/ComfyUI` — image quirk).

## Customising

- **Model:** `OLLAMA_LOCAL_MODEL=llama3.3:70b docker compose up -d`, plus
  `docker compose exec hermes hermes config set model.default <name>`.
  Any Ollama model with ≥64K native context and tool-calling works.
- **Agent's working files:** whatever you drop in `./host-workspace` (mounted
  at `/work`) is what the agent can touch.

## Troubleshooting

- **GPU not detected / falls back to CPU:** confirm `ls /dev/kfd /dev/dri`
  exists and the compose `group_add` IDs match (`getent group video render`).
  For an unsupported ASIC, uncomment `HSA_OVERRIDE_GFX_VERSION` (e.g. "11.0.0").
  On 8060S/8050S it's detected natively.
- **"context window … below the minimum 64,000"** → the model's native context
  is <64K. Pick a ≥64K model (see above).
- **Tool calls fail with `tool_call requires 'calls'`** → the model doesn't
  emit valid tool calls on Ollama's OpenAI endpoint. Use `llama3.1:8b`.
- **`docker: permission denied`** → add your user to the docker group and
  re-login (a fresh tab from the same login session may not pick it up — use
  `newgrp docker`).
- **Dashboard/API unreachable** → the gateway is the container's main process;
  `docker compose ps` should show `local-hermes-agent Up`. It restarts on crash
  automatically.
