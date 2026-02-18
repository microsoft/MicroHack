# Walkthrough Challenge 5 - Encryption in use with Confidential VMs/Node Pools in Azure Kubernetes Service (AKS)

[Previous Challenge Solution](../challenge-04/solution-04.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-06/solution-06.md)

**Estimated Duration:** 90-120 minutes

> 💡 **Objective:** Learn how to deploy and validate guest attestation on Azure Confidential VMs in AKS to ensure business logic only executes in trusted, hardware-backed confidential computing environments. You will create an AKS cluster using Azure CLI, add a Confidential VM node pool, deploy attestation workloads, and verify cryptographic proof of node integrity before processing sensitive operations.

---

## Prerequisites

Please ensure that you successfully verified the [General prerequisites](../../README.md#general-prerequisites) before continuing with this challenge.

- Azure CLI >= 2.54 installed and logged in (`az login`)
- **Linux/Bash environment** - Choose one of the following:
  - **Azure Cloud Shell (Bash)** - Recommended for ease of use
  - **WSL2 on Windows** - Windows Subsystem for Linux 2
  - **Linux or macOS** - Native Bash terminal
- Azure subscription with permissions to create AKS clusters, node pools, and register preview features
- `kubectl` command-line tool (can be installed via `az aks install-cli`)
- Basic understanding of Kubernetes concepts (pods, deployments, node pools)
- Familiarity with Azure CLI commands
- Basic understanding of confidential computing concepts

## Scenario Context

You are a cloud security engineer at a European healthcare organization that processes sensitive patient data in containerized applications. Your organization has adopted Kubernetes (AKS) for container orchestration but must comply with strict data protection regulations including GDPR and healthcare privacy requirements.

Your mandate includes:

- **Encryption in Use**: Protect data while it's being processed in containers, not just at rest or in transit
- **Hardware-Based Trust**: Ensure security guarantees are rooted in hardware (AMD SEV-SNP), not just software isolation
- **Attestation for Workloads**: Verify that containerized applications run only on genuine confidential computing nodes
- **Zero Trust for Kubernetes**: Validate the integrity of worker nodes before deploying sensitive workloads
- **Compliance and Auditability**: Provide cryptographic evidence that workloads execute in compliant infrastructure

In this challenge, you'll deploy Azure Confidential Computing node pools in AKS using Azure CLI. You'll configure a confidential VM node pool with AMD SEV-SNP technology, deploy attestation-aware workloads, and verify that containers run in hardware-protected environments before processing sensitive operations.

### Understanding Confidential VMs in AKS

Azure Kubernetes Service (AKS) supports Confidential VM node pools, which provide:

- **Hardware-based memory encryption** - AMD SEV-SNP encrypts node memory at the hardware level
- **Node attestation** - Cryptographic proof that worker nodes run on genuine confidential hardware
- **Workload isolation** - Containers benefit from the underlying confidential VM protections
- **Integration with existing Kubernetes workflows** - Use standard Kubernetes constructs (node selectors, taints/tolerations)

**Security Architecture:**

This setup implements defense-in-depth security:
- **Confidential VM Node Pool** - Worker nodes with AMD SEV-SNP hardware encryption
- **Attestation Verification** - Pods can verify they're running on confidential nodes
- **Node Selectors** - Target sensitive workloads to confidential node pools only
- **Microsoft Azure Attestation (MAA)** - Validates node integrity and issues signed JWT tokens

### Learning Resources

- [Azure Confidential Computing overview](https://azure.microsoft.com/solutions/confidential-compute/)
- [Confidential VMs on Azure](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview)
- [AKS with Confidential Computing](https://learn.microsoft.com/azure/aks/use-confidential-computing)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/)

### Original Source Materials

This challenge is based on the **AKS with Confidential Computing Linux Sample** from the Microsoft Azure Confidential Computing repository:

- **Main Repository**: [Azure Confidential Computing CVM Guest Attestation](https://github.com/Azure/confidential-computing-cvm-guest-attestation)
- **Source Module**: [AKS Linux Sample](https://github.com/Azure/confidential-computing-cvm-guest-attestation/tree/main/aks-linux-sample)

The AKS deployment patterns and attestation verification workflows have been adapted for this MicroHack challenge to provide a guided learning experience with Confidential VM node pools in Azure Kubernetes Service.

---

## Task 1: Configure Environment and Register Preview Features

💡 **Set up your environment variables and register the required Azure preview features for Confidential VM support in AKS.**

### Step 1: Configure Environment Variables

### Linux/Bash

```bash
# Set common variables
# Customize ATTENDEE_ID for each participant
RESOURCE_GROUP="labuser-xx"  # Change this for each participant (e.g., labuser-01, labuser-02,...)

ATTENDEE_ID="${RESOURCE_GROUP}"

# Generate a unique random hash suffix (different on each run)
HASH_SUFFIX=$(echo -n "$ATTENDEE_ID-$(date +%s)-$RANDOM" | md5sum | cut -c1-6)

LOCATION="northeurope"
AKS_CLUSTER_NAME="aks-cvmcluster$HASH_SUFFIX"
DNS_LABEL="cvmcluster$HASH_SUFFIX"
ADMIN_USERNAME="azureuser"
KEYVAULT_NAME="kv-cc-${HASH_SUFFIX}"  # Must be globally unique
SSH_KEY_NAME="cc-${ATTENDEE_ID}-key"
ATTESTATION_NAME="attest${HASH_SUFFIX}"
```

### Step 2: Install Required AKS Extensions

```bash
# Install / Update `aks-preview` extension
az extension add --name aks-preview
az extension update --name aks-preview

# Register the `AzureLinuxCVMPreview` feature flag
az feature register --namespace "Microsoft.ContainerService" --name "AzureLinuxCVMPreview"

# Verify the registration status - status should show "Registered"
az feature show --namespace Microsoft.ContainerService --name AzureLinuxCVMPreview

# Refresh the registration of the `Microsoft.ContainerService` resource provider
az provider register --namespace Microsoft.ContainerService
```

---

## Task 2: Create Resource Group and AKS Cluster

💡 **Deploy the foundational AKS cluster with a standard system node pool. You'll add the Confidential VM node pool in the next task.**

### Step 1: Create Resource Group and AKS Cluster

```bash
# Create Resource Group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create an AKS cluster
az aks create --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --node-count 1 --generate-ssh-keys

# Connect to the cluster
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME
```

---

## Task 3: Add Confidential VM Node Pool

💡 **Create a dedicated node pool with Confidential VM compute resources for running sensitive workloads.**

### Step 1: Add the Confidential Node Pool

```bash
az aks nodepool add --resource-group $RESOURCE_GROUP --cluster-name $AKS_CLUSTER_NAME --name cvmnodepool --node-count 1 --node-vm-size Standard_DC2as_v5
```

---

## Task 4: Verify Confidential Node Pool Configuration

💡 **Validate that the Confidential VM node pool is properly configured and running with the correct VM size and image.**

### Step 1: Verify VM Size and Image

```bash
# Verify that the node pool uses a Confidential VM
az aks nodepool show --resource-group $RESOURCE_GROUP --cluster-name $AKS_CLUSTER_NAME --name cvmnodepool --query 'vmSize'

# Verify that the node pool uses a Confidential VM image
az aks nodepool list --resource-group $RESOURCE_GROUP --cluster-name $AKS_CLUSTER_NAME --query "[?name=='cvmnodepool'].nodeImageVersion" -o tsv
```

---

## Task 5: Deploy and Verify Attestation Pod

💡 **Deploy a sample pod that retrieves attestation data to prove it's running on a confidential VM node.**

### Step 1: Deploy the Attestation Pod

1. The attestation pod YAML file is located at `walkthrough/challenge-5/resources/cvm-attestation-pod.yaml` in this repository.

2. Apply the YAML file using the relative path from the repository root:

```bash
kubectl apply -f walkthrough/challenge-5/resources/cvm-attestation-pod.yaml
```

2. Check pod status:

```bash
kubectl get pods
```

3. Get the attestation report by checking logs:

```bash
kubectl logs cvm-attestation
```

### Expected Output

The attestation report will contain JWT tokens with confidential computing verification data:

```json
{
  "alg": "RS256",
  "jku": "https://sharedeus2.eus2.attest.azure.net/certs",
  "kid": "J0pAPdfXXHqWWimgrH853wMIdh5/fLe1z6uSXYPXCa0=",
  "typ": "JWT"
}
{
  "exp": 1663376286,
  "iat": 1663347486,
  "iss": "https://sharedeus2.eus2.attest.azure.net",
  "jti": "89a500344d9ecc081b14ff6c848fbc1d557694946e6f8d83687654a1139e055d",
  "nbf": 1663347486,
  "secureboot": true,
  "x-ms-attestation-type": "azurevm",
  "x-ms-azurevm-attestation-protocol-ver": "2.0",
  "x-ms-azurevm-attested-pcrs": [0, 1, 2, 3, 4, 5, 6, 7],
  "x-ms-azurevm-bootdebug-enabled": false,
  "x-ms-azurevm-dbvalidated": true,
  "x-ms-azurevm-dbxvalidated": true,
  "x-ms-azurevm-debuggersdisabled": true,
  "x-ms-azurevm-default-securebootkeysvalidated": true,
  "x-ms-azurevm-elam-enabled": false,
  "x-ms-azurevm-flightsigning-enabled": false,
  "x-ms-azurevm-hvci-policy": 0,
  "x-ms-azurevm-hypervisordebug-enabled": false,
  "x-ms-azurevm-is-windows": false,
  "x-ms-azurevm-kerneldebug-enabled": false,
  "x-ms-azurevm-osbuild": "NotApplication",
  "x-ms-azurevm-osdistro": "Ubuntu",
  "x-ms-azurevm-ostype": "Linux",
  "x-ms-azurevm-osversion-major": 18,
  "x-ms-azurevm-osversion-minor": 4,
  "x-ms-azurevm-signingdisabled": true,
  "x-ms-azurevm-testsigning-enabled": false,
  "x-ms-azurevm-vmid": "A80B7FE7-5B93-4027-9971-6CCEE468C2B3",
  "x-ms-isolation-tee": {
    "x-ms-attestation-type": "sevsnpvm",
    "x-ms-compliance-status": "azure-compliant-cvm",
    "x-ms-runtime": {
      "keys": [
        {
          "e": "AQAB",
          "key_ops": ["encrypt"],
          "kid": "HCLAkPub",
          "kty": "RSA",
          "n": "2I-ayAABWYhQU-D81quVW4i1sH14-Offul2U2LwsgtihxykIzXY_5YzQAY4e56GMZSpm5r6telRr5rnFJa8iklzol7ecYZEX1nc1WK51a68E2kZNyomFVSIlDPJCn14NpRoxuipIfhe16zWVYZ8dpYbpelyzHZZpskdBLnUKldffUYliWSXLBpjPb89VV0FYxKPi_bSGviBXWOiRtcITRcXfpjlfD3DgZqlK4gj11RChqaEYG_GAPlxceu5h1pusgLuPEULWzvkKuGw7j8ZrxdYEUNB-uHU0nxuQvYxtksPs3zX6ELcV2GjwJupzYUUAu95OQUGI-soDWKvIXM4epw"
        }
      ],
      "vm-configuration": {
        "console-enabled": true,
        "current-time": 1662691445,
        "secure-boot": true,
        "tpm-enabled": true,
        "vmUniqueId": "A80B7FE7-5B93-4027-9971-6CCEE468C2B3"
      }
    },
    "x-ms-sevsnpvm-authorkeydigest": "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    "x-ms-sevsnpvm-bootloader-svn": 2,
    "x-ms-sevsnpvm-familyId": "01000000000000000000000000000000",
    "x-ms-sevsnpvm-guestsvn": 2,
    "x-ms-sevsnpvm-hostdata": "0000000000000000000000000000000000000000000000000000000000000000",
    "x-ms-sevsnpvm-idkeydigest": "57486a447ec0f1958002a22a06b7673b9fd27d11e1c6527498056054c5fa92d23c50f9de44072760fe2b6fb89740b696",
    "x-ms-sevsnpvm-imageId": "02000000000000000000000000000000",
    "x-ms-sevsnpvm-is-debuggable": false,
    "x-ms-sevsnpvm-launchmeasurement": "ad6de16ac59ee52351c6038df58d1be5aeaf41cd0f7c81b2279ecca0df6ef43a2b69d663ad6973d6dbb9db0ffd7a9023",
    "x-ms-sevsnpvm-microcode-svn": 93,
    "x-ms-sevsnpvm-migration-allowed": false,
    "x-ms-sevsnpvm-reportdata": "d707bdbeeeb6c6e7fa42e94e71ec537e21c8d4c4316422c4011742f55ecc22c00000000000000000000000000000000000000000000000000000000000000000",
    "x-ms-sevsnpvm-reportid": "afc01d4d5f22974bd00c2d993bc3354fcd3bf37c789c2611233da72df1712d82",
    "x-ms-sevsnpvm-smt-allowed": true,
    "x-ms-sevsnpvm-snpfw-svn": 6,
    "x-ms-sevsnpvm-tee-svn": 0,
    "x-ms-sevsnpvm-vmpl": 0
  },
  "x-ms-policy-hash": "wm9mHlvTU82e8UqoOy1Yj1FBRSNkfe99-69IYDq9eWs",
  "x-ms-runtime": {
    "client-payload": {
      "nonce": "MTIzNA=="
    },
    "keys": [
      {
        "e": "AQAB",
        "key_ops": ["encrypt"],
        "kid": "TpmEphemeralEncryptionKey",
        "kty": "RSA",
        "n": "peWMfgAALfH53tQC-noqUvYLgycL8K9Ejn7mKKDJwu7hdrrfydinD04burg83WANTGOKO4OHiNieJf4SiGmxZQyLym6gJr4m0bGbsMt4NM6dXXVmRZZSkCp4hn_2XL6aMOnnn0YNOXg6zmRmOeRu4rgkOA_WCd8YE23k7wp0twZG0VCgVmUUr2LD_xwqLLsukoDG8_b38QJmkh78Vz6BGLIA9-qgG5fpBGVoERWe1CCC1aH7bkKhKtNPSD0x6EbfxCfe4dU_Adg6xdxuaDEK9mcfxZWz56cevmlc44SapFm00iSYeWmyoyqlZUJ6mr-1P-DYataNHZPZr8mz2wDAgQ"
      }
    ]
  },
  "x-ms-ver": "1.0"
}
```

### Key Attestation Fields

The attestation report contains important security validation fields:

- **secureboot**: `true` - Secure Boot is enabled
- **x-ms-azurevm-attestation-protocol-ver**: Version of attestation protocol
- **x-ms-azurevm-attested-pcrs**: Platform Configuration Registers that were measured
- **x-ms-isolation-tee**: Trusted Execution Environment details
- **x-ms-compliance-status**: `"azure-compliant-cvm"` - Confirms Azure Confidential VM compliance
- **x-ms-sevsnpvm-is-debuggable**: `false` - VM is not debuggable (production setting)
- **x-ms-sevsnpvm-launchmeasurement**: Launch measurement for integrity verification

---

## Task 6: Clean Up Resources

💡 **Delete all resources to avoid ongoing charges.**

### Step 1: Delete Resource Group

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

⚠️ **Warning**: This command will permanently delete all resources in the resource group including the AKS cluster, node pools, and all associated resources.

---

## Key Takeaways

In this challenge, you successfully deployed and validated Azure Confidential Computing in AKS with guest attestation. Here are the key concepts and best practices:

### Confidential Computing in Kubernetes

✅ **Node-Level Encryption** - Confidential VM node pools provide hardware-based memory encryption (AMD SEV-SNP) for all containers running on those nodes

✅ **Workload Targeting** - Use Kubernetes node selectors to schedule sensitive workloads exclusively on confidential node pools

✅ **Transparent Integration** - Applications benefit from confidential computing protections without code changes (though attestation-aware apps provide stronger guarantees)

### Attestation in Containerized Environments

✅ **Node Attestation** - Containers can query the Instance Metadata Service to retrieve attestation tokens proving they run on confidential hardware

✅ **Runtime Verification** - Applications should verify attestation at startup before processing sensitive data

✅ **JWT Token Validation** - Attestation tokens are signed by Microsoft Azure Attestation and contain claims about hardware security features

### AKS Architecture and Security

✅ **Mixed Node Pools** - Combine standard and confidential node pools in the same cluster for cost optimization (use confidential nodes only for sensitive workloads)

✅ **Preview Features** - Confidential VM support in AKS requires feature registration via `az feature register`

✅ **CLI Management** - Azure CLI provides efficient commands for managing AKS clusters and confidential node pools

### Production Best Practices

✅ **Node Pool Sizing** - Start with DC-series VMs (e.g., Standard_DC2as_v5) and scale based on workload requirements

✅ **Workload Isolation** - Use Kubernetes namespaces, network policies, and RBAC in addition to confidential computing

✅ **Attestation Policies** - For production, consider custom Azure Attestation policies that enforce specific security requirements

✅ **Monitoring and Logging** - Integrate AKS diagnostics with Azure Monitor to track confidential node pool health

### Compliance and Governance

✅ **Data Sovereignty** - Confidential computing ensures data in containers is encrypted even from cloud operators

✅ **Regulatory Compliance** - Meets requirements for healthcare (HIPAA), financial services, and government workloads

✅ **Audit Trail** - Attestation tokens provide cryptographic proof for compliance auditing

---

## Next Steps

### Explore Advanced AKS Confidential Computing Scenarios

- **[Confidential Containers on AKS](https://learn.microsoft.com/azure/confidential-computing/confidential-containers)** - Deploy containers with Intel SGX enclaves for process-level isolation
- **[Azure Confidential Computing Add-on for AKS](https://learn.microsoft.com/azure/confidential-computing/confidential-nodes-aks-get-started)** - Explore the official Microsoft add-on for confidential computing
- **[Managed Identity with Confidential AKS](https://learn.microsoft.com/azure/aks/use-managed-identity)** - Integrate Azure AD workload identities with confidential workloads

### Implement Production-Ready Confidential AKS

- **Custom Attestation Policies** - Define organization-specific attestation requirements using Azure Attestation policies
- **Multi-Region Deployment** - Deploy confidential AKS clusters across multiple Azure regions for high availability
- **GitOps with Confidential Workloads** - Use Flux or ArgoCD to manage confidential workload deployments
- **Service Mesh Integration** - Combine Istio/Linkerd with confidential computing for end-to-end encryption

### Secure Your AKS Workloads Further

- **[Azure Key Vault Provider for Secrets Store CSI Driver](https://learn.microsoft.com/azure/aks/csi-secrets-store-driver)** - Securely inject secrets into confidential pods
- **[Azure Policy for AKS](https://learn.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes)** - Enforce governance policies on confidential node pools
- **[Network Policies](https://learn.microsoft.com/azure/aks/use-network-policies)** - Restrict network traffic to/from confidential workloads

### Learn More About Confidential Computing

- **[Confidential Inferencing](https://learn.microsoft.com/azure/machine-learning/how-to-machine-learning-confidential-containers)** - Deploy ML models in confidential containers on AKS
- **[Azure Confidential Ledger](https://learn.microsoft.com/azure/confidential-ledger/overview)** - Integrate tamper-proof audit logs with confidential AKS workloads
- **[Multi-Party Computation Patterns](https://learn.microsoft.com/azure/confidential-computing/use-cases-scenarios)** - Build collaborative data processing scenarios with confidential AKS

---

## Additional Resources

- [Azure Confidential Computing overview](https://azure.microsoft.com/solutions/confidential-compute/)
- [Confidential VMs on Azure](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview)
- [AKS Documentation](https://learn.microsoft.com/azure/aks/)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/)
- [AMD SEV-SNP Technology](https://www.amd.com/en/developer/sev.html)
- [Kubernetes Node Selectors](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
