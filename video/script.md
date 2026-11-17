# Video script — "I Built a Fully Local AI Agent on an AMD Machine (No Cloud)"

Target: 8–10 min · Tutorial + demo. Tone: direct, first-person, "I actually did this."
Every command shown here was run and verified on the machine in this video.

**B-roll:** real terminal captures, `docker compose` output, `ollama ps` GPU table,
the tool-call demo (`🔎 Find`, `📖 Read`), `rocm-smi`/log line. Keep the cursor slow.

---

## 0:00 — Hook
**Visual:** title card. Then me at the desk, the actual machine.
**VO:**
"You can run a real AI agent — one that reads files, runs tools, and answers —
entirely on your own hardware, no internet. Today I built one on an AMD
machine, inside Docker, end to end. This is exactly how it did it."

## 0:35 — The stack in one sentence
**Visual:** the three-piece diagram (Ollama / Hermes / one network).
**VO:**
"Two containers on one Docker network. Ollama in ROCm mode actually holds the
model and drives the GPU. Hermes Agent, Nous Research's agent framework, is
the brains that decides to call tools. They talk over a local OpenAI-compatible
endpoint. Nothing leaves the box."

## 1:10 — The hardware & the ROCm reality
**Visual:** `lspci | grep -i display` → "Radeon 8060S" (Strix Halo). 122 GB RAM.
**VO:**
"The machine: a Radeon 8060S, AMD's Strix Halo — an APU with a 61-gigabyte
unified memory pool for the GPU. That's a big deal: it means I can run a
serious local model, and even scale up later. Here's the pleasant surprise —
modern ROCm docker images detect gfx1151 with zero override. The GPU just
shows up."

## 2:00 — The compose file — passing the GPU in
**Visual:** scrolling the ollama service block.
**VO:**
"The whole thing is one compose file. The two things every AMD container needs
are the kernel driver devices, `/dev/kfd` and `/dev/dri`, and the group IDs for
`video` and `render` — I threw them in. Ollama auto-pulls its model on first
boot. Yes, that pull is the only network call, ever."

## 2:50 — Boot it
**Visual:** `docker compose up -d --build`; the pull ticker (~20 GB, two models).
**VO:**
"One command. Images build, the models download once, and `ollama ps` shows
`qwen3.8-27b:q4km — 100% GPU — 131072 context`. That GPU column is the whole point."

## 3:30 — The config that makes Hermes local
**Visual:** `hermes/config.yaml`.
**VO:**
"The Hermes side is just seeding a config that says: use a custom provider,
point at `http://local-ollama:11434/v1`, fake API key 'none'. I baked that into
a tiny Dockerfile, so the container seeds its own state on first boot. No setup
wizard, no API keys, no cloud anywhere."

## 4:10 — Gotcha #1: the context window floor
**Visual:** the error "context window … below the minimum 64,000 required".
**VO:**
"The stock Ollama tags for Qwen3.8 clamp context at ~40K. Hermes said no — it
needs at least a 64,000-token context. And you can't push a model past the
context it was tested on, no matter what flag you set. So the fix is an
extended-context GGUF — unsloth's Qwen3.8-27B is 262K native — aliased so
Ollama serves it at 131K. Rule: the model needs 64K or more native context."

## 5:00 — Gotcha #2: "Hermes" doesn't mean agentic
**Visual:** the CLI warning "Hermes 3 & 4 models are NOT agentic… lack tool-calling."
**VO:**
"Here's a tripwire: I tried the model literally named Hermes. Cute — but the
agent's own banner says Hermes 3 and 4 are NOT agentic; no tool calling. A
'local AI agent' needs a model that actually calls tools, so the default here
is qwen3.8-27b, which is proven at this."

## 5:40 — The money shot: it calls tools on-device
**Visual:** the live demo. `🔎 Find *.md` → `📖 Read notes.md` → answer.
**VO:**
"This is the part I wanted to see. I drop a file into the agent's work
directory and ask it a question it literally cannot answer without reading the
file. Watch the right side: it runs `Find`, then reads the file, and answers
'Kona blend, 200 degrees.' That's a real tool call, then real inference — both
on the GPU. `ollama ps` says 100% GPU the whole time."

## 7:00 — Prove it's air-gapped in spirit
**Visual:** `grep -A4 '^model:' /opt/data/config.yaml` → only `local-ollama`.
**VO:**
"Fold the config back and there it is — the only endpoint Hermes talks to is
the local container. No cloud provider, no API key. Your prompts and files
stay on your desk."

## 7:35 — What's next + outtro
**Visual:** model list; space check; possibilities.
**VO:**
"And because Strix Halo has so much VRAM, this scales: swap the model line and
I can step up to something much bigger for the same setup. The blueprint is
one compose file on a machine you own. Link is in the description — the 
`README` has every command. Go run your own."

---

### On-screen caption principles
- Keep every command as a real terminal capture, not mockups.
- Flag the two gotchas with a ⚠ lower-third so they're skimmable.
- Measure everything in token counts and GPU%.
