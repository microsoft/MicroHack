# Deploy the Resources for the MicroHack

Either using [ARM](./ARM) or [Terraform](./terraform) you can deploy the resources for the MicroHack.

## Quota Information if multiple Users Deploy to the same subscription

If you have multiple users deploying to the same subscription you need to make sure you have enough quota for the deployments.
For 1 User deployment you should make sure to have the following quotas requested upfront:

| Quota name  | needed Quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | tbd  |
| Standard BS Family vCPUs  | tbd  |
| Public IP Addresses | tbd |

That means for 5 Users that need to deploy individually to a Region you need to make sure you have the following quotas in place:

| Quota name  | needed Quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | tbd  |
| Standard BS Family vCPUs  | tbd  |
| Public IP Addresses | tbd |

To request the quota please follow: https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal

## Use KeyVault for VM access for multiple Users to the same subscrption

- Create a `KeyVault` and `resource group` for sharing access credentials for the VMs
  - username and password for Windows VMs
  - username and ssh key for Linux VMs

- Adding ssh key via Azure CLI
  - `az keyvault secret set --vault-name <your-unique-vault-name> --name <your-unique-ssh-key-name> --file ~/.ssh/id_rsa.pub`

## Register Resource Providers for new Subscriptions

- Microsoft.OperationalInsights
- Microsoft.Insights
- Microsoft.Network
- Microsoft.Compute
- Microsoft.OperationsManagement
