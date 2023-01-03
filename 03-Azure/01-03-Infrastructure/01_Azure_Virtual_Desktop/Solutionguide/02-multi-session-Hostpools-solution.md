# Exercise 2: Create a host pool for multi-session desktops

Duration: 45 min


[Previous Challenge Solution](./01-Personal-Hostpools-solution.md) - **[Home](../readme.md)** - [Next Challenge Solution](03-Implement-FSLogix-Profile-Solution.md)

In this challenge you will create Azure Active Directory Domain Service joined pooled desktops used as a jump box. After deployment you will connect to the jumpbox, deploy Notepad++, 
create an Image and upload the image to the Image gallery. You will deploy a new hostpool from this image and deploy 2 Session hosts. Then you will provide Remote Apps to user

In a pooled configuration we will be hosting multiple non-persistent sessions, with no user profile information stored locally. This is where FSLogix Profile Containers provide the users profile to the host dynamically. This provides the ability for an organization to fully utilize the compute resources on a single host and lower the total overhead, cost, and number of remote workstations.

**Additional Resources**

  |              |            |  
|----------|:-------------:|
| Description | Links |
| Create Azure Virtual Desktop Hostpool | https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace?tabs=azure-portal |
| Capture an image of a VM using the portal |  https://learn.microsoft.com/en-us/azure/virtual-machines/capture-image-portal | 
| Manage app groups for Azure Virtual Desktop portal |  https://learn.microsoft.com/en-us/azure/virtual-desktop/manage-app-groups   | 
| Connect with the Windows Desktop Client |  https://learn.microsoft.com/en-us/azure/virtual-desktop/users/connect-windows?tabs=subscribe#install-the-windows-desktop-client  | 
  |              |            | 

## Task 1: Create a new Pooled Host Pool and Workspace

1.  Sign in to the [Azure Portal](https://portal.azure.com/).

2.  Search for **Azure Virtual Desktop** and select it from the list.

3.  Under Manage, select **Host pools** and select **+ Create**.
   
![This image shows where to select host pools under manage and select add to add a new host pool.](../Images/01-avdHostPool.png "Azure Virtual Desktop blade")

4.  On the Basics page, refer to the following screenshot to fill in the required fields. Select your Subscription, Resource Group and define a Hostpool name. As Location choose **West Europe**. 

> **Info:** This will only effect metadata. The Datacenter location for virtual machines will follow. 

Change **Validation environment** to **Yes**.
Once complete, select **Next: Virtual Machines**.

![This image shows where you will enter the information for the host pool.](../Images/02-Hostpool_create_multisession_2.png "Create pooled host pool page")

5.  On the Virtual Machines page, provision a Virtual machine with the **Windows 11 Enterprise multi-session + Microsoft 365 Apps**. Once complete, select **Next: Workspace**.
   
6.  For the **Image**, select **Browse all images and disks** and search to find **Windows 11 Enterprise multi-session + Microsoft 365 Apps** and select that image.
    >**Note**: Selecting this image is very important. You will need the Microsoft 365 for assigning apps in this exercise.

    ![This image shows the image that you need for your host pool virtual machine.](../Images/02-vmwith365_1.png "Host pool Virtual Machine with image")

    ![This image shows the image that you need for your host pool virtual machine.](../Images/02-vmwith365_2.png "Host pool Virtual Machine with image")

     ![This image shows the image that you need for your host pool virtual machine.](../Images/01-vmwith365_3.png "Host pool Virtual Machine with image")
 
7.  On the Workspace page, select **Yes** to register a new desktop app group. Select **Create new** and provide a **Workspace name**. Select **OK** and **Review + create**.

    ![This image shows how from the create a host pool workspace tab, enter the required information.](../Images/02-hostpoolWorkspace.png "Create a host pool workspace tab")

8.  On the Create a host pool page, select **Create**.
## Task2: Assign user access to host pools

After you've created your host pool, you must assign users access to let them access their resources. To grant access to resources, add each user to the app group. Follow the instructions in Manage app groups to assign user access to apps and desktops. We recommend that you use user groups instead of individual users wherever possible.

1. Assign your users the Virtual Machine User Login role so they can sign in to the VMs.

2. Assign administrators who need local administrative privileges the Virtual Machine Administrator Login role.
To grant users access to Azure AD-joined VMs, you must [configure role assignments for the VM](https://docs.microsoft.com/en-us/azure/active-directory/devices/howto-vm-sign-in-azure-ad-windows#configure-role-assignments-for-the-vm). 

### Add role assignment page in Azure portal

To configure Virtual machine Administrator login for **AVDuser3**, follow the following steps:

1. Select Access control (IAM).

2. Select Add > Add role assignment to open the Add role assignment page.

3. Assign the following role. For detailed steps, see [Assign Azure roles using the Azure portal](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal?tabs=current).

| Setting	| Value | 
| --------| ------| 
|Role	| Virtual Machine Administrator Login |
|Assign access to	| User, group, service principal, or managed identity |

![Assign user access to host pools](../Images/02-assign_user_access_2.png)

## Task 3: Create a new imaging VM and install applications

1.  Open the [Azure Virtual Machine site](https://azvm.cmd.ms/) and create new virtual machine for manual creation of a custom image. 

2. **Select your subscription, the resource group, and define a temporary name for the virtual machine** that will be deleted after the custom image is captured. The region is filled automatically based on the resource group region. The availability options and security type do not need to be changed. 

![Create Custom Image](../Images/02-Create_CustomImage_1.png)

3. For the image, you need to find the **Windows 11 Enterprise Multi-Session + Microsoft 365 Apps** via the **Show all images** link.

![Create Custom Image](../Images/02-Create_CustomImage_2.png)

![Create Custom Image](../Images/02-Create_CustomImage_3.png)

> The VM architecture is automatically filled in based on the selected image.

Please leave the **Run with Azure Spot discount** option disabled. 

![Create Custom Image](../Images/02-Create_CustomImage_4.png)

4. Select the VM size, enter your preferred local administrator credentials, select **None** for public incoming ports, and answer the license questions.  

![Create Custom Image](../Images/02-Create_CustomImage_5.png)

5. Click **Next : Disk >** and change the disk settings if you want, otherwise click **Next : Network >** so we can **disable the Public IP** creation.  

Select **None** for the public IP and the network security group NIC and enable the **Delete NIC when deleting the VM** option. 

>Note: The imaging VM should be accessible from the AVD session hosts. You can deploy the imaging VM on the same virtual network, because the VM will be deleted after the image is created. 

![Create Custom Image](../Images/02-Create_CustomImage_6.png)

6. Next click **Review + Create** and then click **Create**.

7. Log in to an AVD session host that can reach the Imaging VM via RDP. Open **mstsc** and use the private IP address to connect to the Imaging VM. Log in with the credentials of the local administrator that you specified a few steps earlier. 

8. Next, **install some applications what you want**, for example [Visual Studio Code](https://aka.ms/vscode-win32-x64-system-stable) or the special application [Notepad++](https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.4.7/npp.8.4.7.Installer.x64.exe).

9. Clean up the browsing history and delete the entire **C:\Windows\Panther** folder. Then run **sysprep to generalize the VM**. 

Open a CMD terminal as administrator and execute the following commands:

``` CMD 
rmdir /s C:\Windows\Panther

%windir%\system32\sysprep\sysprep.exe /oobe /generalize /mode:vm /shutdown
```

For more information check this [link](https://learn.microsoft.com/en-us/azure/virtual-machines/generalize).

10. Deallocate the imaging VM completely from the Azure portal. 

> Note: A shutdown within a VM does not unassign the VM in Azure, it only stops the VM. 

### Create Image with generalized option and upload it to the shared image gallery

1. Navigate to [Azure Virtual Machine site](https://azvm.cmd.ms/) and select the imaging VM, where you installed your applications. Then select **Capture**.

![Create Custom Image](../Images/02-Create_CustomImage_7.png)

2. Select the **Subscription and Resource group details**. Then enter the information for the shared image as in the screenshots below.  

![Create Image](../Images/02-Create_Image_2.png)

- Share image to Azure compute gallery: **Yes, share it to a gallery as a VM image version**
- Target Azure compute gallery: **Select create new, insert a name AVD_multisession_Image_gallery**
- Operating system state: **Generalized: VMs created from this image require hostname, admin user, and other VM related setup to be completed on first boot**

![Create Image](../Images/02-Create_Image_3.png)
- Target VM image definition: **Select Create new**
- Insert name: **AVD_multisession_Image_gallery**
- Publisher: **microsoftwindowsdesktop**
- Offer: **office-365**
- SKU: **win11-21h2-avd-m365pp**

![Create Image](../Images/02-Create_Image_4.png)

- Select your recently created Target VM image definition **AVD_multisession_Image_gallery**
- Enter an image version number, type **0.0.1**
- If you want this version to be included when you specify latest for the image version, then leave Exclude from latest unchecked.
- if you want, you can select an End of life date. This date can be used to track when older images need to be retired.
- Under Replication, select a default replica count and then select any additional regions where you would like your image replicated.
- When you are done, select **Review + create**.

## Task 4: Create 2 session hosts from your recently created image

1. Navigate to your multisession hostpool and select **Session host**
2. Click **Add**

![Create Image](../Images/02-Hostpool_create_sessionhosts_1.png)

3. Navigate to **Virtual Machines** at the top and select **Show All Images** to find your recently created image. 

![Create Image](../Images/02-Hostpool_create_sessionhosts_2.png)

4. Next, go to **My Items** then select **Shared Images** and click on your recently created image.

![Create Image](../Images/02-Hostpool_create_sessionhosts_3.png)

5. Now your recently created image should be displayed as an image parameter. Enter the number of VMs **2** and click **Check + Create**.

![Create Image](../Images/02-Hostpool_create_sessionhosts_4.png)


After the VMs are created, login and verify, if your applications are installed.

## Task 5: create Remote Apps

![Create Image](../Images/02-Hostpool_RemoteApp-1.png)

- Navigate to the Azure Virtual Desktop and select **Application Groups**
- Click **Create**

![Create Image](../Images/02-Hostpool_RemoteApp-2.png)

Create a new Application group
- **Select your Resource group**
- **Select your multi-session AVD Host pool**
- Application group type: **Remote App (RAIL)**
- Application group name: **RemoteApp**
- click **create**

![Create Image](../Images/02-Hostpool_RemoteApp-2-1.png)

Select Workspace in the creation wizard
- Register application group: **Yes**
- Register application group: **Multi-Session** 
- Click **Review + create**

> If another application group in the AVD host pool has already been registered then this app group will also be registered to that same workspace.

Navigate to your Windows 11 multisession Hostpool, on the left side below Manage, select **Application groups**
click on your recently created Application group named **RemoteApp**

![Create Image](../Images/02-Hostpool_RemoteApp-3.png)

- In your Application group RemoteApp, on the left side below Manage, select **Applications** 
- Click on **Add**

![Create Image](../Images/02-Hostpool_RemoteApp-4.png)

- Application source: **Startmenu**
- Application: **Select Notepad++**

![Create Image](../Images/02-Hostpool_RemoteApp-5.png) 
- Application: **Notepad++ should appear**
- Application path and Icon path should automatically appear
- Click on **Save**

![Create Image](../Images/02-Hostpool_RemoteApp-8.png) 

- Navigate to **Assignments**
- Assign the AVDUsers group to the Application group

Next, start your Remote Desktop Client App, refresh the AVD Workspace and launch the Notepad++ application.

> **Note**: If you are trying to access your virtual desktop from Windows devices or other devices that are not connected to Azure AD, add **targetisaadjoined:i:1** as a custom RDP property to the host pool. [More information here](https://learn.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-ad-joined-vm#access-azure-ad-joined-vms)
