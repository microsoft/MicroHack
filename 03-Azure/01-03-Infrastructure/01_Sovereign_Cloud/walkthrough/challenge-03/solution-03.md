# Challenge 3 - Encryption in transit: enforcing TLS

[Previous Challenge Solution](../challenge-02/solution-02.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-04/solution-04.md)

**Estimated Duration:** 30 minutes

> 💡**Objective:**
- Understand encryption in transit considerations for sovereign scenarios
- Configure Azure Storage accounts to require secure transfer (HTTPS only) and enforce TLS 1.2 as the minimum protocol version.
- Apply Azure Policy to block weaker TLS versions and monitor client protocol usage through Log Analytics.

## Prerequisites

- Azure subscription with permissions to manage Storage accounts and assign Azure Policy (Contributor or higher).
- Existing StorageV2 account with Blob service enabled and access via the Azure Portal.
- Azure CLI 2.54 or later and Azure PowerShell Az module 10.0.0 or later installed locally.
- Log Analytics workspace (or rights to create one) for collecting Storage diagnostic logs.

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

### Prerequisites:
- StorageV2 account with Blob service enabled in the target subscription.
- Contributor permissions on the resource group hosting the account.

### Azure Portal steps
#### Require secure transfer for a new storage account
1. Open the **Create storage account** pane in the Azure portal.
2. In the **Advanced** page, select the **Enable secure transfer** checkbox.
3. Create storage account blade
<img width="900" height="573" alt="image" src="https://github.com/user-attachments/assets/fd48ddb5-1e49-4d4b-87a8-d773d0679abb" />



#### Require secure transfer for an existing storage account
1. Select an existing storage account in the Azure portal.
2. In the storage account menu pane, under **Settings**, select **Configuration**.
3. Under **Secure transfer required**, select **Enabled**.
<img width="1462" height="738" alt="8986c5e2-4783-4475-8fbf-97532b9ed2e9" src="https://github.com/user-attachments/assets/76813943-4533-43b0-a380-ec302bfae00d" />


### CLI alternative
```bash
az storage account update -g $RESOURCE_GROUP -n $STORAGEACCOUNT_NAME --https-only true
```
> **Warning:** Enabling secure transfer immediately rejects HTTP (non-TLS) requests to the Storage REST endpoints, including legacy tools or scripts. Update integrations that still rely on `http://` URIs to avoid connectivity failures ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer)).

> **Tip:** Combine secure transfer with private endpoints so client traffic stays on Microsoft's backbone while still enforcing TLS at the service boundary.

## Task 4: Hands-on: Enforce minimum TLS version with Azure Policy

Goal: ensure all storage accounts enforce **Minimum TLS Version = TLS 1.2**.

### Azure Portal steps

1. Open **Azure Policy** in the Portal.
2. Select **Definitions**, search for **"Storage accounts should have the specified minimum TLS version"** (Policy ID `fe83a0eb-a853-422d-aac2-1bffd182c5d0`).
3. Choose **Assign**.
4. Set **Scope** to the subscription or resource group.
5. Under **Parameters**, set **Minimum TLS version** to `TLS 1.2` and (optionally) effect to `Deny`.
6. Complete **Review + Create**, then select **Create**.
<img width="900" height="380" alt="image" src="https://github.com/user-attachments/assets/639f9f53-e9b5-40f6-9970-dc0de34e1109" />


### CLI alternative

```bash
az policy assignment create \
  --name enforce-storage-min-tls12 \
  --display-name "Enforce storage min TLS 1.2" \
  --policy fe83a0eb-a853-422d-aac2-1bffd182c5d0 \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
  --params '{ "effect": { "value": "Deny" }, "minimumTlsVersion": { "value": "TLS1_2" } }'
```

> **Note:** Use the policy's `effect = Audit` when you need discovery before enforcement. Switching to `Deny` blocks new or updated storage accounts that attempt to set weaker TLS versions ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version); [azadvertizer.net](https://www.azadvertizer.net/azpolicyadvertizer/fe83a0eb-a853-422d-aac2-1bffd182c5d0.html)).

## Task 5: Validation: detect TLS versions used by clients (Log Analytics/KQL)

> **Tip:** You can upload or download files from your storage account, to generate traffic for Task 5. For guidance on how to upload or download files: https://learn.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-portal

### Create Log Analytics workspace and Diagnostic settings to capture logs

```bash
# Create Log Analytics workspace
LOG_ANALYTICS_WORKSPACE=law-$RESOURCE_GROUP
az monitor log-analytics workspace create --resource-group $RESOURCE_GROUP \
       --workspace-name $LOG_ANALYTICS_WORKSPACE

# Get the storage account resource ID
STORAGE_ACCOUNT_ID=$(az storage account show \
  --name $STORAGEACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query id --output tsv)

# Get the Log Analytics workspace resource ID
LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --query id --output tsv)

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


1. Open the storage account and go to **Monitoring > Diagnostic settings**.
2. Select **+ Add diagnostic setting**.
3. Name the setting (e.g., `blob-tls-insights`).
4. Check **Blob** under **Logs**.
5. Choose **Send to Log Analytics workspace** and select an existing workspace (or create one beforehand).
6. Save the diagnostic setting.
<img width="1091" height="621" alt="image" src="https://github.com/user-attachments/assets/b70f33a2-2ca6-47a7-bf22-f43e03effe8d" />


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
```bash
# Create a blob storage container
# Create a container named "test-container"
az storage container create \
  --name test-container \
  --account-name $STORAGEACCOUNT_NAME \
  --auth-mode login
```

Run the following queries in **Log Analytics**:

```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d) and AccountName == "$STORAGEACCOUNT_NAME"
| summarize requests = count() by TlsVersion
```
<img width="900" height="424" alt="image" src="https://github.com/user-attachments/assets/06f1c3ce-17f1-408b-b345-7278329cb125" />

```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d) and AccountName == "$STORAGEACCOUNT_NAME"
| where TlsVersion !in ("TLS 1.2","TLS 1.3")
| project TimeGenerated, TlsVersion, CallerIpAddress, UserAgentHeader, OperationName
| sort by TimeGenerated desc
```

> **Tip:** If you observe TLS 1.0/1.1 usage, upgrade client frameworks (e.g., .NET, Java, Python SDKs), avoid hardcoded protocol versions, and rely on OS defaults that negotiate TLS 1.2+ ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version)).

## Results & acceptance criteria

- ✅ Storage accounts reject HTTP requests and enforce HTTPS (secure transfer required) ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer)).
- ✅ Policy compliance shows all storage accounts with **Minimum TLS Version = TLS 1.2** ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&tabs=portal#use-azure-policy-to-audit-for-compliance)).
- ✅ Log Analytics reports no requests using TLS 1.0/1.1 in the past 7 days (or policy denies/blocks them) ([learn.microsoft.com](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&tabs=portal#detect-the-tls-version-used-by-client-applications)).

## Cleanup

- Remove the policy assignment when enforcement is no longer required:
  ```bash
  az policy assignment delete --name enforce-storage-min-tls12 --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP
  ```
- Delete or disable diagnostic settings to stop streaming logs if the workspace costs are no longer justified.

## References

- [Azure encryption overview](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-overview)
- [Require secure transfer (HTTPS only) for Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer)
- [Enforce a minimum required TLS version for Storage](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version)
- [Azure Resource Manager TLS support](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tls-support)
- [Policy: Storage accounts should have the specified minimum TLS version](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&tabs=portal#detect-the-tls-version-used-by-client-applications)

---

You successsfully completed challenge 3! 🚀🚀🚀

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-04/solution-04.md)
