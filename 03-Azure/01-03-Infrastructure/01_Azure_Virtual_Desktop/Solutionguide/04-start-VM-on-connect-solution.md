# Exercise 4: Implement Start VM on connect Feature

## Task 1:

In this first part of the challenge we have to create and assign a custom role. Once assigned, this custom role enables Azure Virtual Desktop to turn on VMs.

### Create custom role:

- Navigate to Access Control (IAM) in the Subscription where the VMs are located
- On the top left choose Add and then click on Add custom role 
- The window to create a custom role opens
- Give a name to the role like, for example: AVD-Start VM on connect
- Now you have two options to continue: either giving the permissions by choosing them manually or by entering them in the JSON format (see below for both options)

![Create Custom Role](../Images/04-custom_role_1.png)

#### Option 1: Add permissions for custom role by choosing manually:

-	In this case you go to the Permissions tab in the window to create a custom role
-	Here you add the permissions that are required for the custom role, manually from a list. The required permissions are as follows:
  -	Microsoft.Compute/virtualMachines/start/action
  -	Microsoft.Compute/virtualMachines/read
  -	Microsoft.Compute/virtualMachines/instanceView/read
-	Save the choice and continue to Assignable Scopes to go sure the correct subscription (the one where the VMs are located) is chosen
-	Afterwards, continue to Review and Create to create the custom role

#### Option 2: Add permissions for custom role in JSON template:

-	With this option you can jump directly to the JSON tab of the custom role creation window and enter the subscription ID in the template for *assignable scopes* 
-	Afterwards, enter the following lines within the brackets behind *permissions* (compare Image below): 
```
"Microsoft.Compute/virtualMachines/start/action"
"Microsoft.Compute/virtualMachines/read"
"Microsoft.Compute/virtualMachines/instanceView/read"
```
-	Save the progress and continue to Review and Create to create the custom role

![Create Custom Role](../Images/04-custom_role_2.png)

### Assign custom role:

- Make sure you are still working in the subscription where you just created the custom role
- Navigate again to Access Control (IAM) on the left side menu and click on Add on the top left and then Add Role Assignment (compare image below)

![Assign Custom Role](../Images/04-custom_role_3.png)

- Under the Role tab select the role you just created (If you just created the role, it might take a few minutes until it appears)
- Navigate to the Members tab:
  - Here you select the first option *user, group or service principal* 
  - Click on Select Members, search for *Windows Virtual Desktop* and select the option
- Navigate to Review and Assign to create the role assignment (by doing so you give Azure Virtual Desktop the permission to turn on VMs) 

![Assign Custom Role](../Images/04-custom_role_4.png)
 
## Task 2:

In a second step we want to enable the feature *start VM on connect* for the single session host-pool, which we created in a previous challenge. This will work only if the custom role, as described above, is created and assigned to Azure Virtual Desktop - otherwise Azure Virtual Desktop does not have the permission to turn on VMs. 

### Enable the start VM on connect feature: 

- In the Azure Portal move to the single session host-pool, which you created in one of the previous challenges
- On the left-side menu navigate to Properties
- Within the properties window, turn on start VM on connect

![Start VM on connect feature](../Images/04-enable_feature_1.png)


