# TTYD lab automation

MicroHack [labautomation](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md)
integration for the Talk-To-Your-Data MicroHack.

## Layout

| File | Purpose |
| --- | --- |
| `lab-defaults.json` | Platform sizing: `resourcegroup`, 42 labs/subscription. |
| `shared-deploy-lab.ps1` | Runs once per subscription → `rg-shared`. Shared VNet, SQL MI, Fabric F32 capacity + gateway, backup storage, shared CSV storage, shared webshop, demo databases, stored proc, product, Agent job. |
| `deploy-lab.ps1` | Runs once per attendee. Two databases in the shared MI, the attendee's login + Fabric workspace, and CSV upload into the attendee's shared storage container. |
| `shared.bicep` | ARM template for the shared stack (reuses `infra/modules`). There is no per-attendee ARM deployment. |
| `sql/` | `StoredProcedure.sql`, `Jobs.sql`, `InsertProduct.sql` (discover per-attendee DBs by name pattern). |

## Split model

- **Shared, once per subscription:** one SQL Managed Instance and one Fabric F32
  capacity. Every lab user is a Fabric capacity administrator. The webshop and the
  `usp_PurchaseSpaceRanger` proc / Agent job are shared and fan out to every attendee
  database that exists. Employee CSV files live in one
  shared `employeedata...` storage account with per-user containers such as `container0001`
  for lab users or `containerx001` for local tests with regular tenant accounts.
- **Per attendee:** `TailspinToys_User####` + `TailspinToysFeedback_User####` in the
  shared MI, one Fabric workspace on the shared capacity, and one shared-storage
  container named `container####`. Local tests with regular tenant accounts use
  `TailspinToys_Userx001` / `TailspinToysFeedback_Userx001` and `containerx001`.

## Prerequisites

- The platform runs as a service principal. A Fabric administrator must enable both
  **Service principals can call Fabric public APIs** and **Service principals can create
  workspaces, connections, and deployment pipelines** in the Fabric Admin portal, with
  the platform service principal included in an allowed security group. The second
  setting is separate and disabled by default for new tenants.
  Instead of clicking through the portal, a Fabric/Global administrator can run
  `enable-fabric-sp-tenant-settings.ps1 -SecurityGroupObjectId <group-object-id>`
  (signed in as themselves, not the deployment service principal) to enable both
  settings for the security group that contains the platform service principal.
- The automation accesses SQL with a stable administrator password scoped to `rg-shared`;
  both hooks derive the same value without printing or distributing it. The shared hook
  also configures the first lab user as the SQL MI Entra admin and grants Directory Readers
  to the MI identity for attendee login creation.
- Fabric mirroring uses the shared SQL login `demouser` / `Demo@pass1234567`; both hooks
  ensure the login exists and has `db_owner` access to restored lab databases.
- The scripts read `databasebackup/*.bak` and `csvdata/*.csv` and reuse
  `shared.bicep` and `infra/modules`, all local to this folder, so **mount this
  `labautomation` folder** for local testing.

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

For local testing with regular tenant accounts instead of framework-created
`labuser-####` accounts, set `TTYD_LOCAL_TEST_USER_INDEX` before each attendee
run. This keeps the hook parameters framework-compatible while producing stable
local names such as `TailspinToys_Userx001` and `containerx001`:

```powershell
$env:TTYD_LOCAL_TEST_USER_INDEX = '1'
./deploy-lab.ps1 `
  -DeploymentType      resourcegroup `
  -SubscriptionId      (Get-AzContext).Subscription.Id `
  -ResourceGroupName   "rg-lab-local-test-x001" `
  -PreferredLocation   "swedencentral" `
  -AllowedEntraUserIds '<regular-user-object-id>'

$env:TTYD_LOCAL_TEST_USER_INDEX = '2'
./deploy-lab.ps1 `
  -DeploymentType      resourcegroup `
  -SubscriptionId      (Get-AzContext).Subscription.Id `
  -ResourceGroupName   "rg-lab-local-test-x002" `
  -PreferredLocation   "swedencentral" `
  -AllowedEntraUserIds '<regular-user-object-id>'
```

> Provisioning a SQL Managed Instance takes hours; `shared-deploy-lab.ps1` submits it
> asynchronously and refreshes credentials while it polls.
