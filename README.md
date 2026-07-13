# Lemonade Server — Railway Template

A self-hosted, OpenAI-compatible local-AI server powered by [Lemonade](https://github.com/lemonade-sdk/lemonade) (AMD-backed, multi-backend: CPU / Vulkan / ROCm), deployed as a single Railway service. Drop in any HuggingFace GGUF model id and serve chat, completions, embeddings, images, audio, and more via standard OpenAI endpoints.

## Features

- **OpenAI-compatible API** — `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/models`, plus image/audio endpoints.
- **Auto model download** — Models pull from HuggingFace on first request; nothing to pre-bake.
- **Persistent cache** — One Railway volume at `/root/.cache` keeps downloaded model weights and config across deploys (Railway allows one volume per service).
- **CPU by default** — Reliable first boot on Railway's managed containers (no GPU passthrough needed).
- **Railway-native** — Honors Railway's injected `$PORT`; liveness probe at `/live`.

## Architecture

    Railway CDN ──► Lemonade container (lemond :$PORT)
                        ├── /live            (health)
                        ├── /v1/chat/completions
                        ├── /v1/models
                        └── volume /root/.cache  (hf models + lemonade config/metadata)

> **Note on volumes:** Railway allows **one volume per service** on this plan. We mount a single volume at `/root/.cache`, which covers both `/root/.cache/huggingface` (downloaded model weights) and `/root/.cache/lemonade` (config + model metadata). The `/opt/lemonade/llama` backend binaries are not persisted (they auto-install and are small); if a backend reinstall is unwanted, bump the volume to a larger tier or accept the one-time install.

## Deploy

1. Click **Deploy on Railway** (or link this folder as a new service).
2. Wait for the build (pulls `ghcr.io/lemonade-sdk/lemonade-server:latest`).
3. The server starts in CPU mode and is reachable at your Railway domain on `/v1/...`.
4. Load a model (auto-downloads):

       curl -X POST https://<railway-domain>/v1/load \
         -H "Content-Type: application/json" \
         -d '{"model_name":"Qwen3-0.6B-GGUF"}'

5. Chat (OpenAI SDK):

       from openai import OpenAI
       client = OpenAI(base_url="https://<railway-domain>/v1", api_key="lemonade")
       print(client.chat.completions.create(
           model="Qwen3-0.6B-GGUF",
           messages=[{"role":"user","content":"Hello, Lemonade!"}]
       ).choices[0].message.content)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LEMONADE_BACKEND` | `cpu` | llama.cpp backend. `cpu` is safe on Railway. GPU hosts may try `vulkan`/`rocm`. |
| `LEMONADE_DEFAULT_MODEL` | `Qwen3-0.6B-GGUF` | Model id auto-loaded on first request. |

## Notes / Limitations

- Railway's managed containers do **not** expose AMD/NVIDIA devices, so ROCm/Vulkan GPU backends are not available by default — CPU is the reliable path.
- On CPU, inference is slow: a 0.6B Q4 model can take 1-3+ minutes for a short reply. This is expected; the server returns HTTP 200 but generation is CPU-bound. Use a small model (e.g. `Qwen3-0.6B-GGUF`) for reasonable latency.
- First model load downloads weights from HuggingFace (enable **Outbound IPv6** in project Settings if egress is blocked).
- The HuggingFace cache + config live on a single Railway volume at `/root/.cache`, so reboots don't re-download.

## Resources

- [Lemonade on GitHub](https://github.com/lemonade-sdk/lemonade)
- [Lemonade Server Docs](https://lemonade-server.ai/docs/api/openai/)
- [Railway Docs](https://docs.railway.com)
