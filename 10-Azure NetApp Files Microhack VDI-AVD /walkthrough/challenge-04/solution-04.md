## Integrate Azure NetApp Files volume into AVD environment 

** Deploy new SMB volume, integrate with AVD Session Host and verify ** 



## Prerequisites

The pre-provisioned AVD setup already has a designated Hostpool for each attendee. Your Hostpool is microhack_hostpool{Group Number}

### Task 1: Configure AD connection in NetApp account

1. Log in to the [Azure portal](https://portal.azure.com/#home) 

2. Pick Azure NetApp Files service 

3. From the Azure NetApp Files management sidebar, select your NetApp account, e.g. myaccount1

4. One the left side expand **Azure Netapp Files** and click on **Active Directory connections**

5. Click **Join** and enter the following values (leave all other fields blank)

* Primary DNS: **10.100.0.4**
* AD DNS Domain Name: **microhack.test**
* AD Site Name: **Default-First-Site-Name**
* SMB Serve: **MH**
* Organizational Unit Path: **OU=Hostpool{Group Number}**
* AES Encryption: **checked**

Click **OK**

### Task 2: Create a new SMB volume

1. On the left side expand **Storage service**, click on **Volumes** and **Add volume**. Enter the following

* Volume Name: **mySMBvol{Group Number}**
* Capacity Pool: **your existing capacity pool**
* Quota: **100**
* Max. Throughput: What throughput value did you get? Why can't you change it?
* Virtual Network: **microhack_vnet**
* Delegated subnet: **anf**

Click on **Next Protocol**

Access: Select **SMB**

Click on **Review + create** and **create**

### Task 3: Integration of your volume into AVD (Trainer Task)

1. Click on your new volume
2. On the left side under **Storage Service** click on **Mount instructions** to identify the UNC path of your volume

The UNC path of your share needs to be entered in the AD Group Policy attribute **VHD locations** which is assigned to your OU (see AD connection) 

### Task 4: Test and verify correct AVD integration of your SMB volume 

1. Login to AVD using your assigned AVD user

2. Goto **Settings** and select **Manage disks and volumes**

3. Can you see the attached VHD disks?

4. Now select **Map network drive** and mount you SMB share manually

5. Can you find your home directory on the share?





🔑 **Key to a successful strategy....**
- The key to success is not a technical consideration of....

### **Task 2: Think about if...**


### **Task 3: Put yourself in the position...**

* [Checklist Testing for...](Link to checklist or microsoft docs)

### Task 4: Who defines the requirements...


![image](Link to image)


You successfully completed challenge 1! 🚀🚀🚀

