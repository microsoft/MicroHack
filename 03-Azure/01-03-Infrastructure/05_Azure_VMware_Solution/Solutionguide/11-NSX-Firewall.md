# Exercise 11: Lets explore NSX - Stepping stone to Microsegmentation

[Previous Challenge Solution](./10-AVS-Migrate-VM.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./12-AVS-ANF-Datastores.md)

## Create a Distributed firewall

Use the VMs that you migrated in the last step to create a distributed firewall rule between the 2 VMs.

Workload-1-1-1 & Workload-1-1-2

1.	From your browser, log in to an NSX Manager at the URL and credentials indicated here:

    ![](./Images/11-NSX-Firewall/NSX_image21.png)

    ![](./Images/11-NSX-Firewall/NSX_image22.png)

    ![](./Images/11-NSX-Firewall/NSX_image23.png)

2.	Go to Inventory > Groups > Add Group

    ![](./Images/11-NSX-Firewall/NSX_image24.png)
 
3.	Add a group name as Application1 and then press Set Compute Members

    ![](./Images/11-NSX-Firewall/NSX_image25.png)
 
4.	Add the IP of Workload-1-1-1 VM IP to this group and the press Apply

    ![](./Images/11-NSX-Firewall/NSX_image27.png)
 
5.	Then press save button

    ![](./Images/11-NSX-Firewall/NSX_image28.png)

6.	Now create a second Application group and click set members

    ![](./Images/11-NSX-Firewall/NSX_image29.png)
 
7.	Click the IP addresses and then provide the IP address of the AVS Workload-1-1-2 VM and then press apply

    ![](./Images/11-NSX-Firewall/NSX_image30.png)

8.  Then press save button
 
9.	Select Security > Distributed Firewall from the navigation panel and click Add Policy

    ![](./Images/11-NSX-Firewall/NSX_image32.png)
 
10.	Enter a Name for the new policy section. Example: AVS-Microhack-Policy

    ![](./Images/11-NSX-Firewall/NSX_image39.png)
 
11.	Click Add Rule and name it. Example: AVS-Microhack-Policy
 
    ![](./Images/11-NSX-Firewall/NSX_image40.png)

12.	Set source for the rule by selecting the first Application group and then press apply

    ![](./Images/11-NSX-Firewall/NSX_image33.png)
 
13.	Set destination for the rule by selecting the first Application group and then press apply

    ![](./Images/11-NSX-Firewall/NSX_image34.png)
 
14.	Keep the action as Allow and then press publish

    ![](./Images/11-NSX-Firewall/NSX_image35.png)

15.	One you firewall rule has been published, ping the Workload-1-1-2 VM from Workload-1-1-2 VM. We should notice that the ping is going through

     ![](./Images/11-NSX-Firewall/NSX_image37.png)

16.	Now come back to the distributed firewall and set the action to reject

     ![](./Images/11-NSX-Firewall/NSX_image36.png)

17.	Now ping the Workload-1-1-2 VM from Workload-1-1-1 VM. We should notice that the ping is blocked.

     ![](./Images/11-NSX-Firewall/NSX_image38.png)
     
> [!NOTE]
> Please [Visit AVS Hub](https://www.avshub.io/workshop-guide/#credentials-for-the-workload-vms) for VM Credentials

This proves the distributed firewall rule between the 2 application groups
