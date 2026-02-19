# Sign in to Azure

Sign in to the Azure portal with your Azure account.


# Create a virtual network and subnet delegation

The following procedure creates a virtual network with a resource subnet, an Azure Bastion subnet, and a Bastion host:

1. In the portal, search for and select Virtual networks.

2. On the Virtual networks page, select + Create.

3. On the Basics tab of Create virtual network, enter, or select the following information:

![image](./img/create-virtual-network-basics.png)


4. Select Next to proceed to the IP Addresses tab.

5. In the address space box in Subnets, select the default subnet.

6. In Edit subnet, enter or select the following information:

* Subnet purpose: Leave the default of Default.
* Name: Enter subnet-1.
* IPv4 address range: Leave the default of 10.0.0.0/16.
* Starting address: Leave the default of 10.0.0.0.
* Size: Leave the default of /24 (256 addresses).

7. Select Save

8. Select Review + create at the bottom of the window. When validation passes, select Create

