# Exercise 5: Set up a scaling plan

## Task 1:

In this first part of the challenge...

### Create custom role:

![Create Custom Role](../Images/imagename.png)

#### Option 1: Add permissions for custom role by choosing manually:

#### Option 2: Add permissions for custom role in JSON template:

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

In a second step we want to...

### Enable the start VM on connect feature: 


Test: 
