# Challenge 6 - Operating a Sovereign Hybrid Cloud with Azure Arc & Azure Local

## Goal

Explore how Azure Arc manages VMs and Kubernetes workloads on Azure Local, simulated by LocalBox. Create and manage a VM, then review the AKS load balancer, deploy a sample application, and connect to it using Arc Proxy.

## Scenario

Your organization must run workloads in a sovereign cloud while still leveraging Azure's management and governance capabilities. Azure Local represents your sovereign on-premises infrastructure, and Azure Arc enables you to apply consistent governance across your hybrid estate.

## Actions

Before starting, return your Challenge 1 exercise policies to **DoNotEnforce**. If a policy blocks deployment, use the [troubleshooting steps](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/walkthrough/challenge-06/solution-06.md#if-validation-or-deployment-is-blocked-by-a-location-policy) or ask the facilitator.

### Explore and manage a VM

* Explore the LocalBox hybrid infrastructure in the Azure Portal
* Deploy your own VM on Azure Local using Azure Arc VM management and verify that guest management is connected
* Verify Microsoft Defender for Cloud coverage and review security recommendations for the VM you provisioned
* Use Azure Update Manager to assess OS updates on the VM you provisioned

### Review the AKS load balancer and deploy an app

* Review the preinstalled **MetalLB load balancer**: check that it is healthy and understand how it assigns IP addresses to applications
* Deploy the sample application to your team's namespace on the shared AKS cluster and inspect its assigned service IP
* Connect using **Azure Arc Proxy** and port forwarding, then open the application privately in your browser
* Clean up your team's application resources, leaving the shared cluster and load balancer unchanged

Follow [Task 5 of the walkthrough](https://github.com/microsoft/MicroHack/blob/main/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/walkthrough/challenge-06/solution-06.md#task-5-deploy-a-container-to-the-aks-cluster-deployed-on-azure-local) for the commands and checks. The infrastructure is already prepared; you do not need to install MetalLB or access the LocalBox Client VM. Ask the facilitator if access or health checks fail.

In a real deployment, clients would reach the app through its MetalLB IP address. In this lab, Arc Proxy and port forwarding provide private access without requiring a direct route to the cluster.

## Success criteria

* You can navigate and understand the LocalBox hybrid environment in the Azure Portal
* You have deployed your own VM on Azure Local via the Azure Portal and verified that guest management is Enabled (Connected)
* You have verified Defender for Servers coverage for your VM and reviewed its available recommendations, or identified that its assessment is still pending
* You have completed an Azure Update Manager assessment for your VM and reviewed the results, including when no updates are pending
* You can explain MetalLB's role and have checked that the preinstalled load balancer is healthy
* Your sample application runs in your team's namespace and has a load-balancer IP address
* You can open the application privately using Arc Proxy and port forwarding, and explain how this differs from direct load-balancer access
* You have cleaned up your team's application resources without changing shared infrastructure
* You understand how Azure Arc provides a unified control plane for sovereign hybrid scenarios

## Learning resources

* [Azure Arc-enabled Servers overview (background for guest management)](https://learn.microsoft.com/azure/azure-arc/servers/overview)
* [Azure Local hybrid capabilities](https://learn.microsoft.com/azure/azure-local/hybrid-capabilities-with-azure-services-23h2)
* [Create Azure Local VMs](https://learn.microsoft.com/azure/azure-local/manage/create-arc-virtual-machines)
* [Enable guest management on Azure Local VMs](https://learn.microsoft.com/azure/azure-local/manage/manage-arc-virtual-machines#enable-guest-management)
* [Microsoft Defender for Cloud with Arc-enabled servers](https://learn.microsoft.com/azure/defender-for-cloud/quickstart-onboard-machines)
* [Azure Update Manager overview](https://learn.microsoft.com/azure/update-manager/overview)
* [Azure Arc Jumpstart - LocalBox](https://jumpstart.azure.com/azure_jumpstart_localbox)
* [Azure CLI Cluster Connect proxy reference](https://learn.microsoft.com/cli/azure/connectedk8s#az-connectedk8s-proxy)
