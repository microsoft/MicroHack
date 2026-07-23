#!/usr/bin/env bash
# Runs once when the Codespace / devcontainer is created.
set -euo pipefail

echo "==> Installing uv (fast Python package manager)"
python -m pip install --upgrade pip uv

echo "==> Installing dependencies from src/pyproject.toml (uv sync)"
( cd src && uv sync )

echo "==> Seeding src/.env (edit it with your lab dashboard values)"
if [ ! -f src/.env ]; then
  cp .env.example src/.env
fi

echo ""
echo "============================================================"
echo " Ready. Next steps:"
echo "   1. az login"
echo "   2. Edit src/.env with PROJECT_ENDPOINT + MODEL_DEPLOYMENT_NAME + COSMOS_ENDPOINT"
echo "   3. cd src && uv run uvicorn ui.app:app --reload --port 8000"
echo "   4. Open the forwarded port 8000 and follow the console."
echo "============================================================"
