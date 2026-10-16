#!/usr/bin/env bash

: "${AZURE_SUBSCRIPTION:?Set AZURE_SUBSCRIPTION to the target subscription ID.}"
if ! az account show >/dev/null 2>&1; then
  if [[ "${ADAPTIVE_APPS_NONINTERACTIVE:-false}" == "true" ]]; then
    echo "Azure authentication is unavailable. Refresh the Console token or sign in before retrying." >&2
    exit 1
  fi
  az login
fi
az account set --subscription "$AZURE_SUBSCRIPTION"
