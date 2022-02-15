# Exercise 2: Create a host pool for multi-session desktops

Duration: 45 min


[Previous Challenge Solution](./01-Personal-Hostpools-solution.md) - **[Home](../readme.md)** - **[Next Challenge Solution](03-Implement-FSLogix-Profile-Solution.md)**

In this challenge you will create Azure Active Directory joined pooled desktops used as a jump box. After deployment you will connect to the jumpbox, deploy Notepad++, 
create an Image and upload the image to the Image gallery. You will deploy a new hostpool from this image and deploy 2 Session hosts. Then you will provide Remote Apps to user

**Additional Resources**

  |              |            |  
|----------|:-------------:|
| Description | Links |
| Create Azure Virtual Desktop Hostpool | https://docs.microsoft.com/de-de/azure/virtual-desktop/create-host-pools-azure-marketplace?tabs=azure-portal|
| Deploy Azure AD joined VMs in Azure Virtual Desktop |  https://docs.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-ad-joined-vm   | 
| Capture an image of a VM using the portal |  https://docs.microsoft.com/en-us/azure/virtual-machines/capture-image-portal   | 
| Manage app groups for Azure Virtual Desktop portal |  https://docs.microsoft.com/en-us/azure/virtual-desktop/manage-app-groups   | 
| Connect with the Windows Desktop Client |  https://docs.microsoft.com/en-us/azure/virtual-desktop/user-documentation/connect-windows-7-10#install-the-windows-desktop-client   | 
  |              |            | 

## Task 1:

Create multi-session Hostpool joined in Azure Active Directory with the following settings:
- West Europe Region
- Metadata located in West Europe
- Mark as Validation environment
- Host Pool type: Pooled
- Add 1 Virtual machine with a Windows 10 Enterprise multi-session Version 20H2 + Microsoft 365 Apps Gallery image
- Domain to join: Azure Active Directory (Enroll with Intune “No”)
- Register desktop app group to new workspace
- Assign users

![Create Hostpool](../Images/02-Hostpool_create_multisession_1.png)



![Create Hostpool](../Images/02-Hostpool_create_multisession_2.png)

### Basics:
- choose your appropriate subscription
- choose the Resource group 
- Host pool name: Multi-session
- Location: West Europe
- Validation environment: yes (:bulb:as we are using the Azure AD join preview feature)
- Host pool type: Pooled
- Load balancing algorithm: Breath-first
- Max session limit: 15

klick next: Virtual machines

### Virtual machines:

![Create Hostpool](../Images/02-Hostpool_create_multisession_3.png)

Add Azure Virtual Machines: select yes

- Resource group: choose the appropriate Resource group
- Name prefix: pooled
- Virtual machine location: West Europe
- Availability options: no infrastructure redundandcy required
- Security type: Standanrd
- Image type: Gallery
- Image: Select an Image: Windows 10 Enterprise multi-session, Version 20H2 + Microsoft 365 Apps
- Virtual machine size: Standard D2s v 3 (2vCPU's, 8 GiB memory)
- number of VMs: 1
- OS disk type: Standard SSD
- Boot Diagnostics: Enable with managed storage account (recommended)



#### Network and Security:

![Create Hostpool](../Images/02-Hostpool_create_multisession_6.png)

- Virtual Network: Select your Virtual network
- Network security group: Basic
- Public inbound ports: No

#### Domain to join:

![Create Hostpool](../Images/02-Hostpool_create_multisession_7.png)

- Select which directory you would like to join: Select Azure Active Directory
- Enroll VM with Intune: No

#### Virtual Machine Administrator account:

![Create Hostpool](../Images/02-Hostpool_create_multisession_8.png)

- Username: avduser1
- Password: avdPa$$w0rd1!
- Confirm password: avdPa$$w0rd1!

click Next: Workspace

### Workspace:

![Create Hostpool](../Images/02-Hostpool_create_multisession_4.png)

Register desktop app group: Yes

![Create Hostpool](../Images/02-Hostpool_create_multisession_5.png)

To this workspace: click "Create new"
Enter workspace name: multi-session

![Create Hostpool](../Images/02-Hostpool_create_multisession_9.png)

click Review + create


## Task2:

### Assign user access to host pools

After you've created your host pool, you must assign users access to let them access their resources. To grant access to resources, add each user to the app group. Follow the instructions in Manage app groups to assign user access to apps and desktops. We recommend that you use user groups instead of individual users wherever possible.

For Azure AD-joined VMs, you'll need to do two extra things on top of the requirements for Active Directory or Azure Active Directory Domain Services-based deployments:

Assign your users the Virtual Machine User Login role so they can sign in to the VMs.
Assign administrators who need local administrative privileges the Virtual Machine Administrator Login role.
To grant users access to Azure AD-joined VMs, you must [configure role assignments for the VM](https://docs.microsoft.com/en-us/azure/active-directory/devices/howto-vm-sign-in-azure-ad-windows#configure-role-assignments-for-the-vm). 
You can assign the Virtual Machine User Login or Virtual Machine Administrator Login role either on the VMs, the resource group containing the VMs, or the subscription. We recommend assigning the Virtual Machine User Login role to the same user group you used for the app group at the resource group level to make it apply to all the VMs in the host pool.

### Add role assignment page in Azure portal

To configure role assignments for your Azure AD enabled VMs:

Select Access control (IAM).

Select Add > Add role assignment to open the Add role assignment page.

Assign the following role. For detailed steps, see [Assign Azure roles using the Azure portal](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal?tabs=current).

| Setting	| Value | 
| --------| ------| 
|Role	| Virtual Machine Administrator Login |
|Role | Virtual Machine User Login | 
| Assign access to	| User, group, service principal, or managed identity |


![Assign user access to host pools](../Images/02-assign_user_access_2.png)

## Task 3:
### Login to the session host and create image

Login as a user with local administrative privileges (:bulb: therefore we added the role assignment "Virtual Machine Administrator Login" in Task 2)
You can Login either with the [AVD Webclient](https://rdweb.wvd.microsoft.com/arm/webclient/index.html) or with the [Windows Desktop Client](https://rdweb.wvd.microsoft.com/arm/webclient/index.html)

![Login to the session host](../Images/02-Login_session_host_1.png)

### Install Notepad++
[Download Notepad++](https://notepad-plus-plus.org/downloads/) and Install Notepad++

Log off

### Create Image with generalized option and upload it to the shared image gallery

![Create Image](../Images/02-Create_Image_1.png)

- Navigate to Virtual machines and select the VM, where you installed Notepad++

- Select Capture, add Subscription and Resource group details

![Create Image](../Images/02-Create_Image_2.png)

- Share image to Azure compute gallery: Yes, share it to a gallery as a VM image version
- Target Azure compute gallery: Select create new, insert a name: AVD_multisession_Image_gallery
- Operating system state: Generalized: VMs created from this image require hostname, admin user, and other VM related setup to be completed on first boot


![Create Image](../Images/02-Create_Image_3.png)
- Target VM image definition: Select Create new
- Insert name: AVD_multisession_Image_gallery
- Publisher: microsoftwindowsdesktop
- Offer: office-365
- SKU: 20h2-evd-o365pp

![Create Image](../Images/02-Create_Image_4.png)

- Select your recently created Target VM image definition AVD_multisession_Image_gallery
- Enter an image version number, type 0.0.1
- If you want this version to be included when you specify latest for the image version, then leave Exclude from latest unchecked.
- if you want, you can select an End of life date. This date can be used to track when older images need to be retired.
- Under Replication, select a default replica count and then select any additional regions where you would like your image replicated.
- When you are done, select Review + create.

## Task 4:
### Create 2 session hosts from your recently created image

![Create Image](../Images/02-Hostpool_create_sessionhosts_1.png)

- Navigate to your multisession hostpool and select Session host
- click add
-
![Create Image](../Images/02-Hostpool_create_sessionhosts_2.png)

- On the top, navigate to Virtual Machines
- Image type: Gallery
- Select see all images

![Create Image](../Images/02-Hostpool_create_sessionhosts_3.png)

- On the top, go to: My Items
- select: Shared Images
- click on your recently created image

![Create Image](../Images/02-Hostpool_create_sessionhosts_4.png)

- Image: your recently created image should show up
- Number of VMs: 2
- click: Review + Create

After the VMs are created, login and verify, if Notepad++ is installed

## Task 5: create Remote Apps

![Create Image](../Images/02-Hostpool-RemoteApp_1.png)
Create a new Application group
- Navigate to Application groups
- Select your Wind10multisession-DAG Workspace
- Host pool: Win10multisession
- Application group type: RemoteApp
- Application group name: RemoteApp
- click create


![Create Image](../Images/02-Hostpool_RemoteApp-2.png)
Navigate to your Win10 multisession Hostpool, on the left side below Manage, select Application groups
click on your recently created Application group named RemoteApp


![Create Image](../Images/02-Hostpool_RemoteApp-3.png)
in your Application group RemoteApp, on the left side below Manage, select Applications
click on +Add

![Create Image](../Images/02-Hostpool_RemoteApp-4.png)
Application source: Startmenu
Application: select Notepad++

![Create Image](../Images/02-Hostpool_RemoteApp-5.png) 
Application: Notepad++ should appear
Application path and Icon path should automatically appear
Click on Save

![Create Image](../Images/02-Hostpool_RemoteApp-6.png) 

Start your Remote Desktop Client App and launch Notepad++

