# Walkthrough Challenge 1 - Prerequisites and landing zone preparation

**[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-02/solution-02.md)

Duration: 15 minutes (verification of an already-provisioned lab)

## Prerequisites

- Please ensure that you successfully verified the [General prerequisites](../../Readme.md#general-prerequisites) before continuing with this challenge.
- Your instructor/platform has completed [predeployment](../../resources/README.md), and your platform dashboard contains the subscription, lab resource group, connection details, and login credential fields.
- Your learner account has **Owner** on the assigned resource group and **Reader** on the subscription.

> [!IMPORTANT]
> **Many of the resource deployments in this Hack are adapted from the [Jumpstart ArcBox for IT Pros](https://jumpstart.azure.com/azure_jumpstart_arcbox/ITPro). Special thanks to the [Jumpstart Team](https://aka.ms/arcjumpstart) for their excellent work.**

### **Task 1: Receive the lab and verify host readiness**

1. Open your platform dashboard. Record the assigned subscription, `<YOUR-LAB-RESOURCE-GROUP>`, region, Hyper-V host name, and login credential fields. Do not copy passwords into shared notes.
2. Sign in to the [Azure Portal](https://portal.azure.com) with your assigned learner account. Open that existing resource group; do not create a source or destination resource group.
3. Locate the Hyper-V host `mh-<8charStableLabSuffix>-hv`. The suffix is a deterministic eight-character hash of the subscription and resource-group scope, not a UPN. Use the actual host name shown by your dashboard.
4. On the host VM, check that **DeploymentProgress** is **Deployment Completed** and **LabReady** is **single-rg-v1**; the resource group's **LabVerified** tag must also be **single-rg-v1**. Bootstrap publishes `C:\MHBox\lab-ready.json` (schema version 1), which the deployer independently checks before handoff. You can inspect ARM deployment status under the lab resource group's **Deployments**, but ARM success alone is not the readiness gate.
5. Connect to the host using **Connect** > **Bastion** and the supplied host login credentials. You can also select **Password from Azure Key Vault** and use the login secrets stored in the lab Key Vault.

> [!NOTE]
> Screenshots are illustrative and can show older names. Your dashboard's resource group, host name, and credentials are authoritative.

![Host VM DeploymentProgress tag example](./img/CS9.png)

> [!IMPORTANT]
> Fresh predeployment can take **35–90+ minutes**, including nested-VM downloads and configuration. ARM submission is polled with token refresh for up to **180 minutes per invocation**; guest readiness then has a separate **120-minute post-deployment timeout**. Before the initial handoff, the deployer waits for the completion tags, ready marker, four running guests, and both dashboard HTTP checks. Use the dashboard's lab region, also recorded in the RG's **LabRegion** tag; the RG's own metadata location can differ. The instructor's deployer can skip an unsupported preferred region before initial deployment, but retries never move or delete an existing lab. If your lab is not ready, contact the instructor with its status; do not delete the resource group or redeploy into a different region.

These are **initial-handoff** checks. If you revisit this walkthrough after migration, source guests may correctly be stopped. Completed deployment reruns preserve that state instead of restarting guests or requiring all four to be running; do not reset learner progress just to repeat Challenge 1.

### **Task 2: Verify the deployed VM resources**
Open *Hyper-V Manager* on the supplied host and ensure that four VMs are running.
+ MHBox-AzMigSrv
    + This system will be used later to deploy the Azure Migrate appliance, which is required for the discovery process.
+ MHBox-SQL
    + This system hosts a Microsoft SQL Server installation to demonstrate the SQL assessment capabilities.
+ MHBox-Ubuntu-01
    + This system hosts an Ubuntu server with an installed Apache web server.
+ MHBox-Win2K22
    + This system hosts Windows Server 2022 with an installed IIS web server.

The following lab-only credentials are used inside the nested VMs. These are separate from the generated host login credentials delivered by the platform and stored in Key Vault.

**Windows virtual machine credentials:**

```text
Username: Administrator
Password: JS123!!
```

**Ubuntu virtual machine credentials:**

```text
Username: jumpstart
Password: JS123!!
```

![image](./img/CS12.png)

Open Microsoft Edge and navigate to the IP address of each web VM. Confirm that the migration journey dashboard returns HTTP success and shows the correct details:

| VM | Platform | Web server |
| --- | --- | --- |
| *MHBox-Win2K22* | `Windows Server 2022` | `IIS` |
| *MHBox-Ubuntu-01* | `Ubuntu Linux` | `Apache` |

The **Hostname** value must match the VM you opened.

![image](./img/CS13.png)


### **Task 3: Verify the deployed Azure resources**

Within **the same** `<YOUR-LAB-RESOURCE-GROUP>`, verify:

| Component | Purpose |
| --- | --- |
| Source VNet, `mh-<suffix>-Source-VNet`, `10.1.0.0/16` | Hosts the Azure Hyper-V VM `mh-<suffix>-hv`, with the four nested guests above |
| Destination VNet, `mh-<suffix>-destination-VNet`, `10.2.0.0/16` | Target network for the migrated Azure VMs in Challenge 5 |
| Bastion access and NAT Gateways | Private administration and outbound connectivity for the respective networks |
| Azure Key Vault, `mhkv` plus the unique suffix derived from the RG ID | Stores the host login username and generated password |

**Textual architecture:** one learner resource group contains two networks. The source network contains the Hyper-V host and its nested appliance, SQL, Windows/IIS, and Ubuntu/Apache guests. Azure Migrate will later discover the guests and migrate the two web workloads into the destination network **without changing resource group**. Monitoring and App Service resources will also be created in this lab group during their exercises.

Do not install the Azure Migrate appliance or configure replication, monitoring, or App Service yet. Keep the whole resource group through Challenges 2–8; deleting it would remove both the simulated source and the migrated environment.

You successfully completed Challenge 1! 🚀🚀🚀
