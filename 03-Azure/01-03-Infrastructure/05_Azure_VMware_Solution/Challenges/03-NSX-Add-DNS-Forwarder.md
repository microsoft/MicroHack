# NSX Add Segment

[Previous Challenge](./02-NSX-Add-Segment.md) - **[Home](../Readme.md)** - [Next Challenge](./04-NSX-Firewall.md)

## Introduction

By default, Azure VMware Solution management components such as vCenter can only resolve name records available through Public DNS. However, certain hybrid use cases require Azure VMware Solution management components to resolve name records from privately hosted DNS to properly function, including customer-managed systems such as vCenter and Active Directory.

Private DNS for Azure VMware Solution management components lets you define conditional forwarding rules for the desired domain name to a selected set of private DNS servers through the NSX-T DNS Service.

This capability uses the DNS Forwarder Service in NSX-T. A DNS service and default DNS zone are provided as part of your private cloud. To enable Azure VMware Solution management components to resolve records from your private DNS systems, you must define an FQDN zone and apply it to the NSX-T DNS Service. The DNS Service conditionally forwards DNS queries for each zone based on the external DNS servers defined in that zone.

## Challenge 

In this challenge, you will perform the following tasks:

1.	Configure a DNS forwarder within NSX such that the On Prem FQDN can be resolved from AVS itself

Since the default DNS is preconfigured with AVS, to test DNS we are using a feature where we need name resolution

As a part of this challenge you are also expected to <u>log on to the AVS Private cloud assigned to your team</u> and create a DNS forwarder within NSX such that the On Prem FQDN can be resolved from AVS itself. You can use this to also import images from On Prem to AVS using a content library which is configured On Prem

## Success Criteria

By the end of this challenge you should independantly be able to answer the following questions

1. What benefits does DNS forwarder get here?
2. How can you resolve AVS On-Prem FQDN on AVS?
3. How will you go about configuring LDAP integration for NSX? 

## Learning resources

### Solution - Spoilerwarning

[Solution Steps](../Solutionguide/03-NSX-Add-DNS-Forwarder.md)