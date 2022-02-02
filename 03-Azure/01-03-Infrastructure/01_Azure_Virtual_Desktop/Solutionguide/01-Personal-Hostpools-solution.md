## Exercise 1: Create a host pool for personal desktops

Duration:  45 minutes

[Previous Challenge](./00-Pre-Reqs.md) - **[Home](../readme.md)** - **[Next Challenge solution](02-multi-session-Hostpools-solution.md)**

In this exercise we will be creating an Azure Virtual Desktop host pool for personal desktops. This is a set of computers or hosts which operate on an as-needed basis. In a pooled configuration we will be hosting multiple non-persistent sessions, with no user profile information stored locally. This is where FSLogix Profile Containers provide the users profile to the host dynamically. This provides the ability for an organization to fully utilize the compute resources on a single host and lower the total overhead, cost, and number of remote workstations.

**Additional Resources**

  |              |            |  
|----------|:-------------:|
| Description | Links |
| Create a host pool with the Azure portal | https://docs.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace |
  |              |            | 

### Task 1: Create a new Host Pool and Workspace

1.  Sign in to the [Azure Portal](https://portal.azure.com/).

2.  Search for **Azure Virtual Desktop** and select it from the list.

    ![This image shows the Azure portal search bar, and how to search for Azure Virtual Desktop and select the service.](../Images/02-Hostpool_create_multisession_1.png)    

3.  Under Manage, select **Host pools** and select **+ Create**.
   
    ![This image shows where to select host pools under manage and select add to add a new host pool.](../Images/01-avdHostPool.png "Azure Virtual Desktop blade")

4.  On the Basics page, refer to the following screenshot to fill in the required fields. Select your Subscription, Resource Group and define a Hostpool name. As Location choose **West Europe**. 

:warning: This will only effect Meta data. The Datacenter location for virtual machines will follw. 

Change **Validation environment** to **Yes**.
Once complete, select **Next: Virtual Machines**.

    ![This image shows where you will enter the information for the host pool.](../Images/01-createhostpool.png "Create host pool page")

5.  On the Virtual Machines page, provision a Virtual machine with the **Windows 10 multi-user + M365 apps**. Once complete, select **Next: Workspace**.
   
6.  For the **Image**, select **Browse all images and disks** and search to find **Windows 10 Enterprise multi-session, Version 2004 + Microsoft 365 Apps** and select that image.
    >**Note**: Selecting this image is very important. You will need the Microsoft 365 for assigning apps in this exercise.

    ![This image shows the image that you need for your host pool virtual machine.](../Images/01-vmwith365.png "Host pool Virtual Machine with image")

    ![The image shows the blade that you will enter in the information for the host pool name and select next for virtual machines.](../Images/01-nextworkspace5.png "Virtual Machine information")

7.  On the Workspace page, select **Yes** to register a new desktop app group. Select **Create new** and provide a **Workspace name**. Select **OK** and **Review + create**.

    ![This image shows how from the create a host pool workspace tab, enter the required information.](../Images/01-hostpoolWorkspace.png "Create a host pool workspace tab")

8.  On the Create a host pool page, select **Create**.

### Task 2: Create a friendly name for the workspace

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

    ![This image shows how from the workspace properties tab, view the workspace that you created.](../Images/01-workspaceFriendlyName.png "workspace properties tab")

### Task 3: Assign an Azure AD User to the desktop application group

In the new Azure Virtual Desktop ARM portal, we now can use Azure Active Directory groups to manage access to our host pools.

1.  Sign in to the [Azure Portal](https://portal.azure.com/).

2.  Search for **Azure Virtual Desktop** and select it from the list.

    ![This image shows where to search for Azure Virtual Desktop from the Azure portal search bar.]../Images/01-searchavd.png "Search for Azure Virtual Desktop")

3.  Under Manage, select **Application groups**.
    
4.  Locate the Application group that was created as part of Task 1 (**\<poolName\>-DAG**). Select the name to manage the Application group.

    ![This image shows where you will find the application group created in Task 1.](../Images/01-avdappgroups.png "Select the application group")

5.  Under Manage, select **Assignments** and select **+ Add**.

    ![This image shows where to find manage in the menu and select assignments and add.](../Images/01-addassignments.png)

6.  In the fly out, enter **AVD** in the search to find the name of your Azure AD group. In this exercise we will select **AVD Pooled Desktop Users** and **AAD DC Administrators**.
    >**Note**: AAD DC Administrators will allow you to use your Azure tenant login to access resources in Exercise 7.

    ![In this image, you can view the groups that you need to select and save.](../Images/01-avdpooleduseradd.png "Add Pooled Desktop user")

7.  Choose **Select** to save your changes.

    ![This image shows how to find and select the AVD Pooled desktop users in the list of users and groups.](../Images/01-hostpoolusers.png "Host pool users for AVD")

With the assignment added, you can move on to the next exercise. The users in the Azure AD group can be used to validate access to the new host pool in a later exercise.
