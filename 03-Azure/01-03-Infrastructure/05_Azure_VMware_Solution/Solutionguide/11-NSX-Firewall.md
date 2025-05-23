# Exercise 11: Lets explore NSX - Stepping stone to Microsegmentation

[Previous Challenge Solution](./10-AVS-Migrate-VM.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./12-AVS-ANF-Datastores.md)

## Create a Distributed firewall

Use the VMs that you migrated in the last step to create a distributed firewall rule between the 2 VMs.

Workload-1-1-1 & Workload-1-1-2

1.	From your browser, log in with admin privileges to an NSX Manager at https://10.83.0.3

2.	Go to Inventory > Groups > Add Group 
 
3.	Add a group name as Application1 and then press Set Members

![](./Images/11-NSX-Firewall/NSX_image10.png)
 
4.	Add the IP of Workload-1-1-1 VM IP to this group and the press apply

![](./Images/11-NSX-Firewall/NSX_image11.png)
 
5.	Then press save button
 
![](./Images/11-NSX-Firewall/NSX_image12.png)

6.	Now create a second Application group and click set members

![](./Images/11-NSX-Firewall/NSX_image13.png)
 
7.	Click the IP addresses and then provide the IP address of the AVS Workload-1-1-2 VM and then press apply

![](./Images/11-NSX-Firewall/NSX_image14.png)
 
8.	Select Security > Distributed Firewall from the navigation panel.

9.	Click Add Policy

![](./Images/11-NSX-Firewall/NSX_image15.png)
 
10.	Enter a Name for the new policy section.

![](./Images/11-NSX-Firewall/NSX_image16.png)
 
11.	Click Add Rule
 
![](./Images/11-NSX-Firewall/NSX_image17.png)

12.	Set source for the rule by selecting the first Application group and then press apply

![](./Images/11-NSX-Firewall/NSX_image18.png)
 
13.	Set destination for the rule by selecting the first Application group and then press apply

![](./Images/11-NSX-Firewall/NSX_image19.png)
 
14.	Keep the action as Allow and then press publish

![](./Images/11-NSX-Firewall/NSX_image20.png)

15.	One you firewall rule has been published, ping the Workload-1-1-2 VM from Workload-1-1-2 VM. We should notice that the ping is going through

16.	Now come back to the distributed firewall and set the action to reject

17.	Now ping the Workload-1-1-2 VM from Workload-1-1-1 VM. We should notice that the ping is blocked.
> [!NOTE]
> Please [Visit AVS Hub](https://www.avshub.io/workshop-guide/#credentials-for-the-workload-vms) for VM Credentials

This proves the distributed firewall rule between the 2 application groups
