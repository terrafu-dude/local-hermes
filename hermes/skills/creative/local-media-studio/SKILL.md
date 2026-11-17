---
name: local-media-studio
description: "Use when the user wants an image or spoken audio generated locally. Drives on-prem ComfyUI (FLUX.1-schnell) and Piper TTS."
---

# Local Media Studio

This Hermes runs next to two LOCAL media services on the same Docker network.
Always use these for image/audio work — never call a cloud image or audio API.

## Services (reachable from inside this container by service name)
| Service | Base URL | What it makes / endpoints |
|---|---|---|
| **ComfyUI** | `http://comfyui:8188` | Images (FLUX.1-schnell). `POST /prompt`, `GET /history/{id}`, `GET /view?filename=` |
| **Piper** | `http://piper:5000` | Speech WAV. OpenAI-compatible `POST /v1/audio/speech` |

## Generate an image (ComfyUI)
A configured workflow is at **`/work/workflows/flux-txt2img.json`** (ComfyUI API
format: FLUX.1-schnell, 1024x1024, 4 steps, cfg 1.0). Use it like this:

1. Load the workflow. Set node `"2"` `.inputs.text` = your prompt; node `"3"`
   `.inputs.seed` = an integer (so you can vary output).
2. POST to `http://comfyui:8188/prompt` with body
   `{"prompt": <the workflow's "prompt" object>, "client_id": "hermes"}`.
   Response contains `{"prompt_id": "…"}`.
3. Poll `http://comfyui:8188/history/<prompt_id>` until an `outputs` entry exists.
4. Take the first `outputs[*].images[0].filename` and GET
   `http://comfyui:8188/view?filename=<filename>` → PNG bytes.
5. Write the bytes to `/work/gallery/<name>.png` and report the exact path.

Write concrete, detailed prompts (subject, medium, lighting, composition) for the
best FLUX results. One POST per image; vary `seed` to get more options.

```bash
# Example (body.json has {"prompt":{...},"client_id":"hermes"} with node 2 text + node 3 seed set)
curl -s http://comfyui:8188/prompt -H 'Content-Type: application/json' --data @body.json
```

## Generate speech (Piper)
POST `http://piper:5000/v1/audio/speech` with JSON:
```json
{"model":"en_US-lessac-medium","input":"<text>","voice":"en_US-lessac-medium","response_format":"wav"}
```
The response body is the WAV. Write it to `/work/<titled>.wav` and report the path.

## Notes
- **Local only** — images and audio are generated on this machine.
- If ComfyUI replies with an OOM/GPU error (it shares the GPU with the LLM), tell
  the user to run:
  `docker compose exec ollama ollama stop qwen3.8-27b:q4km qwen3-4b:128k`
  then retry the generation.
- Outputs land in `/work/gallery/` (images) and `/work/` (audio).
