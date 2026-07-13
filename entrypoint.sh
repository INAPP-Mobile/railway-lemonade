#!/bin/sh
# Lemonade server entrypoint for Railway.
# Railway injects $PORT (the public port). We launch lemond on that port so the
# OpenAI-compatible server is reachable behind Railway's proxy.
#
# No `set -e`: volume dir chmod must not crash the container (volume-safety rule).

# Make sure the persistent dirs exist (volumes arrive empty/root-owned).
mkdir -p /root/.cache/huggingface /opt/lemonade/llama /root/.cache/lemonade 2>/dev/null || true

CONFIG_DIR="/root/.cache/lemonade"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Apply backend override from template var (default: cpu, baked into the image).
# Merge into the existing config.json (preserving upstream defaults) rather than
# overwriting the whole file, so we don't drop other server settings.
if [ -n "${LEMONADE_BACKEND:-}" ]; then
  if [ ! -f "$CONFIG_FILE" ]; then
    echo '{}' > "$CONFIG_FILE"
  fi
  python3 - "$CONFIG_FILE" "$LEMONADE_BACKEND" <<'PYEOF'
import json, sys
path, backend = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        cfg = json.load(f)
except Exception:
    cfg = {}
cfg.setdefault("llamacpp", {})
cfg["llamacpp"]["backend"] = backend
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
  echo "Lemonade: llama.cpp backend set to '${LEMONADE_BACKEND}'"
fi

PORT="${PORT:-13305}"
echo "Lemonade: starting lemond on 0.0.0.0:${PORT} (Railway \$PORT=${PORT})"

# Forward to the upstream server binary. --host/--port are documented flags.
exec lemond --host 0.0.0.0 --port "$PORT"
