# Lemonade Server

A self-hosted, OpenAI-compatible local-AI server powered by [Lemonade](https://github.com/lemonade-sdk/lemonade) (AMD-backed, multi-backend), deployed as a single Railway service. Drop in any HuggingFace GGUF model id and serve chat, completions, embeddings, images, audio, and more via standard OpenAI endpoints.

# Deploy and Host

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/lemonade-server-1)

## About Hosting

Lemonade Server runs as a single Docker container wrapping the official `ghcr.io/lemonade-sdk/lemonade-server:latest` image. A thin entrypoint launches the `lemond` binary on Railway's injected `$PORT`, exposes a `/live` healthcheck, and defaults to the **CPU** backend (Railway's managed containers have no GPU passthrough). Models auto-download from HuggingFace on first request and are cached on a persistent Railway volume, so reboots don't re-fetch weights.

- **Default Port:** Railway injects `$PORT` (the server binds it directly)
- **Health Check:** `GET /live` → `{"status":"ok"}`
- **Startup Time:** ~10-20 seconds (server boots; model weights download on demand)
- **Resource Usage:** CPU-only; a 0.6B Q4 model is usable, larger models are slow

## Why Deploy

- **OpenAI-compatible API** — Any OpenAI SDK works against `/v1/chat/completions`, `/v1/completions`, `/v1/embeddings`, `/v1/models`, plus image/audio endpoints.
- **Zero model baking** — No weights in the image; pull any GGUF from HuggingFace at runtime.
- **Persistent model cache** — A Railway volume at `/root/.cache` keeps downloaded weights and config across deploys.
- **Privacy-first** — All inference stays in your Railway project; no third-party API keys required.
- **Drop-in for Open WebUI** — Point Open WebUI's `OPENAI_API_BASE_URL` at this service's `/v1` to get a chat UI on top of your self-hosted models (no OpenAI key needed).

## Common Use Cases

- Self-hosted chat completion backend for apps expecting OpenAI endpoints
- **Chat UI via Open WebUI** — Run Open WebUI as a second service and connect it to this server's `/v1` for a full chat front-end
- Private embeddings endpoint for RAG / semantic search
- Local image generation and text-to-speech (TTS) without cloud providers
- A portable OpenAI-compatible API for experimentation and prototyping

## Dependencies for

### Deployment Dependencies

- **HuggingFace reachability** — Model weights download from `huggingface.co` on first load. If egress is blocked, enable **Outbound IPv6** in the project's Settings.
- **CPU compute** — No GPU needed; smaller GGUF models (e.g. `Qwen3-0.6B-GGUF`) give the best latency on CPU.

## API Endpoints

### `GET /live`
Liveness probe for Railway's healthcheck. Returns `{"status":"ok"}`.

### `GET /v1/models`
List models available locally (those downloaded/cached).

### `POST /v1/load`
Download and load a model by id (auto-fetches from HuggingFace):
```json
{ "model_name": "Qwen3-0.6B-GGUF" }
```

### `POST /v1/chat/completions`
OpenAI-compatible chat completion. The model auto-downloads on first use if not already loaded.

### `POST /v1/completions`, `POST /v1/embeddings`
Text completions and embedding vectors, OpenAI-compatible.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LEMONADE_BACKEND` | `cpu` | llama.cpp backend. `cpu` is reliable on Railway; GPU hosts may try `vulkan`/`rocm`. |
| `LEMONADE_DEFAULT_MODEL` | `Qwen3-0.6B-GGUF` | Model id auto-loaded on first request. |

## Notes / Limitations

- Railway's managed containers do **not** expose AMD/NVIDIA devices, so ROCm/Vulkan GPU backends are not available by default — CPU is the reliable path.
- **CPU inference is slow and model-size bound.** There is no GPU on Railway, so everything runs on CPU. A tiny model like `Qwen3-0.6B-GGUF` (≈0.4 GB, Q4) gives the best latency (still often 1-3+ minutes per short reply). Models with more parameters or heavier quantization (e.g. 1.5B-3B+) consume more RAM and take exponentially longer per token, and large models can exceed the container's memory and crash or get OOM-killed. **Stick to small GGUF models (≤ ~1B params, Q4/Q3) for usable CPU latency.**
- The server returns HTTP 200 but generation is CPU-bound — first-token latency and throughput scale directly with model size. Size down if responses feel too slow.
- Railway allows **one volume per service**; we mount a single volume at `/root/.cache` covering both the HuggingFace cache and the Lemonade config.

## Quick Start

1. Deploy via the button above (or link this repo as a new service).
2. Wait for the build to finish.
3. Load a model (auto-downloads):
   ```bash
   curl -X POST https://<railway-domain>/v1/load \
     -H "Content-Type: application/json" \
     -d '{"model_name":"Qwen3-0.6B-GGUF"}'
   ```
4. Chat with the OpenAI SDK:
   ```python
   from openai import OpenAI
   client = OpenAI(base_url="https://<railway-domain>/v1", api_key="lemonade")
   print(client.chat.completions.create(
       model="Qwen3-0.6B-GGUF",
       messages=[{"role":"user","content":"Hello, Lemonade!"}]
   ).choices[0].message.content)
   ```

## Resources

- [Lemonade on GitHub](https://github.com/lemonade-sdk/lemonade)
- [Lemonade Server Docs](https://lemonade-server.ai/docs/api/openai/)
- [Railway Docs](https://docs.railway.com)
