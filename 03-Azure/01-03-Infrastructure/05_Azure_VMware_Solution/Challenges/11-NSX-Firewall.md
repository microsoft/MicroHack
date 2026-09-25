# NSX Add Firewall

[Previous Challenge](./10-AVS-Migrate-VM.md) - **[Home](../Readme.md)** - [Next Challenge](./12-AVS-Placement-Policy)

## Introduction

Using the NSX Service-defined firewall, customers can gain visibility into traffic and easily create network segmentation by defining them entirely in software — no need to change your network or hairpin traffic by deploying discrete appliances. 

Please carefully follow the instructions provided by your facilitator. 

Work with the instructor to ensure your VMware environment has the required permissions to access your AVS vCenter Server and the NSX Manager.

Applications and workloads running in an Azure VMware Solution private cloud environment require name resolution and DHCP services (optionally) for lookup and IP address assignments. A proper DHCP and DNS infrastructure are required to provide these services. You can configure a virtual machine to provide these services in your private cloud environment.

## Challenge 

In this challenge, you will perform the following tasks:

1. Configure a Distributed Firewall using NSX-T

As a part of this challenge you are also expected to <u>log on to the AVS Private cloud assigned to your team</u> achieve a phased approach enabling yourself to quickly implement zone-based segmentation – for example between Application1 and Application2 – and then gradually you can deepen your security with application isolation and micro-segmentation over time.

## Success Criteria

A firewall rule is created between two application groups is created and ping is either successful or blocked respectively.

## Learning resources

### Solution - Spoilerwarning

[Solution Steps](../Solutionguide/11-NSX-Firewall.md)