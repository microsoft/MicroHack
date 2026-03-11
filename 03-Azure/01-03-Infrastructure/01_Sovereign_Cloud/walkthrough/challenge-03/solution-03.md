# Walkthrough Challenge 3 - Encryption in transit: enforcing TLS

[Previous Challenge Solution](../challenge-02/solution-02.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-04/solution-04.md)

**Estimated Duration:** 30 minutes

> 💡 **Objective:** Understand encryption in transit considerations for sovereign scenarios. Configure Azure Storage accounts to require secure transfer (HTTPS only) and enforce TLS 1.2 as the minimum protocol version. Apply Azure Policy to block weaker TLS versions and monitor client protocol usage through Log Analytics.

## Prerequisites

Please ensure that you successfully verified the [General prerequisites](../../Readme.md#general-prerequisites) before continuing with this challenge.

- Azure subscription with Contributor permissions on your resource group
- Azure CLI >= 2.54 or access to Azure Portal
- Existing StorageV2 account with Blob service enabled (created in Challenge 2)
- Log Analytics workspace (or permissions to create one) for collecting Storage diagnostic logs

> [!IMPORTANT]
> The Azure CLI commands in this walkthrough use **bash** syntax and will not work directly in PowerShell. Use **Azure Cloud Shell (Bash)** for the best experience. If running locally on Windows, use **WSL2** (Windows Subsystem for Linux) to run a bash shell. You can install the Azure CLI inside WSL with:
>
> ```bash
> curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
> ```

Set up the common variables that will be used in the CLI alternatives throughout this challenge:

```bash
# Set common variables
# Customize RESOURCE_GROUP for each participant
RESOURCE_GROUP="labuser-xx"  # Change this for each participant (e.g., labuser-01, labuser-02, ...)
SUBSCRIPTION_ID="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx"  # Replace with your subscription ID
LOCATION="norwayeast"  # If attending a MicroHack event, change to the location provided by your local MicroHack organizers
STORAGEACCOUNT_NAME="yourStorageAccountName"  # Replace with the name of your storage account from Challenge 2
```

> [!WARNING]
> If your Azure Cloud Shell session times out (e.g. during a break), the variables defined above will be lost and must be re-defined before continuing. We recommend saving them in a local text file on your machine so you can quickly copy and paste them back into a new session.

## Task 1: Understand Encryption in transit

💡Encryption in transit protects data as it travels between clients and Azure services, ensuring confidentiality, integrity, and mutual authentication. Transport Layer Security (TLS) establishes a cryptographic handshake that negotiates protocol versions, cipher suites, and validates certificates before any payload flows. In Azure, enforcing TLS aligns with service-specific capabilities (e.g., Storage, Key Vault, App Service) and underpins sovereign cloud controls by preventing downgrade attacks and plaintext exposures. Azure's encryption guidance emphasizes pairing secure transport with encryption at rest to meet regulatory requirements and Zero Trust principles.

## Task 2: Understand TLS versions & recommendation

| TLS version | Azure Storage public HTTPS endpoint support | Recommendation |
|-------------|----------------------------------------------|----------------|
| TLS 1.0     | Supported for backward compatibility (legacy only) | Not recommended; scheduled for retirement across Azure services |
| TLS 1.1     | Supported for limited scenarios | Not recommended; migrate clients to TLS 1.2+ |
| TLS 1.2     | Fully supported | **Recommended minimum**; enforce for Storage accounts |
| TLS 1.3     | Supported on public endpoints but cannot be enforced as account minimum | Use when available; falls back to TLS 1.2 if client lacks support |

Azure Storage currently allows setting **Minimum TLS Version = TLS 1.0, 1.1, or 1.2**, with **TLS 1.2** as the recommended baseline; enforcing TLS 1.3 is not yet available at account-scope ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version)). Azure Resource Manager will drop support for protocols older than TLS 1.2 on **March 1, 2025**, so modernize SDKs, runtimes, and appliances ahead of that date ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tls-support)).

## Task 3: Hands-on: Azure Blob Storage - require secure transfer (HTTPS only) in Azure Portal

### Task prerequisites
- StorageV2 account with Blob service enabled in the target subscription (created in Challenge 2).
- Contributor permissions on the resource group hosting the account.

### Azure Portal steps
#### Require secure transfer for a new storage account
1. In the top center search bar in the Azure portal, search for **Storage accounts**
1. Click on **Create**
1. Select your own resource group, provide a unique name for the **Storage account name** and select "**Azure Blob Storage or Azure Data Lake Storage Gen2** for the **Preferred storage type** parameter
1. Click next and in the **Advanced** page, select the **Require secure transfer for REST API operations** checkbox if not already enabled.
1. Leave the rest of the parameters as-is and click **Review + create**

![desc](./images/storage_01.png)

#### Require secure transfer for an existing storage account
1. Select an existing storage account in the Azure portal.
2. In the storage account menu pane, under **Settings**, select **Configuration**.
3. Under **Secure transfer required**, select **Enabled**.

![desc](./images/storage_02.png)

### CLI alternative
```bash
az storage account update -g $RESOURCE_GROUP -n $STORAGEACCOUNT_NAME --https-only true
```
> **Warning:** Enabling secure transfer immediately rejects HTTP (non-TLS) requests to the Storage REST endpoints, including legacy tools or scripts. Update integrations that still rely on `http://` URIs to avoid connectivity failures ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer)).

> **Tip:** Combine secure transfer with private endpoints so client traffic stays on Microsoft's backbone while still enforcing TLS at the service boundary.

## Task 4: Hands-on: Enforce minimum TLS version with Azure Policy

Goal: ensure all storage accounts enforce **Minimum TLS Version = TLS 1.2**.

### Azure Portal steps

1. In the Azure Portal, navigate to **Policy**
2. Select **Definitions**, search for **"Storage accounts should have the specified minimum TLS version"** (Policy ID `fe83a0eb-a853-422d-aac2-1bffd182c5d0`).
3. Choose **Assign**.
4. Set **Scope** to your **Labuser-xxx** resource group. **Do NOT select the subscription** — assigning at subscription scope will affect all other participants.
5. Uncheck the box: **Only show parameters that need input or review**
6. Under **Parameters**, set **Minimum TLS version** to `TLS 1.2` and (optionally) effect to `Deny`.
7. Complete **Review + Create**, then select **Create**.

![Azure Policy](./images/policy_01.png)

### CLI alternative

```bash
az policy assignment create \
  --name $RESOURCE_GROUP-enforce-storage-min-tls12 \
  --display-name "${RESOURCE_GROUP} - Enforce storage min TLS 1.2" \
  --policy fe83a0eb-a853-422d-aac2-1bffd182c5d0 \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
  --params '{ "effect": { "value": "Deny" }, "minimumTlsVersion": { "value": "TLS1_2" } }'
```

> **Note:** Use the policy's `effect = Audit` when you need discovery before enforcement. Switching to `Deny` blocks new or updated storage accounts that attempt to set weaker TLS versions ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version); [azadvertizer.net](https://www.azadvertizer.net/azpolicyadvertizer/fe83a0eb-a853-422d-aac2-1bffd182c5d0.html)).

## Task 5: Validation: detect TLS versions used by clients (Log Analytics/KQL)

> **Tip:** You can upload or download files from your storage account, to generate traffic for Task 5. For guidance on how to upload or download files: https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal

### Create Log Analytics workspace and Diagnostic settings to capture logs

### CLI

```bash
# Create Log Analytics workspace
LOG_ANALYTICS_WORKSPACE=law-$RESOURCE_GROUP
az monitor log-analytics workspace create --resource-group $RESOURCE_GROUP \
       --workspace-name $LOG_ANALYTICS_WORKSPACE
```

```bash
# Get the storage account resource ID
STORAGE_ACCOUNT_ID=$(az storage account show \
  --name $STORAGEACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query id --output tsv)
```

```bash
# Get the Log Analytics workspace resource ID
LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --query id --output tsv)
```

```bash
# Create diagnostic setting for blob service with StorageRead and StorageWrite categories
az monitor diagnostic-settings create \
  --name blob-tls-insights \
  --resource ${STORAGE_ACCOUNT_ID}/blobServices/default \
  --workspace $LOG_ANALYTICS_WORKSPACE_ID \
  --logs '[
    {
      "category": "StorageRead",
      "enabled": true
    },
    {
      "category": "StorageWrite",
      "enabled": true
    }
  ]'
```

### Azure Portal steps

1. Open the storage account and go to **Monitoring > Diagnostic settings**.
2. Select **+ Add diagnostic setting**.
3. Name the setting (e.g., `blob-tls-insights`).
4. Check **Blob** under **Logs**.
5. Choose **Send to Log Analytics workspace** and select an existing workspace (or create one beforehand).
6. Save the diagnostic setting.

![Diagnostic settings](./images/storage_03.png)

### Create a Container and perform a blob upload and download

#### Grant access to the current user id to the Blob storage service

```bash
# Get your current user's object ID
CURRENT_USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Assign the "Storage Blob Data Contributor" role to your user
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee $CURRENT_USER_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGEACCOUNT_NAME

```

#### Create a Container

Use the Azure Portal to create a new container or use CLI below

```bash
# Create a blob storage container
# Create a container named "test-container"
az storage container create \
  --name test-container \
  --account-name $STORAGEACCOUNT_NAME \
  --auth-mode login
```

- In the Azure portal, search for **Storage accounts** in the top center search bar and navigate to the storage account which resides in your resource group.
- Click on the menu blade **Storage browser**, navigate to **Blob containers** -> **test-container** and click the **Upload**-button to upload a sample file (e.g. an image or text-file) from your local computer to generate some traffic/logs

![Storage account](./images/storage_04.png)

- In the Azure portal, search for **Log Analytics workspaces** in the top center search bar and navigate to the workspace which resides in your resource group.
- Click on **Logs**, close any welcome/introduction-notifications, select **KQL mode** and run the following queries:

```kusto
StorageBlobLogs
| where TimeGenerated > ago(1d)
| summarize requests = count() by TlsVersion
```

![Log Analytics](./images/log_analytics_01.png)

```kusto
StorageBlobLogs
| where TimeGenerated > ago(1d)
| where TlsVersion !in ("TLS 1.2","TLS 1.3")
| project TimeGenerated, TlsVersion, CallerIpAddress, UserAgentHeader, OperationName
| sort by TimeGenerated desc
```

![Log Analytics](./images/log_analytics_02.png)

Look for TLS 1.0/1.1 usage.

> **Tip:** If you observe TLS 1.0/1.1 usage, upgrade client frameworks (e.g., .NET, Java, Python SDKs), avoid hardcoded protocol versions, and rely on OS defaults that negotiate TLS 1.2+ ([learn.microsoft.com](https://learn.microsoft.com/azure/storage/common/transport-layer-security-configure-minimum-version)).

## Results & acceptance criteria

- ✅ Storage accounts reject HTTP requests and enforce HTTPS (secure transfer required) ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer)).
- ✅ Policy compliance shows all storage accounts with **Minimum TLS Version = TLS 1.2** ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&tabs=portal#use-azure-policy-to-audit-for-compliance)).
- ✅ Log Analytics reports no requests using TLS 1.0/1.1 in the past 7 days (or policy denies/blocks them) ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&tabs=portal#detect-the-tls-version-used-by-client-applications)).

## References

- [Azure encryption overview](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-overview)
- [Require secure transfer (HTTPS only) for Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer)
- [Enforce a minimum required TLS version for Storage](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version)
- [Azure Resource Manager TLS support](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tls-support)
- [Policy: Storage accounts should have the specified minimum TLS version](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&tabs=portal#detect-the-tls-version-used-by-client-applications)

---

You successfully completed challenge 3! 🚀🚀🚀

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-04/solution-04.md)
