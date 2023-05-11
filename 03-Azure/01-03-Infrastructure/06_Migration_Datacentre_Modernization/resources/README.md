# Deploy the Landing Zone for the Micro Hack

The Azure CLI is required to deploy the Bicep configuration of the Micro Hack.

- Install the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) on your local PC
- Open a PowerShell (Windows) or Bash (Linux and macOS) terminal window
- Execute `az login` and sign in with your Azure AD account
- Execute `az ad signed-in-user show`
- Copy the property *id* to the clipboard (e.g., b0b34544-d61f-46f3-92c8-0da38137f623)
- Execute `az deployment sub create --location westeurope --template-file .\main.bicep`
- Paste the previously copied *id* as *currentUserObjectId*
- Wait for the deployment to finish
