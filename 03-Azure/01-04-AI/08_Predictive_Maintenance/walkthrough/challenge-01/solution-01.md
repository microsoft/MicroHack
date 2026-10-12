# Challenge 1 walkthrough - Environment Setup and Data Foundation

**[Back to challenge](../../challenges/challenge-01.md)**

This walkthrough adds the exact commands, expected output, and a validation checklist for [Challenge 1](../../challenges/challenge-01.md). It does not repeat the background, scenario, or objective — see the challenge file for that.

## Prerequisites

* The Hackbox credential sheet for this lab, containing your Azure sign-in, GitHub sign-in, and resource group name.
* A modern browser. No local tooling is required before you reach Task 3 (the Codespace provides everything else).

## Task 1: Sign in to Azure

1. Go to [https://portal.azure.com](https://portal.azure.com).
2. Select your account avatar (or **Use another account** if you're already signed in as someone else).
3. Enter the username and password from your Hackbox sheet.
4. Once signed in, select **Resource groups** in the left-hand menu or search bar, and open the resource group named on your Hackbox sheet.

Expected result: the resource group's **Overview** page lists resources including a Cognitive Services / Foundry account, a Cosmos DB account, a Storage account, and an API Management instance.

## Task 2: Sign in to GitHub

1. Go to [https://github.com](https://github.com) and select **Sign in**.
2. Enter the username from your Hackbox sheet, then select **Sign in with your identity provider** when prompted (rather than a password), and complete the identity provider sign-in flow.
3. Navigate to the GitHub organization named on your Hackbox sheet and open the `MicroHack` repository.
4. Confirm you can browse to `03-Azure/01-04-AI/08_Predictive_Maintenance` in the file browser.

## Task 3: Create the development environment

1. From the repository page, select the green **Code** button, open the **Codespaces** tab.
2. Select the `...` (more options) menu next to **Create codespace on main**, then choose **New with options**.
3. For **Dev container configuration**, select **Azure / AI / Predictive Maintenance**.
4. Select **Create codespace**.

The Codespace takes a few minutes to build the container image the first time. Once it opens:

```bash
az --version
dotnet --version
```

Expected result: both commands print a version number without a "command not found" error.

```bash
uv sync --frozen
source .venv/bin/activate
```

Expected result: `uv sync --frozen` reports the resolved/installed packages and exits with code 0; after `source .venv/bin/activate` your shell prompt is prefixed with `(.venv)`.

```bash
az login --use-device-code
```

Expected result: the CLI prints a URL and a device code. Open the URL in a browser tab, enter the code, and sign in with the Hackbox Azure credentials. The terminal then prints your subscription details.

## Task 4: Retrieve environment configuration

```bash
bash labautomation/get-keys.sh --resource-group "<your-resource-group-name>"
```

Expected result: the script prints progress lines for each resource it queries and finishes with `Environment file created: <path>/.env`. No line should show an empty value in quotes (`""`) for a required setting — if you see one, see [Troubleshooting](#troubleshooting) below.

```bash
export $(grep -v '^#' .env | xargs)
```

This command has no output on success. Verify a couple of the values loaded:

```bash
echo "$AZURE_AI_PROJECT_ENDPOINT"
echo "$COSMOS_ENDPOINT"
```

Expected result: both print an `https://` URL, not an empty line.

## Task 5: Verify the seeded factory data

```bash
az cosmosdb sql container list \
  --account-name "$COSMOS_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --database-name "FactoryOpsDB" \
  --query "[].id" --output tsv
```

Expected output (order may vary):

```text
Machines
Thresholds
Telemetry
KnowledgeBase
PartsInventory
Technicians
WorkOrders
```

```bash
az storage blob list \
  --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
  --container-name machine-wiki \
  --query "length(@)" --output tsv
```

Expected output: `5`

## Troubleshooting

* **A Cosmos DB container is missing or empty, or `machine-wiki` blob container has fewer than 5 blobs:** the automatic post-deployment seeding step may not have completed yet, or it targeted a different resource group. As a fallback, you can re-seed manually. Ask your coach whether this is expected for your lab, then, from the repository root:

  ```bash
  # Re-upload the knowledge base wiki articles
  for f in data/kb-wiki/*.md; do
    az storage blob upload \
      --connection-string "$AZURE_STORAGE_CONNECTION_STRING" \
      --container-name machine-wiki \
      --name "$(basename "$f")" \
      --file "$f" \
      --overwrite
  done
  ```

  Re-run the verification commands in Task 5 afterwards to confirm the fix.

  If a Cosmos DB container is missing documents (not just the blob container), the fix is on the
  provisioning side rather than something you can safely redo from inside the Codespace: ask your
  coach to re-run the data-seeding portion of `labautomation/deploy-lab.ps1` for your resource
  group. See [labautomation/README.md](../../labautomation/README.md#data-seeding) for what that
  step does.
* **`get-keys.sh` prints empty values for one or more settings:** confirm the deployment in your resource group finished successfully (**Deployments** blade in the Azure portal should show *Succeeded*), and that you passed the correct `--resource-group` name.
* **`az login --use-device-code` succeeds but later commands return `AuthorizationFailed`:** confirm you're targeting the correct subscription with `az account show`; if it's wrong, run `az account set --subscription "<subscription-id>"`.

## Validation checklist

* [ ] Signed in to the Azure portal with the Hackbox account and can see the assigned resource group's resources.
* [ ] Signed in to GitHub with the Hackbox account and can browse the `MicroHack` repository.
* [ ] Codespace created using the **Azure / AI / Predictive Maintenance** dev container configuration.
* [ ] `az --version` and `dotnet --version` both succeed inside the Codespace.
* [ ] `uv sync --frozen` completed and `.venv` is activated.
* [ ] Signed in to Azure CLI inside the Codespace (`az login --use-device-code`).
* [ ] `.env` file created by `labautomation/get-keys.sh` with no empty required values.
* [ ] Environment variables exported into the current shell.
* [ ] All 7 Cosmos DB containers listed for the `FactoryOpsDB` database.
* [ ] `machine-wiki` blob container contains 5 markdown articles.

**Next:** [Challenge 2 walkthrough](../challenge-02/solution-02.md)
