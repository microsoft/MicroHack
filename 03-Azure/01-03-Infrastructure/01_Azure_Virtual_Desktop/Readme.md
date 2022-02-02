# Azure Virtual Desktop - Micro Hack

## Introduction

This hack is designed to help you get hands-on experience with Azure Virtual Desktop (AVD) and to ramp up for the AZ-140 AVD specialst certification. 

AVD – is a born-in-the-cloud desktop-as-a-service platform service offered entirely on our Microsoft Intelligent Cloud. 
All traditional infrastructure services such as brokering, web access, load balancer, management and monitoring are part of the AVD control plane and can be configured from the Azure portal or via the Azure Resource Manager (ARM)

AVD has quickly gained adoption across the globe with companies moving to remote work for their employees. 

This hack covers all essential artifacts of AVD and starts off by covering the basics and then digs deep into the different componets. You will encounter different types of solutions that is or could be needed in a AVD environment. 

## Learning Objectives

In this hack you will learn how to set up a Azure Virtual Desktop in a typical scenario and build it out in your own environment. Once your AVD environment is built you will learn how to scale. monitor and manage the environment with other Azure resources. 

## Content and Challenges

- Challenge 0: **[Getting started](Challenges/00-Pre-Reqs.md)**
- Challenge 1: **[Deploy a personal session host](Challenges/01-Personal-Hostpools.md)**
- Challenge 2: **[Deploy multi-session hostpool](Challenges/02-multi-session-Hostpools.md)**
- Challenge 3: **[Implement FSLogix Profile solution](Challenges/03-Implement-FSLogix-Profile-Solution.md)**
- Challenge 4: **[Start VM on connect](04-start-VM-on-connect.md)**
- Challenge 5: **[Scaling plan](05-scaling-plan.md)**
- Challenge 6: **[Configure RDP Properties](Challenges/06-RDP-properties.md)**
- Challenge 7 (optional): Monitoring (Log Analytics workspace required)
- Challenge 8 (optional): disaster recovery & backup for AVD (failover / replicate in other region) 
- Challenge 9 (optional): conditional access (MFA required)


## Prerequisites

- Azure Subscription
- Visual Studio Code (https://code.visualstudio.com/)
- Visual Studio Biceps Extension installed
- Azure CLI 
- [M365 License](https://docs.microsoft.com/en-us/azure/virtual-desktop/overview#requirements)

## Solution Guide

- Challenge 0: **[Getting started](....md)**
- Challenge 1: **[Deploy a personal session host](Solutionguide/01-Personal-Hostpools-solution.md)**
- Challenge 2: **[Deploy multi-session hostpool](Solutionguide/02-multi-session-Hostpools-solution.md)**
- Challenge 3: **[Implement FSLogix Profile Solution](Solutionguide/03-Implement-FSLogix-Profile-Solution.md)**
- Challenge 4: **[Implement „start VM on connect“ (single-session)](Solutionguide/04-start-VM-on-connect-solution.md)**
- Challenge 5: **[Setup scaling-plan (multi-session)](Solutionguide/05-scaling-plan-solution.md)**
- Challenge 6: **[Configure RDP Properties](Solutionguide/06-RDP-properties-solution.md)**
- Challenge 7 (optional): Monitoring (Log Analytics workspace required)
- Challenge 8 (optional): disaster recovery & backup for AVD (failover / replicate in other region) 
- Challenge 9 (optional): conditional access (MFA required)

## Contributor
- Ben Martin Baur
- Angelika Gerl
- Leonie Mueller
