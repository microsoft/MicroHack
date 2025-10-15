# Challenge 3 - Access Azure resources using Managed Identities from your on-premises servers

[Previous Challenge Solution](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-04.md)

### Goal

Managing secrets, credentials or certificates to secure communication between different services is a main challenge for developers and administrators. Managed Identities is Azure's answer to all these challenges and eliminates the need to manage and securely store secrets, credentials or certificates on the virtual machine. In challenge 3 you will leverage Managed Identities via Azure Arc to securely access an Azure Key Vault secret from your Azure Arc enabled servers without the need of managing any credential.

## Actions

- Create an Azure Key Vault in your Azure resource group
- Create a secret in the Azure Key Vault and assign permissions to your Linux virtual machine
- Access the secret via bash script

## Success Criteria

- You successfully output the secret in the terminal on your Linux server without providing any credentials (except for your SSH login 😊).

## Learning resources

- [Create a key vault using the Azure portal](https://docs.microsoft.com/azure/key-vault/general/quick-create-portal)
- [Set and retrieve a secret from Azure Key Vault using the Azure portal](https://docs.microsoft.com/azure/key-vault/secrets/quick-create-portal)
- [Use a Linux VM system-assigned managed identity to access Azure Key Vault](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/tutorial-linux-vm-access-nonaad)
- [Authenticate against Azure resources with Azure Arc-enabled servers](https://docs.microsoft.com/azure/azure-arc/servers/managed-identity-authentication)

