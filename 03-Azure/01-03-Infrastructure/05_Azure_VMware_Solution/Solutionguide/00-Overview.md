# Overview about the Microhack enivorment

The general lab environment for this Microhack is a combination of Azure and Azure VMware Solution (AVS). The lab environment consists of the following components:

![](./Images/00-Overview/Architecture.png)

For the solution of each challenge you will need to use the following information:

## Resources AVS SDDC

| Type | Name  |
|------| ----| 
| Jumpbox VM | AVS-SDDC-FOM-Jumpbox |
| Azure Key Vault | AVS-Microhack |
| vCenter on AVS | AVS-SDDC-FOM-SDDC |

## vCenter onprem

| Type | Name  |
|------| ----| 
| vCenter on-prem | 10.1.1.2 |
| HCX Manager on-prem | 10.1.1.9 |
| Workload-1-1-1 | 10.1.11.129 |
| Workload-1-1-2 | 10.1.11.130 |

## VMs in the onprem SDDC

| Name | IP  |
|------| ----| 
| win2022-dc | 10.1.1.30|
| win2022-worker | 10.1.1.31 |