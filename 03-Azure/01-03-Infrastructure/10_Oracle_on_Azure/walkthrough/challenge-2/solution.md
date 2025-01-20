# Walkthrough Challenge 2 - Oracle to IaaS migration

Duration: 20 minutes

## Prerequisites

- Please ensure that you successfully verified the [General prerequisits](../../Readme.md#general-prerequisites) before continuing with this challenge.
- For this walkthrough solution you will need a bash shell with the following:
  - [Terraform](https://developer.hashicorp.com/terraform/install) 
  - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)

### **Task 1: Determine the most cost efficient SKUs for compute and storage**

💡 The first....

💥 **Here are the first three general steps that are typically happen:** 
1. Everybody struggles with finding the right person....
2. If somebody finds the plan, the first three actions...
3. Do not sress to much we have a...

🔑 **Key to a successful strategy....**
- The key to success is not a technical consideration of....

### **Task 2: Deploy the Azure VM**

In the folder [resources/challenge-2/terraform](../../resources/challenge-2/terraform/) you find a terraform template which deploys the following resources:

| resource       | name                    |    description                                      |
|----------------|-------------------------|-----------------------------------------------------|
| resource group | var.resource_group_name | the target resource group for the deployment        |
| virtual network| local.vnet_name         | "${var.vm_name}-vnet"                               |
| subnet         | local.subnet_name       | "${var.vm_name}-subnet"                             |
| nic            | local.nic_name          | "${var.vm_name}-nic"                                |
| managed disk(s)| var.data_disk_config    | all disks are of type PremiumV2_LRS. Size, IOPS and throuput can be configured in variables.tf. You can change the number of disks if needed. Example values are provided |
| virtual machine| var.vm_name             | the name of your virtual machine                    |

Required input parameters:

| parameter           | default value           | effect                                              |
|----------------     |-------------------------|-----------------------------------------------------|
| location            | germanywestcentral      | the region where the resources will get deployed to |
| resource_group_name | challenge-1             | you need to add a unique prefix (i.e. your user name) here during the microhack to avoid conflicts with other participants                                  |
| availability_zone   | 1                       | required parameter because managed disks of type PremiumV2_LRS support zonal deployment only, hence we need to specify this value                      |
| vm_name             | ora-vm                  | name of the vm. Will be used as prefix for other resources as depicted in the table above                                                              |
| vm_size             | Standard_E2bds_v5       | Change this to the most cost efficient value for your migrated database                                                                                     |
| vm_username         | local linux login name  | adminuser                                           |
| path_to_ssh_key_file| ~/.ssh/lza-oracle-single-instance.pub | path to your public key file for SSH login. **Note: You need to create your own key!**                                                     |
| data_disk_config    | 
    data_disk = {
      name      = "data_disk"   # name of disk 1 
      size_gb   = 128           # size of disk 1
      iops      = 5000          # provisioned iops of disk 1
      throughput = 150          # provisioned throuput of disk 1
      caching   = "None"        # PremiumV2_LRS disks to not support host caching at the time of writing. 
                                # Hence, do not change the caching value.
    }
    asm_disk = {
      name      = "asm_disk"    # name of disk 2
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }
    redo_disk = {
      name      = "redo_disk"   # name of disk 3
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }

🔑 **Note: The objective of this challenge is to learn how to use the most cost efficient SKU combination for compute and disks. Therefore, you should not go with the provided default values for vm_size and data_disk, but use the most cost efficient SKUs which will fullfil your performance requirements!**

Here are the detailed steps for the deployment:

1. Create a key pair for SSH login:

```bash
ssh-keygen -f ~/.ssh/oracle_vm_rsa_id
``` 
If successfully created, there should be now to new files in your home directories .ssh subfolder:

```bash
ls -la ~/.ssh/

-rw-------  1 <username> 2655 Jan 15 14:52 oracle_vm_rsa_id
-rw-r--r--  1 <username>  574 Jan 15 14:52 oracle_vm_rsa_id.pub
``` 

2. Clone the repository if not done already to the system you are using your shell and change directory to the folder where you have cloned the terraform files for challenge 1. Validate that you are in the correct folder. The output of ls -la should look like this.

```bash
cd  <replace/with/your/local/terraform/path>

ls -la
total 76
drwxrwxrwx 1 <username>  4096 Jan 15 18:22 .
drwxrwxrwx 1 <username>  4096 Jan 15 14:55 ..
-rwxrwxrwx 1 <username>    36 Jan 15 15:34 backend.tf
-rwxrwxrwx 1 <username>   265 Jan 15 16:26 locals.tf
-rwxrwxrwx 1 <username>   544 Jan 15 15:33 providers.tf
-rwxrwxrwx 1 <username> 22128 Jan 15 18:22 terraform.tfstate
-rwxrwxrwx 1 <username> 19010 Jan 15 18:21 terraform.tfstate.backup
-rwxrwxrwx 1 <username> 14299 Jan 15 18:21 tfplan
-rwxrwxrwx 1 <username>  1759 Jan 16 09:52 variables.tf
-rwxrwxrwx 1 <username>  3417 Jan 15 18:09 vm.tf
``` 

3. Init your terraform

```bash
terraform init
``` 
You should see something like the following output:
```bash
Initializing the backend...
Initializing provider plugins...
- Reusing previous version of hashicorp/azurerm from the dependency lock file
- Using previously-installed hashicorp/azurerm v3.117.0

Terraform has been successfully initialized!
```

4. Change the parameters where your find such comments in variables.tf with your preferred editor:

```terraform
variable "location" {
  description = "The Azure region where the resources will be deployed"
  type        = string
  # In the microhack subscription there is a deployment limit of 10 cores per VM type per region.
  # Please align with your coach what region you should use to avoid hitting the limit.
  default     = "germanywestcentral"  
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "challenge-1" # you should add a unique prefix (i.e. your name) here to avoid name collisions with your co-participants
}

variable "vm_size" {
  description = "The size of the virtual machine"
  type        = string
  default     = "Standard_E2bds_v5" # change this according the the sizing determined in the previous challenge
}

variable "path_to_ssh_key_file" {
  description = "The path to the SSH public key file"
  type        = string
  default     = "~/.ssh/oracle_vm_rsa_id.pub" # only change this if you used another path or name for your key file.
}

# change the size, IOPS and throughput of each disk according to the requirements.
# Please note: It's recommended to separate at least the disks or database files, redo logs and other files.
variable "data_disk_config" {
  description = "The configuration for the data disks"
  type        = map(object({
    name      = string
    size_gb   = number
    iops      = number
    throughput = number
    caching = string
  }))
  default = {
    data_disk = {
      name      = "data_disk"
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }
    asm_disk = {
      name      = "asm_disk"
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }
    redo_disk = {
      name      = "redo_disk"
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }
  }
}
```

5. Deploy your Azrue resources

```bash
terraform plan -out=tfplan
```

Verify the deployment plan or adjust parameter values in case you encounter errors

```bash
terraform apply tfplan
```
Wait for the resources to get created. This may take several minutes.

### **Task 3: Put yourself in the position...**

* [Checklist Testing for...](Link to checklist or microsoft docs)

### Task 4: Who defines the requirements...


![image](Link to image)


You successfully completed challenge 1! 🚀🚀🚀

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-2/solution.md)