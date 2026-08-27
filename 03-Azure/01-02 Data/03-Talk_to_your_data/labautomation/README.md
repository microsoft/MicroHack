# TTYD lab automation

MicroHack [labautomation](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md)
integration for the Talk-To-Your-Data MicroHack.

## Layout

| File | Purpose |
| --- | --- |
| `lab-defaults.json` | Platform sizing: `resourcegroup`, 42 labs/subscription. |
| `shared-deploy-lab.ps1` | Runs once per subscription → `rg-shared`. Shared VNet, SQL MI, Fabric F32 capacity + gateway, backup storage, shared webshop, demo databases, stored proc, product, Agent job. |
| `deploy-lab.ps1` | Runs once per attendee. Two databases in the shared MI, the attendee's login + Fabric workspace, a per-attendee CSV storage account. |
| `shared.bicep` / `main.bicep` | ARM templates for the shared stack and the per-attendee resources (reuse `infra/modules`). |
| `sql/` | `StoredProcedure.sql`, `Jobs.sql`, `InsertProduct.sql` (discover per-attendee DBs by name pattern). |

## Split model

- **Shared, once per subscription:** one SQL Managed Instance and one Fabric F32
  capacity. The webshop and the `usp_PurchaseSpaceRanger` proc / Agent job are shared
  and fan out to every attendee database that exists.
- **Per attendee:** `TailspinToys_<short>` + `TailspinToysFeedback_<short>` in the
  shared MI, one Fabric workspace on the shared capacity, one CSV storage account in
  the attendee resource group.

## Prerequisites

- **Fabric APIs for service principals** must be enabled in the tenant admin portal
  (the platform runs as a service principal). Without it, gateway/workspace creation
  fails.
- SQL is accessed with an Entra token as the deploying principal, which
  `shared-deploy-lab.ps1` sets as the SQL MI Entra admin (plus Directory Readers on the
  MI identity). No shared SQL password is distributed.
- The scripts read `databasebackup/*.bak` and `csvdata/*.csv` and reuse
  `infra/modules`, all local to this folder, so **mount this `labautomation` folder** for local testing.

## Local testing

Run the [adminpwsh](https://github.com/qxsch/adminpwsh) container from the
**`labautomation` folder** so the scripts can reach `databasebackup`, `csvdata` and `infra`:

```powershell
docker run -it -v "${PWD}:/app" --rm "ghcr.io/qxsch/adminpwsh:latest"
```

Inside the container, sign in yourself (the platform does this automatically in
production — do not add these logins to the scripts):

```powershell
Connect-AzAccount -UseDeviceAuthentication
az login --use-device-code
cd /app
```

Then run the two hooks in the real order. Pass more than one object id to
`-AllowedEntraUserIds` to check RBAC covers every attendee:

```powershell
./shared-deploy-lab.ps1 `
    -SubscriptionId      (Get-AzContext).Subscription.Id `
    -PreferredLocation   "swedencentral" `
    -AllowedEntraUserIds (Get-AzADUser -SignedIn).Id

./deploy-lab.ps1 `
    -DeploymentType      resourcegroup `
    -SubscriptionId      (Get-AzContext).Subscription.Id `
    -ResourceGroupName   "rg-lab-local-test" `
    -PreferredLocation   "swedencentral" `
    -AllowedEntraUserIds (Get-AzADUser -SignedIn).Id
```

> Provisioning a SQL Managed Instance takes hours; `shared-deploy-lab.ps1` submits it
> asynchronously and refreshes credentials while it polls.
