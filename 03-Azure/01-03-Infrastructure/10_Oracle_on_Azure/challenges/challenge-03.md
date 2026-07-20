# Challenge 3 - Update the Oracle ADB NSG and DNS

[Previous Challenge Solution](challenge-02.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-04.md)

Update the Network Security Group to allow traffic from the AKS environment and register the Oracle private endpoints in the AKS Private DNS zones. Validate connectivity from AKS after both security and DNS changes are applied.

## Actions
* Set the NSG of the CIDR on the OCI side, to allow Ingress from the AKS on the ADB
* Extract the ODAA FQDN and IP Address and assign them to the Azure Private DNS Zones linked to the AKS VNet.  

## Sucess criteria
* Set the NSG of the CIDR on the OCI side, to allow Ingress from the AKS on the ADB
* DNS is setup correctly. <font color=red><b>Important:</b> Without a working DNS the next Challenge will failed.</font>

## Learning Resources
* [Network security groups overview](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview),
* [Private DNS zones in Azure](https://learn.microsoft.com/azure/dns/private-dns-privatednszone), 
* [Oracle Database@Azure networking guidance](https://docs.oracle.com/en-us/iaas/Content/database-at-azure/azucr-networking-overview.htm)

