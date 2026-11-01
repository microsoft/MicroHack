# Lab Automation — Air-Gapped Agentic AI: Orchestrating Local SLMs and IoT on Edge Kubernetes

This folder integrates the MicroHack with the automated lab provisioning platform.

## Files

- [`lab-defaults.json`](lab-defaults.json): Declares `resourcegroup-with-subscriptionowner` scope (required so participants can onboard Azure Arc connected clusters and create custom locations/role assignments), packing 4 labs per subscription (64 vCPUs total using `Standard_D16s_v5`).
- [`shared-deploy-lab.ps1`](shared-deploy-lab.ps1): Runs once per subscription prior to participant fan-out to register `Microsoft.Kubernetes`, `Microsoft.IoTOperations`, `Microsoft.Foundry`, `Microsoft.CertManagement`, and related resource providers.
- [`deploy-lab.ps1`](deploy-lab.ps1): Runs once per participant to deploy [`../resources/infra/main.bicep`](../resources/infra/main.bicep) (`Standard_D16s_v5` Ubuntu 24.04 VM with K3s, Helm, `kubectl`, and Azure CLI extensions pre-installed via `cloud-init-k3s.yaml`).
