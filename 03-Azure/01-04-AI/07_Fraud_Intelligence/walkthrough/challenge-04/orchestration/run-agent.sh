#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${HOME}/venvs/fraud-intelligence"

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
trap 'deactivate 2>/dev/null || true' EXIT

cd "$SCRIPT_DIR/src"

python -m pip install -r requirements.txt
python main.py

deactivate
trap - EXIT