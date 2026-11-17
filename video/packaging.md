# Packaging — title, description, tags, thumbnail

## Title options (A/B test)
1. **I Built a Fully Local AI Agent on AMD — No Cloud, No Tracking** *(recommended)*
2. Run an AI Agent 100% Offline on an AMD Radeon (Docker + Ollama + Hermes)
3. Your Own AI Agent Locally: Strix Halo, 61 GB VRAM, Tool Calls Included
4. Stop Sending Prompts to the Cloud — Local Agent on AMD in ~10 Minutes

## Description (first 2 lines carry the hook)
> I set up Hermes Agent to run **completely offline** on an AMD Radeon 8060S,
> inside Docker, with its own local model in Ollama (ROCm). It reads files and
> calls tools on-device — no API keys, no cloud. Here's the full blueprint.
>
> Post a ✅ in the comments if you've gone fully local on AMD too.

Full description bullets:
- 🖥 Hardware: Radeon 8060S / 8050S (Strix Halo), 122 GB RAM
- ⚙ Stack: Docker Compose → Ollama (ROCm) + Hermes Agent on one bridge network
- 🧠 Model: llama3.1:8b, 131K native context, 100% GPU
- ⚠ Two gotchas that cost me time: the 64K context floor, and Hermes-models-not-being-agentic
- 🔗 Repo/README + scripts in the description (link the `local-hermes` project)
- ⏱ Chapters: 00:00 Hook · 01:10 Hardware · 02:00 Compose · 03:30 Config ·
  04:10 Gotcha 1 · 05:00 Gotcha 2 · 05:40 Tool-call demo · 07:00 Proof · 07:35 Outtro

## Tags
`local AI agent`, `AMD ROCm`, `Strix Halo`, `Radeon 8060S`, `Ollama`,
`Hermes Agent`, `self-hosted AI`, `local LLM`, `docker`, `tool calling`,
`function calling`, `offline AI`, `Nous Research`, `LLM on AMD`, `homelab AI`

## Thumbnail concept (dark, high-contrast)
- **Left half:** terminal window with `☤ Hermes Agent` prompt and `🔎 Find *.md`
  showing a real tool call.
- **Right half:** AMD "Radeon"/ROCm-style accent (red-on-navy) with a GPU die icon
  + `100% GPU`.
- **Center-top caption, 3 words max per line:** `FULLY LOCAL` / `AI AGENT` / `NO CLOUD`.
- **A small "→ 61 GB VRAM" chip** bottom-left so the hardware story is visible at a glance.
- Palette: near-black background, white terminal text, AMD-red accents. Legible at
  YouTube's smallest thumbnail size.

## End screen
- Link card A: the `local-hermes` repo (README).
- Link card B: related "self-host / homelab" video if you have one.
- Subscribe + "which model should I try next?" poll card.
