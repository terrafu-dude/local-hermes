---
name: local-media-studio
description: "Use when the user wants an image, a video, or spoken audio generated locally. Drives on-prem ComfyUI (FLUX.1-schnell images, Wan 2.1 T2V video) and Piper TTS."
---

# Local Media Studio

This Hermes runs next to LOCAL media services on the same Docker network.
Always use these for image/video/audio work — never call a cloud media API.

## Services (reachable from inside this container by service name)
| Service | Base URL | What it makes / endpoints |
|---|---|---|
| **ComfyUI** | `http://comfyui:8188` | Images (FLUX.1-schnell) **and** video (Wan 2.1 T2V 1.3B). `POST /prompt`, `GET /history/{id}`, `GET /view?filename=` |
| **Piper** | `http://piper:5000` | Speech WAV. OpenAI-compatible `POST /v1/audio/speech` |

## Generate an image (ComfyUI)
Workflow: **`/work/workflows/flux-txt2img.json`** (FLUX.1-schnell, 1024x1024).
1. Load it. Set node `"2"` `.inputs.text` = prompt; node `"3"` `.inputs.seed` = int.
2. POST `http://comfyui:8188/prompt` with `{"prompt": <the "prompt" object>, "client_id": "hermes"}` → `{prompt_id}`.
3. Poll `/history/<prompt_id>` until an `outputs` entry exists.
4. GET `/view?filename=<outputs[*].images[0].filename>` → PNG bytes.
5. Write to `/work/gallery/<name>.png`; report the exact path.
Concrete, detailed prompts (subject, medium, lighting, composition) give the best
FLUX results. One POST per image; vary `seed` for more options.

## Generate a video (ComfyUI / Wan 2.1 T2V 1.3B)
Workflow: **`/work/workflows/wan-t2v.json`** (Wan 2.1 text-to-video 1.3B, 480p).
1. Load it. Set:
   - node `"3"` `.inputs.text` = prompt (a short story or scene description),
   - node `"6"` `.inputs.length` = frame count = `round(duration_s * fps, step 4)`
     (e.g. 15 s @ 16 fps → 240 → must be a multiple of 4),
   - node `"9"` `.inputs.fps` = fps (16 or 24),
   - node `"7"` `.inputs.seed` = integer.
2. POST `/prompt` as above → `{prompt_id}`.
3. Poll `/history/<prompt_id>` until an `outputs` entry exists (generation takes a
   few minutes for ~15 s).
4. Read the NEWEST output filename from that history entry — the `SaveWEBM` node
   is `outputs["9"]["images"][0]["filename"]` (it auto-increments the index like
   `hermes_video_00002_.webm`, so never assume `_00001_`).
5. `GET /view?filename=<that filename>&type=output` → bytes. Write them to
   **`/work/videos/<name>.webm`** (create the dir) and report the exact path +
   duration.
Write cinematic scene descriptions; the model renders 480p clips. Longer = slower;
keep ~5–20 s.

## Generate speech (Piper)
POST `http://piper:5000/v1/audio/speech` with:
```json
{"model":"en_US-lessac-medium","input":"<text>","voice":"en_US-lessac-medium","response_format":"wav"}
```
Response body is the WAV. Write to `/work/<titled>.wav`; report the path.

## Notes
- **Local only** — images/video/audio are generated on this machine.
- If ComfyUI OOMs (it shares the GPU with the LLM), tell the user to run:
  `docker compose exec ollama ollama stop qwen3.8-27b:q4km qwen3-4b:128k`
  then retry.
- Outputs land in `/work/gallery/` (images), `/work/videos/` (video), `/work/` (audio).
