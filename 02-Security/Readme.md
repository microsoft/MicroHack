# **Microsoft Security MicroHacks**

# Content

[MicroHack introduction and context](#microhack-introduction-and-context)

[What is a MicroHack?](#what-is-a-microhack)

[How does it work?](#how-does-it-work)

[What is the benefit?](#what-is-the-benefit)

[Why for security?](#why-for-security)

[Prerequisites](#prerequisites)

[Architecture for this MicroHack Series](#overall-architecture-for-microsoft-security-microhack-series)

[MicroHack 1: How to collect all my security relevant log data? (Log Analytics)](#microhack-1-how-to-collect-all-my-security-relevant-log-data-log-analytics) 

[MicroHack 2: How can I further increase my security baseline? (Azure Defender)](#microhack-2-how-can-i-further-increase-my-security-baseline-azure-defender) 

[MicroHack 3: How can security be handeled in a multi-cloud environment? (Azure Arc)](#microhack-3-how-can-security-be-handeled-in-a-multi-cloud-environment-azure-arc-aws-gcp-splunk) 

[MicroHack 4: How do I react to alerts and how do I avoid them next time with advanced hunting? (Azure Sentinel)](#microhack-4-how-do-i-react-to-alerts-and-how-do-i-avoid-them-next-time-with-advanced-hunting-azure-sentinel-nils) 

# MicroHack introduction and context

MicroHacks are great for building base knowledge for people new to a technical area. However, they are often too high-level to build technical readiness in many niche areas of Azure that our customers need support on.  Our teams often hear from customers once they have read documentation and tried to setup a PoC. If this fails, they come to us looking for support. To be effective in this situation we need to build additional ‘hands on’ technical readiness.

## What is a MicroHack? 
A MicroHack is a small workshop, less than four hours, where you’ll get hands-on experience and solve different challenges to better understand a certain technology / topic. Let’s say, it’s the mini Version of an OpenHack which focuses on real life scenario or transformation.

## How does it work? 

There are many small individual MicroHacks that build on each other and therefore have certain dependencies. In each MicroHack the requirements are therefore described to understand exactly what must be done before. The procedure is described relatively simple and explained step by step what to do. You have to fulfill certain challenge based tasks before you can continue with the next challenge. At first glance, everything looks simple, but if you take a closer look, the whole construct is revealed at the end of the MicroHack series. 

## What is the benefit? 

The great benefit of MicroHacks is that you can quickly, precisely and hands on understand one or the combination of several services. There are often only a few concrete tasks to do and the hands on experience is lifted to the next level in a very short time. After completing all the challenges you will almost certainly have jumped over your own shadow, expanded the mindset and can directly deal with the implementation in practice and outside of a lab environment. 

## Why for Security?

Security is still not taken seriously in many areas and is pushed along as a necessary evil in IT strategy or projects. Security experts are often not taken seriously or the management does not understand what these security teams actually do and why they are important. The last years, months and weeks have hopefully shown how important the topic of cybersecurity is for a company not only from a technical, but also from an organizational and risk management perspective. In order to put your on premise, Azure or multi-cloud strategy on a solid footing from a security perspective and to create a next generation security approach, you first have to understand how you can actually collect and process the relevant information in a centralized manner. 

- [Why Microsoft?](https://www.microsoft.com/en-us/security/business)
- [Why Zero Trust?](https://www.microsoft.com/en-us/security/business/zero-trust)


# Prerequisites

### Subscription

To be able to perform the microhacks, it would be great if you had a subscription with contributor rights and you were allowed to use Azure Security Services. This is necessary to perform certain actions.

### Permissions

- Contributor on your Subscription / Resource Group
- Azure AD rights for Activity Log connection


# Overall Architecture for Microsoft Security MicroHack Series

![image](./Architecture.svg)

# Available MicroHacks

## [MicroHack 1: How to collect all my security relevant log data? (Log Analytics)](https://github.com/nilsbankert/MicroHacks-Microsoft-Security/blob/main/1-MicroHacks-Azure-Security/1-MicroHack-Log-Analytics/readme.md)

### Topic and context

This MicroHack scenario walks through the use of Log Analytics and with a focus on security log collection. Specifically, this builds up to include working with an existing infrastructure to get an overview how to collect relevant security logs.

### Expected Learning outcome

Know how to build a basic log analytics workspace design and connect a new workspace to relevant services
Understand default security log configuration
Have an overview of why log analytics is important to build an overall security baseline
Understand the basics from log analytics and how it relates to the Azure security products

[Click here to start the first MicroHack](https://github.com/nilsbankert/MicroHacks-Microsoft-Security/blob/main/1-MicroHacks-Azure-Security/1-MicroHack-Log-Analytics/readme.md)

## MicroHack 2: How can I further increase my security baseline? (Azure Defender)

Topic
Scope
Expected Learning outcome
Dependencies

## MicroHack 3: How can security be handeled in a multi-cloud environment? (Azure Arc, AWS, GCP, Splunk)

## MicroHack 4: How do I react to alerts and how do I avoid them next time with advanced hunting? (Azure Sentinel) (Nils)

## Other MicroHacks
