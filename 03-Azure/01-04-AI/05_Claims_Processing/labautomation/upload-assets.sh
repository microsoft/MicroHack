#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: upload-assets.sh --subscription ID --resource-group NAME [options]

Options:
  --storage-account NAME      Storage account to use (auto-detected by default)
  --claims-container NAME     Claims container (default: claims-data)
  --policies-container NAME   Policies container (default: policies)
  -h, --help                  Show this help
EOF
}

subscription_id=""
resource_group=""
storage_account=""
claims_container="claims-data"
policies_container="policies"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription)
      subscription_id="${2:-}"
      shift 2
      ;;
    --resource-group)
      resource_group="${2:-}"
      shift 2
      ;;
    --storage-account)
      storage_account="${2:-}"
      shift 2
      ;;
    --claims-container)
      claims_container="${2:-}"
      shift 2
      ;;
    --policies-container)
      policies_container="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$subscription_id" || -z "$resource_group" ]]; then
  usage >&2
  exit 2
fi

script_path=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
claims_root="$script_path/data/claims"
policies_root="$script_path/data/policies"

if [[ ! -d "$claims_root" ]]; then
  echo "Claim data folder not found: $claims_root" >&2
  exit 1
fi
if [[ ! -d "$policies_root" ]]; then
  echo "Policy data folder not found: $policies_root" >&2
  exit 1
fi

mapfile -d '' claim_files < <(find "$claims_root" -type f -print0)
mapfile -d '' policy_files < <(find "$policies_root" -maxdepth 1 -type f -name '*.md' -print0)
if [[ ${#claim_files[@]} -eq 0 || ${#policy_files[@]} -eq 0 ]]; then
  echo "No upload assets found." >&2
  exit 1
fi

az account set --subscription "$subscription_id"
az group show --name "$resource_group" --output none

if [[ -z "$storage_account" ]]; then
  mapfile -t storage_accounts < <(
    az storage account list \
      --resource-group "$resource_group" \
      --query '[].name' \
      --output tsv
  )
  if [[ ${#storage_accounts[@]} -ne 1 ]]; then
    echo "Expected one storage account in '$resource_group', found ${#storage_accounts[@]}. Pass --storage-account." >&2
    exit 1
  fi
  storage_account="${storage_accounts[0]}"
fi

storage_key=$(az storage account keys list \
  --resource-group "$resource_group" \
  --account-name "$storage_account" \
  --query '[0].value' \
  --output tsv)

if [[ -z "$storage_key" ]]; then
  echo "Could not retrieve a key for storage account '$storage_account'." >&2
  exit 1
fi

printf "Uploading %d claim assets to %s/%s...\n" \
  "${#claim_files[@]}" "$storage_account" "$claims_container"
az storage blob upload-batch \
  --account-name "$storage_account" \
  --account-key "$storage_key" \
  --destination "$claims_container" \
  --source "$claims_root" \
  --overwrite \
  --output none

printf "Uploading %d policy assets to %s/%s...\n" \
  "${#policy_files[@]}" "$storage_account" "$policies_container"
az storage blob upload-batch \
  --account-name "$storage_account" \
  --account-key "$storage_key" \
  --destination "$policies_container" \
  --source "$policies_root" \
  --pattern '*.md' \
  --overwrite \
  --output none

mapfile -t actual_claim_blobs < <(
  az storage blob list \
    --account-name "$storage_account" \
    --account-key "$storage_key" \
    --container-name "$claims_container" \
    --query '[].name' \
    --output tsv
)
mapfile -t actual_policy_blobs < <(
  az storage blob list \
    --account-name "$storage_account" \
    --account-key "$storage_key" \
    --container-name "$policies_container" \
    --query '[].name' \
    --output tsv
)

missing=0
for file in "${claim_files[@]}"; do
  blob_name="${file#"$claims_root"/}"
  if [[ ! " ${actual_claim_blobs[*]} " =~ " ${blob_name} " ]]; then
    echo "Missing claim blob after upload: $blob_name" >&2
    missing=1
  fi
done
for file in "${policy_files[@]}"; do
  blob_name="$(basename -- "$file")"
  if [[ ! " ${actual_policy_blobs[*]} " =~ " ${blob_name} " ]]; then
    echo "Missing policy blob after upload: $blob_name" >&2
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "Upload verification failed." >&2
  exit 1
fi

printf "Asset upload complete and verified: %d claims, %d policies.\n" \
  "${#claim_files[@]}" "${#policy_files[@]}"
