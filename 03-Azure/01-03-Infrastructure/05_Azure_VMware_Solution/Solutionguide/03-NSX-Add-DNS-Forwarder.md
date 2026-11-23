# Exercise 3: Lets explore NSX - So we need to add a DNS Forwarder

[Previous Challenge Solution](./02-NSX-Add-Segment.md) - **[Home](../Readme.md)** - [Next Challenge Solution](./04-HCX-Manager-Appliance.md)

## Configure a DNS forwarder

1.  In your Azure VMware Solution private cloud, under Workload Networking, select DNS > DNS zones. Then select Add.

![](./Images/03-NSX-Add-DNS-Forwarder/DNS1.png)

2.  Add the On-Prem FQDN zone by inputting details regarding the DNS Zone Name, Domain Name and DNS Seever IP from the Credentials&IP document and press save 

![](./Images/03-NSX-Add-DNS-Forwarder/DNS2.png)

3.  Attach the configured DNS Zone name to Default DNS Zone and press save

![](./Images/03-NSX-Add-DNS-Forwarder/DNS3.png)

![](./Images/03-NSX-Add-DNS-Forwarder/DNS4.png)

### Note : 

These DNS zones are a prerequisite for LDAP configuration for NSX.