# Lab automation

This folder is optional. Delete it if this MicroHack does not need automated Azure provisioning.

When present, the MicroHack platform reads [lab-defaults.json](lab-defaults.json) to determine how to scope lab environments. It invokes [deploy-lab.ps1](deploy-lab.ps1) once per participant and, when present, [shared-deploy-lab.ps1](shared-deploy-lab.ps1) once per subscription before participant deployments begin.

## Folder layout

```text
labautomation/
|-- lab-defaults.json        # Platform-facing configuration
|-- deploy-lab.ps1           # Per-participant deployment hook
|-- run-local.ps1            # Local end-to-end test wrapper
|-- shared-deploy-lab.ps1    # Optional per-subscription deployment hook
`-- main.bicep               # MicroHack-specific infrastructure
```

## Test a deployment locally

Use [run-local.ps1](run-local.ps1) to test the participant deployment outside the MicroHack platform. The wrapper supplies the platform helper functions, resolves the participant's Entra object ID, and invokes [deploy-lab.ps1](deploy-lab.ps1).

Prerequisites:

- PowerShell with the `Az.Accounts` and `Az.Resources` modules available.
- An authenticated Azure session in the correct tenant (`Connect-AzAccount`).
- Permission to resolve the test user's Entra ID and to create resources and role assignments in the target subscription.

From this directory, select the test subscription and run:

```powershell
Set-AzContext -Subscription '<subscription-id>'
.\run-local.ps1 -UserPrincipalName 'labuser-1@contoso.com'
```

For UPNs matching `labuser-<number>@...`, the wrapper derives a resource group named `rg-labuser-<number>`. For other UPN formats, or to select a different test resource group, provide the name explicitly:

```powershell
.\run-local.ps1 `
	-SubscriptionId '<subscription-id>' `
	-ResourceGroupName 'rg-fraud-intelligence-test' `
	-UserPrincipalName 'tester@contoso.com'
```

> [!WARNING]
> Region fallback may remove and recreate the specified resource group. Use only a disposable test resource group in a non-production subscription, and do not target a resource group containing unrelated resources.

## Authoring guidance

- Keep each participant deployment isolated.
- Put shared resources and one-time subscription preparation in `shared-deploy-lab.ps1`.
- Use `Get-MhhStableHash` when deterministic per-participant resource names are required.
- Return participant-facing values as `HackboxCredential` hashtables.
- Never return participant-specific secrets from the shared deployment hook.

For the complete platform contract and helper cmdlet reference, see the [upstream MicroHack template documentation](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md).