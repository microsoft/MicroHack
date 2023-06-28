# Exercise 7: What Network will be used by Interconnect Appliances? - Configure Network Profile

[Previous Challenge Solution](./06-HCX-Site-Pair.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./08-HCX-Compute-Profiles.md)

## Create Network Profile

VMware HCX Connector deploys a subset of virtual appliances (automated) that require multiple IP segments. When you create your network profiles, you use the IP segments that have been identified during the VMware HCX Network Segments pre-deployment preparation and planning stage.

### Note

Generally in a customer scenario we create multiple network profiles for the networks below

#### Management	
#### vMotion
#### Replication
#### Uplink


For this MicroHack, we will be using the same network profile for all the four networks

1.	Under Infrastructure, select Interconnect > Multi-Site Service Mesh > Network Profiles > Create Network Profile.

![](./Images/07-HCX-Network-Profiles/HCX_image18.png)

2.	For each network profile, select the network and port group, provide a name, and create the segment's IP pool. Then select Create. Please refer to the Credentials&IP document for the details for the IP addresses to be used
 
![](./Images/07-HCX-Network-Profiles/NetworkProfile.PNG)

3.	Once done, the network profile created by you will be available to be used by the Interconnect and Network Extension appliances within the Service Mesh