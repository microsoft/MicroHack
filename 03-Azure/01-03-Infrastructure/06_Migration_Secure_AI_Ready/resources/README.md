# Instructor deployment and validation

Learners start with a ready environment and follow [Solution 1](../walkthrough/challenge-01/solution-01.md) to verify it. They do not deploy the landing zone themselves.

## Hosted deployment

The platform reads [lab-defaults.json](../labautomation/lab-defaults.json):

| Default | Value |
| --- | --- |
| `groups` | `[]` |
| `deploymentType` | `resourcegroup` |
| `labsPerSubscription` | `2` |
| `preferredLocation` | `swedencentral` |
| `estimatedDailyCostsUsd` | `80.0` |

The USD 80 daily value is a **conservative planning estimate for a running baseline, not a quote**. Check current Azure pricing, quota, learner count, and event duration before the event; later migration, monitoring, and App Service exercises can add charges.

The platform first runs [shared-deploy-lab.ps1](../labautomation/shared-deploy-lab.ps1) **once per subscription** to register required resource providers. This hook creates no shared resource group and makes no Defender plan changes. It then invokes [deploy-lab.ps1](../labautomation/deploy-lab.ps1) once per learner. The per-learner entry point accepts exactly these platform parameters:

| Parameter | Type | Meaning |
| --- | --- | --- |
| `DeploymentType` | `string` | `resourcegroup` for this Hack |
| `SubscriptionId` | `string` | The learner's assigned subscription |
| `ResourceGroupName` | `string` | The single, already-created learner resource group |
| `PreferredLocation` | `string[]` | Ordered deployment regions; default `swedencentral`. The RG's metadata location does not restrict its resources' region. |
| `AllowedEntraUserIds` | `string[]` | Learner Entra object IDs requiring lab access |

Before per-learner invocation, the platform creates the resource group, authenticates Az PowerShell and Azure CLI, selects the subscription, and assigns the learner **Owner** on the resource group and **Reader** on the subscription. The hosted script neither signs in nor creates another resource group. Instructors must verify that the shared provider-registration hook succeeded, quota is sufficient, and any optional Defender plans were separately approved and enabled; do not grant subscription Owner to every learner.

[main.bicep](../labautomation/bicep/main.bicep) and its local modules are packaged together under `labautomation/bicep`, so importing or mounting only `labautomation` is sufficient for template deployment. The guest automation and demo-page assets remain under `resources/artifacts` and are downloaded from the selected repository/branch.

The template deploys at **resource-group scope** into the existing group. For a fresh lab, the deployer tries `PreferredLocation` in order and warns when skipping a region. Preflight checks provider-advertised service regions, the documented Bastion Developer regional list, zone-1 availability of `Standard_D16s_v5` and `PremiumV2_LRS`, and available regional/DSv5 quota for a new host. These checks do not reserve capacity or guarantee that a later ARM deployment will succeed. With only the default `swedencentral` configured, there is no second candidate; instructors can configure an ordered list of suitable regions before deployment.

The selected region is recorded as **LabRegion** on the RG before submission. Its metadata location stays unchanged, even if resources deploy in a different preferred region. Existing labs retain their recorded region, checked against the host location and deployment parameters. A retry never moves partial resources to another region, deletes the RG, or changes the lab names. Include the recorded region in `PreferredLocation` when rerunning an existing lab; resolve inconsistent or missing region records before retrying.

All user-controlled resources for the Hack stay in that one group: the source VNet (`10.1.0.0/16`), destination VNet (`10.2.0.0/16`), NAT Gateways, Bastion access, Key Vault, and Hyper-V host.

Names use the first eight characters of a deterministic 12-character platform hash of the subscription and resource-group scope, not the deployer's UPN. Requesting 12 characters respects `Get-MhhStableHash`'s documented 12–64 range while retaining the eight-character naming suffix:

| Resource | Name |
| --- | --- |
| Hyper-V host | `mh-<suffix>-hv` (14 characters) |
| Source VNet | `mh-<suffix>-Source-VNet` |
| Destination VNet | `mh-<suffix>-destination-VNet` |
| Key Vault | `mhkv` followed by `uniqueString(resourceGroup().id)` |

The deployer passes the Bicep parameters `labSuffix` and `participantObjectIds`. The main template exposes `hostVmName`, `keyVaultName`, `sourceVnetName`, `destinationVnetName`, and `clientVmLogonUserName` so automation can discover the actual deployed names.

Fresh predeployment prepares only Challenge 1, including the four running nested guests `MHBox-AzMigSrv`, `MHBox-SQL`, `MHBox-Win2K22`, and `MHBox-Ubuntu-01`. It does not configure discovery, migration, monitoring, or App Service. Bootstrap publishes the schema-version-1 ready marker at `C:\MHBox\lab-ready.json` and sets the host VM tags `LabReady=single-rg-v1` and `DeploymentProgress=Deployment Completed`. Before the initial handoff, the deployer waits for completion and independently checks the marker and four running guests; the marker records Bootstrap's HTTP/metadata checks of both dashboards. Only after independent verification succeeds does the deployer set `LabVerified=single-rg-v1` on the resource group. Failed verification is retried rather than treated as a completed handoff.

Allow **35–90+ minutes** for a fresh environment. ARM is submitted asynchronously and polled every 30 seconds with token refresh, bounded to **180 minutes per invocation**. An already-running deployment is polled rather than resubmitted. After ARM succeeds, the separate guest-readiness wait is bounded to **120 minutes**. ARM failure/cancellation, submission errors, and timeouts stop the script without publishing credentials. A timeout does not cancel ARM; resources are preserved, and a rerun resumes polling. Inspect deployment/provisioning diagnostics before retrying; no deployment failure triggers destructive cleanup or cross-region recreation. An ARM deployment success alone does not prove guest readiness.

**Completed reruns preserve learner progress:** the deployer reuses an already-completed baseline without restarting the nested guests or requiring them to be running. A learner may have legitimately stopped source guests during migration. Only incomplete deployments receive an incremental deployment retry; rerunning is not a request to reset the lab.

The platform dashboard provides the lab resource group, connection details, and login credential fields. The Key Vault retains the host login username and generated password. Keep those credentials private; do not paste generated passwords into deployment commands, shared notes, or screenshots.

## Manual/local validation for instructors

Use the current standard template's [local testing harness](../../../../99-MicroHack-Template/labautomation/README.md#local-testing), not an arbitrary PowerShell session. That harness supplies the platform helper stand-ins through the `ghcr.io/qxsch/adminpwsh:latest` container. Mount this Hack's `labautomation` directory, including its `bicep` subtree, at `/app` as shown by the harness. No sibling repository directories are required. The pinned Azure Verified Module for Key Vault must still be restored by Bicep, and downloaded guest artifacts must be reachable.

1. Follow the harness's container setup and authenticate **both** Az PowerShell and Azure CLI locally; select the same intended instructor-owned test subscription in both contexts. Hosted runs already have those contexts.
2. Follow [testing the shared hook locally](../../../../99-MicroHack-Template/labautomation/README.md#testing-the-shared-hook-locally): from this Hack's `labautomation` directory, run `shared-deploy-lab.ps1` once for the test subscription before the per-learner script, using that subscription's preferred regions and learner object IDs. The instructor test identity needs permission to register providers; learner subscription Reader is intentionally insufficient.
3. Create a fresh, uniquely named test resource group before the per-learner invocation, normally in the first preferred region, and grant the test learner RG Owner and subscription Reader to reproduce learner access. Unlike hosted execution, local preparation is your responsibility. If a test group already exists, inspect it or choose a new name; do not delete a group as a retry shortcut.
4. Inside the harness, invoke `deploy-lab.ps1` from this Hack's `labautomation` directory with all five parameters from the table above, using `DeploymentType` = `resourcegroup`, the existing test resource group, ordered region array, and learner object-ID array. Confirm that the reported selected region and RG **LabRegion** tag match the resources, not necessarily the RG's metadata location. Follow the standard harness invocation syntax and helper limitations.
5. Verify the returned credential fields (the platform dashboard shows these for hosted runs) and Key Vault access as the test learner, then follow Solution 1's **initial-handoff** readiness checks. Also verify that a completed rerun preserves learner state and does not restart migrated source guests. Syntax/build checks alone are not evidence of a live deployment.

The official source remains `microsoft/MicroHack` on `main`. For premerge fork testing, check out the fork's feature branch locally **and** set `MICROHACK_GITHUB_ACCOUNT` and `MICROHACK_GITHUB_BRANCH` in the harness/deployment environment to that owner and branch before invocation. These environment variables default to `microsoft` and `main` and select downloaded automation and demo-page assets via the existing Bicep `githubAccount` and `githubBranch` parameters. The local checkout and asset reference must match, and the branch must retain the Hack resource paths. Do not change the official repository identifiers in documentation or templates just to test a fork.

## Resource lifecycle

Keep the single lab resource group throughout Challenges 2–8, including the learner-created Azure Migrate, migrated VMs, monitoring resources, and App Service resources. Azure Monitor can create an Azure-managed `MA_*_managed` group for workspace internals; that service-managed exception is not another learner-created lab group.

Only after the lab owner approves the finish should you clean up. Use Azure Migrate's supported test-migration cleanup and complete-migration/stop-replication actions, and remove backup protection or retained recovery data through the relevant service's supported cleanup. Backup or replication dependencies can block resource-group deletion. Deleting the lab resource group removes **both** the simulated source and migrated resources, plus monitoring and App Service; it is not a way to remove just the source environment.

## Quota information if multiple users deploy to the same subscription

If you have multiple users deploying to the same subscription, you need to make sure you have enough quota for the deployments.
For a single-user deployment, you should make sure to have the following quotas requested upfront:

| Quota name  | Needed quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | 30  |
| Standard DSv5 Family vCPUs  | 16  |
| Standard BS Family vCPUs  | 10  |
| Public IP Addresses - Standard | 5 |

For five users who need to deploy individually to a region, make sure you have the following quotas in place:

| Quota name  | Needed quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | 150  |
| Standard DSv5 Family vCPUs  | 80  |
| Standard BS Family vCPUs  | 50  |
| Public IP Addresses - Standard | 25 |

To request a quota increase, follow [Request quota increases in the Azure portal](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal).
