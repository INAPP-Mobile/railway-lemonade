# syntax=docker/dockerfile:1
# Wrap the official Lemonade server image so Railway can inject its $PORT.
# Upstream: https://github.com/lemonade-sdk/lemonade/pkgs/container/lemonade-server
FROM ghcr.io/lemonade-sdk/lemonade-server:latest

# curl is handy for Railway's HTTP healthcheck probe and in-container diagnostics.
# The upstream image is Ubuntu-based; use apt.
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Ensure cache/config dirs exist (volume mounts arrive empty + root-owned).
RUN mkdir -p /root/.cache/huggingface /opt/lemonade/llama /root/.cache/lemonade

# Default backend = CPU for reliable first boot on Railway (no GPU passthrough).
# The Railway volume mounted at /root/.cache/lemonade shadows this baked file;
# entrypoint.sh rewrites config.json from $LEMONADE_BACKEND at boot so the
# variable actually takes effect at runtime.
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY config.json /root/.cache/lemonade/config.json

EXPOSE 13305

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
