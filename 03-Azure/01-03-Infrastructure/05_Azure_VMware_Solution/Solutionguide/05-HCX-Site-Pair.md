# Exercise 6: So how do we connect On Prem to AVS? - Configure Site Pairing

[Previous Challenge Solution](./04-HCX-Manager-Appliance.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./06-HCX-Network-Profiles.md)

## Add a site pairing
You can connect or pair the VMware HCX Cloud Manager in AVS with the VMware HCX Connector in your On-Prem datacenter.

1.	Go to you onprem SDDC and login to your HCX Connector under https://10.1.1.9 

![](./Images/05-HCX-Site-Pair/HCX_Sitepair1.png)

2.	Under Infrastructure, select Site Pairing, and then select the Connect To Remote Site option (in the middle of the screen).

![](./Images/05-HCX-Site-Pair/HCX_Sitepair2.png)

 ![](./Images/05-HCX-Site-Pair/HCX_Sitepair3.png)

3.	Enter the Azure VMware Solution HCX Cloud Manager URL or IP address, username and password to intiate the site pairing. 

The IP will be https://10.83.0.9 and the username and password can be found in the Azure Portal.

![](./Images/05-HCX-Site-Pair/HCX_Sitepair4.png)

 ### Note

To successfully establish a site pair:
Your VMware HCX Connector must be able to route to your HCX Cloud Manager IP over port 443.

You'll see a screen showing that your VMware HCX Cloud Manager in Azure VMware Solution and your on-premises VMware HCX Connector are connected (paired).

![](./Images/05-HCX-Site-Pair/HCX_Sitepair5.png)

![](./Images/05-HCX-Site-Pair/HCX_Sitepair6.png)