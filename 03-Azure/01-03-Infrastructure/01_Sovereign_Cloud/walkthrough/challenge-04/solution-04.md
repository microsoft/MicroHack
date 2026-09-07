# Walkthrough Challenge 4 - Encryption in use with Azure Confidential Compute – VM

[Previous Challenge Solution](../challenge-03/solution-03.md) - **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-05/solution-05.md)

**Estimated Duration:** 45-60 minutes

> 💡 **Objective:** Validate guest attestation on a pre-provisioned Azure Confidential VM to confirm that workloads execute only in trusted, hardware-backed confidential computing environments. You will inspect the VM's security configuration, connect through Azure Bastion, build and run attestation client applications, and verify cryptographic proof of VM integrity using your dedicated Microsoft Azure Attestation (MAA) provider.

## Prerequisites

Please ensure that you successfully verified the [General prerequisites](../../Readme.md#general-prerequisites) before continuing with this challenge.

- Access to the Azure Portal or Azure CLI
- Lab dashboard credentials (Resource Group Name, Confidential VM, Confidential VM Admin Username, Confidential VM Admin Password, Attestation Provider, Sovereign Lab Bastion)
- **Linux/Bash environment** — Azure Cloud Shell (Bash), WSL2 on Windows, or a native Linux/macOS terminal (for optional CLI steps)
- Basic understanding of Azure Virtual Machines, networking, and confidential computing concepts

## Scenario Context

You are a security architect at a European financial services organization that processes highly sensitive customer data and must comply with strict data sovereignty and protection requirements. Your organization has determined that traditional encryption at rest and in transit is insufficient for protecting high-value workloads.

Your mandate includes:

- **Encryption in Use**: Data must be protected even while being processed, not just when stored or transmitted
- **Hardware-Based Trust**: Security guarantees must be rooted in hardware, not just software configurations
- **Attestation Requirements**: Workloads must verify they are running in a genuine confidential environment before processing sensitive data
- **Zero Trust Architecture**: Never assume trust; always verify the execution environment cryptographically
- **Regulatory Compliance**: Meet stringent requirements for data protection in financial services

In this challenge, you'll implement Azure Confidential Computing using AMD SEV-SNP technology to create a hardware-based Trusted Execution Environment (TEE). You'll configure guest attestation to provide cryptographic proof that your workload is running in a protected environment before it processes any sensitive operations.

### Understanding Guest Attestation

Guest attestation helps you confirm that your confidential VM environment is secured by a genuine hardware-backed Trusted Execution Environment (TEE) with security features enabled for isolation and integrity.

**You can use guest attestation to:**

- **Verify hardware platform** - Confirm the confidential VM runs on expected AMD SEV-SNP hardware
- **Validate secure boot** - Verify secure boot is enabled, protecting firmware, bootloader, and kernel from malware
- **Provide cryptographic evidence** - Obtain JWT tokens proving the VM runs on confidential hardware
- **Prevent data exposure** - Ensure workloads refuse to start in untrusted environments

### Attestation Workflow Pattern

![Scenario diagram](./images/attestation-workflow.png)

In this challenge, you will implement a common pattern where **attestation requests are made from inside the workload** at program startup. The workload verifies that it's running on the correct hardware platform before executing any sensitive business logic.

**How it works:**

1. Your workload starts on the Confidential VM
2. Before processing any sensitive data, the workload calls the attestation library
3. The attestation library contacts Microsoft Azure Attestation (MAA) to verify the TEE environment
4. The workload parses the attestation response (JWT token) to confirm:
   - The VM runs on genuine AMD SEV-SNP confidential hardware
   - Secure boot is enabled and validated
   - The VM guest state is protected
5. Only after successful verification does the workload proceed with sensitive operations

**Why this matters:**

This pattern ensures your application never processes sensitive data in an untrusted environment. If attestation fails (e.g., the code is running on a standard VM or a compromised environment), the workload can refuse to start or handle data differently.

### Learning Resources

- [Azure Confidential Computing overview](https://learn.microsoft.com/azure/confidential-computing/overview)
- [Confidential VM concepts](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview)
- [Guest attestation for confidential VMs](https://learn.microsoft.com/azure/confidential-computing/guest-attestation-confidential-vms)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)

### Original Source Materials

This challenge is based on the **Confidential VM Guest Attestation Sample Application** from the Microsoft Azure Confidential Computing repository:

- **Main Repository**: [Azure Confidential Computing CVM Guest Attestation](https://github.com/Azure/confidential-computing-cvm-guest-attestation)
- **Source Module**: [CVM Attestation Sample App](https://github.com/Azure/confidential-computing-cvm-guest-attestation/tree/main/cvm-attestation-sample-app)

The sample application and deployment patterns have been adapted for this MicroHack challenge to provide a guided learning experience with Azure Confidential VMs.

---

## Task 1: Locate Pre-Provisioned Resources and Verify CVM Security Settings

💡 **The platform has pre-provisioned a private Ubuntu Confidential VM, a shared Azure Bastion, and a custom Attestation Provider in your resource group. Inspect the VM's security configuration before connecting.**

### Pre-Provisioned Resources

Locate the following values on your lab dashboard before proceeding:

| Dashboard Field | Description |
|---|---|
| **Resource Group Name** | Your dedicated resource group containing all lab resources |
| **Sovereign Lab Region** | Azure region where the CVM and Attestation Provider are deployed |
| **Confidential VM** | Name of the pre-provisioned private Ubuntu 22.04 Confidential VM |
| **Confidential VM Admin Username** | Username for Bastion login |
| **Confidential VM Admin Password** | Password for Bastion login |
| **Attestation Provider** | Name of the custom MAA provider (note field contains the full Attest URI) |
| **Sovereign Lab Bastion** | Name of the shared Standard Azure Bastion for private VNet access |

> [!IMPORTANT]
> Copy the **Attestation Provider** Attest URI from the dashboard note field — you will need it in Task 4 when running the attestation client inside the VM.

### Step 1: Verify Confidential VM Security Settings via Azure CLI

```bash
# Set variables from your dashboard
RESOURCE_GROUP="<Resource Group Name from dashboard>"
VM_NAME="<Confidential VM from dashboard>"

# Verify security type, secure boot, and vTPM
az vm show \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --query "{securityType: securityProfile.securityType, secureBootEnabled: securityProfile.uefiSettings.secureBootEnabled, vTpmEnabled: securityProfile.uefiSettings.vTpmEnabled}" \
  -o table
```

Expected output:

```
SecurityType       SecureBootEnabled    VTpmEnabled
-----------------  -------------------  -----------
ConfidentialVM     True                 True
```

### Step 2: Confirm No Public IP Address

```bash
# Verify the VM has no public IP (private access via Bastion only)
az vm list-ip-addresses \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --query "[].virtualMachine.network.publicIpAddresses" \
  -o table
```

The output should be empty — no public IP is assigned to the Confidential VM.

> **Why these settings matter:**
> - `ConfidentialVM` security type activates AMD SEV-SNP hardware memory encryption
> - Secure Boot prevents unauthorized firmware or bootloaders from running
> - vTPM is required for cryptographic attestation
> - No public IP enforces network isolation; all access routes through Azure Bastion

---

## Task 2: Connect to the Confidential VM via Azure Bastion

💡 **Connect to the private Confidential VM through your pre-provisioned Azure Bastion using username/password credentials from your dashboard.**

> [!IMPORTANT]
> The Azure CLI commands in this walkthrough use **bash** syntax and will not work directly in PowerShell. Use **Azure Cloud Shell (Bash)** or a local bash terminal.

### Step 1: Connect via Azure Bastion (Portal)

1. Navigate to the [Azure Portal](https://portal.azure.com)
2. Open your resource group (**Resource Group Name** from your dashboard)
3. Click on the Confidential VM (**Confidential VM** from your dashboard)
4. Click **Connect** > **Connect via Bastion**
5. In the connection panel:
   - **Authentication Type**: `Password`
   - **Username**: value of **Confidential VM Admin Username** from your dashboard
   - **Password**: value of **Confidential VM Admin Password** from your dashboard
6. Click **Connect** — a new browser tab opens with the VM terminal

![Connect via Azure Bastion](./images/vm-connect-via-bastion.png)

> [!NOTE]
> All commands in Tasks 3 and 4 run **inside this VM terminal**, not in Azure Cloud Shell or your local machine.

### Alternative: Connect via Azure CLI Bastion Tunnel

```bash
# Set variables from your dashboard
RESOURCE_GROUP="<Resource Group Name from dashboard>"
VM_NAME="<Confidential VM from dashboard>"
BASTION_NAME="<Sovereign Lab Bastion from dashboard>"
ADMIN_USERNAME="<Confidential VM Admin Username from dashboard>"

# Get the VM resource ID
VM_RESOURCE_ID=$(az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --query id -o tsv)

# Open SSH tunnel via Bastion
az network bastion ssh \
  --name $BASTION_NAME \
  --resource-group $RESOURCE_GROUP \
  --target-resource-id $VM_RESOURCE_ID \
  --auth-type "password" \
  --username $ADMIN_USERNAME
```

---

## Task 3: Install System Dependencies and Attestation Package

💡 **Install the required build tools and attestation library on the Confidential VM.**

> **📝 Note: These commands run ON the Linux VM itself inside the Bastion terminal (not on your local machine or in Azure Cloud Shell)**

> [!NOTE]
> If you encounter prompts to restart services during installation, press `<Enter>` to confirm and continue.

### Step 1: Install System Dependencies and Build Tools

```bash
# Install system dependencies
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none

sudo -E apt-get update -y
sudo -E apt-get upgrade -y

sudo -E apt-get install -y build-essential libcurl4-openssl-dev libjsoncpp-dev libboost-all-dev nlohmann-json3-dev cmake wget git jq
```

💡 **What's Being Installed**:
- Build tools (gcc, g++, make) for compiling C++ attestation client
- Cryptographic libraries (libcurl, jsoncpp) for HTTPS and JSON handling
- Boost libraries for advanced C++ functionality
- CMake for build orchestration
- jq for JSON parsing and token inspection

### Step 2: Clone Attestation Repository

```bash
# Clone the attestation repository
git clone https://github.com/Azure/confidential-computing-cvm-guest-attestation.git
```

### Step 3: Download and Install Azure Guest Attestation Package

```bash
# Download the attestation package
wget https://packages.microsoft.com/repos/azurecore/pool/main/a/azguestattestation1/azguestattestation1_1.1.2_amd64.deb

# Install the attestation package
sudo dpkg -i azguestattestation1_1.1.2_amd64.deb
```

💡 **About the Package**: The `azguestattestation1` package provides the attestation client library that interfaces with the VM's vTPM and Microsoft Azure Attestation service.

---

## Task 4: Build and Execute Attestation Client

💡 **You'll compile the attestation client application and execute it to obtain cryptographic proof of the VM's confidential computing capabilities.**

### Step 1: Build the Attestation Client

Install prerequisites by running these commands:

```bash
sudo apt  install cmake

sudo apt-get update -y && sudo apt-get install -y build-essential

sudo apt-get install -y libcurl4-openssl-dev libjsoncpp-dev libboost-all-dev nlohmann-json3-dev jq
```

### Generate build files

```bash
# Navigate to the sample app directory
cd confidential-computing-cvm-guest-attestation/cvm-attestation-sample-app/

# Generate build files with CMake
cmake .
```

### Compile the application

```bash
make
```

💡 **Build Process**: CMake analyzes dependencies and generates Makefiles, then `make` compiles the C++ source code into the `AttestationClient` executable.

### Step 2: Run Attestation and Inspect JWT Token

To use the dedicated Attestation Provider from your lab dashboard, pass its Attest URI using the `-a` argument.

#### Retrieve Your Attestation Provider URI

Use the **Attestation Provider** URI from your lab dashboard note field:

> On your dashboard, the **Attestation Provider** row shows the provider name as the value and the full Attest URI in the note field (e.g., `https://<name>.<region>.attest.azure.net`).

#### Run attestation with your custom provider (inside the Linux VM)

```bash
# Set the Attestation URI from your dashboard note field
ATTESTATION_URI="<Attestation Provider URI from dashboard note>"
# Run attestation with your custom provider
sudo ./AttestationClient -a $ATTESTATION_URI -o token | jq -R 'split(".") | .[0],.[1] | @base64d | fromjson'
```

![Attestation Client - Specified Provider](./images/attestation-specified-provider.png)

🔑 **Why Use a Custom Attestation Provider?**:
- **Custom Policies**: Define organization-specific attestation policies
- **Audit Control**: Maintain your own attestation logs and policies
- **Compliance**: Meet regulatory requirements for attestation service ownership
- **Isolation**: Separate attestation infrastructure from shared services

### Step 3: Understand the Attestation Token

The JWT token contains multiple claims that cryptographically prove the VM's security posture:

**Key Claims to Review**:

- `x-ms-isolation-tee.x-ms-attestation-type` - Should show `sevsnpvm` (AMD SEV-SNP)
- `x-ms-isolation-tee.x-ms-compliance-status` - Should show `azure-compliant-cvm`
- `x-ms-isolation-tee.x-ms-sevsnpvm-is-debuggable` - Should be `false` (debugging disabled for security)
- `x-ms-policy-hash` - Hash of the attestation policy used
- `secureboot` - Should be `true`
- `x-ms-ver` - Attestation service version

🔑 **Security Insight**: This JWT token is signed by Microsoft Azure Attestation. Any relying party can verify the signature to confirm the claims are authentic and the VM is running in a genuine confidential environment.

---

## Task 5: Implement Attestation-Based Workload Protection (Conceptual)

💡 **Understanding how to use attestation in production applications to enforce "only execute in confidential environment" policies.**

### Production Implementation Pattern

In a production scenario, your application would implement attestation checks before processing sensitive data (this is just an example for inspiration, do not run this on the Linux server):

```python
# Pseudocode - Production attestation pattern
def process_sensitive_data(customer_data):
    # Step 1: Perform attestation
    attestation_token = get_attestation_token()

    # Step 2: Validate token with relying party
    if not validate_attestation(attestation_token):
        log_error("Attestation failed - not running in confidential environment")
        raise SecurityException("Execution environment not trusted")

    # Step 3: Verify specific claims
    claims = parse_jwt_claims(attestation_token)
    if claims['x-ms-isolation-tee.x-ms-attestation-type'] != 'sevsnpvm':
        raise SecurityException("Not running on AMD SEV-SNP hardware")

    if claims['x-ms-isolation-tee.x-ms-sevsnpvm-is-debuggable'] == 'true':
        raise SecurityException("VM debugging is enabled - security risk")

    # Step 4: Only now proceed with sensitive operations
    encrypted_results = process_pii_data(customer_data)
    return encrypted_results
```

### Use Cases for Attestation-Based Protection

1. **Financial Services**: Verify trading algorithms run only in hardware-protected environments
2. **Healthcare**: Ensure patient data processing occurs only in attested confidential VMs
3. **Government**: Validate classified workloads execute in compliant infrastructure
4. **Multi-Party Computation**: Prove to partners that shared data is processed securely

🔑 **Best Practice**: Attestation should be performed at application startup and periodically during long-running workloads to detect runtime tampering.

---

## Key Takeaways

In this challenge, you successfully implemented and validated Azure Confidential Computing with guest attestation. Here are the key concepts and best practices:

### Confidential Computing Fundamentals

✅ **Hardware-Based Trust** - AMD SEV-SNP provides hardware-level memory encryption that protects data in use, not just at rest or in transit

✅ **Trusted Execution Environments (TEEs)** - Confidential VMs create isolated environments where even the cloud operator cannot access your data

✅ **Virtual TPM (vTPM)** - Enables cryptographic attestation and secure boot validation

### Attestation and Verification

✅ **Guest Attestation** - Cryptographically proves that workloads run in genuine confidential computing environments before processing sensitive data

✅ **Microsoft Azure Attestation (MAA)** - Provides centralized attestation services that validate TEE integrity and issue signed JWT tokens

✅ **Zero Trust Validation** - Applications should verify execution environment before processing sensitive operations

### Security Architecture

✅ **Defense in Depth** - Combining multiple security layers (no public IPs, Azure Bastion, hardware encryption, attestation)

✅ **Custom Attestation Provider** - A dedicated MAA provider enables organization-specific policies, audit logs, and compliance requirements separate from shared services

✅ **Network Isolation** - Confidential VM has no public IP; all access routes through Azure Bastion with lab-scoped credentials

### Production Best Practices

✅ **Attestation at Startup** - Perform attestation checks before processing any sensitive data

✅ **Periodic Re-attestation** - Long-running workloads should re-attest periodically to detect runtime tampering

✅ **JWT Token Validation** - Verify attestation tokens are signed by trusted authorities and contain expected claims

✅ **Fail Securely** - Applications should refuse to start or handle data differently if attestation fails

### Compliance and Governance

✅ **Data Sovereignty** - Confidential computing ensures data remains encrypted even from cloud operators

✅ **Regulatory Requirements** - Meets stringent requirements for financial services, healthcare, and government workloads

✅ **Audit Trail** - Attestation tokens provide cryptographic proof for compliance auditing

---

## Next Steps

### Explore Advanced Confidential Computing Scenarios

- **[Azure Confidential Containers](https://learn.microsoft.com/azure/confidential-computing/confidential-containers)** - Deploy containerized workloads with hardware-based confidential computing
- **[Confidential VMs with Customer-Managed Keys](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview#encryption-at-host-with-customer-managed-keys)** - Use your own encryption keys for additional control
- **[Confidential Computing on Azure Kubernetes Service](https://learn.microsoft.com/azure/aks/confidential-computing-azure)** - Orchestrate confidential containers at scale

### Implement Application-Level Confidential Computing

- **[Enclave Applications](https://learn.microsoft.com/azure/confidential-computing/application-development)** - Build applications that use Intel SGX or AMD SEV-SNP enclaves
- **[Confidential Inferencing](https://learn.microsoft.com/azure/machine-learning/how-to-machine-learning-confidential-containers)** - Protect ML models and data during inference
- **[Always Encrypted](https://learn.microsoft.com/sql/relational-databases/security/encryption/always-encrypted-database-engine)** - Combine confidential computing with SQL Server encryption

### Learn More About Azure Security

- **[Azure Security Benchmark for Confidential Computing](https://learn.microsoft.com/security/benchmark/azure/baselines/confidential-computing-security-baseline)** - Follow Microsoft's security recommendations
- **[Azure Confidential Ledger](https://learn.microsoft.com/azure/confidential-ledger/overview)** - Tamper-proof, immutable ledger for audit logs
- **[Microsoft Azure Attestation Documentation](https://learn.microsoft.com/azure/attestation/overview)** - Deep dive into attestation concepts and policies

### Practice Confidential Computing Patterns

- **Multi-Party Computation** - Build scenarios where multiple organizations jointly process data without exposing it to each other
- **Confidential AI** - Implement ML training and inference in confidential environments
- **Secure Enclaves** - Explore Intel SGX for process-level isolation within VMs

---

## Additional Resources

- [Azure Confidential Computing overview](https://learn.microsoft.com/azure/confidential-computing/overview)
- [Confidential VM concepts](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview)
- [Guest attestation for confidential VMs](https://learn.microsoft.com/azure/confidential-computing/guest-attestation-confidential-vms)
- [Microsoft Azure Attestation](https://learn.microsoft.com/azure/attestation/overview)
- [AMD SEV-SNP Technology](https://www.amd.com/en/developer/sev.html)
- [Azure Bastion Documentation](https://learn.microsoft.com/azure/bastion/bastion-overview)

---

## Technical Notes

1. **Security**: Confidential VM has no public IP; all access routes through Azure Bastion
2. **Credentials**: Use the username and password from your lab dashboard for Bastion login
3. **Attestation URI**: Copy the Attest URI from the dashboard note field — it follows the pattern `https://<name>.<region>.attest.azure.net`
4. **Regional Fallback**: The Attestation Provider is deployed with regional fallback; the URI region code reflects the actual deployment region
