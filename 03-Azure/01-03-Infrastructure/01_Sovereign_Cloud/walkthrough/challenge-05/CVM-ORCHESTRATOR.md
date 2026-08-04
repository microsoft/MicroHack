# Confidential VM Orchestrator: when it is required

This supplement explains the Microsoft-owned **Confidential VM Orchestrator**
enterprise application and, equally importantly, when it is not involved.

## The short answer

- Challenge 5 does not use Confidential VM Orchestrator. It creates an AKS node
  pool on Confidential VM sizes and uses the platform-managed AKS provisioning
  path.
- Challenge 5.5 uses Confidential VM Orchestrator because it creates a standalone
  Confidential VM with confidential OS disk encryption backed by a
  customer-managed key (CMK).
- Microsoft documents tenant opt-in of this service principal for confidential
  disk encryption with a CMK.
- The application ID is Microsoft-owned:
  `bf7b6499-ff71-4aa2-97a4-f372087be7f0`.
- Creating the service principal only makes that Microsoft application known in
  the tenant. Access to a key is granted separately and should be least
  privilege.

## For a business reader

### The problem being solved

A customer-managed key gives an organization control over whether an encrypted
OS disk can be unlocked. That control is valuable only if Azure can create and
start the Confidential VM without turning the key into a broadly available
platform secret.

The provisioning process therefore needs a recognizable, narrowly authorized
identity to participate in the confidential disk key-release workflow. The
Confidential VM Orchestrator enterprise application is that Microsoft-owned
service identity in the customer's tenant.

A useful analogy is a named, audited courier. The organization keeps the key in
its vault. It explicitly recognizes the courier and gives it only the actions
needed for the delivery. The courier does not own the vault and does not receive
permission merely because it exists.

### Business value

This design provides:

- explicit tenant consent before the Microsoft service identity can be used;
- a named identity for access reviews and audit records;
- separation between the human deploying the VM and the service completing the
  confidential provisioning operation;
- least-privilege access to retrieve and release protected key material;
- automation without distributing a reusable user credential or client secret.

### What happens without it

If the tenant has not registered the service principal, Azure cannot assign the
required Key Vault permission to that identity. The CMK-backed confidential OS
disk provisioning path cannot complete.

Granting broad access to users or applications as a workaround would weaken the
reason for using a customer-managed key. The correct remediation is the one-time
registration by an authorized Entra administrator, followed by narrowly scoped
Key Vault authorization.

## For a technical reader

### Enterprise application versus application registration

The application is published and owned by Microsoft. The tenant-local service
principal, shown in Entra as an enterprise application, is the local identity
object for that application.

Running `New-MgServicePrincipal` with the fixed Microsoft application ID does
not create new application code or transfer ownership to the attendee. It opts
the tenant into recognizing the Microsoft application. This is normally a
one-time tenant operation and requires privileged Microsoft Graph permission.

Registration alone grants no Key Vault data access. Challenge 5.5 separately
adds a vault access policy granting the service principal `get` and `release`.

### Why Challenge 5.5 needs it

Challenge 5.5 selects all of these options together:

- standalone AMD SEV-SNP Confidential VM;
- confidential OS disk encryption;
- `ConfidentialVmEncryptedWithCustomerKey` disk encryption set;
- HSM-backed customer-managed key with an attestation release policy.

Azure's confidential provisioning path must obtain the protected disk key under
the release conditions so the confidential OS disk can be prepared and made
available to the attested VM. Microsoft documents Confidential VM Orchestrator
registration and Key Vault `get`/`release` permissions for this CMK scenario.

The high-level flow is:

1. The tenant recognizes the Microsoft-owned Orchestrator service principal.
2. Key Vault holds the HSM-backed disk key and its release policy.
3. The Orchestrator has only the Key Vault operations required by the
   confidential disk provisioning workflow.
4. The disk encryption set references the versioned customer-managed key.
5. Azure validates the confidential platform state and performs secure key
   release as part of VM creation.
6. The confidential OS disk is bound to the VM's protected state and vTPM.

The service principal is retained during Challenge 5.5 cleanup because it is a
shared tenant-level identity, not a resource owned by one attendee deployment.
Per-deployment Key Vault access disappears when that lab vault is removed.

### Why Challenge 5 does not need it

Challenge 5 adds an AKS node pool using a Confidential VM SKU. AKS and Azure
Compute manage that node-pool provisioning path. The challenge does not create a
customer-managed confidential disk encryption set or grant a disk key to
Confidential VM Orchestrator.

A successful AKS confidential node pool therefore does not prove that the
tenant-local Orchestrator service principal exists. Conversely, registering the
Orchestrator is not required to attest a pod running on those nodes.

### Do not confuse the identities

Challenge 5.5 uses several identities for different trust boundaries:

| Identity | Purpose in Challenge 5.5 |
|----------|--------------------------|
| Confidential VM Orchestrator | Microsoft service identity for the CMK-backed confidential OS disk provisioning path; receives `get` and `release`. |
| Disk Encryption Set managed identity | Connects the disk encryption set to its Key Vault key; receives key operations used by the disk encryption integration. |
| VM user-assigned managed identity | Workload identity used by the running VM to request the separate application Secure Key Release key. |
| Human attendee | Creates resources through Azure Resource Manager; does not become the runtime workload identity. |

These identities are deliberately separate. Passing hardware attestation does
not grant application authorization, and possessing a workload identity does
not prove that code is running inside a healthy Confidential VM.

### Is it required for every Confidential VM?

No. The requirement discussed here is tied to confidential OS disk encryption
using a customer-managed key. A Confidential VM can use other supported disk
protection choices, including platform-managed keys, or can be created without
confidential OS disk encryption where supported. Those choices have different
provisioning and key-management requirements.

## Operational guidance

- Treat service-principal registration as a one-time tenant prerequisite.
- Verify the fixed Microsoft application ID before granting access.
- Grant only the documented key operations and scope them as narrowly as the
  chosen Key Vault authorization model permits.
- Do not delete the enterprise application during attendee cleanup; another
  deployment in the tenant might depend on it.
- Do not use attendee credentials or a custom client secret as a substitute.

## Official references

- [Create a Confidential VM with a CMK using Azure CLI](https://learn.microsoft.com/azure/confidential-computing/quick-create-confidential-vm-azure-cli#create-confidential-virtual-machine-using-a-customer-managed-key)
- [Deploy a Confidential VM with a CMK using an ARM template](https://learn.microsoft.com/azure/confidential-computing/quick-create-confidential-vm-arm#deploy-confidential-vm-template-with-os-disk-confidential-encryption-via-customer-managed-key)
- [Create a Confidential VM in the Azure portal](https://learn.microsoft.com/azure/confidential-computing/quick-create-confidential-vm-portal)
- [Confidential VM and confidential OS disk encryption overview](https://learn.microsoft.com/azure/confidential-computing/confidential-vm-overview#confidential-os-disk-encryption)
