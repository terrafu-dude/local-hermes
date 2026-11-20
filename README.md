# local-hermes — a fully local AI agent on AMD ROCm

Run **Hermes Agent** (Nous Research's agent framework) with its own local
inference, entirely in Docker, on an AMD GPU. No cloud model, no API keys,
no data leaves your machine.

The inference engine is **Gufo** — the Strix Halo–native server for AMD's
Radeon 8060S/8050S (`gfx1151`) — serving **Qwen3.8-27B UD-Q4_K_XL** with
**DFlash2 speculative decoding** (a small `z-lab/...DFlash2-Q4_K_M` draft for
faster output), plus fully-local **voice**: faster-whisper for speech-to-text
and Piper for text-to-speech.

Verified on: **AMD Radeon 8060S/8050S ("Strix Halo"), 122 GB system RAM,
Linux + Docker**. Runs fully offline after first boot.

```
┌────────────────────────────────────────────────────────────┐
│  localhost                                                  │
│                                                             │
│  ┌──────────────── hermes-net (bridge) ──────────────────┐  │
│  │   local-gufo      local-hermes-agent   local-openwebui│  │
│  │   Gufo (ROCm)     Hermes Agent         chat web UI    │  │
│  │   ├─ Qwen3.8-27B   ├─ /opt/data (config,             │  │
│  │  │  UD-Q4_K_XL      │   sessions, skills, hf-cache)  │  │
│  │   └─ DFlash2 draft  ├─ /work (host-workspace)        │  │
│  │     128K ctx        └─ →http://gufo:8080/v1          │  │
│  │     3 sessions       └─ voice: faster-whisper + piper│  │
│  └────────────────────┴──────────────────────────────────┘  │
│           ▲              local-hub :8080 (services portal) │
│   OpenAI API :8000 · web dashboard :9120 · Open WebUI :3000│
└──────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **An AMD GPU that ROCm supports.** Verified on Radeon 8060S/8050S (Strix
   Halo, `gfx1151` — detected natively, no override needed). For another ASIC
   see "GPU not detected" in Troubleshooting.
2. **Docker** with GPU passthrough: your user must be in the `docker` group
   (`sudo usermod -aG docker $USER`, then re-login), and the container needs
   `/dev/kfd` and `/dev/dri`.
3. **~20 GB free** for the Qwen3.8-27B weights (+ ~1 GB DFlash2 draft), plus
   the base images.

## Quick start

```bash
git clone git@github.com:terrafu-dude/local-hermes.git && cd local-hermes
cp .env.example .env              # optionally set HF_TOKEN to avoid rate limits
docker compose up -d --build      # first boot installs the Gufo model (~21 GB)
curl -s http://localhost:8000/v1/models     # → qwen27-q4 (served on-device)
docker compose exec hermes hermes chat -q "Hi, in one short sentence."   # agent answers via Gufo
```

Everything after the first boot is **fully offline**.

## Surfaces

| Surface | URL | Auth |
|---|---|---|
| **Services portal** (start here) | http://localhost:**8080** | none |
| **Web dashboard** | http://localhost:**9120** | `local` / `local-demo-pass` (override via `DASHBOARD_USER`/`DASHBOARD_PASS`) |
| **Gufo OpenAI API** | http://localhost:**8000** `/v1` | none (local) |
| **Open WebUI** (chat browser) | http://localhost:**3000** | set once, then open |
| **CLI (tool calling)** | — | `docker compose exec hermes hermes chat -q "…"` |

Example call against Gufo's API:

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen27-q4","messages":[{"role":"user","content":"Hi."}],"max_tokens":120}'
```

### Desktop app ↔ gateway

The native Hermes desktop app dials the dashboard's live WebSocket
(`/api/ws`). Hermes only serves that socket's session token when the gateway
isn't behind the auth gate, and the default token rotates on every restart —
which is why a *stable* token is pinned here. Generate one, put it in `.env`,
and enter it in the desktop's gateway connection:

```bash
openssl rand -hex 24                      # then in .env:
# DASHBOARD_SESSION_TOKEN=<that value>
docker compose up -d hermes               # re-apply the env
```
**URL:** `http://localhost:9120` · **Token:** the `DASHBOARD_SESSION_TOKEN` value.

## Voice (fully local, free)

The agent can listen and talk back with no cloud services.

- **Speech-to-text:** faster-whisper (`base`) — local, free.
- **Text-to-speech:** Piper (`en_US-lessac-medium`) — local neural voice.

```yaml
# hermes/config.yaml (shipped — the engines are baked into the image)
stt:
  enabled: true
  provider: local            # faster-whisper
  local:
    model: base              # tiny | base | small | medium | large-v3 | turbo
tts:
  provider: piper            # local neural TTS; set tts.piper.voice to switch
```

The Whisper model and Piper voice download **once** into the persistent,
service-writable `HF_HOME=/opt/data/hf-cache` (the `hermes` service user's own
writable data volume), then survive container recreates. Both engines are baked
into the image (`faster-whisper`, `piper-tts`, `av<19` — PyAV 19 dropped a kwarg
faster-whisper needs for audio decode).

Turn on voice-to-voice in a session with the slash command: **`/voice on`**
(`/voice tts` for always-voice, `/voice off` to stop). Verify with
`docker compose exec hermes hermes doctor` (reports `✓ stt` / `✓ tts`).
Change the speaking voice with `tts.piper.voice: en_US-lessac-medium`.

## How it works

Everything needed to deploy is in `docker-compose.yml` + the `./hermes` build
context — there is no manual `hermes setup` wizard.

| Piece | What it does |
|---|---|
| **`gufo`** (`ghcr.io/gufo-org/toolboxes/gufo-runtime`) | Strix Halo–native model server (ROCm/HIP). Passes `/dev/kfd` + `/dev/dri` (+ the NPU `/dev/accel/accel0`), serves `qwen27-q4` = Qwen3.8-27B UD-Q4_K_XL + DFlash2 draft. OpenAI-compatible at :8000. |
| **`hermes`** (`./hermes/Dockerfile`) | The agent + a stable always-on gateway. The Dockerfile bakes `config.yaml` + `.env` into `/opt/data`, installs the fully-local voice engines (`faster-whisper`/`piper-tts`), ships the Services dashboard plugin, and removes the crashing profile-reconciler. |
| **`openwebui`** | Browser front-end pointed at Gufo's OpenAI API. |
| **`hub`** | The services portal page. |
| (*`ollama-fallback`*) | Opt-in: the old Ollama server is kept behind the `ollama-fallback` compose profile, not deleted. |

The config that matters (`hermes/config.yaml`):

```yaml
model:                      # main agent model (via local Gufo)
  provider: custom
  model: qwen27-q4          # Qwen3.8-27B UD-Q4_K_XL + DFlash2
  base_url: http://gufo:8080/v1
  api_key: "none"

delegation:                 # subagent tasks — same resident model
  model: qwen27-q4
  base_url: http://gufo:8080/v1
  api_key: "none"
```

### Context vs sessions (the tradeoff that keeps things running)

Gufo allocates each session a KV cache sized by the context, and caps all of it
at the ~42 GB of *device* memory left on the 61 GB pool once the ~20 GB of
weights are resident. So **context and concurrency trade off**:

| Context | Max sessions | Used KV |
|---|---|---|
| 64K | 6 | ~40 GB |
| ~82K | 3 | ~41 GB |
| **128K** | **3** | ~32 GB |
| 128K | 4+ | won't load (> 42 GB) |

Set it with Gufo's `--context` / `--sessions` in `docker-compose.yml` (e.g.
`--context 131072 --sessions 3`), then `docker compose up -d gufo`. Hermes
needs ≥64K and auto-compacts within whatever window it's given.

> Note: `vram=0` / the "61 GB pool" is the iGPU's **GTT window** — a flat
> ~50% carve-out of the 122 GB. The other ~61 GB is plain system RAM the GPU
> can't see. To grow the GPU pool you'd raise the iGPU memory allocation in
> BIOS (or via `amdgpu.gttsize`), trading system RAM for GTT.

## Screenshots (highlight reel)

Live captures — a fully-local Hermes (Qwen3.8-27B on ROCm) writing a story,
plus the services portal. The engine shown is the local model; no cloud calls
happen in any frame. (Images are stored with Git LFS.)

![The services portal — one page linking every local web UI](docs/screenshots/hub-portal.png)

![Hermes writing the 144-word "floating-island fox" story in the dashboard chat](docs/screenshots/chat-story-result.png)

![Dashboard Sessions/History view](docs/screenshots/sessions-history.png)

## Verifying it's local + on the GPU

```bash
docker compose logs gufo | grep -iE "gfx1151|ROCm|load_completed" | tail
#   ... event=load_completed ... speculative=dflash2 ...
docker compose exec hermes hermes doctor        # checks deps incl. stt/tts
docker compose exec hermes grep -A4 '^model:' /opt/data/config.yaml
#   base_url: http://gufo:8080/v1                ← the ONLY endpoint
```

## Customising

- **Context / concurrency:** edit Gufo's `--context` / `--sessions` in compose
  and `docker compose up -d gufo` (see the tradeoff table above).
- **Agent's working files:** whatever you drop in `./host-workspace` (mounted
  at `/work`) is what the agent can touch.
- **Whisper model size / Piper voice:** `stt.local.model` and `tts.piper.voice`
  in `hermes/config.yaml` (models download on first use).

## Troubleshooting

- **GPU not detected / falls back to CPU:** confirm `ls /dev/kfd /dev/dri`
  exists and the compose `group_add` IDs match (`getent group video render`).
- **`... sessions at ... exceed device memory` from `gufo`:** the KV budget is
  ~42 GB of device memory — lower `--sessions` and/or `--context`.
- **Local voice fails: `open() got an unexpected keyword argument
  'metadata_errors'`:** PyAV must be `<19` — it's pinned in the Dockerfile; a
  fresh image build restores it.
- **Voice model download fails (`Permission denied: ...`):** the service user's
  writable home is `/opt/data`; `HF_HOME=/opt/data/hf-cache` is set in compose.
- **Desktop drops its live socket after a restart:** set a stable
  `DASHBOARD_SESSION_TOKEN` (see Desktop section) so `/api/ws?token=` stays
  valid — the ephemeral token rotates on every gateway restart.
- **`docker: permission denied`** → add your user to the docker group and
  re-login (a fresh tab from an existing login session may keep stale groups —
  use `newgrp docker`).
- **Dashboard/API unreachable** → the gateway is the container's main process;
  `docker compose ps` should show `local-hermes-agent Up`. It restarts on
  crash automatically.
