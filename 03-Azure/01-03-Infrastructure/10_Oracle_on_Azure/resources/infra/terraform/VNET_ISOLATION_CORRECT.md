# VNet Isolation - Correct Architecture

## Current Architecture (Shared ODAA VNet)

### Problem: All Users Share One ODAA VNet

```
Current Setup:
┌────────────────────────────────────────────────────────────────┐
│ ODAA Subscription: 4aecf0e8-2fe2-4187-bc93-0356bd2676f5        │
│                                                                │
│  ┌──────────────────────────────────────────────┐             │
│  │  odaa-user00 VNet: 192.168.0.0/16            │             │
│  │    - user00's ADB                            │             │
│  │    - user01's ADB                            │             │
│  │    - user02's ADB                            │             │
│  │    - All ADBs share same network             │             │
│  └──────────────────────────────────────────────┘             │
│         ↑ peered      ↑ peered      ↑ peered                  │
└─────────┼─────────────┼─────────────┼────────────────────────┘
          │             │             │
┌─────────┼─────────────┼─────────────┼────────────────────────┐
│         │             │             │                         │
│   ┌─────────┐   ┌─────────┐   ┌─────────┐                   │
│   │AKS-user00   │AKS-user01   │AKS-user02                    │
│   │10.0.0.0/16│ │10.1.0.0/16│ │10.2.0.0/16│                  │
│   └─────────┘   └─────────┘   └─────────┘                    │
│                                                                │
│   Multiple AKS Subscriptions (5 total)                        │
└────────────────────────────────────────────────────────────────┘
```

**Security Issues:**
- ❌ All users' ADBs in same VNet (192.168.0.0/16)
- ❌ User00 could potentially access User01's ADB
- ❌ Network isolation depends only on NSG rules
- ❌ Misconfigured NSG = cross-user access possible

## Proposed Architecture (Isolated ODAA VNets per User)

### Solution: Each User Gets Dedicated ODAA VNet

```
Proposed Setup:
┌──────────────────────────────────────────────────────────────────┐
│ ODAA Subscription: 4aecf0e8-2fe2-4187-bc93-0356bd2676f5          │
│                                                                  │
│  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐  │
│  │odaa-user00 VNet│   │odaa-user01 VNet│   │odaa-user02 VNet│  │
│  │192.168.0.0/16  │   │192.168.0.0/16  │   │192.168.0.0/16  │  │
│  │  - user00 ADB  │   │  - user01 ADB  │   │  - user02 ADB  │  │
│  └────────────────┘   └────────────────┘   └────────────────┘  │
│         ↑                    ↑                    ↑             │
│      (peered)             (peered)             (peered)         │
└─────────┼────────────────────┼────────────────────┼─────────────┘
          │                    │                    │
┌─────────┼────────────────────┼────────────────────┼─────────────┐
│         ↓                    ↓                    ↓             │
│   ┌─────────┐          ┌─────────┐          ┌─────────┐        │
│   │AKS-user00          │AKS-user01          │AKS-user02         │
│   │10.0.0.0/16│        │10.0.0.0/16│        │10.0.0.0/16│       │
│   └─────────┘          └─────────┘          └─────────┘         │
│                                                                  │
│   Multiple AKS Subscriptions (5 total)                          │
└──────────────────────────────────────────────────────────────────┘

KEY POINTS:
- Each user: Own ODAA VNet (192.168.0.0/16) + Own AKS VNet (10.0.0.0/16)
- ODAA VNets NOT peered to each other (complete isolation)
- AKS VNets NOT peered to each other (complete isolation)
- Each AKS ↔ ODAA peering is 1:1 per user
```

## Why Same CIDR Works

### Key Architecture Rules:

1. **All AKS VNets use `10.0.0.0/16`** - OKAY because they're not peered to each other
2. **All ODAA VNets use `192.168.0.0/16`** - OKAY because they're not peered to each other
3. **Each user's AKS-to-ODAA peering is isolated** - No overlap issues

### Per-User Network Topology:

```
User00 Environment (Completely Isolated):
┌──────────────────────────────────────┐
│ AKS Subscription: 556f9b63...        │
│   ┌────────────────────────┐         │
│   │ aks-user00             │         │
│   │ VNet: 10.0.0.0/16      │         │
│   │   Subnet: 10.0.0.0/23  │         │
│   └────────────────────────┘         │
└──────────────┬───────────────────────┘
               │ VNet Peering
               ↓
┌──────────────────────────────────────┐
│ ODAA Subscription: 4aecf0e8...       │
│   ┌────────────────────────┐         │
│   │ odaa-user00            │         │
│   │ VNet: 192.168.0.0/16   │         │
│   │   Subnet: 192.168.0.0/24│        │
│   │   - user00 ADB only    │         │
│   └────────────────────────┘         │
└──────────────────────────────────────┘

User01 Environment (Completely Isolated):
┌──────────────────────────────────────┐
│ AKS Subscription: a0844269...        │
│   ┌────────────────────────┐         │
│   │ aks-user01             │         │
│   │ VNet: 10.0.0.0/16      │ ← Same CIDR as user00, but isolated!
│   │   Subnet: 10.0.0.0/23  │         │
│   └────────────────────────┘         │
└──────────────┬───────────────────────┘
               │ VNet Peering
               ↓
┌──────────────────────────────────────┐
│ ODAA Subscription: 4aecf0e8...       │
│   ┌────────────────────────┐         │
│   │ odaa-user01            │         │
│   │ VNet: 192.168.0.0/16   │ ← Same CIDR as user00, but isolated!
│   │   Subnet: 192.168.0.0/24│        │
│   │   - user01 ADB only    │         │
│   └────────────────────────┘         │
└──────────────────────────────────────┘

NO peering between:
  - user00 AKS ←X→ user01 AKS
  - user00 ODAA ←X→ user01 ODAA
  - user00 AKS ←X→ user01 ODAA
```

## Implementation Changes

### Step 1: Update Variables (variables.tf)

**Current:**
```terraform
variable "aks_cidr_base" {
  description = "The base CIDR block for AKS deployments"
  type        = string
  default     = "10.0.0.0"  # Currently unique per user: 10.0, 10.1, 10.2...
}

variable "odaa_cidr_base" {
  description = "The base CIDR block for ODAA deployments"
  type        = string
  default     = "192.168.0.0"  # Currently shared single VNet
}
```

**Proposed (No change needed - already correct!):**
```terraform
variable "aks_cidr_base" {
  description = "The base CIDR block for AKS deployments (same for all users - isolated by VNet)"
  type        = string
  default     = "10.0.0.0"
}

variable "odaa_cidr_base" {
  description = "The base CIDR block for ODAA deployments (same for all users - isolated by VNet)"
  type        = string
  default     = "192.168.0.0"
}
```

### Step 2: Update Locals in main.tf

**Current (Line 47):**
```terraform
aks_cidr  = "10.${idx}.0.0"  # Unique: 10.0.0.0, 10.1.0.0, 10.2.0.0...
```

**Proposed:**
```terraform
aks_cidr  = "10.0.0.0"  # Same for all: 10.0.0.0
```

**Justification:** Each AKS VNet is in a different subscription and NOT peered to other AKS VNets, so overlapping CIDR is safe.

### Step 3: Remove Shared ODAA Module

**Current (Line ~458):**
```terraform
module "odaa_shared" {
  source = "./modules/odaa"
  
  providers = {
    azurerm = azurerm.odaa
  }
  
  prefix                     = "shared"
  postfix                    = ""
  location                   = var.location
  cidr                       = local.default_odaa_cidr_base  # 192.168.0.0
  password                   = null
  create_autonomous_database = false
  
  tags = merge(local.common_tags, {
    ODAAFor = "shared"
  })
}
```

**Action:** DELETE this entire module block

### Step 4: Create Per-User ODAA Modules

**Add after removing odaa_shared (for each slot):**

```terraform
# ===============================================================================
# ODAA VNets - Per User (Slot 0)
# ===============================================================================

module "odaa_slot_0" {
  source = "./modules/odaa"
  
  for_each = local.aks_deployments_by_slot["0"]
  
  providers = {
    azurerm = azurerm.odaa
  }
  
  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr  # 192.168.0.0 for all
  password                   = null
  create_autonomous_database = false
  
  tags = merge(local.common_tags, {
    ODAAFor   = each.value.name
    UserIndex = each.value.index
  })
}

# ===============================================================================
# ODAA VNets - Per User (Slot 1)
# ===============================================================================

module "odaa_slot_1" {
  source = "./modules/odaa"
  
  for_each = local.aks_deployments_by_slot["1"]
  
  providers = {
    azurerm = azurerm.odaa
  }
  
  prefix                     = each.value.prefix
  postfix                    = each.value.postfix
  location                   = each.value.location
  cidr                       = each.value.odaa_cidr  # 192.168.0.0 for all
  password                   = null
  create_autonomous_database = false
  
  tags = merge(local.common_tags, {
    ODAAFor   = each.value.name
    UserIndex = each.value.index
  })
}

# Repeat for slots 2, 3, 4...
```

### Step 5: Create ODAA Module Lookup Map

**Add after ODAA module definitions:**

```terraform
# ===============================================================================
# ODAA Module Outputs Map
# ===============================================================================
# Maps each deployment key to its corresponding ODAA module output

locals {
  odaa_modules = merge(
    module.odaa_slot_0,
    module.odaa_slot_1,
    module.odaa_slot_2,
    module.odaa_slot_3,
    module.odaa_slot_4
  )
}
```

### Step 6: Update VNet Peering (All 5 Slots)

**Current (Line ~589-590):**
```terraform
module "vnet_peering_slot_0" {
  source = "./modules/vnet-peering"
  
  for_each = local.aks_deployments_by_slot["0"]
  
  # ... other config ...
  
  odaa_vnet_id         = module.odaa_shared.vnet_id          # ❌ Shared VNet
  odaa_vnet_name       = module.odaa_shared.vnet_name        # ❌ Shared VNet
  odaa_resource_group  = module.odaa_shared.resource_group_name
}
```

**Proposed:**
```terraform
module "vnet_peering_slot_0" {
  source = "./modules/vnet-peering"
  
  for_each = local.aks_deployments_by_slot["0"]
  
  # ... other config ...
  
  odaa_vnet_id         = module.odaa_slot_0[each.key].vnet_id          # ✅ Per-user VNet
  odaa_vnet_name       = module.odaa_slot_0[each.key].vnet_name        # ✅ Per-user VNet
  odaa_resource_group  = module.odaa_slot_0[each.key].resource_group_name
}
```

**Repeat for all 5 slots (slot_0 through slot_4)**

### Step 7: Update ADB Resource

**Current (uses shared ODAA subnet):**
```terraform
resource "azurerm_oracle_autonomous_database" "user" {
  for_each = var.create_oracle_database ? local.deployments : {}
  
  # ... other config ...
  
  subnet_id          = module.odaa_shared.subnet_id       # ❌ Shared subnet
  virtual_network_id = module.odaa_shared.vnet_id         # ❌ Shared VNet
}
```

**Proposed (uses per-user ODAA subnet):**
```terraform
resource "azurerm_oracle_autonomous_database" "user" {
  for_each = var.create_oracle_database ? local.deployments : {}
  
  # ... other config ...
  
  subnet_id          = local.odaa_modules[each.key].subnet_id       # ✅ Per-user subnet
  virtual_network_id = local.odaa_modules[each.key].vnet_id         # ✅ Per-user VNet
}
```

### Step 8: Update Role Assignments

**Current:**
```terraform
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_group" {
  provider             = azurerm.odaa
  scope                = module.odaa_shared.resource_group_id  # ❌ Single RG
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = module.entra_id_users.group_object_id
  description          = "Grants ... permissions ..."
}
```

**Proposed (Option 1 - Subscription scope):**
```terraform
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_group" {
  provider             = azurerm.odaa
  scope                = data.azurerm_subscription.odaa.id  # ✅ Entire subscription
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = module.entra_id_users.group_object_id
  description          = "Grants group permissions to manage ADB resources across all user resource groups."
}
```

**Proposed (Option 2 - Per-user RG, per-user permissions):**
```terraform
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_per_user" {
  for_each = local.deployments
  
  provider             = azurerm.odaa
  scope                = local.odaa_modules[each.key].resource_group_id  # ✅ Per-user RG
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = local.deployment_user_object_ids[each.key]  # ✅ Individual user
  description          = "Grants ${each.value.name} permissions to manage ADB in their resource group."
}
```

## Network Flow After Implementation

### User00 Accessing Their ADB:

```
1. App running in AKS user00 pod (10.0.0.5)
   ↓
2. Targets ADB endpoint: user00adb.adb.eu-paris-1.oraclecloud.com
   ↓
3. DNS resolves to private IP: 192.168.0.10 (in user00's ODAA VNet)
   ↓
4. Traffic flows through VNet peering: aks-user00 ↔ odaa-user00
   ↓
5. Reaches ADB in odaa-user00 VNet (192.168.0.10)
   ✅ SUCCESS
```

### User00 CANNOT Access User01's ADB:

```
1. App running in AKS user00 pod (10.0.0.5)
   ↓
2. Targets ADB endpoint: user01adb.adb.eu-paris-1.oraclecloud.com
   ↓
3. DNS resolves to private IP: 192.168.0.10 (in user01's ODAA VNet)
   ↓
4. Tries to reach 192.168.0.10
   ✗ NO ROUTE: aks-user00 NOT peered to odaa-user01
   ✗ BLOCKED at Azure fabric level
   ❌ FAILURE - Network isolation working!
```

## Resource Organization

### Current:
```
ODAA Subscription:
  └─ odaa-user00 (Resource Group)
      └─ odaa-user00 VNet (192.168.0.0/16)
          ├─ user00's ADB
          ├─ user01's ADB
          └─ user02's ADB

AKS Subscriptions:
  ├─ aks-user00 (10.0.0.0/16)
  ├─ aks-user01 (10.1.0.0/16)  ← Different CIDRs
  └─ aks-user02 (10.2.0.0/16)
```

### Proposed:
```
ODAA Subscription:
  ├─ odaa-user00 (Resource Group)
  │   └─ odaa-user00 VNet (192.168.0.0/16)
  │       └─ user00's ADB only
  ├─ odaa-user01 (Resource Group)
  │   └─ odaa-user01 VNet (192.168.0.0/16)  ← Same CIDR, different VNet
  │       └─ user01's ADB only
  └─ odaa-user02 (Resource Group)
      └─ odaa-user02 VNet (192.168.0.0/16)  ← Same CIDR, different VNet
          └─ user02's ADB only

AKS Subscriptions:
  ├─ aks-user00 (10.0.0.0/16)  ← All same CIDR now
  ├─ aks-user01 (10.0.0.0/16)
  └─ aks-user02 (10.0.0.0/16)
```

## Benefits

### Security:
- ✅ Complete network isolation at Azure fabric level
- ✅ User00 physically cannot reach User01's ADB (no network path)
- ✅ No shared network means no NSG misconfiguration risks
- ✅ Blast radius limited to single user

### Simplicity:
- ✅ All AKS VNets use 10.0.0.0/16 (easier to remember/document)
- ✅ All ODAA VNets use 192.168.0.0/16 (consistent addressing)
- ✅ No complex CIDR calculations needed
- ✅ Simplified network documentation

### Operations:
- ✅ Clear resource ownership (1 RG = 1 user)
- ✅ Independent lifecycle per user
- ✅ Easy to delete single user's environment
- ✅ Better cost tracking per user

### Scalability:
- ✅ Scales to unlimited users (no CIDR exhaustion)
- ✅ No need to track unique CIDR ranges

## Cost Impact

**No additional cost:**
- VNets: Free in Azure
- Resource Groups: Free
- Peerings: Same count (1 per user)
- Subnets: Same count
- ADBs: Same count

**Result:** Same cost as current architecture

## Migration Steps

### Recommended: Clean Slate Approach

```powershell
# 1. Destroy existing infrastructure
terraform destroy -auto-approve

# 2. Update code (see implementation steps above)

# 3. Verify changes
terraform plan

# 4. Deploy new isolated architecture
terraform apply -auto-approve

# 5. Test connectivity
# (see testing section below)
```

## Testing Checklist

```powershell
# 1. Verify per-user ODAA VNets created with same CIDR
az network vnet list --subscription 4aecf0e8-2fe2-4187-bc93-0356bd2676f5 `
  --query "[?contains(name, 'odaa-user')].{Name:name, CIDR:addressSpace.addressPrefixes[0], RG:resourceGroup}" `
  -o table

# Expected output:
# Name          CIDR              RG
# odaa-user00   192.168.0.0/16    odaa-user00
# odaa-user01   192.168.0.0/16    odaa-user01
# odaa-user02   192.168.0.0/16    odaa-user02

# 2. Verify AKS VNets all use same CIDR
# (Check across multiple subscriptions)
# Expected: All show 10.0.0.0/16

# 3. Verify peering is 1:1 per user
az network vnet peering list --vnet-name odaa-user00 --resource-group odaa-user00 `
  --query "[].{Name:name, RemoteVNet:remoteVirtualNetwork.id}" -o table

# Expected: Only shows peering to aks-user00, NOT to other ODAA VNets

# 4. Test connectivity from AKS to own ADB
kubectl run test-user00 --image=busybox -it --rm -- nslookup user00adb.adb.eu-paris-1.oraclecloud.com
# Should resolve to 192.168.0.x

# 5. Verify isolation (user00 CANNOT reach user01's ADB)
kubectl exec -it test-pod -- ping 192.168.0.10  # user01's ADB IP
# Should timeout or fail (no route)

# 6. Check resource group isolation
az group list --subscription 4aecf0e8-2fe2-4187-bc93-0356bd2676f5 `
  --query "[?contains(name, 'odaa-user')].{Name:name, Location:location}" -o table

# Expected: Separate RG per user
```

## Summary

### What Changes:
1. ✅ AKS CIDR: From unique per user (`10.0.0.0`, `10.1.0.0`...) → Same for all (`10.0.0.0`)
2. ✅ ODAA Architecture: From shared VNet → Per-user isolated VNets
3. ✅ ODAA CIDR: Same `192.168.0.0/16` for all (isolated by VNet)
4. ✅ Peering: Still 1:1 per user (aks-userN ↔ odaa-userN only)

### What Doesn't Change:
- ❌ Number of VNets (same: N AKS + N ODAA)
- ❌ Number of peerings (same: N peerings)
- ❌ Cost (VNets and RGs are free)
- ❌ ADB functionality (works exactly same)

### Result:
**Complete user isolation with simpler, consistent addressing scheme.**
