# Walkthrough Challenge 2 - Enable Azure Monitor for Containers

Duration: 30-45 min

## Prerequisites
* You have an arc-connected k8s cluster/finisched challenge 01.
* You require at least Contributor access to the cluster for onboarding.
* You require Monitoring Reader or Monitoring Contributor to view data after monitoring is enabled.
* Verify the firewall requirements in addition to the Azure Arc-enabled Kubernetes network requirements.
* A Log Analytics workspace (law). (If you used the terraform to deploy the microhack environment, each participant already has a law in his arc resource group.)
* You must be logged in to az cli (az login)

## Task 1 - Enable Azure Monitor for k8s
Execute the following commands in your bash shell to install the container log extension with default settings:
```bash
# Extract user number from Azure username (e.g., LabUser-37 -> 37)
azure_user=$(az account show --query user.name --output tsv)
user_number=$(echo $azure_user | sed -n 's/.*LabUser-\([0-9]\+\).*/\1/p')
echo $user_number

# if you are running this in a non-microhack env, adjust the values to match your env
export arc_resource_group="${user_number}-k8s-arc"
export arc_cluster_name="${user_number}-k8s-arc-enabled"
export law_resource_id=$(az monitor log-analytics workspace show --resource-group $arc_resource_group --workspace-name "${user_number}-law" --query 'id' -o tsv)

az k8s-extension create \
    --name azuremonitor-containers \
    --cluster-name $arc_cluster_name \
    --resource-group $arc_resource_group \
    --cluster-type connectedClusters  \
    --extension-type Microsoft.AzureMonitor.Containers \
    --configuration-settings azure-monitor-workspace-resource-id=$law_resource_id

```
The output should look roughly like this:
```bash
Ignoring name, release-namespace and scope parameters since microsoft.azuremonitor.containers only supports cluster scope and single instance of this extension.
Defaulting to extension name 'azuremonitor-containers' and release-namespace 'azuremonitor-containers'
{
 [...]
  "isSystemExtension": false,
  "name": "azuremonitor-containers",
  "packageUri": null,
  "plan": null,
  "provisioningState": "Succeeded",
  "releaseTrain": "Stable",
  "resourceGroup": "37-k8s-arc",
  "scope": {
    "cluster": {
      "releaseNamespace": "azuremonitor-containers"
    },
    "namespace": null
  },
 [...]
  "type": "Microsoft.KubernetesConfiguration/extensions",
  "version": null
}
```

To verify the installation, navigate to your arc-enabled k8s cluster in the Azure portal. 
* In the left navigation pane in section Monitoring select Insights. Then in the main windows check the tabs Cluster, Reports, Nodes, Controllers and Containers. You should see a dashboard in each tab. Please note that it takes a few minutes after activation until the first values are displayed.
* In tab Containers find "clusterconnectservice-operator" and click the title. This opens an Overview pane on the right hand side. Click on "View in Log Analytics" to see the stdout logs of this container.

## Task 2 - Enable Defender for Containers Plan
To enable the Defender for Containers plan on your subscription, 
* Open the [Defender for Cloud | Environment settings](https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/EnvironmentSettings) - if prompted for credentials, use the LabUser you were provided for the microhack.
* At the bottom of your page find your subscription and click the elipses on the right hand side, then in the popup click "Edit settings".

![environment-settings](img/01_env_settings.png)
* In section Cloud Workload Protection (CWPP) find the line for the Containers Plan and click the "Settings" links in that line.

![container-plan-setting](img/02_container_plan_settings.png)
* In the Settings & monitoring page ensure the following settings are turned on (please note that you are working with several participants in the same subscription. Someone might already turned on the recommended settings.):
    * Defender sensor - Required because Arc clusters do not have agentless telemetry collection like AKS. Installs the Defender sensor DaemonSet on every node for runtime threat detection.
    * Azure Policy - Installs Gatekeeper/OPA in your Arc cluster. Required for Kubernetes posture management, admission control, and workload hardening.
    * Kubernetes API access - sets permissions to allow API-based discovery of your Kubernetes clusters. For Arc, this enables Defender to read Kubernetes API objects for configuration assessment.
    * Registry access - Vulnerability assessment scanning for images stored in ACR registries. It does NOT scan non‑Azure registries.
* When finished click on the Continue link at the top of the page:

![settings_n_monitoring](img/03_settings_n_monitoring.png)
* If you made changes, they are not yet saved. Make sure to click the Save link at the top of the page:

![save](img/04_save.png)


## Task 3 - Deploy Defender for Container

For Arc‑enabled Kubernetes, Defender for Containers cannot operate agentlessly the way it does on AKS. Arc clusters require the Defender sensor DaemonSet to be deployed.

If auto‑provisioning is enabled in the portal (the toggle “Defender sensor” → ON”), then Defender for Cloud will attempt to deploy the sensor automatically using the Arc extension mechanism. You can check whether the defender extension is already present with the following command:

```bash
# Check current extensions
echo "Checking current Arc extensions:"
az k8s-extension list \
  --cluster-name $arc_cluster_name \
  --resource-group $arc_resource_group \
  --cluster-type connectedClusters \
  --query '[].{Name:name, Type:extensionType, State:provisioningState}' \
  -o table
```

If you see the following extension, the defender extension already got deployed automatically:

```bash
Name                                Type                                State
----------------------------------  ----------------------------------  ---------
microsoft.azuredefender.kubernetes  microsoft.azuredefender.kubernetes  Succeeded
```

If it's not yet present or you want to force it (recommended), use:

```bash
az k8s-extension create \
  --name microsoft.azuredefender.kubernetes \
  --cluster-type connectedClusters \
  --cluster-name $arc_cluster_name \
  --resource-group $arc_resource_group \
  --extension-type microsoft.azuredefender.kubernetes \
  --configuration-settings logAnalyticsWorkspaceResourceID=$law_resource_id
```

If you run into an error telling you "Helm installation failed : Resource already existing in your cluster" this means that the Defender for Cloud policy already installed the extension successfully.

Optionally, check again for the existence of the defender extension as described above (az k8s-extensions list command). 

Let's see whether the defender related pods are running in our k8s cluster:

```bash
# Check Defender pods including example output
kubectl get pods -n mdc
NAME                                                     READY   STATUS    RESTARTS   AGE
microsoft-defender-collectors-bct8t                      2/2     Running   0          10m
microsoft-defender-collectors-h7q6l                      2/2     Running   0          10m
microsoft-defender-collectors-htqq5                      2/2     Running   0          10m
microsoft-defender-pod-collector-misc-65c56849bd-zq6fk   1/1     Running   0          10m
microsoft-defender-publisher-k9lt9                       1/1     Running   0          10m
microsoft-defender-publisher-mcq7g                       1/1     Running   0          10m
microsoft-defender-publisher-q4bwq                       1/1     Running   0          10m

# Check Azure Policy (Gatekeeper) pods including example output
kubectl get pods -n gatekeeper-system
NAME                                             READY   STATUS    RESTARTS   AGE
gatekeeper-audit-7df994876b-jrfqt                1/1     Running   0          17m
gatekeeper-controller-manager-7655d54c66-4d95b   1/1     Running   0          17m
gatekeeper-controller-manager-7655d54c66-pcp26   1/1     Running   0          17m

```

Check Policy recommendations in Defender for Cloud: 
* In the Azure Portal > Defender for Cloud > General > Inventory
* In the search bar filter for your arc-enabled k8s cluster's name - i.e. 37-k8s-arc-enabled
![alt text](img/05_defender.png)
* Click on the name of your cluster and view the recommendations and alerts

## Task 4 - Assign Azure Policy for Kubernetes
For Arc-enabled Kubernetes clusters, Azure Policy requires installing the Azure Policy extension (which includes Gatekeeper/OPA). Let's set this up:

```bash
# Installing Azure Policy extension on Arc cluster...
az k8s-extension create \
    --cluster-name $arc_cluster_name \
    --resource-group $arc_resource_group \
    --cluster-type connectedClusters \
    --extension-type Microsoft.PolicyInsights \
    --name azurepolicy

{
  "aksAssignedIdentity": null,
  "autoUpgradeMinorVersion": true,
  "configurationProtectedSettings": {},
  "configurationSettings": {},
  "currentVersion": "1.15.0",
  "customLocationSettings": null,
  "errorInfo": null,
  "extensionType": "microsoft.policyinsights",
  [...]
  "isSystemExtension": false,
  "name": "azurepolicy",
  "packageUri": null,
  "plan": null,
  "provisioningState": "Succeeded",
  "releaseTrain": "Stable",
  "resourceGroup": "37-k8s-arc",
  "scope": {
    "cluster": {
      "releaseNamespace": "kube-system"
    },
    "namespace": null
  },
  "statuses": [],
  [...]
  "type": "Microsoft.KubernetesConfiguration/extensions",
  "version": null
}
```

Verify the Gatekeeper pods are running:

```bash
# Checking Gatekeeper (Azure Policy) pods
kubectl get pods -n gatekeeper-system

NAME                                             READY   STATUS    RESTARTS   AGE
gatekeeper-audit-79d8755674-7rvqs                1/1     Running   0          3m38s
gatekeeper-controller-manager-666b666854-mg5lr   1/1     Running   0          3m38s
gatekeeper-controller-manager-666b666854-rr66f   1/1     Running   0          3m38s

# Checking all policy-related pods
kubectl get pods -A | grep -E "(policy|gate)"

gatekeeper-system   gatekeeper-audit-79d8755674-7rvqs                        1/1     Running   0               4m44s
gatekeeper-system   gatekeeper-controller-manager-666b666854-mg5lr           1/1     Running   0               4m44s
gatekeeper-system   gatekeeper-controller-manager-666b666854-rr66f           1/1     Running   0               4m44s
kube-system         azure-policy-665f9645d-577xx                             2/2     Running   0               4m44s
kube-system         azure-policy-webhook-685f6f584b-glbrh                    1/1     Running   1 (4m16s ago)   4m44s
```

Now, let's check what Azure policies are available out-of-the-box for k8s:

```bash
# Looking for Kubernetes policy initiatives
az policy set-definition list --query "[?contains(displayName, 'Kubernetes')].{DisplayName:displayName, ResourceId:id}" -o table

Name                                  DisplayName
------------------------------------  -------------------------------------------------------------------------------------------------------------------------------------------
42b8ef37-b724-4e24-bbc8-7a7708edfe00  Kubernetes cluster pod security restricted standards for Linux-based workloads
4fd005fd-51be-478f-a8fb-149d48b20d48  [Preview]: Kubernetes cluster should follow the security control recommendations of Center for Internet Security (CIS) Kubernetes benchmark
a8640138-9b0a-4a28-b8cb-1666c838647d  Kubernetes cluster pod security baseline standards for Linux-based workloads
```

Let's assign the pod security baseline policy:

```bash
# validate the required az cli extension "connected8s" is installed
if ! az extension show --name connectedk8s > /dev/null 2>&1; then
    az extension add --name connectedk8s
else
    az extension update --name connectedk8s
fi

cluster_resource_id=$(az connectedk8s show --name $arc_cluster_name --resource-group $arc_resource_group --query id -o tsv)
echo "Cluster Resource ID: $cluster_resource_id"

policy_id="/providers/Microsoft.Authorization/policySetDefinitions/a8640138-9b0a-4a28-b8cb-1666c838647d"

# Assign the baseline pod security standards policy
az policy assignment create \
    --name "k8s-pod-security-baseline-${user_number}" \
    --policy-set-definition $policy_id \
    --scope "$cluster_resource_id" \
    --display-name "Kubernetes Pod Security Baseline for cluster ${arc_cluster_name}" \
    --description "Enforces pod security baseline standards on Arc-enabled Kubernetes cluster"

{
  "definitionVersion": "1.*.*",
  "description": "Enforces pod security baseline standards on Arc-enabled Kubernetes cluster",
  "displayName": "Kubernetes Pod Security Baseline for cluster 37-k8s-arc-enabled",
  "enforcementMode": "Default",
 [...]
  "name": "k8s-pod-security-baseline-37",
  "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/a8640138-9b0a-4a28-b8cb-1666c838647d",
  "resourceGroup": "37-k8s-arc",
  "scope": "/subscriptions/a271110f-4e09-47aa-9d1c-743b520ccbca/resourceGroups/37-k8s-arc/providers/Microsoft.Kubernetes/connectedClusters/37-k8s-arc-enabled",
 [...]
  "type": "Microsoft.Authorization/policyAssignments"
}
```
*PLEASE NOTE*: At the time of writing a bug in the az cli prevents the above command from execution. If you run in error for the az policy assignment create command, here is a workaround:
```bash
assignment_name="k8s-pod-security-baseline-${user_number}"
policy_set_id="/providers/Microsoft.Authorization/policySetDefinitions/a8640138-9b0a-4a28-b8cb-1666c838647d"

az rest \
  --method PUT \
  --url "https://management.azure.com${cluster_resource_id}/providers/Microsoft.Authorization/policyAssignments/${assignment_name}?api-version=2023-04-01" \
  --body "{
    \"properties\": {
      \"displayName\": \"Kubernetes Pod Security Baseline for cluster ${arc_cluster_name}\",
      \"description\": \"Enforces pod security baseline standards on Arc-enabled Kubernetes cluster\",
      \"policyDefinitionId\": \"${policy_set_id}\"
    }
  }"
```

As a result there should appear several contrainttemplates in your cluster:
```bash
kubectl get constrainttemplates
NAME                               AGE
k8sazurev1blockdefault             11m
k8sazurev1ingresshttpsonly         11m
k8sazurev1serviceallowedports      11m
k8sazurev2blockautomounttoken      11m
k8sazurev2blockhostnamespace       11m
k8sazurev2containerallowedimages   11m
k8sazurev2noprivilege              11m
k8sazurev3allowedcapabilities      11m
k8sazurev3allowedusersgroups       11m
k8sazurev3containerlimits          11m
k8sazurev3disallowedcapabilities   11m
k8sazurev3enforceapparmor          11m
k8sazurev3hostnetworkingports      11m
k8sazurev3noprivilegeescalation    11m
k8sazurev3readonlyrootfilesystem   11m
k8sazurev4hostfilesystem           11m
```

⏳ Constraint templates will appear within 15-30 minutes

⏳ Policy compliance data will populate in Azure Portal within 15-30 minutes

Let's check the compliance status via az cli:

```bash
# Policy assignment details
az policy assignment show \
  --name "k8s-pod-security-baseline-${user_number}" \
  --scope "$cluster_resource_id" \
  --query '{Name:name, DisplayName:displayName, EnforcementMode:enforcementMode, PolicyDefinitionId:policyDefinitionId}' \
  -o table

#expected output:
Name                          DisplayName                                                      EnforcementMode    PolicyDefinitionId
----------------------------  ---------------------------------------------------------------  -----------------  --------------------------------------------------------------------------------------------
k8s-pod-security-baseline-37  Kubernetes Pod Security Baseline for cluster 37-k8s-arc-enabled  Default            /providers/Microsoft.Authorization/policySetDefinitions/a8640138-9b0a-4a28-b8cb-1666c838647d

# Policy compliance state
az policy state list \
  --resource "$cluster_resource_id" \
  --query '[].{PolicyDefinitionName:policyDefinitionName, PolicyAssignmentName:policyAssignmentName, ComplianceState:complianceState}' \
  -o table

# expected output (there are many more but these are the ones corresponding to the pod security baseline policy we applied earlier):
PolicyDefinitionName                  PolicyAssignmentName                                             ComplianceState
------------------------------------  ---------------------------------------------------------------  -----------------
[...]
098fc59e-46c7-4d99-9b16-64990e543d75  k8s-pod-security-baseline-37                                     NonCompliant
47a1ee2f-2a2a-4576-bf2a-e0e36709c2b8  k8s-pod-security-baseline-37                                     Compliant
82985f06-dc18-4a48-bc1c-b9f4f0098cfe  k8s-pod-security-baseline-37                                     NonCompliant
95edb821-ddaf-4404-9732-666045e056b4  k8s-pod-security-baseline-37                                     Compliant
c26596ff-4d70-4e6a-9a30-c2506bd2f80c  k8s-pod-security-baseline-37                                     NonCompliant
```
Some policies should show as 'Compliant' and some as 'NonCompliant'.

Optionally, check on your k8s cluster how the policies are implemented there.
```bash
# in the list of all constraints injected via Azure Policy, identify constraints with violations
kubectl get constraints

# expected output (shortened):
NAME                                                                                                                     ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
k8sazurev3allowedcapabilities.constraints.gatekeeper.sh/azurepolicy-k8sazurev3allowedcapabilities-69e35e5e70785d0cd7c5   dryrun               0
k8sazurev3allowedcapabilities.constraints.gatekeeper.sh/azurepolicy-k8sazurev3allowedcapabilities-e5d0b70be34e42817a95   dryrun               0
k8sazurev3allowedcapabilities.constraints.gatekeeper.sh/azurepolicy-k8sazurev3allowedcapabilities-f9e7a5d4539f18fafe48   dryrun               3

# identify the k8sazurev3allowedcapabilities.constraint with violations and store it in a variable
constraint_name="k8sazurev3allowedcapabilities.constraints.gatekeeper.sh/azurepolicy-k8sazurev3allowedcapabilities-f9e7a5d4539f18fafe48"

# In the constraint details you can see a message for each violation
kubectl describe $constraint_name
```

💡**Note:** Many violations are originating from the defender pods itself. This is (at time of writing) a known issue. A simple workaround is to exclude the **mdc, gatekeeper-system and azure-arc** namespaces from policy evaluation (not in scope of the microhack). 


You successfully completed challenge 2! 🚀🚀🚀

[Back to challenge 01](../challenge-01/solution.md) - [Next challenge](../challenge-03/solution.md) - [Next Challenge's Solution](../../walkthroughs/challenge-03/solution.md)