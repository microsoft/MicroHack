# Deploy Azure Arc Jumpstart LocalBox

This folder contains the manual deployment entry point and preparation instructions for the Sovereign Cloud MicroHack's Azure Arc Jumpstart LocalBox environment.

## Overview

For Challenge 6 (Operating a Sovereign Hybrid Cloud with Azure Arc & Azure Local), we use the official Azure Arc Jumpstart LocalBox environment. Participants provision their own Azure Local VMs and use those VMs for the Defender for Cloud and Azure Update Manager exercises. This provides:

- **Maintained templates** - Arc Jumpstart is actively maintained by Microsoft
- **Latest features** - Always uses the newest Azure Arc and Azure Local capabilities
- **Validated configurations** - Tested and proven deployment patterns
- **Comprehensive documentation** - Extensive guides available

## LocalBox
Azure Local environment simulating an on-premises private cloud.

**Features:**
- Virtualized Azure Local cluster
- Arc Resource Bridge integration
- VM deployment capabilities via Azure Portal
- AKS on Azure Local support

**Requirements:**
- 32 vCPUs (Standard_E32s_v6 recommended)
- ~4-6 hours deployment time

**Deployment:**
```powershell
.\deploy-localbox.ps1 -ResourceGroupName "rg-localbox-shared" -Location "swedencentral"
```

**Cost**

LocalBox cost is approximately 100-110 USD per day. We recommend setting it up the week before the event, so for example 5 days before the event would result in a cost between 5-600 USD.

Budget separately for the approved Defender for Servers plan and review its scope and charges before enabling it on the shared subscription.

## Arc Jumpstart Resources

- **LocalBox Documentation**: https://jumpstart.azure.com/azure_jumpstart_localbox
- **GitHub Repository**: https://github.com/microsoft/azure_arc

## Usage Instructions

### Step 1: Verify Prerequisites
Before deploying, ensure you have:
1. Sufficient vCPU quotas (run `../subscription-preparations/2-vcpu-quotas.ps1`)
2. Required resource providers registered (run `../subscription-preparations/1-resource-providers.ps1`)
3. Azure CLI and Az PowerShell modules installed

### Step 2: Deploy Environment
Run the LocalBox deployment script:

```powershell
.\deploy-localbox.ps1 -ResourceGroupName "rg-localbox-shared" -Location "swedencentral"
```

### Step 3: Wait for Deployment
LocalBox provisioning can take 4-6 hours, with additional time for the VM image and preparation steps below. Monitor progress in:
- Azure Portal > Resource Groups > Deployments

#### Hackathons console deployment behavior

The Hackathons console runs `labautomation/shared-deploy-lab.ps1` once per
subscription. The shared hook creates or reuses `rg-localbox-shared`, validates the
LocalBox template, and submits the deployment asynchronously. Step 2 is
considered successful when Azure accepts that deployment; it does not wait for
the full LocalBox environment to finish provisioning.

The LocalBox host, network, Bastion, and Log Analytics resources use the selected
lab region. Azure Local registration and its staging storage account use Australia East,
which is a supported Azure Local registration region and is not blocked by the hosted
lab subscription policy that denies West Europe.

The shared hook applies `SecurityControl=Ignore` to `rg-localbox-shared`, and the
outer LocalBox template applies the same tag to its resources. This temporary MCAPS
exemption is required during Azure Local deployment because cluster validation uses
storage account key authentication and requires public access to its validation
storage account and Key Vault. The exemption is scoped to the LocalBox resource
group and expires after 14 days under MCAPS governance automation. Deploy or rerun
the shared hook early enough for the exemption to take effect before validating the
Azure Local cluster.

If MCAPS policy modified resources before the exemption took effect, applying the
tag does not revert those existing settings. After the exemption is active, enable
storage account key access and public network access on the validation storage
account, enable public network access on the validation Key Vault, and rerun the
Azure Local validate and deploy workflow from `LocalBox-Client`.

After Step 2 completes, a facilitator must verify the deployment manually:

1. Open `rg-localbox-shared` in the Azure Portal and select **Deployments**.
2. Confirm that the `localbox-*` deployment is progressing without a failed
    operation.
3. Confirm that the `LocalBox-Client` VM appears after approximately 15-20
    minutes. Its presence confirms that the deployment has started, not that the
    complete LocalBox environment is ready.
4. Before signing in to the VM, use **Help > Reset password** on
    `LocalBox-Client` to set a facilitator-known password for the `arcdemo`
    account. The unattended shared deployment uses an automatically generated
    password and does not publish it to participants.
5. Continue monitoring the deployment and complete the storage, VM image,
    logical network, and role-assignment checks below before participants start
    Challenge 6. Full provisioning can take 4-6 hours.

Re-running Step 2 does not submit another LocalBox deployment while an existing
`localbox-*` deployment is active or has succeeded. If the existing deployment
failed, correct the Azure deployment error before retrying Step 2.

### Step 4: Expand UserStorage Volumes

> [!IMPORTANT]
> LocalBox VM creation may fail for some attendees if the UserStorage volumes do not have enough free space. The default volume sizes (~679 GB each) can be too small when multiple attendees create VMs simultaneously. To fix this, add a 1 TB data disk to each Azure Local node and expand the storage pool before the event.

![Create role assignment](./img/localbox_storage_01.png)

This is a two-part process: first add disks from the **host VM**, then expand volumes from a **cluster node**.

#### Part A: Add data disks to each node (run on the host VM)

Connect to the LocalBox host VM (`LOCALBOX-CLIENT`) via Azure Bastion or Remote Desktop, open a PowerShell session as Administrator, and run:

```powershell
# Create and attach a 1 TB dynamic VHDX to each Azure Local node
foreach ($node in @("AzLHOST1", "AzLHOST2")) {
    $vhdxPath = "V:\VMs\${node}-S2D_Disk7.vhdx"
    Write-Host "Creating $vhdxPath (1 TB dynamic)..."
    New-VHD -Path $vhdxPath -SizeBytes 1TB -Dynamic
    Add-VMHardDiskDrive -VMName $node -Path $vhdxPath
    Write-Host "Attached $vhdxPath to $node"
}
```

#### Part B: Expand the storage pool and volumes (run on a cluster node)

Open **Hyper-V Manager** on the host VM, connect to one of the Azure Local nodes (e.g., `AzLHOST1`), and open a PowerShell session as Administrator on the node:

**1. Expand the UserStorage virtual disks and partitions:**

```powershell
# Get the updated pool
$pool = Get-StoragePool -FriendlyName "SU1_Pool"

# Calculate available space and split evenly between the two UserStorage volumes
$freeSpace = ($pool.Size - $pool.AllocatedSize)
$expandPerDisk = [math]::Floor($freeSpace / 2)

# Expand each UserStorage_1 virtual disk
foreach ($diskName in @("UserStorage_1")) {
    $vdisk = Get-VirtualDisk -FriendlyName $diskName
    $currentSize = $vdisk.Size
    $newSize = $currentSize + $expandPerDisk
    Write-Host "Expanding $diskName from $([math]::Round($currentSize/1GB)) GB to $([math]::Round($newSize/1GB)) GB..."
    Resize-VirtualDisk -FriendlyName $diskName -Size $newSize
}

# Expand the partition to use the new virtual disk space
foreach ($diskName in @("UserStorage_1")) {
    $volume = Get-Volume -FriendlyName $diskName
    $partition = $volume | Get-Partition
    $maxSize = ($partition | Get-PartitionSupportedSize).SizeMax
    Resize-Partition -InputObject $partition -Size $maxSize
    Write-Host "$diskName partition resized to $([math]::Round($maxSize/1GB)) GB"
}

# Remove the UserStorage_2 virtual disk as we will only use UserStorage_1 for the labs
Remove-VirtualDisk -FriendlyName UserStorage_2
```

**2. Verify the new sizes:**

```powershell
Get-StoragePool -FriendlyName "SU1_Pool"
```

```powershell
Get-Volume -FriendlyName UserStorage_*
```

![Azure Local storage](./img/localbox_storage_01.png)

You should also see updated values in the Azure Portal:

![Azure Local storage](./img/localbox_storage_02.png)

### Step 5: Configure the Environment

#### VM image and storage paths

1. In the Azure Portal, navigate to your **Azure Local** instance
2. Select **VM images** in the left menu
3. Click **+ Add VM Image -> From Azure Marketplace** to start the VM image creation wizard
![Create VM image](./img/add_vm_image_win_01.jpg)
4. For the **Image to download** parameter, select **[smalldisk] Windows Server 2025: Azure edition - Gen2**
![Create VM image](./img/add_vm_image_win_02.png)
5. For the **Storage path** parameter, select **Choose manually** and the **UserStorage1** storage path.
6. Select **Review + create** and wait for the deployment to finish (on LocalBox, this takes approximately 2,5 hours due to use of nested VMs and a virtual router VM).
7. To avoid an issue with image file copies when many VMs are created in parallel, delete the storage path **UserStorage2**
![Create VM image](./img/add_vm_image_win_03.png)

#### Logical network

1. In the Azure Portal, navigate to your **Azure Local** instance
2. Select **Logical network** in the left menu
3. Click **+ Create logical network** to start the creation wizard
![Create logical network](./img/add_logical_network_01.jpg)
4. For the **Logical network name** parameter, enter **localbox-vm-lnet-vlan200** and click **Next: Network Configuration**:
![Create logical network](./img/add_logical_network_02.jpg)
5. Enter the following parameter values:
- **IPv4 address space**: 192.168.200.0 /24 (256 addresses)
- **IP Pools**: 192.168.200.0 - 192.168.200.255
- **Default gateway**: 192.168.200.1
- **DNS Servers**: 192.168.1.254
- **VLAN ID**: 200
![Create logical network](./img/add_logical_network_03.jpg)
6. Select **Review + create** and wait for the deployment to finish

Role assignments:
1. In the Azure Portal, navigate to your resource group where LocalBox is deployed (e.g. `rg-localbox-shared`)
2. Select **Access control (IAM)** in the left menu
3. Click **+ Add -> Add role assignment** to start the role assignment wizard
![Create role assignment](./img/add_rbac_01.jpg)
4. Select the **Reader** role and click **Next**
![Create role assignment](./img/add_rbac_02.jpg)
5. Click **+ Select members** to add the **LabUsers** Entra ID group
![Create role assignment](./img/add_rbac_03.jpg)
6. Click **Next**
7. For **Assignment type**, select **Active** and click **Review + assign**
![Create role assignment](./img/add_rbac_04.jpg)
8. Repeat steps 1-7 to add a role assignment for the **Azure Stack HCI VM Contributor** role
![Create role assignment](./img/add_rbac_05.jpg)

Hosted lab automation grants participants access to shared LocalBox resources, **Owner** on their own resource group, and subscription-level **Security Reader** for Defender visibility. For manual setups, verify equivalent scoped permissions before testing. Students must be able to create their own VM, manage its extensions, and assess updates without managing other participants' VMs. Do not grant subscription-level Owner or User Access Administrator to perform these exercises.

#### Defender for Servers readiness (organizer)

1. Confirm the Defender for Servers plan approved for the event, including its subscription scope and charges
2. As an authorized subscription administrator, open **Microsoft Defender for Cloud -> Environment settings** and select the lab subscription
3. Under **Defender plans**, enable **Servers** with the approved plan if it is not already enabled, and save the changes
4. Verify that the [Defender for Endpoint integration](https://learn.microsoft.com/azure/defender-for-cloud/enable-defender-for-endpoint) is enabled and that required onboarding settings and extensions can apply to the participant VMs
5. Verify that participants have **Security Reader** access to review coverage and recommendations. Students verify protection on their own VM; subscription-level plan changes remain an organizer responsibility

### Step 6: Test the Environment

Before participants begin, follow the [Challenge 6 walkthrough](../../walkthrough/challenge-06/solution-06.md) using a normal participant identity:

1. Create a Windows Server 2025 VM in that participant's assigned resource group on the prepared LocalBox logical network, with **Enable guest management** selected
2. Verify that the VM has a valid IP address, working DNS, and outbound access to the required Azure Arc, Defender, and configured Windows update-source endpoints. Confirm **Guest management: Enabled (Connected)** on the VM's **Overview -> Properties -> Configuration** page; see [Enable guest management](https://learn.microsoft.com/azure/azure-local/manage/manage-arc-virtual-machines#enable-guest-management) if onboarding fails
3. Confirm that the same VM appears in Defender for Cloud **Inventory**, verify Defender for Servers coverage and onboarding, and review its assessment status. Allow time for recommendations to populate; an empty list is not proof of completed assessment
4. Locate that VM in Azure Update Manager **Resources -> Machines**, run **Check for updates**, and verify a successful assessment and its timestamp. Zero pending updates is a valid result; a pending or failed assessment is not
5. Confirm that neither exercise requires selecting shared cluster nodes, the LocalBox host, Arc Resource Bridge, or another participant's VM, or changing subscription-level settings

Resolve connectivity, extension provisioning, or permission failures before the event. Keep any permission changes limited to the operation and resource scope actually required. Do not install patches or restart shared resources during this readiness test.

## Notes

- **Shared Environment**: For MicroHack events, typically one LocalBox instance per subscription is shared among participants; each participant creates a VM in their assigned resource group
- **Resource Costs**: LocalBox and the enabled security services consume Azure resources; clean up lab resources after the event and review lab-specific paid plans with the subscription owner
- **Deployment Time**: Plan for deployment time when scheduling your MicroHack
