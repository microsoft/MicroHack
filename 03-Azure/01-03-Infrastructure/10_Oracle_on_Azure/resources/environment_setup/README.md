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

> NOTE: If you are using your own MCAPs Tenant you maybe will need to turn on JIT (Cloud Defender) to be able to SSH into the VM

```
$ ssh -i ~/.ssh/mh-oracle-data-guard  oracle@<PUBLIC_IP_ADDRESS>


# Configure Oracle Data Guard via Ansible

On the compute source running Ubuntu or on Azure Cloud Shell, follow the steps given below:

1. Switch to the oracle subdirectory:

```bash
cd ~/ansible/oracle
```

1. Create a new file called inventory and populate it with the following content. Replace `<hostname>` and `<Public IP address of the Azure VM created via terraform>` with the appropriate values before running the command:

```bash
cat > inventory <<EOF
[ora-x1]
vm-primary-0 ansible_host=<Public IP address of the primary node created via terraform or Bicep>  ansible_ssh_private_key_file=~/.ssh/mh-oracle-data-guard ansible_user=oracle
[ora-x2]
vm-secondary-0 ansible_host=<Public IP address of the secondary node created via terraform or Bicep>   ansible_ssh_private_key_file=~/.ssh/mh-oracle-data-guard ansible_user=oracle
EOF
```

1. Start the ansible playbook

> NOTE: if you need to install ansible on windows follow this instructions:
>
> ~~~powershell
> scoop install pipx
> pipx install --include-deps ansible
> ~~~

```bash
ansible-playbook playbook_dg.yml -i inventory --extra-vars "data_guard=yes"
```

(If you are prompted for "are you sure you want to continue connecting?", enter "yes")

(If using Azure Cloud Shell, remember to refresh your browser by scrolling up or down, every 15 minutes or so since the shell times out after 20 minutes of inaction.)

It is acceptable to see warnings highlighted in red.


1. Once the installation and configuration completes, you will see a screen similar to the one below.

## Download Oracle 19c Installation Binaries
In challenge 2 participants are going to set up a VM in Azure and migrate the database from this simulated on-prem dataguard cluster to Azure. As part of the VM creation
process they will need the installation binaries for Oracle 19c. These can only be downloaded from the oracle web site after authenticating. In this microhack we will provide a storage account within the microhack subscription in order to automate this step during challenge 2. Use the following script to create the storage account. Then, in a second step download the binaries and upload them to the storage account.

Change directory to resources/environment_setup/oracle_binaries within the Oracle microhack.

```bash
# get subscription_id
subscription_id=$(az account show --query id -o tsv)

# search and replace the subscription_id in providers.tf
sed -i "s/subscription_id = \".*\"/subscription_id = \"$subscription_id\"/g" ./providers.tf

terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

>**Please note**: Stick to all default values defined in variables_global.tf because the automation script in challenge 2 walkthrough need to match these values.

The output should look like this:

```bash
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

container_url = "https://mhorabinstoregwc71438.blob.core.windows.net/"
```


Now, click [this link](https://www.oracle.com/database/technologies/oracle19c-linux-downloads.html#license-lightbox) to download the Oracle 19c installation binaries. Pick the 2nd download item named 'LINUX.X64_193000_db_home.zip'. You are redirected to the login page. Provide your Oracle account credentials.
If prompted in a popup, read and accept the license terms and click the download button.
After putting in the password, the download starts automatically.

- When the download has finished open the [Azure portal](https://portal.azure.com) and navigate to the storage account you created with the terraform above. 
- In the storage account tab expand the 'Data storage' section and click on 'Containers'. 
- In the containers list click on the container name 'oracle-bin'.
- Click on the 'Upload' button.
- Click on 'Browse for files'
- In the Open Dialog navigate to your download folder and select the LINUX.X64_193000_db_home.zip file.
- Click the 'Upload' button

Done. The microhack environment has now been successfully set up.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.
