# **Nutanix Cloud Clusters (NC2) on Azure BareMetal**
# Contents

- [**MicroHack introduction**](#MicroHack-introduction)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
- [**Contributors**](#contributors)
# MicroHack introduction

This MicroHack scenario walks through deploying a Nutanix Cloud Clusters(NC2) onto Azure BareMateal. NC2 (Nutanix Cloud Clusters) offers a secure and frictionless way for you to run and manage workloads on public cloud bare metal nodes in your own cloud accounts. This enables low latency access to cloud-native services with predictable Nutanix resilience, efficiency, and performance. All from a unified management console, Prism, across on-premises, edge, and public clouds.

NC2 (Nutanix Cloud Clusters) on Microsoft Azure is a solution jointly engineered by Nutanix and Azure teams. It offers bare metal as a service to customers from a hardware consumption perspective, and NC2 provides a consistent experience for provisioning and managing clusters deployed in Azure.

NC2 situates the complete Nutanix hyperconverged infrastructure (HCI) stack directly on a BareMetal instance. This bare-metal instance runs a Controller VM (CVM) and Nutanix AHV as the hypervisor just like any on-premises Nutanix deployment, using the Azure Virtual Network (VNet) to connect to the network.
  
Prism Central then works with AHV and NC2 to use Flow Virtual Networking to create an overlay that provides granular control. Flow Virtual Networking enables connectivity to all Azure services and enables workloads running on the clusters to send and receive north- and south-bound traffic.
You will see how to provision a cluster using Nutanix Flow virtual networking in Azure, configuring your Nutanix Cluster and using DR to migrate workloads from on-premises to Azure. 

This MicroHack is a guided walkthru due to cost of resources and time for provisioning. 

![image](img/AzureClusters-networkingsimple.png)

NC2 uses Flow Virtual Networking in Azure to create an overlay network that simplifies administration and reduces networking constraints across cloud vendors. Flow Virtual Networking masks or reduces cloud constraints by providing an abstraction layer and allows the network substrate (and its associated features and functionalities) to be consistent with the customer's on-premises Nutanix deployments. You can create new virtual networks (called virtual private clouds or VPCs) in Nutanix with subnets in any address range, including those from the RFC1918 (private) address space, and define DHCP, Network Address Translation (NAT), routing, and security policies from the familiar Prism Central interface.

The simplicity provided by Flow Virtual Networking can be seen in the way it allows you to handle subnets. Subnet delegation enables you to designate a specific subnet for an Azure platform as a service (PaaS) that you need to inject into your virtual network, but Azure only allows one delegated subnet per VNet. NC2 needs a management subnet delegated to the Microsoft.BareMetal/AzureHostedService in order to deploy Nutanix clusters, and every subnet used for user-native VM networking also needs to be delegated to the same service. Because a VNet can have only one delegated subnet, networking configuration can quickly get out of hand with VNets peered among each other to allow communication.

This lab is not a full explanation of Nutanix Clusters(NC2) as a technology, please consider the following articles required pre-reading to build foundational knowledge.

- <a href="https://portal.nutanix.com/page/documents/solutions/details?targetId=TN-2156-NC2-on-Azure:TN-2156-NC2-on-Azure" target="_blank">NC2 on Azure Technote</a>
- <a href="https://portal.nutanix.com/page/documents/details?targetId=Nutanix-Cloud-Clusters-Azure:Nutanix-Cloud-Clusters-Azure" target="_blank">Nutanix Cloud Clusters on Azure Deployment and User Guide</a>


# MicroHack context
This MicroHack scenario walks through the deploying a NC2 cluster in Azure, configuring the cluster and looking at the resources we created in our Microsoft Resource Group. 

Once we have our NC2 cluster up and running we will migrate workloads from on-premises to Azure. We will use Prism Central Data Protection capabilities to configure Protection Policies and Recovery Plans to protect our virtual workloads and data in the event of a disaster.


# Objectives

After completing this MicroHack you will:

- Know how to provision a Nutanix Cloud Cluster.
- Understand the resources created in your Microsoft Azure subscription. 
- Use native DR features in Nutanix Prism Central to protect and migrate workloads to Azure.

# MicroHack challenges

## General prerequisites

This MicroHack is a guided walk-through so you only need to have a Internet connection.


## Challenge 1 - Deploying a Nutanix Cloud Cluster(NC2)

### Goal 

The goal of this exercise is to deploy a NC2 cluster on Azure BareMetal.

### Actions

Follow Step 1 of the guided <a href="https://nutanix.storylane.io/share/4vvvcvdwohxd" target="_blank"> Simple Provisioning - step 1</a>

### Success criteria

* You have reached the "Cluster is created" and The Flow Gateway VM has been deployed. We can start to configure Flow Virtual Networking and VPCs in Prism Central in Challenge 2.

## Challenge 2 - Azure resources and Nutanix Flow Virtual Networking

### Goal 

The goal of this exercise is to view the deployed resource in our Azure portal and to configure networking in Prism Central.

### Actions

Follow Step 2 of the guided <a href="https://nutanix.storylane.io/share/4vvvcvdwohxd" target="_blank">Cluster Configuration - step 2</a>


### Success criteria

* You have setup a Nutanix Virtual Flow networking VPC with a new subnet to be used for a migration. 

### Learning resources
Link to <a href="https://portal.nutanix.com/page/documents/details?targetId=Nutanix-Flow-Virtual-Networking-Guide-vpc_2023_1_0_1:Nutanix-Flow-Virtual-Networking-Guide-vpc_2023_1_0_1" target="_blank">https://portal.nutanix.com/page/documents/details?targetId=Nutanix-Flow-Virtual-Networking-Guide-vpc_2023_1_0_1:Nutanix-Flow-Virtual-Networking-Guide-vpc_2023_1_0_1</a>

## Challenge 3 - Migrating Your Application using Nutanix DR from on-premises to Azure 

### Goal 

The goal of this exercise is to use Nutanix Prism Central Data Protection capabilities to configure Protection Policies and Recovery Plans to protect our virtual workloads and data in the event of a disaster. We will then migrate our applications to our Azure NC2 cluster. 

### Actions

* Follow Step 3 of the guided <a href="https://nutanix.storylane.io/share/4vvvcvdwohxd" target="_blank">Nutanix DR - step 3</a>


### Success criteria

* You have successfully e performed a successful planned failover and your workloads are now running in Azure!

### Learning resources
* Link to <a href="https://portal.nutanix.com/page/documents/details?targetId=Disaster-Recovery-DRaaS-Guide-vpc_2023_1_0_1:Disaster-Recovery-DRaaS-Guide-vpc_2023_1_0_1" target="_blank">https://portal.nutanix.com/page/documents/details?targetId=Disaster-Recovery-DRaaS-Guide-vpc_2023_1_0_1:Disaster-Recovery-DRaaS-Guide-vpc_2023_1_0_1</a>


## Finish

Congratulations! You finished the MicroHack Nutanix Cloud Clusters (NC2) on Azure BareMetal. We hope you had the chance to learn about the how to quickly deploy and migrate your workloads to Azure.
If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!


## Contributors
* Dwayne Lessner [GitHub](https://github.com/dlessner); [LinkedIn](https://www.linkedin.com/in/dwaynelessner/)
