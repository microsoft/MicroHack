# Walkthrough Challenge 5 - Encryption in use with Confidential VMs/Node Pools in Azure Kubernetes Service (AKS)
# Azure Portal Guide

**Estimated Duration:** 90-120 minutes

> 💡 **Objective:** Learn how to deploy and validate guest attestation on Azure Confidential VMs in AKS to ensure business logic only executes in trusted, hardware-backed confidential computing environments. You will create an AKS cluster through the Azure Portal, add a Confidential VM node pool, deploy attestation workloads, and verify cryptographic proof of node integrity before processing sensitive operations.

---

## Prerequisites

Please ensure that you successfully verified the [General prerequisites](../../README.md#general-prerequisites) before continuing with this challenge.

- Access to Azure Portal (https://portal.azure.com)
- Azure subscription with permissions to create AKS clusters, node pools, and register preview features
- Azure Cloud Shell access (for kubectl commands)
- Basic understanding of Kubernetes concepts (pods, deployments, node pools)
- Familiarity with Azure Portal navigation
- Basic understanding of confidential computing concepts

**Configuration Variables:** Throughout this challenge, replace these placeholders with your values:
- **ATTENDEE_ID**: `labuser-xx` (customize for each participant, e.g., labuser-01, labuser-02)
- **Region**: North Europe
- **Resource Group**: `${ATTENDEE_ID}`
- **AKS Cluster Name**: `aks-cvmcluster-<unique-suffix>` (Azure will help ensure uniqueness)
- **Confidential Node Pool Name**: `cvmnodepool`
- **VM Size for Confidential Nodes**: `Standard_DC2as_v5`

💡 **Note**: Whenever you see `${ATTENDEE_ID}` or `<unique-suffix>` in commands or configuration, replace them with your actual values.

## Scenario Context

You are a cloud security engineer at a European healthcare organization that processes sensitive patient data in containerized applications. Your organization has adopted Kubernetes (AKS) for container orchestration but must comply with strict data protection regulations including GDPR and healthcare privacy requirements.

Your mandate includes:

- **Encryption in Use**: Protect data while it's being processed in containers, not just at rest or in transit
- **Hardware-Based Trust**: Ensure security guarantees are rooted in hardware (AMD SEV-SNP), not just software isolation
- **Attestation for Workloads**: Verify that containerized applications run only on genuine confidential computing nodes
- **Zero Trust for Kubernetes**: Validate the integrity of worker nodes before deploying sensitive workloads
- **Compliance and Auditability**: Provide cryptographic evidence that workloads execute in compliant infrastructure

In this challenge, you'll deploy Azure Confidential Computing node pools in AKS using the Azure Portal. You'll configure a confidential VM node pool with AMD SEV-SNP technology, deploy attestation-aware workloads, and verify that containers run in hardware-protected environments before processing sensitive operations.

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

The AKS deployment patterns and attestation verification workflows have been adapted for this MicroHack challenge to provide a guided learning experience with Confidential VM node pools in Azure Kubernetes Service using the Azure Portal.

---

## Task 1: Enable Preview Features and Prepare Environment

💡 **Before creating AKS clusters with Confidential VM node pools, you must register the required preview features.**

### Step 1: Register the AzureLinuxCVMPreview Feature

1. In the Azure Portal, search for **Subscriptions** in the top search bar
2. Select your subscription
3. In the left menu, under **Settings**, click **Preview features**

   ![Screenshot placeholder: Subscription Preview Features menu]

4. In the search box, type: `AzureLinuxCVMPreview`
5. Select **AzureLinuxCVMPreview** from the results
6. Click **Register**

   ![Screenshot placeholder: Register AzureLinuxCVMPreview feature]

7. Wait for the registration status to show **Registered** (this may take several minutes)
8. You can check the status by clicking **Refresh** periodically

   ![Screenshot placeholder: Feature registration status showing Registered]

---

---

## Task 2: Create Resource Group

💡 **Create the foundational resource group to organize all AKS-related resources.**

1. In the Azure Portal, click **Create a resource** or search for **Resource groups**
2. Click **+ Create**
3. Fill in the following details:
   - **Subscription**: Select your subscription
   - **Resource group**: `${ATTENDEE_ID}` (e.g., `labuser-01`)
   - **Region**: **North Europe**

   ![Screenshot placeholder: Create resource group form]

4. Click **Review + create**
5. Click **Create**

   ![Screenshot placeholder: Resource group created successfully]

---

---

## Task 3: Create AKS Cluster with Standard Node Pool

💡 **Deploy the AKS cluster with a standard system node pool. You'll add the Confidential VM node pool in the next task.**

1. In the Azure Portal, search for **Kubernetes services** in the top search bar
2. Click **+ Create** and select **Kubernetes cluster**

   ![Screenshot placeholder: Create Kubernetes cluster button]

### Basics Tab

3. Fill in the **Basics** tab:
   - **Subscription**: Select your subscription
   - **Resource group**: `${ATTENDEE_ID}` (select the one you just created)
   - **Cluster preset configuration**: **Dev/Test**
   - **Kubernetes cluster name**: `aks-cvmcluster-<unique-suffix>` (e.g., `aks-cvmcluster-abc123`)
   - **Region**: **North Europe**
   - **Availability zones**: None (or as preferred)
   - **AKS pricing tier**: **Free**
   - **Kubernetes version**: Default (latest stable version)
   - **Automatic upgrade**: **Disabled**
   - **Node security channel type**: **None**

   ![Screenshot placeholder: AKS Basics tab configuration]

### Node pools Tab

4. Click **Next: Node pools**
5. Keep the default node pool settings:
   - **Node pool name**: `agentpool` (default system node pool)
   - **Node size**: Default (e.g., `Standard_DS2_v2`)
   - **Scale method**: **Manual**
   - **Node count**: **1**

   ![Screenshot placeholder: AKS Node pools tab]

### Networking Tab

6. Click **Next: Networking**
7. Configure networking:
   - **Network configuration**: **Azure CNI**
   - **Network policy**: **None** (or **Calico** if preferred)
   - Leave other settings as default

   ![Screenshot placeholder: AKS Networking tab]

### Integrations, Advanced, and Tags Tabs

8. Click **Next** through **Integrations**, **Advanced**, and **Tags** tabs
9. Keep the default settings or configure as needed

### Review + Create

10. Click **Review + create**
11. Wait for validation to complete
12. Click **Create**

    ![Screenshot placeholder: AKS cluster deployment in progress]

13. Wait for the deployment to complete (this may take 5-10 minutes)

    ![Screenshot placeholder: AKS deployment completed]

---

---

## Task 4: Connect to AKS Cluster

💡 **Configure kubectl to connect to your AKS cluster using Azure Cloud Shell.**

1. Once deployment is complete, click **Go to resource**
2. In the AKS cluster overview page, click **Connect** in the top menu

   ![Screenshot placeholder: AKS Connect button]

3. Select **Azure CLI** tab
4. Click **Open Cloud Shell**

   ![Screenshot placeholder: Cloud Shell connection instructions]

5. In Cloud Shell, run the provided `az aks get-credentials` command (replace with your values):
   ```bash
   az aks get-credentials --resource-group ${ATTENDEE_ID} --name aks-cvmcluster-<unique-suffix>
   ```

6. Verify the connection:
   ```bash
   kubectl get nodes
   ```

   ![Screenshot placeholder: kubectl get nodes output in Cloud Shell]

---

---

## Task 5: Add Confidential VM Node Pool

💡 **Create a dedicated node pool with Confidential VM compute resources for running sensitive workloads.**

### Using Azure Portal

1. In your AKS cluster page, go to **Settings** > **Node pools** in the left menu

   ![Screenshot placeholder: Node pools menu]

2. Click **+ Add node pool**

   ![Screenshot placeholder: Add node pool button]

3. Configure the confidential node pool:
   - **Node pool name**: `cvmnodepool`
   - **Mode**: **User**
   - **OS SKU**: **Azure Linux** (or **Ubuntu**)
   - **Node size**: Click **Choose a size**
     - In the size selector, search for: `DC2as_v5`
     - Select **Standard_DC2as_v5** (Confidential VM size)
     - Click **Select**

   ![Screenshot placeholder: Select VM size showing DC2as_v5]

4. Configure scale settings:
   - **Scale method**: **Manual**
   - **Node count**: **1**

   ![Screenshot placeholder: Node pool configuration form]

5. Leave other settings as default
6. Click **Add**

   ![Screenshot placeholder: Node pool being added]

7. Wait for the node pool to be created (this may take 5-10 minutes)
8. The status will change from **Creating** to **Succeeded**

   ![Screenshot placeholder: Node pool list showing cvmnodepool]

### Alternative: Using Cloud Shell

If you prefer, you can add the node pool using Cloud Shell:

```bash
az aks nodepool add \
  --resource-group ${ATTENDEE_ID} \
  --cluster-name aks-cvmcluster-<unique-suffix> \
  --name cvmnodepool \
  --node-count 1 \
  --node-vm-size Standard_DC2as_v5
```

---

---

## Task 6: Verify Confidential Node Pool Configuration

💡 **Validate that the Confidential VM node pool is properly configured and running.**

### Using Azure Portal

1. In your AKS cluster, go to **Settings** > **Node pools**
2. Click on **cvmnodepool**
3. Verify the following details:
   - **Node size**: `Standard_DC2as_v5`
   - **Node count**: 1
   - **Status**: Running

   ![Screenshot placeholder: Node pool details page]

### Using Cloud Shell

1. Open Cloud Shell from the top menu bar
2. Run the following commands to verify:

```bash
# Verify the VM size
az aks nodepool show \
  --resource-group ${ATTENDEE_ID} \
  --cluster-name aks-cvmcluster-<unique-suffix> \
  --name cvmnodepool \
  --query 'vmSize'

# Verify the node image version
az aks nodepool list \
  --resource-group ${ATTENDEE_ID} \
  --cluster-name aks-cvmcluster-<unique-suffix> \
  --query "[?name=='cvmnodepool'].nodeImageVersion" -o tsv
```

3. Check the nodes using kubectl:
```bash
kubectl get nodes -o wide
```

You should see two nodes: one from the default node pool and one confidential VM node.

![Screenshot placeholder: kubectl get nodes showing cvmnodepool node]

---

---

## Task 7: Deploy Attestation Verification Pod

💡 **Deploy a sample pod that retrieves attestation data to prove it's running on a confidential VM node.**

### Step 1: Upload the Attestation Pod YAML File

1. The attestation pod YAML file is located at `walkthrough/challenge-5/resources/cvm-attestation-pod.yaml` in this repository.

2. In Azure Cloud Shell, click the **Upload/Download files** button (📁) in the toolbar

3. Select **Upload** and choose the `cvm-attestation-pod.yaml` file from your local machine

4. Wait for the upload to complete - you should see a confirmation message

   ![Screenshot placeholder: Cloud Shell upload button]

### Step 2: Deploy the Pod

5. In Cloud Shell, apply the YAML file:

```bash
kubectl apply -f cvm-attestation-pod.yaml
```

   ![Screenshot placeholder: kubectl apply output]

6. Check the pod status:

```bash
kubectl get pods
```

Wait until the pod status shows **Running**.

![Screenshot placeholder: kubectl get pods showing running status]

---

---

## Task 8: Retrieve and Analyze Attestation Report

💡 **Examine the attestation JWT token to verify the pod is running on genuine confidential hardware.**

1. In Cloud Shell, retrieve the attestation logs:
```bash
kubectl logs cvm-attestation
```

   ![Screenshot placeholder: kubectl logs output showing attestation report]

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
      "keys": [...],
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
    "keys": [...]
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

---

## Task 9: Explore AKS Resources in Azure Portal

💡 **Navigate the Azure Portal to view workloads, logs, and node pool configurations.**

### View Workloads

1. In your AKS cluster page, go to **Kubernetes resources** > **Workloads** in the left menu
2. Click on **Pods** tab
3. You should see the `cvm-attestation` pod listed

   ![Screenshot placeholder: AKS Workloads showing cvm-attestation pod]

4. Click on the pod name to view details

   ![Screenshot placeholder: Pod details page]

### View Logs in Portal

5. In the pod details page, click on **Logs** tab
6. You can view the attestation report directly in the portal

   ![Screenshot placeholder: Pod logs showing attestation report in portal]

### View Node Pool Scaling

7. Go back to **Settings** > **Node pools**
8. Select **cvmnodepool**
9. You can scale the node pool up or down by clicking **Scale**

   ![Screenshot placeholder: Node pool scale options]

---

---

## Task 10: Clean Up Resources

💡 **Delete all resources to avoid ongoing charges.**

### Using Azure Portal

1. Go to **Resource groups** in the Azure Portal
2. Find and select your resource group `${ATTENDEE_ID}`
3. Click **Delete resource group** in the top menu

   ![Screenshot placeholder: Delete resource group button]

4. Type the resource group name to confirm deletion
5. Click **Delete**

   ![Screenshot placeholder: Confirm delete resource group]

6. Wait for the deletion to complete (this may take several minutes)

### Using Cloud Shell

Alternatively, you can delete the resource group using Cloud Shell:

```bash
az group delete --name ${ATTENDEE_ID} --yes --no-wait
```

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

✅ **Preview Features** - Confidential VM support in AKS requires feature registration and may have regional limitations

✅ **Portal and CLI Management** - AKS supports both Azure Portal and Azure CLI for managing confidential node pools

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

- [Azure Confidential Computing](https://azure.microsoft.com/solutions/confidential-compute/)
- [Confidential VMs on Azure](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview)
- [AKS Documentation](https://learn.microsoft.com/azure/aks/)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/)

---

## Troubleshooting Tips

### Node Pool Creation Fails

- Verify that the `AzureLinuxCVMPreview` feature is registered
- Check that the region (North Europe) supports Confidential VM sizes
- Ensure you have sufficient quota for `Standard_DC2as_v5` VMs

### Pod Stays in Pending State

- Check node pool status: `kubectl get nodes`
- Verify node selector matches: `kubectl describe pod cvm-attestation`
- Check for resource constraints: `kubectl describe nodes`

### Cannot Access Cloud Shell

- Ensure your subscription has Cloud Shell enabled
- Check that you have appropriate permissions
- Try using Azure CLI from your local machine instead

### Attestation Report Not Showing

- Verify the pod is running on the confidential node pool
- Check pod logs for errors: `kubectl logs cvm-attestation`
- Ensure the VM size is a Confidential VM SKU (DC-series)

