#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./delete-all-rgs.sh <subscription-id> [exclude-regex]
#
# Example:
#   ./delete-all-rgs.sh 6a8f6f8b-c0fa-4f8d-a338-a2abec5dfa4b
#   ./delete-all-rgs.sh 6a8f6f8b-c0fa-4f8d-a338-a2abec5dfa4b '^(NetworkWatcherRG|MH-SubKeepAlive-DoNotDelete|Default-ActivityLogAlerts|MA_defaultazuremonitorworkspace-weu_westeurope_managed)$'

SUBSCRIPTION_ID="${1:-}"
EXCLUDE_REGEX="${2:-^$}"   # default: exclude nothing

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "ERROR: subscription id is required"
  exit 1
fi

az account set --subscription "$SUBSCRIPTION_ID"

mapfile -t ALL_RGS < <(az group list --query "[].name" -o tsv)

if [[ ${#ALL_RGS[@]} -eq 0 ]]; then
  echo "No resource groups found in subscription $SUBSCRIPTION_ID"
  exit 0
fi

TO_DELETE=()
for rg in "${ALL_RGS[@]}"; do
  if [[ "$rg" =~ $EXCLUDE_REGEX ]]; then
    continue
  fi
  TO_DELETE+=("$rg")
done

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
  echo "No resource groups matched for deletion after exclusions."
  exit 0
fi

echo "Subscription: $SUBSCRIPTION_ID"
echo "Resource groups to delete (${#TO_DELETE[@]}):"
printf ' - %s\n' "${TO_DELETE[@]}"
echo
read -r -p "Type DELETE to continue: " CONFIRM
if [[ "$CONFIRM" != "DELETE" ]]; then
  echo "Aborted."
  exit 1
fi

echo "Submitting deletions..."
for rg in "${TO_DELETE[@]}"; do
  echo "Deleting $rg"
  az group delete --name "$rg" --yes --no-wait
done

echo "Waiting for deletions to complete..."
for rg in "${TO_DELETE[@]}"; do
  while az group exists --name "$rg" | grep -q true; do
    echo "Still deleting: $rg"
    sleep 10
  done
  echo "Deleted: $rg"
done

echo "Done."