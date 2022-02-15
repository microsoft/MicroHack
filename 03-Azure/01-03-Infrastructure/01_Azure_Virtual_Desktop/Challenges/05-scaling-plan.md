# Exercise 5: Scaling plan 
[Previous Challenge](./04-start-VM-on-connect.md) - **[Home](../readme.md)** - [Next Challenge](./06-RDP-properties.md)

## Introduction
Taking a look at the multi-session usage pattern we recognize that some days are busier than others. Busy days have specific peak hours as well as times where the desktops are not used at all. Moreover, users complain about performance issues with rising users per session. On the other hand, management askes for cost saving opportunities. To optimize costs and user experience, AVD scaling plans are recommended *(feature is still in preview)*. 
Azure Virtual Desktop requires a custom role to be able to deallocate and start VMs based on the scaling plan and user behaviour. That role needs to include the following permissions: 
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

In this Challenge you will set up a scaling plan based on certain insights from previous usage and management requirements on cost savings. In order to do so, you will need to create a custom role for Azure Virtual Desktop first. 

## Challenge
1.	Create and assign the custom role, which is required to enable Azure Virtual Desktop turning on and deallocating VMs based on scaling plans. 
2.	Set up a scaling automation and assign it to the multi-session host pool with respect to the following requirements: 
    - Standard office hours are from 8 am to 6 pm from Monday to Friday
    - Peak hours are between 9 am and 5 pm from Monday to Friday
    - The load balancing algorithm should first allocate all the users to one host until the maximum amount of sessions per host is reached
    - At least 25% of available session capacity should be turned on at any time, even outside the standard office hours - the other ones can be deallocated
    - During ramp up at least 50% of the available session capacity should be turned on
    - If 75% of the current session capacity is reached during ramp up and peak time, a further session host should be turned on
    - During ramp-down and during weekends a new host should be turned on only if all the session capacity is used. Furthermore, only VMs with no active or disconnected session should be deallocated and no users should be forced to log off
    - Keep in mind that the scaling plan has to be in the same time zone as the host pool that it should be applied on

## Success Criteria
Depending on the current time, either (at least) 25% or 50% of the session hosts are available. When connecting more users, further host pools should turn on.

## Learning Resources
- [Autoscale for AVD](https://docs.microsoft.com/en-us/azure/virtual-desktop/autoscale-scaling-plan)
- [Enable scaling plans for host pools](https://docs.microsoft.com/en-us/azure/virtual-desktop/autoscale-new-existing-host-pool)
