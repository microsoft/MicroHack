#!/usr/bin/env bash
# Shared welcome banner for all MicroHack devcontainers.
# Invoked via each config's "postAttachCommand" with the working directory
# set to that MicroHack's workspaceFolder.
set -uo pipefail

name="$(basename "$PWD")"

echo ""
echo "👋 Welcome to the ${name} MicroHack!"
echo ""

if [ -f "$PWD/README.md" ]; then
  echo "Opening README.md to get you started..."
  code "$PWD/README.md" >/dev/null 2>&1 || true
else
  echo "No README.md found in this folder yet — check the MicroHack docs to get started."
fi

echo ""
