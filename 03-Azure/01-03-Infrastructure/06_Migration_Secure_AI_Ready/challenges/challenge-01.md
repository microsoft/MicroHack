# Challenge 1 - Prerequisites and landing zone preparation

**[Home](../Readme.md)** - [Next Challenge](challenge-02.md)

> [!IMPORTANT]
> **Many of the resource deployments in this Hack are adapted from the [Jumpstart ArcBox for IT Pros](https://jumpstart.azure.com/azure_jumpstart_arcbox/ITPro). Special thanks to the [Jumpstart Team](https://aka.ms/arcjumpstart) for their excellent work.**

## Goal

- Understand the preprovisioned single-resource-group lab, its source and destination networks, and the four nested Hyper-V VMs.
- Receive your platform dashboard connection details and verify that the lab is ready.

## Actions

- Open the platform dashboard and record your assigned subscription, `<YOUR-LAB-RESOURCE-GROUP>`, Hyper-V host name, and login credential fields.
- Connect through Azure Bastion, verify the host readiness status and four running nested VMs, and open both web dashboards.
- Leave discovery, migration, monitoring, and App Service configuration for the later challenges. Instructors handle [predeployment](../resources/README.md).

## Success criteria

- You have understood the concept and architecture for the Hack.
- Your one assigned resource group contains the source VNet (`10.1.0.0/16`), destination VNet (`10.2.0.0/16`), NAT Gateways, Bastion access, Key Vault, and the Hyper-V host named in your dashboard (for example, `mh-0013-hv` in a fresh `rg-labuser-0013` lab).
- At initial handoff, the host VM's tags are `DeploymentProgress=Deployment Completed` and `LabReady=single-rg-v1`, the schema-version-1 marker `C:\MHBox\lab-ready.json` is present, and all four nested VMs are running.
- The Windows/IIS and Ubuntu/Apache demo dashboards return HTTP success and show the correct hostname, platform, and web server.

## Learning resources

- [What is Bicep?](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep)
