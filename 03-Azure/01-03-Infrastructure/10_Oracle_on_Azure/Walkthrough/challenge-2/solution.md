# Walkthrough Challenge 2 - Oracle to IaaS migration

Duration: 45 minutes

## Prerequisites

- Please ensure that you successfully verified the [General prerequisits](../../Readme.md#general-prerequisites) before continuing with this challenge.
- For this walkthrough solution you will need a bash shell with the following tools/packages installed:
  - [Terraform](https://developer.hashicorp.com/terraform/install) 
  - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)
  - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu)
- The AWR files in html format generated in challenge 1

### **Task 1: Determine the most cost efficient SKUs for compute and storage**

💡 Task 1 is still work in progress....



🔑 **Key to a successful strategy....**
- Use [this tool](https://github.com/Azure/Oracle-Workloads-for-Azure/tree/main/levelup-oracle-on-iaas/lab1) to analyze AWR/STATSPACK reports and generate recommendation for compute and storage SKUs to match your performance requirements.

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
      caching   = "None"        # PremiumV2_LRS disks do not support host caching at the time of writing. 
                                # Hence, do not change the caching value.
    }
    redo_disk = {
      name      = "redo_disk"   # name of disk 3
      size_gb   = 128
      iops      = 5000
      throughput = 150
      caching   = "None"
    }

🔑 ***Note:** The objective of this challenge is to learn how to use the most cost efficient SKU combination for compute and disks. Therefore, you should not go with the provided default values for vm_size and data_disk, but use the most cost efficient SKUs which will fullfil your performance requirements!**

Here are the detailed steps for the deployment:

1. Create a key pair for SSH login:

TODO: rework to use keys from Keyvault provided by environment setup

```bash
ssh-keygen -f ~/.ssh/mh-oracle-data-guard
``` 
If successfully created, there should be now to new files in your home directories .ssh subfolder:

```bash
ls -la ~/.ssh/

-rw-------  1 <username> 2655 Jan 15 14:52 mh-oracle-data-guard
-rw-r--r--  1 <username>  574 Jan 15 14:52 mh-oracle-data-guard.pub
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
  default     = "challenge-2" # you should add a unique prefix (i.e. your name) here to avoid name collisions with your co-participants
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
# Please note: It's recommended to separate at least the disks for database files and redo logs.
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
Save the changes you made.

5. Deploy your Azure resources

```bash
terraform plan -out=tfplan
```

Verify the deployment plan or adjust parameter values in case you encounter errors

```bash
terraform apply tfplan
```
Wait for the resources to get created. This takes - including the post installation script - approx. 10min. When the deployment finished, note the public IP address of the VM and copy it for use in the next task.

### **Task 3: Configure Oracle DB single instance via Ansible**

Next, we need to configure the OS of the VM and install the Oracle 19c binaries.

1. Switch to the ansible bootstrap subdirectory for oracle:

```bash
cd <THIS_REPO>/03-Azure/01-03-Infrastructure/10_Oracle_on_Azure/resources/challenge-2/ansible/bootstrap/oracle
```

Open the inventory file and replace the \<Public IP address of Azure vm created earlier> with the public ip of your Azure vm and save it. Next start the ansible playbook:
```bash
ansible-playbook -i ./inventory playbook.yml
```
The ansible playbook will configure the guest OS of the created VM and download and install oracle 19c binaries. There will be no instance/database created.
This will be done manually via RMAN RESTORE.

🔑 ***Note:** The ansible playbook takes ~10min to finish.** 

### Task 4: Backup onprem database and restore it on Azure VM using RMAN

🔑 ***HINT:** In this task you need to work on the primary vm and the target vm via ssh sessions. It's recommended to open an ssh shell for each vm and keep both open to easily switch between the two vms.*

In order to connect to the vm-primary-0 we first need to open the ssh port. 
- In the Azure portal navigate to the vm
- Expand section "Networking" and click Network settings
- Click Create port rule button and select inbound port rule
- In Service dropdown list choose SSH
- In priority text box enter 100
- Click Add button

We also need to have connectivity via Oracle port 1521, so repeat the steps above to create another inbound port rule, but give it priority 101.

🔑 ***Note:** Do not open these ports in your production environment to the internet. Rather use private network connectivity and open ports only to required client ip addresses!*

Connect to the **primary onprem Oracle vm**. 

```bash
ssh -i ~/.ssh/mh-oracle-data-guard oracle@<replace-with-vm-primary-puplic-ip>

# open tnsnames.ora
vim $ORACLE_HOME/network/admin/tnsnames.ora
```
Append the following tns entry to the file:
```
ORCL_stby =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = <replace-w-ora-vm-public-ip>)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SID = ORCL)
    )
  )
```
Start the listener:
```bash
lsnrctl stop 
lsnrctl start
```

Connect to the **ora-vm in Azure**:

```bash
ssh -i ~/.ssh/mh-oracle-data-guard oracle@<replace-with-ora-vm-public-ip>

# check whether all oracle environment vars have been created correctly via ansible
echo $ORACLE_HOME  
/u01/app/oracle/product/19.3.0/dbhome_1
echo $ORACLE_BASE 
/u01/app/oracle
echo $ORACLE_SID 
ORCL

mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/pdbseed
mkdir -p $ORACLE_BASE/oradata/$ORACLE_SID/pdb1
mkdir -p $ORACLE_BASE/oradata/fra
mkdir -p $ORACLE_BASE/admin/$ORACLE_SID/adump
mkdir -p $ORACLE_BASE/fast_recovery_area/$ORACLE_SID
```

Edit or create the tnsnames.ora file, which is in the $ORACLE_HOME/network/admin folder.

```
ORCL =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = <replace-w-primary-onpre-vm-public-ip>)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SID = ORCL)
    )
  )
ORCL_stby =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ora-vm)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SID = ORCL)
    )
  )
```

Edit or create the listener.ora file, which is in the $ORACLE_HOME/network/admin folder.

```
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ora-vm)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ORCL_DG22    (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = ORCL)
    )
  )
```
Start the listener:
```bash
lsnrctl stop
lsnrctl start
```

Create the parameter file /tmp/initORCL_stby.ora with the following contents:
```bash
*.db_name='ORCL'
```

Create a password file:
```bash
$ orapwd file=$ORACLE_HOME/dbs/orapwORCL password=Oracle123.? entries=10 force=y
```
(Alternatively, you copy it using scp from primary to ora-vm)

Start the database on ora-vm:
```bash
sqlplus / as sysdba
SQL> CREATE spfile from pfile;
SQL> STARTUP NOMOUNT PFILE='/tmp/initORCL_stby.ora';
SQL> EXIT;
```

Restore the database by using the Oracle Recovery Manager (RMAN) tool:
```bash
rman TARGET sys/Oracle123.?@ORCL AUXILIARY sys/Oracle123.?@ORCL_stby
```
🔑 ***HINT:** In order for this command to work, tnsnames.ora must match on primary and ora-vm and both machines require inbound port 1521 connectivity.*

Run the following commands in RMAN:
```
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET db_unique_name='ORCL_stby' COMMENT 'Is standby'
  NOFILENAMECHECK;
```
Messages similar to the following ones appear when the commands are completed:
```
media recovery complete, elapsed time: 00:00:00
Finished recover at 29-JUN-22
Finished Duplicate Db at 29-JUN-22
```

### Task 5: Configure dataguard on primary vm (onprem)

🔑 ***Please note:** At the time of writing, this task could not be verified. It's still under development. There might be missing steps.*

Enable Data Guard Broker:
```bash
sqlplus / as sysdba
```
```
SQL> ALTER SYSTEM SET dg_broker_start=true;
SQL> CREATE pfile FROM spfile;
SQL> EXIT;
```

Start Data Guard Manager and sign in by using SYS and a password. (Don't use OS authentication.)

```bash
$ dgmgrl sys/Oracle123.?@ORCL
```
```
CREATE CONFIGURATION my_dg_config AS PRIMARY DATABASE IS ORCL CONNECT IDENTIFIER IS ORCL;
```
```
ADD DATABASE ORCL_stby AS CONNECT IDENTIFIER IS ORCL_stby MAINTAINED AS PHYSICAL;
```
```
ENABLE CONFIGURATION;
```
Review the configuration:
```
DGMGRL> SHOW CONFIGURATION;
Configuration - my_dg_config
  Protection Mode: MaxPerformance
  Members:
  ORCL      - Primary database
  ORCL_stby - Physical standby database
Fast-Start Failover: DISABLED
Configuration Status:
SUCCESS   (status updated 26 seconds ago)
```


**You successfully completed challenge 2!** 🚀🚀🚀

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-3/solution.md)