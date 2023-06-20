# Exercise 2: Add a NSX-T Segment

[Previous Challenge Solution](./01-NSX-DHCP.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./03-NSX-Add-DNS-Forwarder.md)

## Add a Network Segment
1.	In NSX-T Manager, select Networking > Segments, and then select Add Segment.

![](./Images/02-NSX-Add-Segment/NSXSegment002.PNG)
 
2.	Enter a name for the segment.

3.	Select the Tier-1 Gateway (TNTxx-T1) as the Connected Gateway 

4.	Select the pre-configured overlay Transport Zone (TNTxx-OVERLAY-TZ) and then select Set Subnets in gateway/prefix length format.

![](./Images/02-NSX-Add-Segment/NSXSegment003.PNG)

5. Add DHCP range to your segment such that the VM's attached to this segment can recieve IP address dynamically

![](./Images/02-NSX-Add-Segment/NSXSegment004.PNG)

6.	Select Apply and then Save.

### Note
The IP address needs to be on a non-overlapping RFC1918 address block, which ensures connection to the VMs on the new segment.

7. Once the segment is created  refer to the “Credentials&IP” document to attach the respective virtual machine listed there to the new segment that has been created and verify that the virtual machine is getting an IP from the DHCP

### Hint

The segment needs to attach to the virtual machine by right clicking the VM > Edit Settings > Network Adaptor 1 
