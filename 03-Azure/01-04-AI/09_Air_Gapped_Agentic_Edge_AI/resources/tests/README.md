# Automated Validation & Testing Suite

This folder provides a two-tier automated test harness for **Air-Gapped Agentic AI: Orchestrating Local SLMs and IoT on Edge Kubernetes**:

## 1. Fast Offline & Closed-Loop Simulation (`-Mode Offline`, < 10 seconds, $0 cost)

Runs locally on Windows, macOS, Linux, or in CI without provisioning Azure resources:

```powershell
pwsh ./resources/tests/Invoke-E2ELabValidation.ps1 -Mode Offline
```

What it validates automatically:
1. **Bicep Compilation:** Compiles [`../infra/main.bicep`](../infra/main.bicep) with `az bicep build` and verifies zero errors/warnings.
2. **Lab Automation Contracts:** Parses [`../../labautomation/deploy-lab.ps1`](../../labautomation/deploy-lab.ps1), [`../../labautomation/shared-deploy-lab.ps1`](../../labautomation/shared-deploy-lab.ps1), and [`../../labautomation/lab-defaults.json`](../../labautomation/lab-defaults.json).
3. **Markdown Link Integrity:** Verifies all relative links across all 15 Markdown files.
4. **Live Closed-Loop Edge Agent + SAT Auth + Foundry Local Simulation ([`test-local-simulation.py`](test-local-simulation.py)):**
   - Validates all 8 Kubernetes YAML manifests and cross-checks SAT `ServiceAccount` names (`inference-client`), token audience (`foundry-local`), and `NetworkPolicy` port rules.
   - Starts an in-process mock Foundry Local `/phi-4-mini/v1/chat/completions` server that enforces `Bearer <SAT-token>` authorization and grounds responses on [`SOP-CNC-042`](../manifests/03-edge-agent/local-sop-configmap.yaml).
   - Feeds both a **Warning telemetry anomaly** (`96.4°C`, `9.8 mm/s`) and the **Challenge 5 Air-Gapped Critical Fault** (`114.6°C`, `15.2 mm/s`, `1.4 LPM`) through the actual [`agent.py`](../src/edge-agent/agent.py) code and asserts the exact PLC actuation payloads (`adjust_plc_setpoint` with `-25%` RPM and `trigger_safety_interlock` with `-60%` RPM / `SAFE_HOLD`).

---

## 2. Unattended Live Azure E2E Test (`-Mode LiveAzure`)

Deploys the `fast-k3s` Ubuntu 24.04 VM into an Azure subscription and uses `az vm run-command invoke` to execute [`run-challenges-e2e.sh`](run-challenges-e2e.sh) directly inside the K3s host without manual SSH/Bastion interaction:

```powershell
pwsh ./resources/tests/Invoke-E2ELabValidation.ps1 `
  -Mode LiveAzure `
  -SubscriptionId "<your-subscription-id>" `
  -ResourceGroupName "rg-edgeai-e2e-test" `
  -Location "eastus2" `
  -CleanupOnSuccess
```
