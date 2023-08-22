# Exercise 1: Create a host pool for personal desktops

Duration:  30 minutes

**[Home](../Readme.md)** - [Next Challenge Solution](./02-Create-a-custom-golden-image-solution.md)

In this exercise we will be creating an Azure Virtual Desktop host pool for personal desktops. This is a set of computers or hosts which operate on an as-needed basis. This personal desktop will also function as a jump host in the following exercises.


**Additional Resources**
|              |            |  
|----------|:-------------|
| Description | Links |
| Create a host pool with the Azure portal | https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace |
| Configure the personal desktop host pool assignment type | https://learn.microsoft.com/en-us/azure/virtual-desktop/configure-host-pool-personal-desktop-assignment-type | 
| Connect with the Windows Desktop Client | https://learn.microsoft.com/en-us/azure/virtual-desktop/users/connect-windows?tabs=subscribe#install-the-windows-desktop-client  | 

## Task 1: Create a new Personal Host Pool and Workspace

1.  Sign in to the [Azure Portal](https://portal.azure.com/).

2.  Search for **Azure Virtual Desktop** and select it from the list.

3.  Under Manage, select **Host pools** and select **+ Create**.
   
![This image shows where to select host pools under manage and select add to add a new host pool.](../Images/01-avdHostPool.png "Azure Virtual Desktop blade")

4.  On the Basics page, refer to the following screenshot to fill in the required fields. Select your Subscription, Resource Group and define a Hostpool name. As Location choose **West Europe**. 

> **Info:** This will only effect metadata. The Datacenter location for virtual machines will follow. 

Change **Validation environment** to **Yes**.
Once complete, select **Next: Virtual Machines**.

![This image shows where you will enter the information for the host pool.](../Images/01-createpersonalhostpool.png "Create host pool page")

5.  On the Virtual Machines page, provision a Virtual machine with the **Windows 11 Enterprise**.
   
6.  For the **Image**, select **Browse all images and disks** and search to find **Windows 11 Enterprise** and select that image.
    >**Note**: Selecting this image is very important. You will need the Microsoft 365 for assigning apps in this exercise.

    ![This image shows the image that you need for your host pool virtual machine.](../Images/01-vmwith365_1.png "Host pool Virtual Machine with image")

    ![This image shows the image that you need for your host pool virtual machine.](../Images/01-vmwith365_2.png "Host pool Virtual Machine with image")

     ![This image shows the image that you need for your host pool virtual machine.](../Images/01-vmwith365_3.png "Host pool Virtual Machine with image")

7.  On the Workspace page, select **Yes** to register a new desktop app group. Select **Create new** and provide a **Workspace name**. Select **OK** and **Review + create**.

    ![This image shows how from the create a host pool workspace tab, enter the required information.](../Images/01-hostpoolWorkspace.png "Create a host pool workspace tab")

8.  On the Create a host pool page, select **Create**.

## Task 2: Create a friendly name for the workspace

The name of the Workspace is displayed when the user signs in. Available resources are organized by Workspace. For a better user experience, we will provide a friendly name for our new Workspace. 

>**Note**: The workspace will not appear until Task 1 has completed deployment. 

1.  Sign in to the [Azure Portal](https://portal.azure.com/).

2.  Search for **Azure Virtual Desktop** and select it from the list.

    ![This image shows how to access Azure Virtual Desktop from the Azure portal search bar.](../Images/01-searchavd.png "Search for Azure Virtual Desktop")

3.  Under Manage, select **Workspaces**. Locate the Workspace you want to update and select the name.

    ![This image shows where to locate the workspace that was created in Task 1 and select it.](../Images/01-workspaceproperties.png "Select the workspace")

4.  Under Settings, select **Properties**.

5.  Update the **Friendly name** field to your desired name.

    ![The image shows that under properties of the workspace, you will enter a name under friendly name and save.](../Images/01-savefriendlyname.png "Enter a friendly name")

6.  Select **Save**.

## Task 3: Assign an Azure AD User to the desktop application group

In the new Azure Virtual Desktop ARM portal, we now can use Azure Active Directory groups to manage access to our host pools.

1.  Sign in to the [Azure Portal](https://portal.azure.com/).

2.  Search for **Azure Virtual Desktop** and select it from the list.

3.  Under Manage, select **Application groups**.
    
4.  Locate the Application group that was created as part of Task 1 (**\<poolName\>-DAG**). Select the name to manage the Application group.

    ![This image shows where you will find the application group created in Task 1.](../Images/01-avdappgroups.png "Select the application group")

5.  Under Manage, select **Assignments** and select **+ Add**.

    ![This image shows where to find manage in the menu and select assignments and add.](../Images/01-addassignments.png)

6.  In the fly out, enter **AAD Username or AAD Group** in the search to find the name of your Azure AD group. In this exercise we will select **Alex Wilber**.

    ![In this image, you can view the groups that you need to select and save.](../Images/01-avdpooleduseradd.png "Add Pooled Desktop user")

7.  Choose **Select** to save your changes.

    ![This image shows how to find and select the AVD Pooled desktop users in the list of users and groups.](../Images/01-hostpoolusers.png "Host pool users for AVD")

With the assignment added, you can move on to the resource group and configure the RBAC permission so the selected user can access the desktop via AAD only.

1.  Go to the resource group e.g. **rg-microhack** and select **Access Control (IAM)**.

    ![This image shows how to add and apply RBAC permissions to a resource group.](../Images/01-rbac1.png "Add Permissions")

2. Select **Add** and search for **Virtual Machine User Login** or **Virtual Machine Administator Login** to access the session with local admin rights.

     ![This image shows how to add and apply RBAC permissions to a resource group.](../Images/01-rbac2.png "Add Permissions")

3. Select and add the **User or Group** and apply the Role assignment. 

    ![This image shows how to add and apply RBAC permissions to a resource group.](../Images/01-rbac3.png "Add Permissions")

With this assignment you now can test the first connection to your AVD session host.

> **Note**: If you are trying to access your virtual desktop from Windows devices or other devices that are not connected to Azure AD, add **targetisaadjoined:i:1** as a custom RDP property to the host pool. [More information here](https://learn.microsoft.com/en-us/azure/virtual-desktop/deploy-azure-ad-joined-vm#access-azure-ad-joined-vms)
