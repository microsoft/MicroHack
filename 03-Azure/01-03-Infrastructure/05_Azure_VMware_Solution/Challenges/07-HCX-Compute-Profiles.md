# HCX Configure Compute Profile

[Previous Challenge](./06-HCX-Network-Profiles.md) - **[Home](../Readme.md)** - [Next Challenge](./08-HCX-Service-Mesh.md)

## Introduction

A Compute Profile configuration is required for Service Mesh deployments. It defines deployment parameters of interconnect and network extension appliances within On Prem

## Characteristics of Compute Profiles

1. An HCX Manager system must have one Compute Profile.

2. Compute Profile references clusters and inventory within the vCenter Server that is registered in HCX Manager (other vCenter Servers require their own HCX Manager).

3. Creating a Compute Profile does not deploy the HCX appliances (Compute Profiles can be created and not used).

4. Creating a Service Mesh deploys appliances using the settings defined in the source and destination Compute Profiles.

5. A Compute Profile is considered "in use" when it is used in a Service Mesh configuration.

6. Changes to a Compute Profile profile are not effected in the Service Mesh until a Service Mesh a Re-Sync action is triggered.

## Challenge 

In this challenge, you will perform the following tasks:

1.	Create Compute Profile

As a part of this challenge you are also expected to <u>log on to the On Prem vCenter server and HCX Manager plugin in the On-Prem vCenter</u> to configure the Compute Profile

Please carefully follow the instructions provided by your facilitator. Incorrectly deploying the HCX may result in multiple forthcoming steps not operating as expected.

Work with the instructor to ensure your VMware environment has the required permissions to access your AVS vCenter Server.

## Success Criteria

The Compute Profile is created and can be used.

## Learning resources

### Solution - Spoilerwarning

[Solution Steps](../Solutionguide/07-HCX-Compute-Profiles.md)