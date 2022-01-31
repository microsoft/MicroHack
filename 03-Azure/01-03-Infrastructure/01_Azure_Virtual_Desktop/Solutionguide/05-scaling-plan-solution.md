# Exercise 5: Set up a scaling plan

## Task 1:

In this first part of the challenge...

### Create custom role:

- Navigate to Access Control (IAM) in the Subscription where the VMs of the multi session host-pool are located
- On the top left choose Add and then click on Add custom role (compare image below)
- The window to create a custom role opens
- Give a name to the role like, for example: AVD-scaling plan
- Now you have two options to continue: either giving the permissions by choosing them manually or by entering them in the JSON format

![Create Custom Role](../Images/04-custom_role_1.png)

#### Option 1: Add permissions for custom role by choosing manually:

-	In this case you go to the Permissions tab in the window to create a custom role
-	Here you add the permissions that are required for the custom role, manually from a list. The required permissions are as follows:
```
Microsoft.Insights/eventtypes/values/read
Microsoft.Compute/virtualMachines/deallocate/action
Microsoft.Compute/virtualMachines/restart/action
Microsoft.Compute/virtualMachines/powerOff/action
Microsoft.Compute/virtualMachines/start/action
Microsoft.Compute/virtualMachines/read
Microsoft.DesktopVirtualization/hostpools/read
Microsoft.DesktopVirtualization/hostpools/write
Microsoft.DesktopVirtualization/hostpools/sessionhosts/read
Microsoft.DesktopVirtualization/hostpools/sessionhosts/write
Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/delete
Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read
Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/sendMessage/action
Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read 
```
-	Save the choice and continue to Assignable Scopes to go sure the correct subscription (the one where the VMs are located) is chosen
-	Afterwards, continue to Review and Create to create the custom role

#### Option 2: Add permissions for custom role in JSON template:

-	With this option you can jump directly to the JSON tab of the custom role creation window and enter the subscription ID in the template for *assignable scopes* 
-	Afterwards, enter the following lines within the brackets behind *permissions*, as we already did in the previous challenge: 
```
"Microsoft.Insights/eventtypes/values/read"
"Microsoft.Compute/virtualMachines/deallocate/action"
"Microsoft.Compute/virtualMachines/restart/action"
"Microsoft.Compute/virtualMachines/powerOff/action"
"Microsoft.Compute/virtualMachines/start/action"
"Microsoft.Compute/virtualMachines/read"
"Microsoft.DesktopVirtualization/hostpools/read"
"Microsoft.DesktopVirtualization/hostpools/write"
"Microsoft.DesktopVirtualization/hostpools/sessionhosts/read"
"Microsoft.DesktopVirtualization/hostpools/sessionhosts/write"
"Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/delete"
"Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read"
"Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/sendMessage/action"
"Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read"
```
-	Save the progress and continue to Review and Create to create the custom role

### Assign custom role:

- Make sure you are still working in the subscription where you just created the custom role
- Navigate again to Access Control (IAM) on the left side menu and click on Add on the top left and then Add Role Assignment (compare image below)

![Assign Custom Role](../Images/04-custom_role_3.png)

- Under the Role tab select the role you just created (If you just created the role, it might take a few minutes until it appears)
- Navigate to the Members tab:
  - Here you select the first option *user, group or service principal* 
  - Click on Select Members, search for *Windows Virtual Desktop* and select the option
- Navigate to Review and Assign to create the role assignment (by doing so you give Azure Virtual Desktop the permission to manage, turn on and shut down VMs) 

![Assign Custom Role](../Images/04-custom_role_4.png)
 
## Task 2:

In a second step we want to...

### Create the scaling plan:

### Assign the scaling plan to the host-pool: 


Test: 
