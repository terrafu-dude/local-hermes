# Storyboard / shot list — "Fully Local AI Agent on AMD (Docker, no cloud)"

Total ~9 min. Format: `SCENE | TIME | VISUAL | AUDIO | WORKING COMMAND`.

## Section A — Open (0:00–1:10)
| # | Time | Visual | Audio | Command (live) |
|---|------|--------|-------|-----------------|
| A1 | 0:00 | Title card, then presenter at desk with the Strix Halo machine | Hook VO | — |
| A2 | 0:35 | Three-piece diagram: Ollama ⟷ Hermes on one bridge | Stack-in-one-sentence VO | — |
| A3 | 1:10 | `lspci` filtered to the GPU | "Radeon 8060S, 61 GB pool" | `lspci \| grep -iE 'vga\|3d\|display'` |

## Section B — Build (1:10–5:40)
| # | Time | Visual | Audio | Command (live) |
|---|------|--------|-------|-----------------|
| B1 | 1:40 | Ollama service block in compose (devices + group_add) | GPU passthrough explainer | `getent group video render` |
| B2 | 2:00 | Compose up; first-boot download ticker | Auto-pull, model once | `docker compose up -d --build` |
| B3 | 2:50 | `ollama list` + `ollama ps` | "100% GPU, 65536 ctx" | `docker compose exec ollama ollama ps` |
| B4 | 3:30 | `hermes/config.yaml` (custom provider → local-ollama) | Config seeding explainer | `docker compose exec hermes grep -A4 '^model:' /opt/data/config.yaml` |
| B5 | 4:10 | ⚠ Error screenshot: "below the minimum 64,000" | Context-floor gotcha | (replay the failing `hermes chat`) |
| B6 | 5:00 | ⚠ CLI banner: "Hermes 3 & 4 … NOT agentic" | Name≠capability gotcha | `docker compose exec hermes hermes chat -q "…"` |

## Section C — Proof (5:40–7:35)
| # | Time | Visual | Audio | Command (live) |
|---|------|--------|-------|-----------------|
| C1 | 5:40 | **The tool demo** — `🔎 Find *.md`, `📖 Read notes.md`, final answer | "real tool call on-device" | `bash scripts/smoke-agent.sh` |
| C2 | 6:50 | `ollama ps` — 13 GB, 100% GPU | hardware proof under load | `docker compose exec ollama ollama ps` |
| C3 | 7:00 | config grep — only endpoint is local | "nothing leaves the box" | (reuse B4 grep) |

## Section D — Close (7:35–9:00)
| # | Time | Visual | Audio | Command (live) |
|---|------|--------|-------|-----------------|
| D1 | 7:35 | `ollama list` (single model) + VRAM math for "scale up" | What's next | `docker compose exec ollama ollama list` |
| D2 | 8:10 | README scrolled; link card | Wrap + CTA | — |

### Shot notes
- The whole thing must be **real**: each "Command (live)" column is genuinely run
  during recording; don't pre-render fake terminal frames.
- Speed selector: 1080p60. Show the cursor blink on demos; keep each command
  typed, not pasted, for the two gotchas.
- Lower-third ⚠ cards for the two gotchas so skimmers catch them.
