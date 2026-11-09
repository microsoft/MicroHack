#!/usr/bin/env bash
# Runs once when the Codespace / Dev Container is created (postCreateCommand).
# Safe to re-run manually:  bash .devcontainer/post-create.sh
set -euo pipefail

# Always work from the hack folder, regardless of the caller's working directory.
HACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HACK_DIR"

echo "==> Checking Python 3.11+"
PYTHON_BIN="$(command -v python3 || command -v python || true)"
if [ -z "$PYTHON_BIN" ]; then
  echo "ERROR: Python is missing. Rebuild the container with the 'Azure / AI / Inventory Planning Agentic' dev container configuration." >&2
  exit 1
fi
if ! "$PYTHON_BIN" -c 'import sys; raise SystemExit(sys.version_info < (3, 11))'; then
  echo "ERROR: Python 3.11 or newer is required (found $("$PYTHON_BIN" --version 2>&1))." >&2
  exit 1
fi
"$PYTHON_BIN" --version

echo "==> Installing uv (fast Python package manager)"
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
  "$PYTHON_BIN" -m pip install --quiet --upgrade uv \
    || curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$HOME/.local/bin" UV_NO_MODIFY_PATH=1 sh
fi
# Make uv available in every new terminal, wherever it was installed.
if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
uv --version

echo "==> Installing dependencies from src/pyproject.toml (uv sync)"
# src/.venv is a Docker volume (see devcontainer.json "mounts"); new volumes are root-owned.
if [ -d src/.venv ] && [ ! -w src/.venv ]; then
  sudo chown "$(id -u):$(id -g)" src/.venv
fi
( cd src && uv sync --python "$PYTHON_BIN" --link-mode=copy )

echo "==> Seeding src/.env (edit it with your lab dashboard values)"
if [ ! -f src/.env ]; then
  cp .env.example src/.env
  echo "    Created src/.env from .env.example"
else
  echo "    src/.env already exists - leaving it unchanged"
fi

echo ""
echo "============================================================"
echo " Ready. Next steps (see challenges/challenge-01.md):"
echo "   1. az login --use-device-code"
echo "   2. Edit src/.env with PROJECT_ENDPOINT + MODEL_DEPLOYMENT_NAME + COSMOS_ENDPOINT"
echo "   3. cd src && uv run uvicorn ui.app:app --reload --port 8000"
echo "   4. Open the forwarded port 8000 and follow the console."
echo "============================================================"