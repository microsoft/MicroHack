# Exercise 4: Start VM on Connect
[Previous Challenge](./03-Implement-FSLogix-Profile-Solution.md) - **[Home](../readme.md)** - [Next Challenge](./05-scaling-plan.md)

## Introduction

Some end users will need their desktops once in a while only. Instead of paying for their VMs regularly, you can allow them to turn on their VMs only when needed. The feature is called *start VM on connect* and turns on the VM when the user tries to connect to the desktop. In order to being able to start VMs, Azure Virtual Desktop needs the following permissions: 
```
Microsoft.Compute/virtualMachines/start/action
Microsoft.Compute/virtualMachines/read
Microsoft.Compute/virtualMachines/instanceView/read
```

In the following sessions you will enable that machines are started once the end users connect to the desktop by setting up a custom role and enabling the *start VM on connect* feature. 

## Challenge 

1.	Create and assign a custom role in the subscription where the VMs are located, which allows Azure Virtual Desktop *(Windows Virtual Desktop)* to turn on VMs
2.	Enable the *start VM on connect* feature in the single session host pool, which you created in previous challenges

## Success Criteria
AVD user can connect to a single session when any VM in the host pool is turned off. Once the connection was successful, one VM from the single session host pool should be turned on. *(Turning on the VM might take some time, so be patient with connecting)*
 
## Learning Resources 
- [Start VM on connect feature](https://docs.microsoft.com/en-us/azure/virtual-desktop/start-virtual-machine-connect)
- [Create custom roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles)
- [Grant roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/quickstart-assign-role-user-portal)
