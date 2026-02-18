# Challenge 3 - Encryption in transit: enforcing TLS

[Previous Challenge Solution](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-04.md)

## Goal

Understand encryption in transit considerations for sovereign scenarios. Configure Azure Storage accounts to require secure transfer (HTTPS only) and enforce TLS 1.2 as the minimum protocol version. Apply Azure Policy to block weaker TLS versions and monitor client protocol usage through Log Analytics.

## Actions

* Understand Encryption in transit
* Understand TLS versions & recommendation
* Hands-on: Azure Blob Storage - require secure transfer (HTTPS only) in Azure Portal
* Hands-on: Enforce minimum TLS version with Azure Policy
* Validation: detect TLS versions used by clients (Log Analytics/KQL)

## Success criteria

* Storage accounts reject HTTP requests and enforce HTTPS (secure transfer required).
* Policy compliance shows all storage accounts with Minimum TLS Version = TLS 1.2.
* Log Analytics reports no requests using TLS 1.0/1.1 in the past 7 days (or policy denies/blocks them).

## Learning resources

* [Azure encryption overview](https://learn.microsoft.com/en-us/azure/security/fundamentals/encryption-overview)
* [Require secure transfer (HTTPS only) for Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-require-secure-transfer)
* [Enforce a minimum required TLS version for Storage](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version)
* [Azure Resource Manager TLS support](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tls-support)
* [Policy: Storage accounts should have the specified minimum TLS version](https://learn.microsoft.com/en-us/azure/storage/common/transport-layer-security-configure-minimum-version?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json&tabs=portal#detect-the-tls-version-used-by-client-applications)

