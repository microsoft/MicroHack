# Oracle on Azure Microhack Terraform

This Terraform project automates the provisioning of a scalable infrastructure for running Oracle on Azure, specifically tailored for a multi-user workshop (like a "MicroHack").

It is designed to create multiple, isolated Azure Kubernetes Service (AKS) environments, one for each participant, while enabling connectivity to a central Oracle Database@Azure (ODAA) deployment.

## Table of Contents

* [Core Functionality](#core-functionality)
* [Important Notes](#important)
* [Architecture Diagrams](#azure-resource-topology)
* [Prerequisites](#prerequisites)
* [Azure Quotas and Limits](#azure-quotas-and-limits)
* [Setup](#setup)
  * [Pre-flight Validation](#pre-flight-validation-recommended)
  * [Azure Authentication](#sign-in-and-set-the-active-subscription-repeat-for-each-subscription-that-will-host-resources)
  * [Oracle SDN Registration](#register-the-oracle-sdn-appliance-preview-feature-on-every-hosting-subscription-so-odaa-networking-works)
* [Configuration](#configuration)
* [Post-Deployment Checks](#post-deployment-checks)
* [Destroying the Environment](#destroying-the-environment)
* [Troubleshooting](#troubleshooting)

## Core Functionality

1.  **Multi-User Environment**: Provisions multiple, environments for a specified number of users (`user_count`). Each user gets their own Azure Kubernetes Service (AKS) cluster.
2.  **Subscription Management**: Distributes the deployments across up to five different Azure subscriptions in a round-robin fashion to manage resource allocation and quotas.
3.  **Identity and Access Management**:
    *   For each user, it creates a new Entra ID user with a generated password and adds them to an already existing security group.
    *   Assigns the necessary RBAC roles to these users so they can manage their AKS cluster and interact with the shared Oracle database resources.
4.  **Oracle Database@Azure (ODAA)**:
    *   Sets up a single, shared virtual network (VNet) in a dedicated subscription to host the Oracle database infrastructure.
6.  **Networking**:
    *   Creates a VNet for each AKS cluster.
    *   Establishes VNet peering between each user's AKS VNet and the central, shared ODAA VNet, allowing applications on AKS to communicate with the Oracle database.
    *   Configures Private DNS zones to resolve Oracle's service endpoints from within the AKS VNets.
7.  **Ingress Control**: Deploys an NGINX Ingress Controller into each AKS cluster using a Helm chart, enabling external access to applications.
8.  **Credential Management**: Generates a `user_credentials.json` file containing the initial login details for the newly created Entra ID users.

## **IMPORTANT**

- Oracle Database@Azure service needs to be bought via Azure Marketplace, you will not be able to use an Azure Subscription which is backed up with Microsoft Credits.
- Microsoft operates an Azure Tenant which can be used during the Microhack.
- Setting up the Environment can only be done by authorized personnel, reach out to your Account Team or contact the Microsoft Microhack organizers for assistance.
- The following instruction are only relevant in case you belong to the authorized team which is allowed to setup the Microhack environment.

## Azure Resource Topology

The following diagram illustrates the default topology created by this Terraform configuration. Multiple participant environments are created , but all are peered to a **single, shared ODAA VNet** located in the central ODAA subscription.

```mermaid
flowchart TD
    subgraph Participant_Subscription_00["Participant Subscription 0"]
        subgraph rgAKS_00["AKS Resource Group 0"]
            vnetAKS_00["AKS VNet 0<br/>10.0.0.0/16"]
            aks_00["AKS Cluster 0"]
            ingress_00["Ingress NGINX"]
            vnetAKS_00 --> aks_00 --> ingress_00
        end
    end

    subgraph Participant_Subscription_01["Participant Subscription 1"]
        subgraph rgAKS_01["AKS Resource Group 1"]
            vnetAKS_01["AKS VNet 1<br/>10.1.0.0/16"]
            aks_01["AKS Cluster 1"]
            ingress_01["Ingress NGINX"]
            vnetAKS_01 --> aks_01 --> ingress_01
        end
    end

    subgraph Shared_ODAA_Subscription["Shared ODAA Subscription"]
        subgraph rgODAA_shared["Shared ODAA Resource Group"]
            direction TB
            vnetODAA_shared["Shared ODAA VNet<br/>192.168.0.0/16"]
            adb_00[("ODAA-ADB 0")]
            adb_01[("ODAA-ADB 1")]
            vnetODAA_shared --> adb_00
            vnetODAA_shared --> adb_01
        end
    end

    vnetAKS_00 <-.-> |"VNet Peering"| vnetODAA_shared
    vnetAKS_01 <-.-> |"VNet Peering"| vnetODAA_shared
```

With the default settings (`user_count = 1`), Terraform provisions a single AKS environment and peers its VNet to the shared ODAA VNet. If `user_count` is increased, the configuration creates additional AKS environments in the next available subscription slots, each peered to the same shared ODAA network.

## Identity and Access Management

The project's identity and access management (IAM) structure is designed to provide secure, role-based access for each participant. The following diagram illustrates how users, groups, and roles are interconnected:

```mermaid
flowchart TD
    subgraph Entra_ID ["Entra ID Tenant"]
        direction LR
        subgraph Users
            direction TB
            user00["User 00 (mh00)"]
            user01["User 01 (mh01)"]
        end
        
        group["Shared Deployment Group<br/>(e.g., mh-odaa-user-grp)"]
        
        user00 --> |Member Of| group
        user01 --> |Member Of| group
    end

    subgraph Azure_Resources ["Azure Resources"]
        direction LR
        subgraph AKS_Resources ["AKS Resources (Per User)"]
            aks_cluster_00["AKS Cluster 00"]
        end
        
        subgraph ODAA_Resources ["Shared ODAA Resources"]
            odaa_rg["ODAA Resource Group"]
        end
    end

    subgraph Oracle_Cloud_App ["Oracle Cloud Enterprise App"]
        oci_app["OCI Service Principal"]
    end

    user00 --> |"AKS Cluster User<br/>AKS RBAC Writer<br/>Subscription Reader"| aks_cluster_00
    user00 --> |"Oracle ADB Admin<br/>Private DNS Zone Reader"| odaa_rg
    
    group --> |"App Role Assignment<br/>(e.g., 'User')"| oci_app
```

- **Entra ID Group**: A single security group is created to contain all workshop participants.
- **User Accounts**: A unique Entra ID user is created for each participant and added to the shared group.
- **Azure RBAC**: Each user is granted specific roles directly on their own resources (like their AKS cluster) and on the shared ODAA resources, following the principle of least privilege.
- **Oracle Cloud Access**: The entire group is granted an App Role on the Oracle Cloud enterprise application, allowing all members to access Oracle Cloud services.

## Subscription Distribution

Terraform keeps the subscription assignments inside `locals.deployments`. Each participant is indexed (starting at zero) and mapped to one of the five `subscription_targets` by taking `index % length(subscription_targets)`. This round-robin pattern repeats once all five slots are used, so participant 5 returns to slot 0, participant 6 to slot 1, and so on. The diagram below visualizes the default `subscription_targets` list and how the first six participants are routed:

```mermaid
flowchart LR
  subgraph Participants["Participants (index order)"]
    direction TB
    U0["user00<br/>index 0"]
    U1["user01<br/>index 1"]
    U2["user02<br/>index 2"]
    U3["user03<br/>index 3"]
    U4["user04<br/>index 4"]
    U5["user05<br/>index 5"]
  end

  subgraph Slots["Round-robin slots"]
    direction TB
    S0["Slot 0"]
    S1["Slot 1"]
    S2["Slot 2"]
    S3["Slot 3"]
    S4["Slot 4"]
  end

  subgraph Subscriptions["subscription_targets"]
    direction TB
    Sub0["subscription id 0"]
    Sub1["subscription id 1"]
    Sub2["subscription id 2"]
    Sub3["subscription id 3"]
    Sub4["subscription id 4"]
  end

  U0 --> S0
  U1 --> S1
  U2 --> S2
  U3 --> S3
  U4 --> S4
  U5 --> S0

  S0 --> Sub0
  S1 --> Sub1
  S2 --> Sub2
  S3 --> Sub3
  S4 --> Sub4
```

Adding or reordering entries in `subscription_targets` immediately changes the destinations for all participants because Terraform recomputes the locals on the next plan/apply.

## Azure Quotas and Limits

> NOTE: The current architecture is setup to support 50 users in parallel.

The main constrain of how many user we can support depends on two main factors:

- vCPU quota for the VM family used by AKS clusters (default: Standard_D4as_v5) cross all 5 subscriptions.
- Number of eCPU allowed for Oracle Autonomous Database instances in the linked OCI Tenancy,

At azure we can provide a current max of 100 vCPU per subscriptions for the Standard_Dv5 family. Each AKS cluster with 2 nodes of size Standard_D4as_v5 consumes in total 8 vCPU. Therefore we can support a 12 users per Subscription (12 * 8 = 96 vCPU < 100 vCPU). Currently we support 5 subscriptions for the Microhack, therefore the total max user count is 60 users (5 * 12 = 60).

Screenshot of the current vCPU quota and usage for one single user
![Azure VM Quotas](./media/imagecopy.png)

## OCI Limits

On the OCI tenancy we do support a total of 128 eCPUs. Each Oracle Autonomous Database instance consumes 2 eCPU. Therefore the max user count is limited to 64 users.

Reference: [Oracle Database@Azure Service Limits and Quotas](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/quotas-service-limits.htm)

![OCI eCPU Quotas](./media/image.png)

If it comes to delegated subnets we need to consider that our OracleSubscription of plan "pay-as-you-go" does only support 2 delegated subnets:
![OCI delegated subnets limits](./media/oci_delegated_subnets_limit.png)
## Prerequisites

### Required Tools

- Windows 10/11 host with PowerShell 7+
- **Terraform** (>= 1.5.0) - Install via: `winget install Hashicorp.Terraform`
- **Azure CLI** - Install via: `winget install Microsoft.AzureCLI`
- **kubectl** - Install via: `winget install Kubernetes.kubectl`
- **helm** - Install via: `winget install Helm.Helm`
- **OCI CLI** - Install via: `winget install Oracle.OCI-CLI`

All tools must be available in your `PATH`.

### Service Principal (Required)

**IMPORTANT:** This deployment requires a Service Principal with the necessary permissions. Azure CLI authentication with a real User would run into a token expiration issue, so it alone is not sufficient because of the long time required for the deployment.

**Create the Service Principal:**

```powershell
cd resources\infra\terraform\scripts
.\create-service-principal.ps1 -OutputPath ..\mhodaa-sp-credentials.json
```

This script creates a service principal with:
- **Azure RBAC roles**: Contributor and User Access Administrator on the mhteams and mhodaa management groups
- **Entra ID directory roles**: User Administrator and Application Administrator
- **Microsoft Graph API permissions**: User.ReadWrite.All and AppRoleAssignment.ReadWrite.All

The credentials will be saved to `mhodaa-sp-credentials.json`.

**Configure Terraform to use the Service Principal:**

Add the credentials to your `terraform.tfvars`:

```hcl
client_id     = "your-app-id-here"
client_secret = "your-client-secret-here"
```

### Azure Permissions

The Service Principal requires the following role assignments on every target subscription (including the shared ODAA subscription):
- **Contributor** - For resource management
- **User Access Administrator** - For RBAC role assignments

Additionally, the Service Principal must have these Entra ID permissions:
- **Directory Roles**: User Administrator, Application Administrator
- **Microsoft Graph API Application Permissions**: User.ReadWrite.All, AppRoleAssignment.ReadWrite.All
  
### Management Group Access

- Read access to the **mhteams** management group for policy definitions and assignments

### Oracle Cloud Integration

- Oracle Cloud service principal (enterprise application) must be registered in your Entra ID tenant
- Default object ID: `6240ab05-e243-48b2-9619-c3e3f53c6dca`
- The service principal must have an enabled app role that workshop users can be assigned to

### Resource Quotas

Ensure adequate quotas in all target subscriptions:
- **VM Quota**: Standard_DASv5Family (Standard_D4as_v5) - Each user requires 8 vCPUs
- **Oracle eCPU**: Each Oracle Autonomous Database requires 2 eCPUs in the linked OCI tenancy
- **Public IPs**: For AKS ingress controllers (1 per cluster)

### Register the Oracle SDN appliance preview feature on every hosting subscription so ODAA networking works

> NOTE: This may already be done for your subscriptions; check the feature state before registering.
>
> Reference: [Oracle Database@Azure Network Planning - Advanced Network Features](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-network-plan#advanced-network-features)

```powershell
az feature register --namespace Microsoft.Baremetal --name EnableRotterdamSdnApplianceForOracle
az feature register --namespace Microsoft.Network --name EnableRotterdamSdnApplianceForOracle
az feature show --namespace Microsoft.Baremetal --name EnableRotterdamSdnApplianceForOracle --query properties.state
az feature show --namespace Microsoft.Network --name EnableRotterdamSdnApplianceForOracle --query properties.state
az provider register --namespace Microsoft.Baremetal
az provider register --namespace Microsoft.Network
```

For bulk registration across many subscriptions use `scripts/register-oracle-sdn.ps1` after updating its subscription list.

### Configure terraform.tfvars

Populate `terraform.tfvars` with the values for your event:

* `microhack_event_name` - Event identifier for tagging (e.g., "mhtest1")
* `user_count` - Number of participants (each gets an isolated AKS environment)

### Configure users.json

This project comes with a `users.json` file template. The `users.json` is located in the terraform root directory (`resources\infra\terraform`) and contain participant information. This is a simple array of user profiles indexed by position (0, 1, 2, etc.):

```json
[
  {
    "given_name": "Peter",
    "surname": "Parker",
    "hero_name": "Spider-Man"
  },
  {
    "given_name": "Bruce",
    "surname": "Wayne",
    "hero_name": "Batman"
  }
]
```

**Required fields per user:**

* `given_name` - User's first name
* `surname` - User's last name
* `hero_name` - Optional friendly identifier for documentation

> IMPORTANT: Ensure the file user.json contains at least as many entries as your configured `user_count` inside `terraform.tfvars`. The deployment will fail if there are insufficient user profiles.

### Deploy the Infrastructure

Run all Terraform commands from `resources\infra\terraform`:

```powershell
# Initialize Terraform (download providers)
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan -out tfplan

# Apply the plan
terraform apply tfplan
```

**Important:** The `user_credentials.json` file contains sensitive initial passwords. Secure this file and distribute credentials through a secure channel (e.g., password manager, encrypted email).

## Post-Deployment Checks

After `terraform apply` completes successfully, verify your deployment using the following methods.

### Review Terraform Outputs

The most efficient verification method is using Terraform's output command:

```powershell
terraform output
```

**Key outputs to review:**

* **`deployment_summary`**: Confirms the total number of AKS deployments and subscription distribution
* **`aks_clusters`**: Lists cluster names, IDs, resource groups, and DNS zone information
* **`vnet_peering_connections`**: Confirms VNet peering between AKS and ODAA networks
* **`entra_id_deployment_group`**: Shows the shared security group details

**Security reminder:** The `user_credentials.json` file contains initial passwords. Distribute securely and instruct users to change passwords on first login.

### Verify AKS Cluster Access (Per-User)

Test connectivity to a specific user's AKS cluster:

```powershell
# Example for user 'mh00'
$rgName = "aks-user00"
$aksName = "aks-user00"

# Get cluster credentials
az aks get-credentials --resource-group $rgName --name $aksName --overwrite-existing

# Verify node status
kubectl get nodes

# Expected output: 2-3 nodes in Ready state
```

### Verify Ingress Controller

Check the NGINX Ingress Controller deployment and external IP assignment:

```powershell
kubectl get services --namespace ingress-nginx
```

**Expected output:**

```text
NAME                                 TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)
ingress-nginx-controller             LoadBalancer   10.0.123.456   20.123.45.67   80:31234/TCP,443:32101/TCP
ingress-nginx-controller-admission   ClusterIP      10.0.78.9      <none>         443/TCP
```

The `EXTERNAL-IP` should be assigned (not `<pending>`). This may take 1-2 minutes after deployment.

### Verify Oracle Database Connectivity (If Enabled)

> NOTE: This verification applies only if you created Oracle Autonomous Databases and also already installed the onprem simulation on AKS.

```powershell
# List Oracle Autonomous Databases in the shared resource group
az oracle autonomous-database list \
  --resource-group odaa-user00 \
  --query "[].{Name:name, State:state, ComputeCount:computeCount}" \
  --output table
```

All databases should show `State: AVAILABLE`.

### Verify VNet Peering

Check that VNet peering is established and active:

```powershell
# Example for user 'mh00'
az network vnet peering list \
  --resource-group aks-mh00 \
  --vnet-name aks-mh00 \
  --query "[].{Name:name, PeeringState:peeringState, RemoteVNet:remoteVirtualNetwork.id}" \
  --output table
```

Expected `PeeringState`: **Connected**

## Destroying the Environment

### Pre-Destroy Checklist

Before destroying the infrastructure, ensure to remove Oracle databases before. this will otherwise cause issues during the terraform destroy.

```powershell
# 1. Verify current state matches Azure reality
terraform plan

# 2. Destroy all resources
terraform destroy

# You will be prompted to confirm. Type 'yes' to proceed.
```

### Post-Destroy Verification

After successful destruction, verify:

```powershell
# Check no resource groups remain
az group list --query "[?starts_with(name, 'aks-mh') || starts_with(name, 'odaa-')].name" --output table

# Verify no orphaned peerings
az network vnet peering list --resource-group <any-remaining-rg> --vnet-name <any-vnet>

# Check custom role definitions (if you want to remove them)
az role definition list --custom-role-only true --query "[?starts_with(roleName, 'Oracle')].roleName" --output table
```

## Additional Resources

* [Oracle Database@Azure Documentation](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/)
* [Oracle Database@Azure - Onboard and provision](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/onboard-oracle-database)
* [Oracle Database@Azure - Network Planning](https://learn.microsoft.com/en-us/azure/oracle/oracle-db/oracle-database-network-plan)
* [Azure Kubernetes Service Documentation](https://learn.microsoft.com/en-us/azure/aks/)
* [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
* [Oracle Database@Azure Service Limits](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/quotas-service-limits.htm)

## OCI SSO

For OCI-Azure SSO integration, refer to:
[Terraform OCI Multicloud Azure Landing Zones](https://github.com/oci-landing-zones/terraform-oci-multicloud-azure)

---

## Appendix: Entra ID Group

**IMPORTANT:** Before deploying, you must create an Entra ID security group for workshop participants. Terraform will add users to this existing group but will not create it.

**Create the group using Azure CLI:**

```powershell
# Set the group name (must match the value in terraform.tfvars)
$groupName = "mh-odaa-user-grp"

# Create the security group
az ad group create --display-name $groupName --mail-nickname $groupName --description "Security group for Oracle on Azure workshop participants"

# Verify the group was created
az ad group show --group $groupName --query "{Name:displayName, ObjectId:id}" --output table
```

> **Note:** The group name must match the `aks_deployment_group_name` value in your `terraform.tfvars` file (default: `mh-odaa-user-grp`).

## Appendix: Monitoring Oracle Autonomous Database Deployment

### Via Azure Portal

1. Navigate to the resource group
2. Select "Deployments" under Settings
3. View deployment status and operation details
4. Check "Activity Log" for detailed progress (refreshes every ~15 seconds)

### Via Azure CLI

```powershell
# Monitor deployment status
az oracle autonomous-database show \
  --resource-group <resource-group> \
  --name <database-name> \
  --query "{Name:name, State:state, Message:lifecycleDetails}" \
  --output table

# Watch for state changes
az oracle autonomous-database list \
  --resource-group <resource-group> \
  --query "[].{Name:name, State:state, Updated:timeUpdated}" \
  --output table
```

### Via OCI CLI

```powershell
# List resources created today in compartment
$TODAY = (Get-Date).ToString("yyyy-MM-dd")
$compartmentId = "<your-compartment-ocid>"

oci search resource structured-search \
  --query-text "query all resources where timeCreated >= '${TODAY}T00:00:00Z' && compartmentId = '$compartmentId'" \
  --query "data.items[*].{ResourceType:\`"resource-type\`",DisplayName:\`"display-name\`",State:\`"lifecycle-state\`"}" \
  --output table
```

#### Example: Real Deployment Log Query

```powershell
# Get detailed creation timeline for a specific compartment
$compartmentId = "ocid1.compartment.oc1..aaaaaaaayehuog6myqxudqejx3ddy6bzkr2f3dnjuuygs424taimn4av4wbq"
oci search resource structured-search \
  --query-text "query all resources where compartmentId = '$compartmentId' && timeCreated >= '2025-11-02T08:00:00Z'" \
  --query "data.items[*].{ResourceType:\`"resource-type\`",DisplayName:\`"display-name\`",TimeCreated:\`"time-created\`"}" \
  --output json | ConvertFrom-Json | Sort-Object TimeCreated
```

