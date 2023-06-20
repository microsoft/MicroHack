# Getting started

**[Home](../readme.md)** - [Challenge One](./01-NSX-DHCP.md)

## Introduction

Azure VMware Solution delivers VMware-based private clouds in Azure and is available for EA and CSP customers. Customers need to request a quota and register the Microsoft.AVS resource provider prior to deploying:

[Request host quota for Azure VMware Solution - Azure VMware Solution | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-vmware/request-host-quota-azure-vmware-solution)

[Deploy and configure Azure VMware Solution - Azure VMware Solution | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-vmware/deploy-azure-vmware-solution?tabs=azure-portal)

As the service isn’t available in all regions yet please check for local coverage in the required regions:

[Azure Products by Region | Microsoft Azure](https://azure.microsoft.com/en-us/global-infrastructure/services/?regions=all&products=azure-vmware)

Each private cloud will have a minimum of one vSAN cluster that consists of three hosts. Additional hosts, clusters or even private clouds can be added to your Azure subscription depending on your requirements and available host quotas.

There is also the option of a trial cluster, these are limited to three hosts and one month duration. After the trial period those hosts will be converted to regular AVS hosts.

[Concepts - Private clouds and clusters - Azure VMware Solution | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-vmware/concepts-private-clouds-clusters)

## Learning resources
