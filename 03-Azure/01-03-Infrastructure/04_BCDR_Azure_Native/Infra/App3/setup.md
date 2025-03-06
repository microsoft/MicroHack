### Actions

* Task 1: Deploy a Windows Server 2022 VM in Germany West Central Resource Group. Please use the "Data Science Virtual Machine - Windows 2022" image from the market place.
> **Note:** The 'Data Science Virtual Machine (DSVM)' is a 'Windows Server 2022 with Containers' VM that has several popular tools for data exploration, analysis, modeling & development pre installed.
> You will to use Microsoft SQL Server Management Studio to connect to the database and Storage Explorer to the storage Account.
* Task 2: Deploy a Ubuntu Server VM in Sweden Central Resource Group.
* Task 3: Deploy a azure sql database server with a database containing the sample data of AdventureWorksLT.
* Task 4: From the Data Science Windows Server VM, connect to the database  and to the storage account.
* Task 5: Create a blob container and upload a sample file to it.
* Task 6: Delete a file in and restore

<details close>
<summary>💡 How-to: Deploy a Ubuntu Server VM in Azure Region Sweden Central</summary>
<br>

</details>

### Task 1: Create a new Virtual Machine in Azure Region Germany West Central

As a first step, we will create a VM (Name: ds-vm-win-serverl) in Azure in the resource group "mh-bcdr-gwc-rg" that we created in the last challenge. This should be a Data Science Virtual Machine - Windows 2022 using a VM Type of Standard DS3v2. 

### Choose OS
![image](./img/001.png)

### Configure Details - Basics
![image](./img/002.png)

### Configure Details - Basics (option 2)
![image](./img/003.png)

Please don't forget to put the VM into the public network and open up Port 3389 to connect to it (or alternatively use Azure Bastion to access it). 
### Enable RDP Port
![image](./img/004.png)

### Review deployed VM
![image](./img/005.png)
![image](./img/005a.png)

### Task 2: Deploy a Azure SQL Database Server with a database containing the sample data of AdventureWorksLT in Azure Region Germany West Central

### Choose SQL Database
![image](./img/011.png)

### Configure Details - Basics
![image](./img/012.png)

### Configure Details - Basics: Create SQL Database Server
![image](./img/012a.png)

### Configure Details - Networking
![image](./img/012b.png)

### Configure Details - Additional settings
Use existing data -> select the sample data of AdventureWorksLT
![image](./img/013.png)

### Review + Create

> **Note:**  "It's important to ensure that there are no connection blockers preventing access to the SQL Database. If necessary, you may need to set up a firewall rule that allows the IP address of the virtual machine to connect.
![image](./img/FWrule.png)

### Task 3: From the Data Science Windows Server VM, connect to the database and to the storage account.

### Connect to deployed "Data Science Windows Server VM"
wait until the pre-configured VM to be installed.
![image](./img/015.png)

### Open SQL Server Management Studio
![image](./img/016.png)

### Put your DB Server name and connect to your Database Server via the preferred Authentication method.
![image](./img/017.png)

### The Database Server is connected!
![image](./img/018.png)

### Task 5: Create a blob container and upload a sample file to it
### Go to the storage account in mh-bcdr-gwc-rg Resource Group.
Under the tab Containers:

![image](./img/019.png)

### Create a Shared access signature (SAS).
![image](./img/020.png)

### Connect to the "Data Science Windows Server VM" and open "Microsoft Azure Storage Explorer"
Choose Storage account or service

![image](./img/022.png)

### Select Shared access signature URL (SAS) as connection method.
![image](./img/023.png)

### Put the Shared access signature (SAS), which we created in the previous task.
![image](./img/024.png)

### Review Summary + Connect
![image](./img/025.png)

### Your storage account is connected!
![image](./img/026.png)

### Now, search for the container that you created in the previous task
![image](./img/027.png)

### Upload a sample file
![image](./img/028.png)
![image](./img/029.png)

### Task 4: Trigger a restore for the blob

### Delete a file in your blob container

### Go to the backup vault and select the backup instance
![image](./img/mh-ch2-screenshot-710.png)
![image](./img/mh-ch2-screenshot-711.png)

### Restore the blob container 
![image](./img/mh-ch2-screenshot-712.png)
![image](./img/mh-ch2-screenshot-713.png)
![image](./img/mh-ch2-screenshot-714.png)
![image](./img/mh-ch2-screenshot-715.png)
![image](./img/mh-ch2-screenshot-716.png)
![image](./img/mh-ch2-screenshot-717.png)