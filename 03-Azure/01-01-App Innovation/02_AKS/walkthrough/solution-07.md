# Exercise 7: Backup and Restore with Azure Backup for AKS

## Objective
In this exercise, you will learn how to protect your AKS workloads using Azure Backup extension. You'll configure backup for your cluster, perform a backup of your application, and restore it to demonstrate disaster recovery capabilities.

## What is Azure Backup for AKS?

Azure Backup for AKS provides a cloud-native, enterprise-ready backup solution that allows you to:
- Back up and restore containerized applications and data
- Protect against accidental deletion or data corruption
- Meet compliance and governance requirements
- Perform disaster recovery scenarios

**Key Features**:
- Application-consistent backups
- Namespace-level or cluster-wide backups
- Scheduled or on-demand backups
- Point-in-time restore capabilities
- Integration with Azure Policy

## Prerequisites
- Completed Exercise 6 (Persistent Storage configured)
- Running AKS cluster with deployed applications
- Access to Azure Portal
- Owner or Contributor role on the subscription

## Tasks

### Task 0: Create Storage Account and Backup Vault

Azure Backup for AKS requires a storage account with a blob container and a backup vault to store backup data.

1. **Create a Storage Account using Azure CLI**

   Open your terminal and run the following commands:

   ```bash
   # Create a storage account for backup
   az storage account create \
     --name stbackupaks<yourinitials> \
     --resource-group $RESOURCE_GROUP \
     --location $LOCATION \
     --sku Standard_LRS \
     --kind StorageV2 \
     --enable-hierarchical-namespace false
   
   # Verify storage account creation
   az storage account show \
     --name stbackupaks<yourinitials> \
     --resource-group $RESOURCE_GROUP \
     --output table
   ```

   > **Note**: Replace `<yourinitials>` with your actual initials (e.g., `stbackupaksjd` for John Doe). Storage account names must be globally unique and lowercase.

2. **Create Blob Container via Azure Portal**

   Due to organizational policies that may restrict SAS token usage, we'll create the container through the Portal:

   - Navigate to **Storage accounts** in Azure Portal
   - Find and click on your storage account: `stbackupaks<yourinitials>`
   - In the left menu, click **Containers** (under Data storage)
   - Click **+ Container** at the top
   - **Name**: `aks-backups`
   - **Public access level**: Private (no anonymous access)
   - Click **Create**

3. **Verify Container Creation**
   - You should now see the `aks-backups` container in the list
   - Click on it to verify it's empty and ready for backup data

4. **Create Backup Vault using Azure CLI**

   ```bash
   # Create a backup vault for AKS
   az dataprotection backup-vault create \
     --resource-group $RESOURCE_GROUP \
     --vault-name backup-vault-aks-<yourinitials> \
     --location $LOCATION \
     --type SystemAssigned \
     --storage-settings datastore-type="VaultStore" type="LocallyRedundant"
   
   # Verify backup vault creation
   az dataprotection backup-vault show \
     --resource-group $RESOURCE_GROUP \
     --vault-name backup-vault-aks-<yourinitials> \
     --output table
   ```

### Task 1: Enable Azure Backup Extension for AKS

In this task, we'll enable the backup extension from the Azure Portal.

1. **Navigate to your AKS cluster in Azure Portal**
   - Sign in to [Azure Portal](https://portal.azure.com)
   - Go to **All resources** or **Kubernetes services**
   - Select your AKS cluster: `aks-lab-<yourinitials>`

2. **Access Backup Settings**
   - In the left navigation menu, scroll down to **Settings**
   - Click on **Backup**
   - You'll see a prompt to install the backup extension

3. **Install Backup Extension**
   - Click **Install Extension**
   - Select the storage account: `stbackupaks<yourinitials>`
   - Select the blob container: `aks-backups`
   - Click **Install**
   - Wait for the extension to be installed (this typically takes around 6 minutes)

4. **Verify Extension Installation**
   - Once installation completes, go to your AKS cluster
   - Navigate to **Settings** > **Extensions + applications**
   - You should see `azure-aks-backup` extension with status "Succeeded"

   Alternatively, verify using Azure CLI:
   ```bash
   az k8s-extension list \
     --cluster-name $AKS_CLUSTER_NAME \
     --resource-group $RESOURCE_GROUP \
     --cluster-type managedClusters
   ```

### Task 2: Configure Backup from AKS Backup Settings

Now that the backup extension is installed, we'll configure the backup policy and instance directly from the AKS cluster.

1. **Navigate to AKS Backup Settings**
   - Go back to your AKS cluster in Azure Portal
   - In the left navigation menu, scroll down to **Settings**
   - Click on **Backup**
   - You should see that the extension is installed successfully

2. **Start Backup Configuration**
   - Click **Configure Backup** button
   - This will open the backup configuration wizard

3. **Select Backup Vault**
   - **Backup vault**: Select your backup vault `backup-vault-aks-<yourinitials>`
   - The vault should be in the same region as your AKS cluster
   - Click **Next**

4. **Grant Permissions to Backup Vault**
   
   The backup vault needs permissions to access your AKS cluster and storage account.
   
   - In the wizard, you'll see a section for **Permissions**
   - Click **Grant Permission** next to:
     - **AKS cluster**: Grants the vault's managed identity access to backup your cluster
     - **Storage Account**: Grants the vault access to store backup data
   - Wait for permissions to be granted (this takes 1-2 minutes)
   - You should see "Permission granted" status with green checkmarks
   - The system will automatically validate the permissions
   - Click **Next** once permissions are granted and validated

5. **Configure or Select Backup Policy**
   
   Now you'll define when and how backups are taken.
   
   **Option A: Create New Policy**
   - Click **Create a new policy**
   - **Policy name**: `aks-daily-backup-policy`
   - **Schedule**:
     - **Backup frequency**: Select "Hourly" or "Daily"
     - If Daily: Choose time (e.g., 2:00 AM UTC)
     - If Hourly: Choose frequency (every 4, 6, 8, 12 hours)
   - **Retention**:
     - **Default**: 3-5 days (for this exercise)
     - Avoid longer retention periods to minimize storage costs
     - > **Important**: Since this is a lab exercise, use minimal retention (3-5 days) to avoid unnecessary storage consumption and costs
   - Click **Create**
   
   **Option B: Use Existing Policy**
   - Select an existing backup policy from the dropdown
   - Review the policy settings
   - Click **Next**

6. **Select Datasources to Backup**
   
   Define what should be included in backups.
   
   - **Add a Datasource to backup**: Choose one of:
     - **All namespaces**: Backup everything in the cluster
     - **Include specific namespaces**: Select specific namespaces (Recommended)
   
   - For this lab, select **Include specific namespaces**:
     - Check the box for **default** (where your application is deployed)
     - You can select multiple namespaces if needed
   
   - **Include cluster-scoped resources**: 
     - Under the other options you could select:
       - Cluster scope
       - Persistent Volumes
       - Secrets
   
   - **Backup hooks** (Optional - Advanced):
     - Leave empty for now
     - These allow running custom commands before/after backup
   
   - **Label selectors** (Optional):
     - Leave empty to backup all resources in selected namespaces
     - Or add labels to backup only specific resources (e.g., `app=backend`)
   
   - Click **Next**

7. **Vallidate the permissions:**
   - Click on **Validate**
   - If you see an error :
     - Click **Assign Missing Roles** button
     - Wait for the role assignment to complete
     - Click **Validate** again
     - All checks should now pass with green checkmarks

8. **Review and Create Backup Configuration**
   
   - Review the configuration summary:
     - Vault name and location
     - Selected AKS cluster
     - Backup policy (schedule and retention)
     - Resources to backup (namespaces)
     - Permissions status
   
   - Click **Configure backup**
   - Wait for the configuration to complete (2-3 minutes)
   - You should see "Backup configuration successful" message

9. **Verify Backup Configuration**
    
    - Stay in your AKS cluster **Backup** section
    - After a couple of minutes, you should see the backup instance move to a proction status **Protection configured**

### Task 3: Perform an On-Demand Backup

Before testing restore, let's ensure we have a recent backup of our application.

1. **Access Backup Section**
   - Stay in your AKS cluster **Settings** > **Backup** section
   - You should see the backup is configured with your vault

2. **Trigger On-Demand Backup**
   - Select the backup job ellipsis, Backup Now
   - Click **Backup now** button at the top
   - A side panel will open
   - **Retention**: 
     - Select the **Retention rule**
     - Click **Backup** to start the backup

3. **Monitor Backup Progress**
   - Click on **Triggering backup ... ** tab in the notification on the top.
   - You'll see your backup job with status "In progress"
   - Refresh the page periodically
   - Wait for the backup to complete (5-10 minutes depending on cluster size)
   - Status should change to "Completed"
   
   **What's happening during backup:**
   - The backup extension creates snapshots of your resources
   - Kubernetes manifests are captured (Deployments, Services, ConfigMaps, etc.)
   - Persistent Volume data is backed up
   - All data is stored in your backup vault and blob container

4. **Verify Backup using Azure CLI**
   ```bash
   # List backup instances
   az dataprotection backup-instance list \
     --resource-group $RESOURCE_GROUP \
     --vault-name backup-vault-aks-<yourinitials> \
     --output table
   ```

5. **View Backup Details and Recovery Points**
   - In your AKS **Backup** section, click on the **Restore** option on the top
   - Select the backup instance
   - Click **Continue**
   - Note the **Recovery point** (timestamp)
   - Check the restore parameters
   - Click: **Next: Review + restore**

### Task 4: Restore from Backup

Now let's restore our application from the backup we created.
1. **View Backup Details and Recovery Points**
   - In your AKS **Backup** section, click on the **Restore** option on the top
   - Select the backup instance
   - Click **Continue**
   - Note the **Recovery point** (timestamp)
   - Check the restore parameters
   - Click: **Next: Review + restore**


## Verification Checklist

Ensure you have successfully:
- [ ] Enabled Azure Backup extension on your AKS cluster
- [ ] Created a Backup vault
- [ ] Configured a backup policy
- [ ] Performed an on-demand backup
- [ ] Simulated a disaster by deleting resources
- [ ] Successfully restored your application from backup
- [ ] Verified that all resources and data were restored
- [ ] Explored backup reports and monitoring

## Key Concepts

### Backup Scope
- **Namespace-level**: Backup specific namespaces
- **Cluster-wide**: Backup entire cluster including cluster-scoped resources
- **Label selectors**: Backup resources matching specific labels

### Recovery Point Objective (RPO)
- How much data you can afford to lose
- Daily backups = 24-hour RPO
- Hourly backups = 1-hour RPO

### Recovery Time Objective (RTO)
- How quickly you need to restore
- Depends on cluster size and data volume
- Typically 5-15 minutes for small clusters

### Backup Types
- **Scheduled backups**: Automatic, policy-driven
- **On-demand backups**: Manual, immediate
- **Application-consistent**: Ensures data integrity

## Troubleshooting

### Backup Extension Installation Failed
- Check if you have sufficient permissions (Owner/Contributor)
- Verify AKS cluster is in a supported region
- Check Azure service health status

### Backup Job Failed
```bash
# Check extension logs
kubectl logs -n azure-aks-backup -l app=azure-aks-backup

# Check backup instance status
az dataprotection backup-instance list \
  --resource-group $RESOURCE_GROUP \
  --vault-name backup-vault-aks-<yourinitials>
```

### Restore Failed
- Verify target cluster has sufficient resources
- Check for resource conflicts (existing resources with same names)
- Review restore job logs in Azure Portal

### PVC Not Restored
- Ensure storage class exists in target cluster
- Check if PVC was included in backup scope
- Verify sufficient storage quota

## Best Practices

### Backup Strategy
- Define clear RPO/RTO requirements
- Test restore procedures regularly
- Backup production namespaces separately
- Include cluster-scoped resources (RBAC, ConfigMaps)
- Use label selectors for granular control

### Retention Policy
- Keep daily backups for 7-30 days
- Keep weekly backups for 3-6 months
- Keep monthly backups for 1 year
- Comply with regulatory requirements

### Security
- Use Azure RBAC to control backup access
- Encrypt backups at rest
- Enable soft delete protection
- Audit backup and restore operations

### Cost Optimization
- Choose appropriate retention periods
- Clean up old recovery points
- Use lifecycle management policies
- Monitor storage consumption

## Additional Resources

- [Azure Backup for AKS Documentation](https://docs.microsoft.com/azure/backup/azure-kubernetes-service-backup-overview)
- [Backup Extension for AKS](https://docs.microsoft.com/azure/backup/azure-kubernetes-service-cluster-backup)
- [Best Practices for AKS Backup](https://docs.microsoft.com/azure/backup/azure-kubernetes-service-backup-best-practices)
- [Azure Backup Pricing](https://azure.microsoft.com/pricing/details/backup/)

## Cost Considerations

Azure Backup for AKS charges are based on:
- **Protected instances**: Number of namespaces backed up
- **Storage**: Volume of backup data stored
- **Operations**: Backup and restore operations

Estimated monthly cost for this lab (1 namespace, 7-day retention): ~$5-10 USD

## Next Steps

Continue to [Exercise 8: Monitoring with Azure Managed Grafana](08-monitoring-grafana.md) to learn about observability and monitoring!

