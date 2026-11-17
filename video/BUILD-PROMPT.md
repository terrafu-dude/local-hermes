# BUILD PROMPT — give this (or edit it) to the LOCAL agent to make the video
# Usage:  docker compose exec hermes hermes chat "$(cat video/BUILD-PROMPT.md)" --in /work
# The local agent has all the tools it needs (see README). Render everything
# on-device: no cloud endpoints, no external services.

You are now a fully-local video studio. Build a short (~45–90s) YouTube-short /
teaser MP4 titled "Fully Local AI Agent on AMD" using ONLY tools running on this
machine. Do not call any cloud service.

Steps:
1. Review the delivered setup so your narration is true to it: Ollama (ROCm)
   drives llama3.1:8b on the AMD Radeon (Strix Halo), Hermes Agent calls tools
   on-device, everything runs in Docker offline.
2. Write a short VO script (200–300 words) that a viewer can follow, mentioning
   the key numbers you can actually see here: 100% GPU, 65536 context, the two
   gotchas (64K context floor; the "Hermes"/hermes3 model not being agentic).
3. Generate the narration with LOCAL TTS: espeak-ng (installed). Use
   `espeak-ng -v en-us -s 160 -w nar.wav "…"` per line, or piper-tts if you
   installed it. Keep pacing conversational.
4. Render terminal-style animated scenes with the `ascii-video` skill
   (numpy/scipy/PIL are installed; ffmpeg is present). Style it like a
   retro-terminal demo — fits a "local AI agent" topic. ~2–3 scenes: boot/compose,
   the tool-call trace (Find → Read → answer), and a "100% GPU" close.
5. Mux narration + scenes with ffmpeg into `final.mp4` (H.264; landscape
   1920x1080 or 1280x720). Add a title frame with your text renderer.
6. Save everything under /work/video-out/ and report the exact file paths you
   wrote, the duration, and which model/deps you used. If a step fails with a
   real error, stop and report the blocker rather than inventing a result.

Constraints:
- Prove-on-device: after rendering, run `ollama ps` if needed to confirm no GPU
  Unload-required. Everything you create must be reproducible from the commands
  you actually ran (list them in a file at /work/video-out/BUILD.md).
