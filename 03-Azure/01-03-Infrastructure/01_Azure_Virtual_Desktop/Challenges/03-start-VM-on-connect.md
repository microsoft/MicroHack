# Exercise 3: Implement Start VM on Connect

[Previous Challenge](./02-Create-a-custom-golden-image.md) - **[Home](../Readme.md)** - [Next Challenge](./04-multi-session-Hostpools.md)

## Introduction

Some end users will need their desktops once in a while only. Instead of paying for their VMs regularly, you can allow them to turn on their VMs only when needed. The feature is called **Start VM on Connect** and turns on the VM when the user tries to connect to the desktop. 

In order to start VMs, Azure Virtual Desktop requires the built-in Azure role permission **Desktop Virtualization Power On Contributor**, which includes the following permissions:  

```
"Microsoft.Compute/virtualMachines/start/action",
"Microsoft.Compute/virtualMachines/read",
"Microsoft.Compute/virtualMachines/instanceView/read",
"Microsoft.Authorization/*/read",
"Microsoft.Insights/alertRules/*",
"Microsoft.Resources/deployments/*",
"Microsoft.Resources/subscriptions/resourceGroups/read"
```

In the following sessions you will enable that machines are started once the end users connect to the desktop by assigning the required Azure role permission and enabling the **Start VM on Connect** feature. 

## Challenge 

1.	Assign the built-in Azure permission role **Desktop Virtualization Power On Contributor** in the subscription where the VMs are located, which allows **Azure Virtual Desktop or Windows Virtual Desktop** to turn on VMs
2.	Enable the **Start VM on Connect** feature in the single session host pool, which you created in previous challenges

## Success Criteria
AVD user can connect to a single session when any VM in the host pool is turned off. Once the connection was successful, one VM from the single session host pool should be turned on. (Turning on the VM might take some time, so be patient with connecting)
 
## Learning Resources 
- [Start VM on connect feature](https://learn.microsoft.com/en-us/azure/virtual-desktop/start-virtual-machine-connect)
- [Grant roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/quickstart-assign-role-user-portal)
