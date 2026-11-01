#!/usr/bin/env bash
# ============================================================================
# Registers all Azure Resource Providers required for:
#   - Azure Arc-enabled Kubernetes (connectedClusters & extensions)
#   - Azure IoT Operations (AIO, Device Registry, SecretSync)
#   - Foundry Local on Azure Arc-enabled Kubernetes (Microsoft.Foundry & CertManagement)
# ============================================================================
set -euo pipefail

PROVIDERS=(
  "Microsoft.Compute"
  "Microsoft.Network"
  "Microsoft.Storage"
  "Microsoft.KeyVault"
  "Microsoft.ExtendedLocation"
  "Microsoft.Kubernetes"
  "Microsoft.KubernetesConfiguration"
  "Microsoft.IoTOperations"
  "Microsoft.DeviceRegistry"
  "Microsoft.SecretSyncController"
)

echo "Registering required Azure Resource Providers..."
for rp in "${PROVIDERS[@]}"; do
  echo " -> Registering $rp"
  az provider register --namespace "$rp" --wait
done

echo "All required resource providers are registered:"
az provider list --query "[?contains(['Microsoft.Kubernetes','Microsoft.KubernetesConfiguration','Microsoft.ExtendedLocation','Microsoft.IoTOperations','Microsoft.DeviceRegistry','Microsoft.SecretSyncController'], namespace)].{Provider:namespace, State:registrationState}" --output table
