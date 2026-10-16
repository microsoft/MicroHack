# ch05 solution: review Defender for Cloud posture

There are several good ways to complete this challenge. This version keeps it simple: identify the resources, inspect Defender for Cloud, fix low-risk items, and write down any decisions you intentionally leave for the enterprise hardening challenge.

Use the stack you chose in Challenge 0 only:

| | `dotnet-sqlserver` | `java-postgresql` |
| --- | --- | --- |
| App runtime | .NET 8 Blazor Server | Spring Boot 3 / Java 17 |
| Local port | 5000 | 8080 |
| Managed database | Azure SQL Database | Azure Database for PostgreSQL Flexible Server |
| Defender database plan | `SqlServers` | `OpenSourceRelationalDatabases` |

Before you start:

- Sign in with `az login` and select the right subscription with `az account set` if needed.
- Replace `rg-userNNN` with your resource group.
- If the retained VM is in another resource group, use that group for VM commands only.
- Do not toggle paid Defender plans in a shared subscription unless the facilitator asks you to.

## Step 1: Find the resources you will review

```bash
RESOURCE_GROUP=rg-userNNN
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
az resource list -g "$RESOURCE_GROUP" --query "[].{name:name,type:type,location:location}" -o table

APP_NAME=$(az containerapp list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
ACR_NAME=$(az acr list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
APP_ID=$(az containerapp show -g "$RESOURCE_GROUP" -n "$APP_NAME" --query id -o tsv)
ACR_ID=$(az acr show -g "$RESOURCE_GROUP" -n "$ACR_NAME" --query id -o tsv)
```

For the database, run the pair that matches your stack:

```bash
# .NET / Azure SQL
SQL_SERVER=$(az sql server list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
SQL_SERVER_ID=$(az sql server show -g "$RESOURCE_GROUP" -n "$SQL_SERVER" --query id -o tsv)

# Java / PostgreSQL
PG_SERVER=$(az postgres flexible-server list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
PG_SERVER_ID=$(az postgres flexible-server show -g "$RESOURCE_GROUP" -n "$PG_SERVER" --query id -o tsv)
```

Find the retained VM:

```bash
VM_ID=$(az vm list -g "$RESOURCE_GROUP" --query "[0].id" -o tsv)
az vm show --ids "$VM_ID" --show-details --query "{name:name,location:location,powerState:powerState,publicIps:publicIps}" -o table
```

## Step 2: Inspect Defender plans

In the Azure portal, open **Microsoft Defender for Cloud** > **Environment settings** > your subscription. Check these plans:

| Plan name | Why you care |
| --- | --- |
| `CloudPosture` | Defender CSPM and posture context across Azure resources |
| `Containers` | Container and serverless-container recommendations |
| `VirtualMachines` / Plan 2 | Defender for Servers P2 on the retained VM |
| `SqlServers` | Azure SQL posture and threat protection |
| `OpenSourceRelationalDatabases` | PostgreSQL Flexible Server posture |

CLI view:

```bash
az rest --method get --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Security/pricings?api-version=2024-01-01" --query "value[].{plan:name,tier:properties.pricingTier,subPlan:properties.subPlan}" -o table
```

## Step 3: Review recommendations and attack paths

Portal route: **Defender for Cloud** > **Recommendations**. Filter by your resource group and sort by severity. Also check **Secure score**, Microsoft Cloud Security Benchmark controls, and **Attack path analysis**.

Useful Resource Graph query for recommendations:

```kusto
securityresources
| where type =~ 'microsoft.security/assessments'
| extend status = tostring(properties.status.code), recommendation = tostring(properties.displayName), resourceId = tostring(properties.resourceDetails.Id)
| where status =~ 'Unhealthy'
| project recommendation, resourceId, status
| order by recommendation asc
```

Run it:

```bash
az graph query --subscriptions "$SUBSCRIPTION_ID" -q "securityresources | where type =~ 'microsoft.security/assessments' | extend status=tostring(properties.status.code), recommendation=tostring(properties.displayName), resourceId=tostring(properties.resourceDetails.Id) | where status =~ 'Unhealthy' | project recommendation, resourceId, status | order by recommendation asc" -o table
```

Attack paths show a chain of exposures, permissions, and reachable resources that could become an end-to-end compromise route:

```bash
az graph query --subscriptions "$SUBSCRIPTION_ID" -q "securityresources | where type =~ 'microsoft.security/attackpaths' | project name, risk=tostring(properties.riskLevel), displayName=tostring(properties.displayName), resources=properties.attackPathResources" -o table
```

Empty output is common soon after resources are created. Treat it as "nothing reported yet", not as proof that the application is safe forever.

## Step 4: Turn off ACR admin authentication

The ACR admin account is a shared static credential. The Container App should pull using managed identity.

```bash
az acr show -g "$RESOURCE_GROUP" -n "$ACR_NAME" --query "{loginServer:loginServer,adminUserEnabled:adminUserEnabled}" -o table
az acr update -g "$RESOURCE_GROUP" -n "$ACR_NAME" --admin-enabled false --output none
az containerapp show -g "$RESOURCE_GROUP" -n "$APP_NAME" --query "{identity:identity,registries:properties.configuration.registries,image:properties.template.containers[0].image}" -o jsonc
```

If image pulls fail, check that the app identity has `AcrPull` on the registry scope:

```bash
APP_PRINCIPAL_ID=$(az containerapp show -g "$RESOURCE_GROUP" -n "$APP_NAME" --query "identity.principalId" -o tsv)
az role assignment list --assignee "$APP_PRINCIPAL_ID" --scope "$ACR_ID" --query "[?roleDefinitionName=='AcrPull'].{role:roleDefinitionName,scope:scope}" -o table
```

For a user-assigned identity, get the principal ID from the identity resource instead.

## Step 5: Make Container App ingress HTTPS-only

Public ingress may be correct for this lab, but insecure HTTP should not be.

```bash
az containerapp ingress show -g "$RESOURCE_GROUP" -n "$APP_NAME" --query "{external:external,allowInsecure:allowInsecure,targetPort:targetPort}" -o table
az containerapp ingress update -g "$RESOURCE_GROUP" -n "$APP_NAME" --allow-insecure false --output none
```

If the app remains public, note the reason and compensating controls: HTTPS-only, no admin endpoints, least-privilege identity, and a future private networking design in Challenge 7.

## Step 6: Decide the database network posture

The setting lives on the database server. If the current Container Apps design has no private path to the database, record that as a deliberate temporary exception instead of breaking the app during class.

```bash
# .NET / Azure SQL
az sql server show -g "$RESOURCE_GROUP" -n "$SQL_SERVER" --query "{name:name,publicNetworkAccess:publicNetworkAccess,fullyQualifiedDomainName:fullyQualifiedDomainName}" -o table

# Java / PostgreSQL
az postgres flexible-server show -g "$RESOURCE_GROUP" -n "$PG_SERVER" --query "{name:name,publicNetworkAccess:publicNetworkAccess,fullyQualifiedDomainName:fullyQualifiedDomainName}" -o table
```

When the app can reach the database privately, disable public network access:

```bash
# .NET / Azure SQL
az sql server update -g "$RESOURCE_GROUP" -n "$SQL_SERVER" --enable-public-network false --output none

# Java / PostgreSQL
az rest --method patch --url "https://management.azure.com${PG_SERVER_ID}?api-version=2024-08-01" --headers Content-Type=application/json --body '{"properties":{"publicNetworkAccess":"Disabled"}}' --output none
```

If public access remains, tighten firewall rules to the smallest source range you can justify.

## Step 7: Check retained VM management ports

The old VM is still part of the risk picture. Look for public inbound SSH (`22`) or RDP (`3389`) on every attached NIC.

```bash
NIC_IDS=$(az vm show --ids "$VM_ID" --query "networkProfile.networkInterfaces[].id" -o tsv)
for nic in $NIC_IDS; do echo "== $nic =="; az network nic list-effective-nsg --ids "$nic" -o table; done
```

If you find a public allow rule, restrict it to a trusted source, move it behind Just-in-Time VM access, or record why it must remain temporarily exposed.

```bash
VM_LOCATION=$(az vm show --ids "$VM_ID" --query location -o tsv)
VM_RESOURCE_GROUP=$(echo "$VM_ID" | cut -d/ -f5)
az rest --method get --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${VM_RESOURCE_GROUP}/providers/Microsoft.Security/locations/${VM_LOCATION}/jitNetworkAccessPolicies?api-version=2020-01-01" -o jsonc
```

## Step 8: Ask Copilot for help

Good prompts name the resource type and the decision you need to make.

```prompt-style
Explain this Microsoft Defender for Cloud recommendation for my Azure Container App. Tell me what risk it represents, whether it applies to Azure Container Apps or only to VM/container hosts, the safest Azure CLI remediation command, and how to verify the app still works. Do not suggest disabling Defender plans.
```

```prompt-style
Review these Azure CLI outputs for my catalog migration: ACR admin status, Container App ingress, database publicNetworkAccess, and VM effective NSG rules. Summarize what is remediated, what is already acceptable, and what should be a temporary exception with compensating controls.
```

## Step 9: Verify the app still works

```bash
APP_FQDN=$(az containerapp show -g "$RESOURCE_GROUP" -n "$APP_NAME" --query "properties.configuration.ingress.fqdn" -o tsv)
curl --fail --silent --show-error "https://${APP_FQDN}/healthz"
curl --fail --silent --show-error "https://${APP_FQDN}/readyz"
```

Open the site in a browser and confirm browse, search, category filtering, detail pages, and images still work.

## What you should have learned

The migration did not magically remove risk; it made the risk visible. You now know which Defender plans apply to each resource, which findings you can fix immediately, and which network decisions belong in the enterprise hardening challenge.

---

**Challenge:** [ch05-defender](../../challenges/ch05-defender.md) · **Previous:** [ch04](../ch04/README.md) · **Next:** [ch06-sre-agent](../ch06-sre-agent/README.md)
