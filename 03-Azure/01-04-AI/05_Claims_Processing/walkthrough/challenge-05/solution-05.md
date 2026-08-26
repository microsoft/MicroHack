---
title: "Solution 05: Host Secure Actions in Azure Functions"
description: "Solution walkthrough for hosting and validating the secured claims action endpoint"
---

[Home](../../README.md) | [Challenge 05](../../challenges/challenge-05.md) | [Previous solution](../challenge-04/solution-04.md)

## Outcome

This optional solution runs the secured action endpoint locally, validates clean
and adversarial requests, and publishes the function with managed identity.

## Prerequisites

* Complete Challenge 04
* Install Python 3.11 and Azure Functions Core Tools v4
* Install the Azure CLI and authenticate to Azure

## Run locally

From the repository root, prepare and start the function:

```powershell
Set-Location docs/claims-security-trigger
Copy-Item local.settings.json.example local.settings.json
python -m pip install -r requirements.txt
func start
```

In another terminal, send the requests supplied in
`docs/claims-security-trigger/demo.http`. The clean request and both injection
requests target:

```text
POST http://localhost:7071/api/claims/actions
```

## Deploy the function

Set the values described in Challenge 05, then create and publish the app:

```bash
az functionapp create --resource-group $RESOURCE_GROUP --name $FUNCTION_APP \
  --storage-account $STORAGE_ACCOUNT --runtime python --runtime-version 3.11 \
  --flexconsumption-location $LOCATION \
  --deployment-storage-auth-type SystemAssignedIdentity --assign-identity [system]

func azure functionapp publish $FUNCTION_APP
```

Assign the function identity the Storage Blob Data Owner role on Storage and
the Cognitive Services User role on the Foundry account before testing the
remote endpoint.

## Expected result

The local host advertises `POST /api/claims/actions`. Valid requests return the
claim ID, unchanged workflow status, agent response, and audit log. Invalid or
inconsistent requests return HTTP 400. The deployed endpoint requires a
function key.

## Troubleshooting

* If startup reports a missing endpoint, update local or deployed settings with
  `FOUNDRY_PROJECT_ENDPOINT`
* For local credential failures, authenticate with `az login`
* For HTTP 400, confirm the claim IDs match and the workflow status is valid
* For remote HTTP 401 or 403, include the function key and verify role assignments

## Validation checklist

* [ ] The local and deployed routes respond
* [ ] The trusted workflow status remains unchanged
* [ ] The response includes the audit log
* [ ] Injection and exfiltration attempts remain blocked
* [ ] Invalid payloads return HTTP 400
* [ ] The deployed endpoint requires a function key

Return to the [MicroHack home page](../../README.md).
