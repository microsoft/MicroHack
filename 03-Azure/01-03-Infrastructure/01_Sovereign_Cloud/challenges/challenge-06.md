# Challenge 6 - Operating a Sovereign Hybrid Cloud with Azure Arc & Azure Local

## Goal

The goal of this challenge is to operate a sovereign hybrid cloud environment by combining Microsoft Sovereign Public Cloud and Sovereign Private Cloud components. You will work with Azure Local, simulated via Azure Arc Jumpstart LocalBox, and provision your own VM. You will use Azure Arc to manage that VM through Azure, review its security posture with Microsoft Defender for Cloud, and assess its OS updates with Azure Update Manager. You will also deploy a container application in your team's namespace on the shared AKS cluster and access it privately from your Sovereign Cloud Codespace.

## Scenario

Your organization must run workloads in a sovereign cloud while still leveraging Azure's management and governance capabilities. Azure Local represents your sovereign on-premises infrastructure, and Azure Arc enables you to apply consistent governance across your hybrid estate.

## Actions

Before deploying, confirm that your Challenge 1 exercise policies are back in
**DoNotEnforce** and ask the facilitator to confirm that the shared LocalBox custom
location's Azure region is permitted in your assigned resource group. This region
can differ from the resource group's location. If a policy blocks creation, follow
the [location-policy troubleshooting steps](../walkthrough/challenge-06/solution-06.md#if-validation-or-deployment-is-blocked-by-a-location-policy);
do not disable organizer-managed policies or change allowlists yourself.

* Explore the LocalBox hybrid infrastructure in the Azure Portal
* Deploy your own VM on Azure Local using Azure Arc VM management and verify that guest management is connected
* Verify Microsoft Defender for Cloud coverage and review security recommendations for the VM you provisioned
* Use Azure Update Manager to assess OS updates on the VM you provisioned
* Verify your Console-provided Microsoft Entra administrator-group membership and the existing Azure Arc Enabled Kubernetes Cluster User Role with the facilitator; portal workload visibility alone does not prove group membership
* Inspect the organizer-prepared `arcnetworking` extension (`microsoft.arcnetworking`) on `localbox-aks` in `rg-localbox-shared`: confirm **Succeeded**, healthy MetalLB workloads, and the existing **`aks-pool`** with **ARP** advertisement and organizer-reserved service VIPs. Do not install or configure shared networking
* Follow [Task 5 of the walkthrough](../walkthrough/challenge-06/solution-06.md#task-5-deploy-a-container-to-the-aks-cluster-deployed-on-azure-local) in **Bash**: run `az connectedk8s proxy` with Microsoft Entra authentication and an isolated kubeconfig, derive a unique namespace from your assigned resource group, and deploy `aks-local-sample-app.yaml` only in that namespace
* Verify successful rollout and the Service's assigned IP, then keep the proxy and namespace-scoped `kubectl port-forward service/aks-container-1 8080:80` running in separate terminals. Open port **8080** through the **Private** Codespaces Ports view (or `localhost:8080` when running directly on a local workstation). Never expose the API proxy port or use service-account/admin tokens; no RDP or static routes are needed
* Clean up only your team's application resources and, when no longer needed by teammates, your exercise namespace. Leave shared infrastructure unchanged

The organizer prepares MetalLB with `resources/prepare-localbox.ps1`; the Console's LocalBox deployment hook alone is not sufficient. If extension health, the pool, or access prerequisites are missing, contact the facilitator rather than installing extensions, creating pools, or granting additional permissions.

The default service VIP range is **`10.10.0.10-10.10.0.100`**, excluding nodes **`10.10.0.101-10.10.0.199`**, control-plane IP **`10.10.0.5`**, and gateway **`10.10.0.1`**. Confirm any organizer customization. Inspect the pool's **IPAddressPool** and **L2Advertisement** in `kube-system` read-only; participants do not create them.

## Success criteria

* You can navigate and understand the LocalBox hybrid environment in the Azure Portal
* You have deployed your own VM on Azure Local via the Azure Portal and verified that guest management is Enabled (Connected)
* You have verified Defender for Servers coverage for your VM and reviewed its available recommendations, or identified that its assessment is still pending
* You have completed an Azure Update Manager assessment for your VM and reviewed the results, including when no updates are pending
* You have verified the shared MetalLB extension, workloads, and reserved ARP IP pool without changing shared infrastructure
* You have deployed the sample application to your team's unique AKS namespace, verified rollout, and recorded a Service IP from the reserved pool
* You have opened the application through a Microsoft Entra Arc proxy and a private application port-forward, with the API proxy never exposed
* You understand that production clients use the MetalLB VIP through configured network routing; proxy plus port-forward access does **not** validate that load-balancer network path
* You have cleaned up only your team's application resources
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
