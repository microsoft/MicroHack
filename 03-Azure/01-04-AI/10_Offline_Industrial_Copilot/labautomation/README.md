# Lab automation

Deploys the per-participant resources for the **Offline Industrial Copilot** MicroHack.

## What it deploys

| Resource | Why |
|----------|-----|
| Azure Machine Learning workspace (with storage account, key vault, Log Analytics and Application Insights) | Challenge 5, full path: train the fault classifier in the cloud |
| Windows 11 Pro VM with Python 3.12, a public IP and RDP (optional) | For participants who do not bring a laptop that can run Foundry Local |

Foundry Local itself is **not** installed by the automation. Installing it is part of challenge 1.

## Files

| File | Purpose |
|------|---------|
| `deploy-lab.ps1` | Platform entry point, one run per participant |
| `shared-deploy-lab.ps1` | Registers resource providers and the public IP feature once per subscription |
| `main.bicep` | The resources above |
| `lab-defaults.json` | Platform configuration |

## Decisions

- **`deploymentType: resourcegroup`**: the platform creates the resource group and the participant is its owner. Nothing in the lab needs subscription-level rights.
- **`preferredLocation: swedencentral, westeurope, norwayeast`**: regions with Azure Machine Learning and the `Standard_D8s_v5` VM size. The platform falls back to the next region if a deployment fails.
- **`labsPerSubscription: 4`**: each lab uses one 8-vCPU VM, so four labs use 32 vCPUs of the DSv5 family.
- **`estimatedDailyCostsUsd: 8`**: about 6 USD for the VM (8 hours), plus the disk, the public IP and a small Azure Machine Learning compute for challenge 5. The workspace itself costs nothing while idle.
- **VM is Windows, not Linux**: the Foundry Local command-line tool is supported on Windows and macOS. The VM runs the models on its CPU, so answers are slower than on a laptop with a GPU or NPU. Choose a GPU `vmSize` in `main.bicep` for faster answers.
- **The extension installs the Visual C++ runtime** next to Python. Foundry Local cannot start without it on a fresh Windows image.
- **Set `$deployVm = $false`** in `deploy-lab.ps1` if every participant brings a suitable laptop.
- **`shared-deploy-lab.ps1` registers `Microsoft.Network/AllowBringYourOwnPublicIpAddress`**, like other labs on the platform that give a VM a public IP. Without it some subscriptions refuse every public IP with `SubscriptionNotRegisteredForFeature`, and the platform stops the lab without trying another region. The `SecurityControl: Ignore` tag does not help here: this is a subscription feature, not a policy. The script also registers `Microsoft.Network` again, because the feature only takes effect after that.
- **The VM password comes from `New-MhhStablePassword -Purpose 'vm-admin'`**: the same value on every run. A redeploy keeps the first password on an existing VM, so a new random password would put a password on the dashboard that does not work.

## Credentials returned to the participant

Resource group, Azure Machine Learning workspace, region, and (with a VM) the VM address, user name and password. The password stays the same on every run of the script.

## Assumptions and checks

- `Invoke-MhhDeploymentWithRegionFallback`, `Get-MhhStableHash` and `New-MhhStablePassword` are platform helpers. Both scripts were tested **unchanged** with the helper module from the platform's local-testing image (`ghcr.io/qxsch/adminpwsh`): `shared-deploy-lab.ps1` registered the public IP feature on a subscription that refused public IPs (1.4 minutes), then `deploy-lab.ps1` provisioned the lab in `swedencentral` on the first attempt in 6.3 minutes, with the VM address, user and password on the dashboard. After provisioning the VM had Python 3.12.8 and the Visual C++ runtime.
- On that VM, signed in as `labadmin`, Foundry Local 0.12.1, the models and the lab code for challenges 1 to 6 were run, including the offline run with the internet blocked (see the coach notes in the walkthrough), and so was the Azure Machine Learning workspace (a compute instance and the challenge 5 notebook, accuracy 0.94).
- **Azure Machine Learning workspaces are soft-deleted** when their resource group is deleted, and the workspace name is the same for a participant on every run. If the platform wipes and recreates the resource group (a retry or a region fallback), the new deployment can meet the soft-deleted name. The platform purges it and treats this as a same-region retry; the older helper in the testing image treats it as fatal. When you test locally with that image, use a new participant ID or wait for the purge.
- Not verified: a participant signing in over Remote Desktop, and the platform's current helper (only the version in the testing image).
- The VM is open for Remote Desktop from the internet and carries the `SecurityControl: Ignore` tag, like other labs on the platform. Do not use it for anything except this lab.
