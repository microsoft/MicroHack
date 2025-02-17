## Challenge 1 - Prerequisites and landing zone preparation

### Goal 🎯

In challenge 1, you will understand and prepare your environment with the needed infrastructure to enable business continuity with Cloud Native / PaaS Services on Azure.

Below an architecure diagram displays the setup. Tutorials and documentation that provide step-by-step guidance on how to deploy the environment comes along.

---

# Lab Environment with Virtual Machines

![Architecture](../img/asrdemo%20architecture.png)

### Deployment

There are **two different ways** to deploy the lab environment. The first is using ARM via **Deploy to Azure-Button** and the second is to use the provided **ARM** or **Bicep** scripts. The ARM method is the preferred method as it is faster and more reliable. However, if you are not familiar with IaaS deployment, you can use the Azure Portal method.

#### ARM Deployment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdemirsenturk%2FHA-multi-region-application%2Frefs%2Fheads%2Fmain%2Fdeploy.json)

Choose the same **resource Group** as the N-tier Application.

#### Terraform Method

To deploy the lab environment using **terraform**, click the link below.

- [Deploy to Azure (terraform)](./resources/terraform/README.md)

### Actions

Create all necessary Azure resources
* Region 1: Germany West Central (Source enviroment)
  * Resource Group: mh-bcdr-gwc-rg<your assigned number>
  * Recovery Services Vault: mh-rsv-gwc
  * Storage Account with GRS (geo-redundant storage) redundancy option: mhstweu\<Suffix\>
* Region 2: Sweden Central (Target environment)
  * Resource Group: mh-bcdr-sc-rg<your assigned number>
  * Recovery Services Vault: mh-rsv-sc


### Success Criteria ✅

* You've created Resource Groups in both regions (Germany West Central & Sweden Central).
* Recovery Services Vaults have been created in both regions.
* A geo-redundant Storage Account has been created.

### 📚 Learning Resources

* [Manage resource groups - Azure Portal - Azure Resource Manager | Microsoft Learn](https://learn.microsoft.com/azure/azure-resource-manager/management/manage-resource-groups-portal)
* [Create a storage account - Azure Storage | Microsoft Learn](https://learn.microsoft.com/azure/storage/common/storage-account-create)
* [Create and configure Recovery Services vaults - Azure Backup | Microsoft Learn](https://learn.microsoft.com/azure/backup/backup-create-recovery-services-vault)


### Solution - Spoiler Warning ⚠️

[Solution Steps](../walkthrough/challenge-1/solution.md)

---

**[> Next Challenge 2 - Protect in Azure - Backup / Restore](./02_challenge.md)** |

**[< Previous Challenge 0 - 🚀 Deploying a Ready-to-Go N-tier App with Awesome Azure Developer CLI](./00_challenge.md)** 
