# Importing Oracle Container Registry Images to Azure Container Registry

This guide explains how to import Oracle GoldenGate images from Oracle Container Image Registry (OCIR) to Azure Container Registry (ACR).

## Overview

The `az acr import` command allows you to import container images from external registries directly into your Azure Container Registry without needing to pull and push the image locally.

## Prerequisites

1. **Azure CLI** installed and authenticated
2. **Azure Container Registry** (e.g., `odaamh.azurecr.io`)
3. **Oracle Cloud Infrastructure (OCI) credentials**:
   - OCI username
   - OCI Auth Token
   - Tenancy namespace

## Getting OCI Credentials

### 1. Tenancy Namespace
Your tenancy namespace is visible in the Oracle Container Registry URL. For example:
- URL: `fra.ocir.io/frul1g8cgfam/pub_gg_micro_bigdata:23.4.0.24.06`
- Tenancy namespace: `frul1g8cgfam`

### 2. OCI Username
Your OCI username format depends on your identity provider:
- **OCI IAM**: `<username>`
- **Oracle Identity Cloud Service (IDCS)**: `oracleidentitycloudservice/<email>`
- **Federated users**: `<identity-provider>/<username>`

### 3. Auth Token
Generate an Auth Token in the OCI Console:
1. Sign in to Oracle Cloud Console
2. Click your profile icon → **User Settings**
3. Under **Resources**, click **Auth Tokens**
4. Click **Generate Token**
5. Provide a description and click **Generate Token**
6. **Copy and save the token immediately** (it won't be shown again)

## Import Command

### Basic Syntax

```powershell
az acr import `
  --name <acr-name> `
  --source <source-registry>/<namespace>/<image>:<tag> `
  --image <target-image-name>:<tag> `
  --username "<tenancy-namespace>/<oci-username>" `
  --password "<oci-auth-token>"
```

### Example: Importing GoldenGate BigData Image

```powershell
# Set the correct Azure subscription
az account set --subscription 09808f31-065f-4231-914d-776c2d6bbe34

# Import the image
az acr import `
  --name odaamh `
  --source fra.ocir.io/frul1g8cgfam/pub_gg_micro_bigdata:23.4.0.24.06 `
  --image goldengate/pub_gg_micro_bigdata:23.4.0.24.06 `
  --username "frul1g8cgfam/<your-oci-username>" `
  --password "<your-oci-auth-token>"
```

### Using Environment Variables (Recommended for Security)

```powershell
# Store credentials in environment variables
$env:OCI_USERNAME = "frul1g8cgfam/<your-oci-username>"
$env:OCI_AUTH_TOKEN = "<your-oci-auth-token>"

# Import using environment variables
az acr import `
  --name odaamh `
  --source fra.ocir.io/frul1g8cgfam/pub_gg_micro_bigdata:23.4.0.24.06 `
  --image goldengate/pub_gg_micro_bigdata:23.4.0.24.06 `
  --username $env:OCI_USERNAME `
  --password $env:OCI_AUTH_TOKEN
```

## Available Images to Import

Based on the configuration in `ggfabric.yaml`, you may need to import:

1. **BigData Image (23.4.0)**:
   ```
   Source: fra.ocir.io/frul1g8cgfam/pub_gg_micro_bigdata:23.4.0.24.06
   Target: odaamh.azurecr.io/goldengate/pub_gg_micro_bigdata:23.4.0.24.06
   ```

2. **BigData Image (23.8.4)**:
   ```
   Source: fra.ocir.io/frul1g8cgfam/pub_gg_micro_bigdata:23.8.4.25.08
   Target: odaamh.azurecr.io/goldengate/pub_gg_micro_bigdata:23.8.4.25.08
   ```

## Verification

After importing, verify the image is available in your ACR:

```powershell
# List all repositories
az acr repository list --name odaamh --output table

# Show tags for a specific repository
az acr repository show-tags --name odaamh --repository goldengate/pub_gg_micro_bigdata --output table

# Get image details
az acr repository show --name odaamh --image goldengate/pub_gg_micro_bigdata:23.4.0.24.06
```

## Updating Kubernetes Deployments

After importing, update your Helm values or Kubernetes manifests to use the ACR image:

```yaml
image:
  imageName: odaamh.azurecr.io/goldengate/pub_gg_micro_bigdata:23.4.0.24.06
```

## Troubleshooting

### 403 Forbidden Error
```
Anonymous users are only allowed read access on public repos
```
**Solution**: Ensure you're providing valid OCI credentials with `--username` and `--password` flags.

### Invalid Credentials
**Solution**: 
- Verify your OCI username format matches your identity provider
- Ensure the Auth Token is valid and not expired
- Check that the tenancy namespace is correct

### Subscription Not Found
**Solution**: Set the correct Azure subscription:
```powershell
az account set --subscription <subscription-id>
```

### Image Not Found in Source Registry
**Solution**: 
- Verify you have access to the OCI repository
- Check that the image path and tag are correct
- Ensure your OCI user has pull permissions for the repository

## Additional Resources

- [Azure Container Registry Import Documentation](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-import-images)
- [Oracle Container Registry Documentation](https://docs.oracle.com/en-us/iaas/Content/Registry/home.htm)
- [Managing Auth Tokens in OCI](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm)

## Related Files

- `ggfabric.yaml` - Helm values file containing image configurations
- `resources/gg-bigdata-build/` - GoldenGate build resources
- `resources/infra/` - Infrastructure deployment files
