#!/usr/bin/env bash

set -euo pipefail

az bicep install

if ! command -v azd >/dev/null 2>&1; then
    curl -fsSL https://aka.ms/install-azd.sh | bash
fi

if ! azd ext list 2>/dev/null | grep -q 'microsoft.foundry'; then
    azd ext install microsoft.foundry
fi

if ! command -v func >/dev/null 2>&1; then
    sudo npm install --global azure-functions-core-tools@4 --unsafe-perm=true
fi