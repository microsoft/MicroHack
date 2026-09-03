# Challenge 1 - Prepare the Environment

**[Home](../README.md)** | [Next challenge](challenge-02.md)

## 🎯 Objective

Sign in with your assigned lab credentials, verify the pre-provisioned Azure resources, and start the GitHub Codespaces development environment used throughout the Claims Intelligence MicroHack.

## 🧭 Context and Background

The remaining challenges use a pre-provisioned Azure environment and a repository hosted on GitHub. You will work from a GitHub Codespace configured with the tools and dependencies required to build the claims intelligence solution.

Complete this setup with the credentials provided in your Hackbox. Use the assigned lab account rather than a personal or work account so that you have access to the correct Azure subscription, resource group, GitHub organization, and repository.

## ✅ Tasks

### 1. Sign in to Azure

Open the [Azure portal](https://portal.azure.com) and sign in with the credentials provided in your Hackbox.

When prompted to choose an account, select **Use another account** and input the credentials provided. Do not use your personal or work account.

![Sign in to the Azure portal with another account](/challenges/images/azureportal.png)

In the Azure portal, select **Resource groups** from the navigation menu.

![Resource groups in the Azure portal navigation menu](/challenges/images/resource-groups.png)

Open the resource group assigned to you and confirm that its resources have been deployed successfully.

![Resources deployed in the assigned resource group](/challenges/images/resource-group-resources.png)

Verify that you can access the resources used in the later challenges, including the Microsoft Foundry project, the `gpt-5.4` and `mistral-document-ai-2512` model deployments, the Azure AI Search service, and the Storage account.

### 2. Sign in to GitHub

Open [GitHub](https://github.com) and sign in with the credentials provided in your Hackbox.

When prompted to choose an account, select **Use another account**. Do not use your personal or work account.

![Sign in to GitHub with another account](/challenges/images/github-login.png)

Select **Sign in with your identity provider**, then use the assigned lab account to authenticate.

Open the organization associated with your lab account.

![GitHub organization selector](/challenges/images/github-organization.png)

Select the organization available to you, then open the `microhack` repository. Confirm that you can see the repository files and folders.

![Files and folders in the GitHub repository](/challenges/images/github-repository.png)

### 3. Create the development environment

From the repository page, select **Code**, then open the **Codespaces** tab. Select the `...` menu and choose **New with options**.

![Create a GitHub Codespace with options](/challenges/images/github-codespaces.png)

For **Dev container configuration**, select **Claims Hack**, then select **Create codespace**.

GitHub opens the Codespace in a new browser tab. Wait for the container setup to finish, then confirm that the repository files are visible in the Explorer and that the integrated terminal opens without errors.

Open a terminal in the Codespace (Terminal > New Terminal) and run the following command to verify that the required tools are installed:

```bash
az --version
```

Install the pinned project dependencies and activate the Python environment:

```bash
uv sync --frozen
source .venv/bin/activate
```

Sign in to Azure from the Codespace terminal with the assigned lab account:

```bash
az login --use-device-code
```

From the repository root, run the setup script with the resource group name provided
in your Hackbox:

```bash
bash labautomation/get-keys.sh --resource-group "<your-resource-group-name>"
```

The script locates the latest successful Claims MicroHack deployment and creates a
local `.env` file at the repository root. It retrieves the Foundry project endpoint,
Mistral Document AI key and endpoint, Azure AI Search key and endpoint, and Storage
connection string required by Challenges 2 through 6. The file is excluded from Git,
written with permissions `600`, and its secret values are not displayed.

### 4. Verify the Blob Storage assets

Before continuing, confirm that the lab deployment uploaded the claim and policy files.
Find the Storage account name in the output from `get-keys.sh`, then run these commands
from the repository root:

```bash
STORAGE_ACCOUNT="<storage-account-name>"
STORAGE_CONNECTION_STRING="$(sed -n 's/^AZURE_STORAGE_CONNECTION_STRING=//p' .env)"

az storage blob list \
	--connection-string "$STORAGE_CONNECTION_STRING" \
	--container-name claims-data \
	--query "length(@)" \
	--output tsv

az storage blob list \
	--connection-string "$STORAGE_CONNECTION_STRING" \
	--container-name policies \
	--query "length(@)" \
	--output tsv
```

The expected results are `17` claim files and `5` policy documents. You can also open
the Storage account in the Azure portal, select **Data storage > Containers**, and
inspect the `claims-data` and `policies` containers directly.

If either count is lower than expected, upload and verify only the missing lab assets
without redeploying the infrastructure:

```bash
bash labautomation/upload-assets.sh \
	--subscription "<your-subscription-id>" \
	--resource-group "<your-resource-group-name>" \
	--storage-account "$STORAGE_ACCOUNT"
```

The command finishes with `Asset upload complete and verified: 17 claims, 5 policies.`
It does not deploy or modify the lab infrastructure.

Confirm that the participant CLI is available:

```bash
python docs/claims-intake-agent.py --help
```

> [!IMPORTANT]
> Do not run `labautomation/deploy-lab.ps1`. The MicroHack platform invokes that
> script before the lab begins. Participants run only `labautomation/get-keys.sh`
> after the platform deployment succeeds.

## 🚀 Go Further

Review the [solution architecture](../README.md#architecture) and identify where each deployed Azure resource is used in the five build challenges.

## 🛠️ Troubleshooting

- **The Azure resource group is missing:** Confirm that you signed in with the assigned lab account and selected the assigned subscription in the Azure portal.
- **The setup script reports an authorization error:** Confirm that the Codespace is signed in with the assigned lab account. That account must be able to read deployment outputs and list keys for the Foundry, Azure AI Search, and Storage resources.
- **The Blob Storage verification reports an authorization error:** Run `get-keys.sh` again and confirm that `.env` contains a non-empty `AZURE_STORAGE_CONNECTION_STRING` value. Do not print or share the value.
- **A Blob Storage container is empty or incomplete:** Run `labautomation/upload-assets.sh` with your subscription, resource group, and Storage account values, then repeat the verification commands.
- **The GitHub organization or repository is missing:** Sign out of GitHub, then sign in again through **Sign in with your identity provider** using the Hackbox credentials.
- **The dev container configuration is unavailable:** Confirm that you opened the assigned `microhack` repository before creating the Codespace.
- **The Codespace does not finish starting:** Review the creation log for the failing step, then rebuild the container or recreate the Codespace.

## 🧠 Conclusion

You have verified the Azure resources and opened the configured development environment.
Continue to [Challenge 2](challenge-02.md) to build the Claims Intake Agent.