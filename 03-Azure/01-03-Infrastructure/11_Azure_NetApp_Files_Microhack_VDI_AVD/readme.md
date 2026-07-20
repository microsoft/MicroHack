![image](./img/1920x300_EventBanner_MicroHack_ANF_VDI_AVD.png)

# Azure NetApp Files Microhack VDI/AVD 

- [**MicroHack introduction**](#MicroHack-introduction)
- [**MicroHack context**](#microhack-context)
- [**Objectives**](#objectives)
- [**MicroHack Challenges**](#microhack-challenges)
- [**Contributors**](#contributors)

# MicroHack introduction

This MicroHack is a hands-on technical workshop designed to help participants build practical experience with Azure NetApp Files (ANF) in the context of Virtual Desktop Infrastructure (VDI) using Azure Virtual Desktop (AVD).

Rather than focusing only on theory or documentation, this MicroHack guides you through real-world configuration tasks and challenges that reflect common customer scenarios. MicroHacks are intentionally scoped, time‑boxed, and challenge‑driven. 

They allow you to learn by doing and to incrementally build technical confidence by solving practical problems step by step

![image](img/fsl-ccd-ha.jpg)

# MicroHack context

Many organizations adopt Azure Virtual Desktop to modernize their end-user computing strategy, but quickly encounter challenges around performance, profile management, and scalable storage.

Azure NetApp Files is a native Azure service that provides high‑performance, low‑latency file storage, making it an ideal backend for FSLogix profiles, user home directories, and application data in AVD environments.

This MicroHack places Azure NetApp Files into a realistic VDI scenario, where participants must integrate ANF with Azure networking, identity services and AVD workloads. The focus is on understanding why specific design decisions matter, not just how to configure them.

# Objectives

By completing this MicroHack, you will be able to:

Understand the role of Azure NetApp Files in a Virtual Desktop Infrastructure scenario
Create and configure an Azure NetApp Files account, capacity pools, and volumes
Integrate Azure NetApp Files with Azure Virtual Desktop
Configure networking prerequisites such as VNets and delegated subnets
Understand how ANF integrates with FSLogix user profiles and session-based workloads
Configure Azure NetApp Files backup for protecting user data
Understand how to monitor and tune Azure NetApp Files performance 
Gain hands-on experience that can be transferred directly to customer or production environments

The challenges are designed to build on each other, reinforcing learning outcomes as you progress.

# MicroHack challenges

## General prerequisites

Before starting this MicroHack, you should have:

* An active Azure subscription with sufficient permissions to create:
    * Resource groups
    * Virtual networks and subnets
    * Azure NetApp Files resources

* Basic knowledge of:
    * Azure networking concepts (VNets, subnets, delegation)
    * Azure Virtual Desktop fundamentals
    * Azure Active Directory

* Familiarity with the Azure Portal and Azure CLI or PowerShell A workstation with:
    * Internet access
    * A modern web browser
    * Access to the Azure Portal

No prior Azure NetApp Files experience is required, but a general understanding of storage concepts will be helpful.


## Challenges
* [Challenge 1 - Introduction to Azure NetApp Files](challenges/challenge-01.md)
* [Challenge 2 - Setup Network Configuration](challenges/challenge-02.md)
* [Challenge 3 - Setting Up Azure NetApp Files](challenges/challenge-03.md)
* [Challenge 4 - Azure NetApp Files for VDI/AVD Use-Case](challenges/challenge-04.md)
* [Challenge 5 - Managing and Monitoring Azure NetApp Files](challenges/challenge-05.md)
* [Challenge 6 - Azure NetApp Files Backup](challenges/challenge-06.md)
* [Challenge 7 - Best Practices and Use Cases](challenges/challenge-07.md) 


## Solutions - Spoilerwarning

* [Solution 1 - Get to know and Register](./walkthrough/challenge-01/solution-01.md)
* [Solution 2 - Setup Network Configuration](./walkthrough/challenge-02/solution-02.md)
* [Solution 3 - Setting Up Azure NetApp Files](./walkthrough/challenge-03/solution-03.md)
* [Solution 4 - Setting Up Azure NetApp Files for VDI/AVD](./walkthrough/challenge-04/solution-04.md)
* [Solution 5 - Managing and Monitoring Azure NetApp Files](./walkthrough/challenge-05/solution-05.md)
* [Solution 6 - Setting Up Azure NetApp Files Backup](./walkthrough/challenge-06/solution-06.md)
* [Solution 7 - Best Practices and Use Cases](./walkthrough/challenge-07/solution-07.md)

## Contributors

* Sascha Petrovski [GitHub](https://github.com/saschape/) [LinkedIn](https://www.linkedin.com/in/sascha-petrovski/)
* Tristan Daude [LinkedIn](https://www.linkedin.com/in/tristandaude/)