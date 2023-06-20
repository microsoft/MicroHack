# NSX Add Segment
[Previous Challenge](./01-NSX-DHCP.md) - **[Home](../Readme.md)** - [Next Challenge](./03-NSX-Add-DNS-Forwarder.md)

## Introduction

In this challenge we will configure a NSX-T Segment.

## Challenge 

In this challenge, you will perform the following tasks:

1.	Add a Network Segment
2.	Attach a Virtual Machine to the Network Segment

As a part of this challenge you are also expected to <u>log on to the jump server assigned to your user</u> and create a network segment from NSX and then a DHCP range will be defined within that segment. When a  virtual machine will be connected to that segment they VM will automatically obtain the IP from the DHCP range.  

### Note

An AVS segment can be created both in the NSX portal and AVS portal

## Use Case Tip 

VMs within the AVS environment can be easily segmented into multiple subnets etc. without the need for physical routers and switches

Customers can easily achieve data center segmentation with a few simple steps without changing any of the underlying physical network configurations with VMware NSX and vSphere 

Please carefully follow the instructions provided by your facilitator. 

Work with the instructor to ensure your VMware environment has the required permissions to access your AVS vCenter Server and the NSX Manager.

## Success Criteria

## Learning resources