# VNet Isolation Proposal - Per-User ODAA Networks

## Current Architecture (Shared ODAA VNet)

### Problem
All users currently share a single ODAA VNet (192.168.0.0/16), which creates security and operational risks:

```
Current Setup:
┌─────────────────────────────────────────────────────────────┐
│ Subscription: ODAA (4aecf0e8-2fe2-4187-bc93-0356bd2676f5)   │
│                                                             │
│  ┌──────────────────────────────────────────────┐          │
│  │ ODAA Shared VNet: 192.168.0.0/16             │          │
│  │  - All user ADBs in same network             │          │
│  │  - Users can potentially access each other's │          │
│  │    databases via network connectivity        │          │
│  └──────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
         ↑ Peered to ↑              ↑ Peered to ↑
┌────────────────────┐      ┌────────────────────┐
│ User00 AKS VNet    │      │ User01 AKS VNet    │
│ 10.0.0.0/16        │      │ 10.1.0.0/16        │
└────────────────────┘      └────────────────────┘
```

**Risks:**
- ❌ User00 can potentially access User01's ADB via shared ODAA VNet
- ❌ Network security groups must be carefully managed
- ❌ Single point of failure for all users
- ❌ Difficult to implement per-user network policies

## Proposed Architecture (Isolated ODAA VNets)

### Solution
Each user gets their own isolated ODAA VNet, all using the same CIDR (10.0.0.0/16):

```
Proposed Setup:
┌─────────────────────────────────────────────────────────────┐
│ Subscription: ODAA (4aecf0e8-2fe2-4187-bc93-0356bd2676f5)   │
│                                                             │
│  ┌──────────────────────┐      ┌──────────────────────┐   │
│  │ ODAA User00 VNet     │      │ ODAA User01 VNet     │   │
│  │ 10.0.0.0/16          │      │ 10.0.0.0/16          │   │
│  │  - Only user00's ADB │      │  - Only user01's ADB │   │
│  └──────────────────────┘      └──────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
         ↑ Peered to ↑                  ↑ Peered to ↑
┌────────────────────┐            ┌────────────────────┐
│ User00 AKS VNet    │            │ User01 AKS VNet    │
│ 10.0.0.0/16        │            │ 10.0.0.0/16        │
└────────────────────┘            └────────────────────┘
```

**Benefits:**
- ✅ Complete isolation: User00 cannot access User01's resources
- ✅ Overlapping CIDR is OK (VNets are NOT peered to each other)
- ✅ Simpler security model (no cross-user access possible)
- ✅ Better resource organization and management
- ✅ Scales to unlimited users

### Why Same CIDR Works

**Key Concept:** VNets with overlapping CIDR can coexist **as long as they're not peered to each other**.

```
User00 Environment (Isolated):
┌──────────────────────────────────┐
│ AKS VNet: 10.0.0.0/16            │
│   ↕ Peered ↕                     │
│ ODAA VNet: 10.0.0.0/16           │
│   - user00's ADB only            │
└──────────────────────────────────┘

User01 Environment (Isolated):
┌──────────────────────────────────┐
│ AKS VNet: 10.0.0.0/16            │
│   ↕ Peered ↕                     │
│ ODAA VNet: 10.0.0.0/16           │
│   - user01's ADB only            │
└──────────────────────────────────┘

NO peering between User00 and User01 VNets!
```

## Implementation Plan

### Changes Required

#### 1. Update Local Variables (main.tf)

**Current:**
```terraform
locals {
  deployments = {
    for idx in local.user_indices :
    tostring(idx) => {
      # ...
      aks_cidr  = "10.${idx}.0.0"  # Unique per user: 10.0.0.0, 10.1.0.0, etc.
      odaa_cidr = local.default_odaa_cidr_base  # Shared: 192.168.0.0
      # ...
    }
  }
}
```

**Proposed:**
```terraform
locals {
  deployments = {
    for idx in local.user_indices :
    tostring(idx) => {
      # ...
      aks_cidr  = "10.0.0.0"  # All users use same CIDR (isolated by VNet)
      odaa_cidr = "10.0.0.0"  # All users use same CIDR (isolated by VNet)
      # ...
    }
  }
}
```

#### 2. Remove Shared ODAA Module (main.tf)

**Remove:**
```terraform
module "odaa_shared" {
  source = "./modules/odaa"
  
  providers = {
    azurerm = azurerm.odaa
  }
  
  prefix                     = "shared"
  postfix                    = ""
  location                   = var.location
  cidr                       = local.default_odaa_cidr_base
  password                   = null
  create_autonomous_database = false
  
  tags = merge(local.common_tags, {
    ODAAFor = "shared"
  })
}
```

#### 3. Create Per-User ODAA VNets

**Add for each subscription slot (example for slot_0):**

```terraform
module "odaa_slot_0" {
  source = "./modules/odaa"
  
  # Create one ODAA VNet per user in this slot
  for_each = local.aks_deployments_by_slot["0"]
  
  providers = {
    azurerm = azurerm.odaa
  }
  
  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr  # Now 10.0.0.0 for all users
  password                   = null
  create_autonomous_database = false
  
  tags = merge(local.common_tags, {
    ODAAFor = each.value.name
    UserIndex = each.value.index
  })
}
```

Repeat for slots 1-4.

#### 4. Update VNet Peering References

**Current:**
```terraform
module "vnet_peering_slot_0" {
  source = "./modules/vnet-peering"
  
  for_each = local.aks_deployments_by_slot["0"]
  
  # ...
  odaa_vnet_id         = module.odaa_shared.vnet_id          # ❌ Shared VNet
  odaa_vnet_name       = module.odaa_shared.vnet_name        # ❌ Shared VNet
  odaa_resource_group  = module.odaa_shared.resource_group_name
  # ...
}
```

**Proposed:**
```terraform
module "vnet_peering_slot_0" {
  source = "./modules/vnet-peering"
  
  for_each = local.aks_deployments_by_slot["0"]
  
  # ...
  odaa_vnet_id         = module.odaa_slot_0[each.key].vnet_id          # ✅ Per-user VNet
  odaa_vnet_name       = module.odaa_slot_0[each.key].vnet_name        # ✅ Per-user VNet
  odaa_resource_group  = module.odaa_slot_0[each.key].resource_group_name
  # ...
}
```

#### 5. Update ADB Creation (if enabled)

**Current:**
```terraform
resource "azurerm_oracle_autonomous_database" "user" {
  for_each = var.create_oracle_database ? local.deployments : {}
  
  # ...
  subnet_id          = module.odaa_shared.subnet_id       # ❌ Shared subnet
  virtual_network_id = module.odaa_shared.vnet_id         # ❌ Shared VNet
  # ...
}
```

**Proposed:**
```terraform
locals {
  # Map each deployment to its ODAA module based on slot
  odaa_modules = merge(
    { for k, v in module.odaa_slot_0 : k => v },
    { for k, v in module.odaa_slot_1 : k => v },
    { for k, v in module.odaa_slot_2 : k => v },
    { for k, v in module.odaa_slot_3 : k => v },
    { for k, v in module.odaa_slot_4 : k => v }
  )
}

resource "azurerm_oracle_autonomous_database" "user" {
  for_each = var.create_oracle_database ? local.deployments : {}
  
  # ...
  subnet_id          = local.odaa_modules[each.key].subnet_id       # ✅ Per-user subnet
  virtual_network_id = local.odaa_modules[each.key].vnet_id         # ✅ Per-user VNet
  # ...
}
```

#### 6. Update Role Assignments

**Current:**
```terraform
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_group" {
  provider             = azurerm.odaa
  scope                = module.odaa_shared.resource_group_id  # ❌ Single RG
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = module.entra_id_users.group_object_id
  # ...
}
```

**Proposed - Option A (Subscription-wide):**
```terraform
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_group" {
  provider             = azurerm.odaa
  scope                = data.azurerm_subscription.odaa.id  # ✅ Entire subscription
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = module.entra_id_users.group_object_id
  # ...
}
```

**Proposed - Option B (Per-user RG):**
```terraform
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_per_user" {
  for_each = local.deployments
  
  provider             = azurerm.odaa
  scope                = local.odaa_modules[each.key].resource_group_id  # ✅ Per-user RG
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = local.deployment_user_object_ids[each.key]  # ✅ Individual user
  # ...
}
```

### Variables Update

**Update variables.tf:**

```terraform
variable "aks_cidr_base" {
  description = "The base CIDR block for AKS deployments (same for all users - isolated by VNet)"
  type        = string
  default     = "10.0.0.0"  # Changed from unique per user
}

variable "odaa_cidr_base" {
  description = "The base CIDR block for ODAA deployments (same for all users - isolated by VNet)"
  type        = string
  default     = "10.0.0.0"  # Changed from 192.168.0.0
}
```

**Update terraform.tfvars (optional - already using defaults):**

```hcl
# No changes needed - using variable defaults
# aks_cidr_base  = "10.0.0.0"
# odaa_cidr_base = "10.0.0.0"
```

## Resource Organization

### Current (Shared ODAA)

```
Resource Groups:
- odaa-user00 (single RG for all users)
  - odaa-user00 VNet (192.168.0.0/16)
  - user00's ADB
  - user01's ADB
  - user02's ADB
  - ...
```

### Proposed (Isolated ODAA)

```
Resource Groups:
- odaa-user00
  - odaa-user00 VNet (10.0.0.0/16)
  - user00's ADB only

- odaa-user01
  - odaa-user01 VNet (10.0.0.0/16)
  - user01's ADB only

- odaa-user02
  - odaa-user02 VNet (10.0.0.0/16)
  - user02's ADB only
```

## Security Comparison

### Current Architecture Security

```
┌─────────────────────────────────────┐
│ Shared ODAA VNet (192.168.0.0/16)  │
│                                     │
│  ┌────────┐  ┌────────┐            │
│  │ ADB-00 │  │ ADB-01 │            │
│  └────────┘  └────────┘            │
│       ↓           ↓                 │
│    Same network segment             │
│    Network isolation via NSGs only  │
└─────────────────────────────────────┘
```

**Security Concerns:**
- NSG misconfigurations could expose databases
- Shared network means shared attack surface
- One compromised ADB could affect others

### Proposed Architecture Security

```
┌──────────────────────┐      ┌──────────────────────┐
│ User00 ODAA VNet     │      │ User01 ODAA VNet     │
│ (10.0.0.0/16)        │      │ (10.0.0.0/16)        │
│                      │      │                      │
│  ┌────────┐          │      │  ┌────────┐          │
│  │ ADB-00 │          │      │  │ ADB-01 │          │
│  └────────┘          │      │  └────────┘          │
└──────────────────────┘      └──────────────────────┘
     Network Isolated             Network Isolated
```

**Security Benefits:**
- Complete network isolation at Azure fabric level
- No shared network segment
- Compromised ADB cannot reach other users' networks
- Simplified security model (no cross-user NSG rules needed)

## Migration Path

### Option 1: Clean Slate (Recommended)

```powershell
# 1. Destroy existing infrastructure
terraform destroy -auto-approve

# 2. Update code with proposed changes
# ... (make code changes) ...

# 3. Deploy new isolated architecture
terraform apply -auto-approve
```

**Pros:**
- Clean implementation
- No migration complexity
- Fast and reliable

**Cons:**
- Downtime required
- Data loss if ADBs exist

### Option 2: Blue-Green Migration

```powershell
# 1. Create new ODAA VNets alongside existing
terraform apply -target=module.odaa_slot_0 -auto-approve
terraform apply -target=module.odaa_slot_1 -auto-approve
# ... (repeat for all slots) ...

# 2. Migrate ADBs to new VNets
# (manual backup/restore or use OCI migration tools)

# 3. Update peering to point to new VNets
terraform apply -target=module.vnet_peering_slot_0 -auto-approve
# ... (repeat for all slots) ...

# 4. Remove old shared ODAA VNet
terraform state rm module.odaa_shared
terraform destroy -target=module.odaa_shared -auto-approve
```

**Pros:**
- Zero downtime possible
- Gradual migration

**Cons:**
- Complex orchestration
- Temporary increased cost

### Option 3: Targeted Replacement (Best for Testing)

```powershell
# 1. Test with single user first
user_count = 1

# 2. Apply changes
terraform apply -auto-approve

# 3. Verify isolated VNet works
az network vnet show --name odaa-user00 --resource-group odaa-user00

# 4. Scale up
user_count = 5
terraform apply -auto-approve
```

## Network Diagram Comparison

### Before (Shared ODAA - Current)

```
┌─────────────────────────────────────────────────────────┐
│                   ODAA Subscription                     │
│  ┌─────────────────────────────────────────────┐       │
│  │         odaa-user00 (192.168.0.0/16)        │       │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │       │
│  │  │ADB00│ │ADB01│ │ADB02│ │ADB03│ │ADB04│  │       │
│  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘  │       │
│  └─────────────────────────────────────────────┘       │
│         ↑         ↑         ↑         ↑         ↑       │
│      (peered) (peered) (peered) (peered) (peered)      │
└─────────┼─────────┼─────────┼─────────┼─────────┼──────┘
          │         │         │         │         │
┌─────────┼─────────┼─────────┼─────────┼─────────┼──────┐
│         ↓         ↓         ↓         ↓         ↓       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │AKS-user00│ │AKS-user01│ │AKS-user02│ │AKS-user03│  │
│  │10.0.0.0  │ │10.1.0.0  │ │10.2.0.0  │ │10.3.0.0  │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
│                Multiple Subscriptions                   │
└─────────────────────────────────────────────────────────┘
```

### After (Isolated ODAA - Proposed)

```
┌─────────────────────────────────────────────────────────┐
│                   ODAA Subscription                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │odaa-usr0│  │odaa-usr1│  │odaa-usr2│  │odaa-usr3│  │
│  │10.0.0.0 │  │10.0.0.0 │  │10.0.0.0 │  │10.0.0.0 │  │
│  │ ┌─────┐ │  │ ┌─────┐ │  │ ┌─────┐ │  │ ┌─────┐ │  │
│  │ │ADB00│ │  │ │ADB01│ │  │ │ADB02│ │  │ │ADB03│ │  │
│  │ └─────┘ │  │ └─────┘ │  │ └─────┘ │  │ └─────┘ │  │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  │
│      ↑            ↑            ↑            ↑          │
│   (peered)    (peered)    (peered)    (peered)        │
└──────┼────────────┼────────────┼────────────┼──────────┘
       │            │            │            │
┌──────┼────────────┼────────────┼────────────┼──────────┐
│      ↓            ↓            ↓            ↓          │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │AKS-usr0 │  │AKS-usr1 │  │AKS-usr2 │  │AKS-usr3 │  │
│  │10.0.0.0 │  │10.0.0.0 │  │10.0.0.0 │  │10.0.0.0 │  │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  │
│                Multiple Subscriptions                 │
└───────────────────────────────────────────────────────┘

Note: All VNets use 10.0.0.0/16 but are completely isolated
      (no inter-user VNet peering)
```

## Cost Impact

### Current (Shared ODAA)

```
- 1 ODAA VNet (shared)
- 1 ODAA Resource Group
- N VNet Peerings (one per user)
```

### Proposed (Isolated ODAA)

```
- N ODAA VNets (one per user)
- N ODAA Resource Groups (one per user)
- N VNet Peerings (one per user)
```

**Cost Difference:**
- **VNets:** No charge for VNets in Azure
- **Resource Groups:** No charge
- **Peerings:** Same number of peerings = same cost
- **Additional Resources:** Same subnet delegation, same ADBs

**Result:** ✅ **No additional cost** (VNets and RGs are free resources)

## Testing Checklist

After implementation:

```powershell
# 1. Verify isolated VNets created
az network vnet list --subscription 4aecf0e8-2fe2-4187-bc93-0356bd2676f5 --query "[?contains(name, 'odaa-user')].{Name:name, CIDR:addressSpace.addressPrefixes[0]}" -o table

# 2. Verify no peering between user VNets
az network vnet peering list --vnet-name odaa-user00 --resource-group odaa-user00 --query "[].remoteVirtualNetwork.id" -o table
# Should only show peering to aks-user00, NOT to other ODAA VNets

# 3. Test AKS to ADB connectivity (user00)
kubectl run -it --rm test-pod --image=busybox --restart=Never -- sh
# Inside pod: should be able to reach user00's ADB endpoint
# Should NOT be able to reach user01's ADB endpoint

# 4. Verify resource group isolation
az group show --name odaa-user00 --query "id"
az group show --name odaa-user01 --query "id"
# Should be separate resource groups

# 5. Check CIDR overlap (expected)
az network vnet show --name odaa-user00 --resource-group odaa-user00 --query "addressSpace.addressPrefixes"
az network vnet show --name odaa-user01 --resource-group odaa-user01 --query "addressSpace.addressPrefixes"
# Both should show [10.0.0.0/16] - this is correct!
```

## Summary

### Problem Solved
- ✅ Users cannot access each other's ADBs via network
- ✅ Complete isolation between user environments
- ✅ Simplified security model
- ✅ Better resource organization

### Implementation Effort
- **Code Changes:** ~100 lines modified
- **Testing Time:** ~1 hour
- **Deployment Time:** ~15 minutes (with clean slate)
- **Risk Level:** Low (if using destroy/recreate)

### Recommendation
**Proceed with Option 1 (Clean Slate)** if no production data exists:
1. Destroy current infrastructure
2. Implement code changes
3. Deploy new isolated architecture
4. Test connectivity and isolation

This provides the cleanest implementation with the strongest security posture.
