#!/usr/bin/env bash
# Prepares a Mac for the Offline Industrial Copilot MicroHack. Run it before the day, while you are online:
#   bash resources/starter/setup.sh            (add --skip-models to skip the model downloads)
# Creates the work folder, a virtual environment with the packages, copies the starter helper, downloads the
# models used in the challenges, and checks the result. Safe to run again.
set -euo pipefail
LAB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$LAB/work"
MODELS=(phi-4-mini qwen2.5-1.5b qwen3-1.7b qwen3-embedding-0.6b)
START=$(date +%s)
step() { printf '\n==> %s\n' "$1"; }

step "Checking Foundry Local and Python"
command -v foundry >/dev/null || { echo "Install Foundry Local first: brew tap microsoft/foundrylocal && brew install foundrylocal"; exit 1; }
echo "Foundry Local $(foundry --version)"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else "Python 3.11 or newer is needed")'

step "Creating $WORK and the virtual environment"
mkdir -p "$WORK"
[ -x "$WORK/.venv/bin/python" ] || python3 -m venv "$WORK/.venv"
cp "$LAB/resources/starter/fl.py" "$WORK/"

step "Installing the Python packages"
"$WORK/.venv/bin/python" -m pip install --quiet --disable-pip-version-check -r "$LAB/resources/starter/requirements.txt" foundry-local-sdk

if [ "${1:-}" != "--skip-models" ]; then
  step "Downloading the models: ${MODELS[*]}"
  for m in "${MODELS[@]}"; do foundry model download "$m"; done
fi

step "Checking the result"
"$WORK/.venv/bin/python" -c "import openai, numpy, onnxruntime, foundry_local_sdk; print('Python packages: ok')"
foundry model list --cached
(cd "$WORK" && "$WORK/.venv/bin/python" -c "import fl; m = fl.load('phi-4-mini'); fl.client().chat.completions.create(model=m, max_tokens=5, messages=[{'role': 'user', 'content': 'Say OK.'}]); print('Local model answers: ok (' + m + ')')")
echo
echo "Ready in $(( ($(date +%s) - START) / 60 )) minutes. Activate the environment with: source $WORK/.venv/bin/activate"
