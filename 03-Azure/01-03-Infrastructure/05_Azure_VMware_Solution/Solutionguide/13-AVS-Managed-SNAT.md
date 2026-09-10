# AVS Managed SNAT

[Previous Challenge Solution](./14-AVS-Placement-Policy.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./16-AVS-Automation-ESLZ.md)

# Internet Service hosted in Azure

There are multiple ways to generate a default route in Azure and send it towards your Azure VMware Solution private cloud or on-premises. The options are as follows:

1. An Azure firewall in a Virtual WAN Hub.
2. A third-party Network Virtual Appliance in a Virtual WAN Hub Spoke Virtual Network.
3. A third-party Network Virtual Appliance in a Native Azure Virtual Network using Azure Route Server.
4. A default route from on-premises transferred to Azure VMware Solution over Global Reach.

Use any of these patterns to provide an outbound SNAT service with the ability to control what sources are allowed out, to view the connection logs, and for some services, do further traffic inspection.

The same service can also consume an Azure Public IP and create an inbound DNAT from the Internet towards targets in Azure VMware Solution.

An environment can also be built that utilizes multiple paths for Internet traffic. One for outbound SNAT (for example, a third-party security NVA), and another for inbound DNAT (like a third party Load balancer NVA using SNAT pools for return traffic).

## Azure VMware Solution Managed SNAT
A Managed SNAT service provides a simple method for outbound internet access from an Azure VMware Solution private cloud. Features of this service include the following.

Easily enabled – select the radio button on the Internet Connectivity tab and all workload networks will have immediate outbound access to the Internet through a SNAT gateway.
No control over SNAT rules, all sources that reach the SNAT service are allowed.
No visibility into connection logs.
Two Public IPs are used and rotated to support up to 128k simultaneous outbound connections.
No inbound DNAT capability is available with the Azure VMware Solution Managed SNAT.

## Azure Public IPv4 address to NSX-T Data Center Edge
This option brings an allocated Azure Public IPv4 address directly to the NSX-T Data Center Edge for consumption. It allows the Azure VMware Solution private cloud to directly consume and apply public network addresses in NSX-T Data Center as required. These addresses are used for the following types of connections:

1. Outbound SNAT
2. Inbound DNAT
3. Load balancing using VMware NSX Advanced Load Balancer and other third-party Network Virtual Appliances
4. Applications directly connected to a workload VM interface.

This option also lets you configure the public address on a third-party Network Virtual Appliance to create a DMZ within the Azure VMware Solution private cloud.

## Features include:

Scale – the soft limit of 64 Azure Public IPv4 addresses can be increased by request to 1,000s of Azure Public IPs allocated if required by an application.
Flexibility – An Azure Public IPv4 address can be applied anywhere in the NSX-T Data Center ecosystem. It can be used to provide SNAT or DNAT, on load balancers like VMware’s NSX Advanced Load Balancer, or third-party Network Virtual Appliances. It can also be used on third-party Network Virtual Security Appliances on VMware segments or directly on VMs.
Regionality – the Azure Public IPv4 address to the NSX-T Data Center Edge is unique to the local SDDC. For “multi private cloud in distributed regions,” with local exit to Internet intentions, it’s much easier to direct traffic locally versus trying to control default route propagation for a security or SNAT service hosted in Azure. If you've two or more Azure VMware Solution private clouds connected with a Public IP configured, they can both have a local exit.

## Considerations for selecting an option
The option that you select depends on the following factors:

1. To add an Azure VMware private cloud to a security inspection point provisioned in Azure native that inspects all Internet traffic from Azure native endpoints, use an Azure native construct and leak a default route from Azure to your Azure VMware Solution private cloud.
2. If you need to run a third-party Network Virtual Appliance to conform to existing standards for security inspection or streamlined opex, you have two options. You can run your Azure Public IPv4 address in Azure native with the default route method or run it in Azure VMware Solution using Azure Public IPv4 address to NSX-T Data Center Edge.
3. There are scale limits on how many Azure Public IPv4 addresses can be allocated to a Network Virtual Appliance running in native Azure or provisioned on Azure Firewall. The Azure Public IPv4 address to NSX-T Data Center Edge option allows for much higher allocations (1,000s versus 100s).
4. Use an Azure Public IPv4 address to the NSX-T Data Center Edge for a localized exit to the internet from each private cloud in its local region. Using multiple Azure VMware Solution private clouds in several Azure regions that need to communicate with each other and the internet, it can be challenging to match an Azure VMware Solution private cloud with a security service in Azure. The difficulty is due to the way a default route from Azure works.

This concludes the enablement of internet connectivity for workloads in AVS!!