# Optional Challenge 6 - Secure on Azure

[Previous Challenge](challenge-05.md) - **[Home](../Readme.md)** - [Next Challenge](challenge-07.md)

## Goal

The goal of this exercise is to ...

* verify and use Defender for Cloud for Servers protection on the migrated virtual machines in your lab resource group.

## Prerequisites

* Learners have **Owner on the Hack subscription**. Subscription-wide plan changes affect every learner, so do not change shared settings without instructor approval.
* The instructor has confirmed that the shared subscription's Defender CSPM and Defender for Servers plans are enabled and has approved their costs.

> [!NOTE]
> In the hosted environment, Defender plans are likely already enabled on the shared subscription through Azure Policy enforcement. Verify the current status of both required plans before requesting activation; do not disable or downgrade policy-managed plans.

## Actions

* Check the existing Defender plans first. If a required plan is missing, ask the instructor to confirm policy enforcement or approve activation. Then inspect endpoint protection and review alerts and recommendations for your lab resources.

## Success criteria

* The migrated servers are protected by Defender for Cloud for Servers.

## Learning resources
* [Deploy Defender for Servers](https://learn.microsoft.com/en-us/azure/defender-for-cloud/tutorial-enable-servers-plan)
