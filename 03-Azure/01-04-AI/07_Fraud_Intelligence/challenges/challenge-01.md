# Challenge 1 - Prepare the Environment

**[Home](../README.md)** | [Next challenge](challenge-02.md)

## 🎯 Objective

Sign in with your assigned lab credentials, verify the pre-provisioned Azure resources, and start the GitHub Codespaces development environment used throughout the Fraud Intelligence MicroHack.

## 🧭 Context and Background

The remaining challenges use a pre-provisioned Azure environment and a repository hosted on GitHub. You will work from a GitHub Codespace configured with the tools and dependencies required to build the fraud intelligence solution.

Complete this setup with the credentials provided in your Hackbox. Use the assigned lab account rather than a personal or work account so that you have access to the correct Azure subscription, resource group, GitHub organization, and repository.

## ✅ Tasks

### 1. Sign in to Azure

Open the [Azure portal](https://portal.azure.com) and sign in with the credentials provided in your Hackbox.

When prompted to choose an account, select **Use another account** and enter the credentials provided. Do not use your personal or work account.

![Sign in to the Azure portal with another account](/challenges/images/azureportal.png)

In the Azure portal, select **Resource groups** from the navigation menu.

![Resource groups in the Azure portal navigation menu](/challenges/images/resource-groups.png)

Open the resource group assigned to you and confirm that its resources have been deployed successfully.

![Resources deployed in the assigned resource group](/challenges/images/resource-group-resources.png)

Verify that you can access the resources used in the later challenges, including the Microsoft Foundry project, model deployments, Azure Cosmos DB account, and Application Insights resource.

### 2. Sign in to GitHub

Open [GitHub](https://github.com) and sign in with the credentials provided in your Hackbox.

When prompted to choose an account, select **Use another account**. Do not use your personal or work account.

![Sign in to GitHub with another account](/challenges/images/github-login.png)

Select **Sign in with your identity provider**, then use the assigned lab account to authenticate.

Open the GitHub organization assigned to your lab account.

![GitHub organization selector](/challenges/images/github-organization.png)

Select the assigned organization, then open the `microhack` repository. Confirm that you can see the repository files and folders.

![Files and folders in the GitHub repository](/challenges/images/github-repository.png)

### 3. Create the development environment

From the repository page, select **Code**, then open the **Codespaces** tab. Select the `...` menu and choose **New with options**.

![Create a GitHub Codespace with options](/challenges/images/github-codespaces.png)

For **Dev container configuration**, select **Azure / AI / Fraud Intelligence**, then select **Create codespace**.

GitHub opens the Codespace in a new browser tab. Wait for the container setup to finish, then confirm that the repository files are visible in the Explorer and that the integrated terminal opens without errors.

Open a terminal in the Codespace (Terminal > New Terminal) and run the following command to verify that Azure CLI is installed:

```bash
az --version
```

Then sign in to Azure from the Codespace terminal:

```bash
az login
```

Next, initialize a local environment file with the following commands:

```bash
# init RG with your Resource Group name provided in Hackbox
rg=<your-resource-group-name>
DEPLOYMENT=$(az deployment group list -g "$rg" \
  --query "sort_by([?starts_with(name, 'mhh')], &properties.timestamp)[-1].name" \
  -o tsv)

az deployment group show -g "$rg" -n "$DEPLOYMENT" \
  --query properties.outputs -o json |
jq -r 'to_entries[] |
  "\(.key)=\(.value.value |
  (if type == "string" then . else tojson end) | @sh)"' \
  > hackenv
az deployment group show -g "$rg" -n "$DEPLOYMENT" \
  --query properties.parameters -o json |
jq -r 'to_entries[]
  | select(.value.value != null)
  | "\(.key)=\(.value.value |
      (if type == "string" then . else tojson end) | @sh)"' \
>> hackenv

chmod 600 hackenv
echo "rg=$rg" >> hackenv
cat hackenv
source hackenv
source baseenv
``` 

## 🚀 Go Further

Review the [solution architecture](../README.md#architecture) and identify where each deployed Azure resource is used in the five build challenges.

## 🛠️ Troubleshooting

- **The Azure resource group is missing:** Confirm that you signed in with the assigned lab account and selected the assigned subscription in the Azure portal.
- **The GitHub organization or repository is missing:** Sign out of GitHub, then sign in again through **Sign in with your identity provider** using the Hackbox credentials.
- **The dev container configuration is unavailable:** Confirm that you opened the assigned `microhack` repository before creating the Codespace.
- **The Codespace does not finish starting:** Review the creation log for the failing step, then rebuild the container or recreate the Codespace.

## 🧠 Conclusion

You have verified the Azure resources and opened the configured development environment. Continue to [Challenge 2](challenge-02.md) to build the Evidence Enrichment Agent.