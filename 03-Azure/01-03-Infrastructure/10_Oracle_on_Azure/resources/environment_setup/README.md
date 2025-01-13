# Step-by-step Instructions how to Deploy Oracle Data Guard on Azure VMs - Terraform Automation

## Overview

This repository contains code to install and configure Oracle databases on Azure VM IaaS in an automated fashion. The scenario of two VMs in an Oracle Dataguard configuration, deployed through Terraform  (TODO: and Ansible).

For more information about how to install and configure Data Guard on an Azure virtual machine (VM) with CLI refer to the documentation [here](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/oracle-dataguard).

__Important Note - Disclaimer__: The code of this repository is largely based on the Oracle Deployment Automation repository (lza-oracle), which can be found [here](https://github.com/Azure/lza-oracle). The goal of the Terraform automation scripts in this repository is primarily to facilitate the successful execution of the Microhack. The code in this repository is not intended for production use and should be used with caution.
At the lza-oracle repository, you can find the code for deploying Oracle databases on Azure VMs using different scenarios, such as single and Dataguard using Terraform, Bicept and Ansible.
If you are interested in deploying Oracle databases on Azure VMs, we recommend you to check the [lza-oracle](https://github.com/Azure/lza-oracle) repository.

Note that Oracle licensing is not a part of this solution. Please verify that you have the necessary Oracle licenses to run Oracle software on Azure IaaS.


The above resources can be deployed using the sample Github action workflows provided in the repository. The workflows are designed to deploy the infrastructure and configure the Oracle database on the VMs. This is the recommended way to deploy the infrastructure and configure the Oracle database. Alternatively the infrastructure can be deployed using Azure CLI and the Oracle database can be configured using Ansible.

Note that the code provided in this repository is for demonstration purposes only and should not be used in a production environment without thorough testing.

## Prerequisites

1. Azure Entra ID Tenant.
2. Minimum 1 subscription, for when deploying VMs. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/en-us/free/?ref=microsoft.com&utm_source=microsoft.com&utm_medium=docs&utm_campaign=visualstudio) before you begin.
3. Azure CLI installed on your local machine. You can install Azure CLI from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
4. Terraform installed on your local machine. You can install Terraform from [here](https://learn.hashicorp.com/tutorials/terraform/install-cli).


## 1. Authenticate Terraform to Azure

To use Terraform commands against your Azure subscription, you must first authenticate Terraform to that subscription. [This doc](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure?tabs=bash) describes how to authenticate Terraform to your Azure subscription.

### 2. Create SSH Key

To deploy Oracle Data Guard on the VMs, you can use **data_guard** module in this repo. The module is located on `terraform/data_guard` directory.

Before using this module, you have to create your own ssh key to deploy and connect to the two virtual machines you will create.

```bash
ssh-keygen -f ~/.ssh/mh-oracle-data-guard

ls -lha ~/.ssh/
-rw-------   1 yourname  staff   2.6K  8 17  2023 mh-oracle-data-guard
-rw-r--r--   1 yourname  staff   589B  8 17  2023 mh-oracle-data-guard.pub
```

### 4. Define Variables

Define the variables such as location and Resource Group name in the `global_variables.tf` file. For more reference on all variables you can set, see [variables description](variables.md)

Next, you go to `terraform/data_guard` directory and create `fixtures.tfvars` file, then copy the contents of the ssh public key used for deploying virtual machines on Azure (~/.ssh/mh-oracle-data-guard.pub).

This is a sample `fixtures.tfvars` file. 

```tf:fixtures.tfvars
ssh_key = "ssh-rsa xxxxxxxxxxxxxx="
```
### 5. Execute Terraform Commands
Execute below Terraform commands. When you deploy resources to Azure, you have to indicate `fixtures.tfvars` as a variable file, which contains the ssh public key.

```bash

$ terraform init

$ terraform plan -var-file=fixtures.tfvars

$ terraform apply -var-file=fixtures.tfvars
```

You can connect to the virtual machine with ssh private key. While deploying resources, a public ip address is generated and attached to the virtual machine, so that you can connect to the virtual machine with this IP address. The username is `oracle`, which is fixed in `terraform/data_guard/module.tf`.

```
$ ssh -i ~/.ssh/mh-oracle-data-guard  oracle@<PUBLIC_IP_ADDRESS>



## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.
