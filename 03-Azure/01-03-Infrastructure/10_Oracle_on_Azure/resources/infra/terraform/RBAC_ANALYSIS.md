# RBAC Analysis - Current vs Proposed Per-User Isolation

## Current RBAC Architecture

### Overview
Currently using a **shared group** model where all users belong to one Entra ID group with shared permissions.

### Entra ID Structure

```
Entra ID Group: "mh-odaa-user-grp"
├─ user00@cptazure.org
├─ user01@cptazure.org
├─ user02@cptazure.org
├─ user03@cptazure.org
└─ user04@cptazure.org

All users = Same group = Same permissions
```

## Current RBAC Assignments

### 1. ODAA Subscription Level (Shared Resources)

#### A. Autonomous Database Administrator Role
**Location:** `main.tf` line 248  
**Resource:** `azurerm_role_assignment.odaa_autonomous_database_admin_group`

```terraform
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_group" {
  provider             = azurerm.odaa
  scope                = module.odaa_shared.resource_group_id  # ❌ Single shared RG
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = module.entra_id_users.group_object_id  # ❌ Entire group
  description          = "Grants mh-odaa-user-grp permissions to manage Oracle ADB resources"
}
```

**Issue:** All users can manage ALL ADBs in the shared resource group
- User00 can modify/delete User01's ADB ❌
- User01 can modify/delete User02's ADB ❌

#### B. Private DNS Zone Reader (Custom Role)
**Location:** `main.tf` lines 256-278  
**Resources:** 
- `azurerm_role_definition.private_dns_zone_reader`
- `azurerm_role_assignment.odaa_private_dns_zone_reader_group`

```terraform
resource "azurerm_role_definition" "private_dns_zone_reader" {
  name        = "custom-private-dns-zone-reader"
  scope       = data.azurerm_subscription.odaa.id  # Subscription-wide
  description = "Allows read-only access to Private DNS Zones."

  permissions {
    actions = [
      "Microsoft.Network/privateDnsZones/read",
      "Microsoft.Network/privateDnsZones/*/read"
    ]
  }
}

resource "azurerm_role_assignment" "odaa_private_dns_zone_reader_group" {
  provider           = azurerm.odaa
  scope              = data.azurerm_subscription.odaa.id  # ✅ Read-only, subscription-wide OK
  role_definition_id = azurerm_role_definition.private_dns_zone_reader.role_definition_resource_id
  principal_id       = module.entra_id_users.group_object_id
}
```

**Assessment:** ✅ This is fine - read-only access to DNS zones is needed across subscription

#### C. Oracle Subscriptions Manager Reader (Custom Role)
**Location:** `roles.tf` lines 5-24, `main.tf` lines 283-289

```terraform
resource "azurerm_role_definition" "oracle_subscriptions_manager_reader" {
  name  = "Oracle Subscriptions Manager Reader"
  scope = "/providers/Microsoft.Management/managementGroups/mhteams"  # Management Group scope

  permissions {
    actions = [
      "Oracle.Database/Locations/*/read",
      "Oracle.Database/oracleSubscriptions/*/read",
      "Oracle.Database/oracleSubscriptions/listCloudAccountDetails/action"
    ]
  }
}

resource "azurerm_role_assignment" "odaa_subscription_manager_reader_group" {
  provider           = azurerm.odaa
  scope              = data.azurerm_subscription.odaa.id  # ✅ Read-only, subscription-wide OK
  role_definition_id = azurerm_role_definition.oracle_subscriptions_manager_reader.role_definition_resource_id
  principal_id       = module.entra_id_users.group_object_id
}
```

**Assessment:** ✅ This is fine - read-only access to Oracle subscription metadata

### 2. AKS Subscription Level (Per-User Resources)

#### A. AKS Cluster User Role
**Location:** `modules/aks/main.tf` line 219

```terraform
resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = azurerm_kubernetes_cluster.aks.id  # ✅ Per-cluster scope
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.deployment_user_object_id  # ✅ Individual user
  description          = "Allows user to get cluster credentials"
}
```

**Assessment:** ✅ Already isolated per user!
- User00 → aks-user00 only
- User01 → aks-user01 only

#### B. AKS RBAC Writer Role
**Location:** `modules/aks/main.tf` line 227

```terraform
resource "azurerm_role_assignment" "aks_rbac_writer" {
  scope                = azurerm_kubernetes_cluster.aks.id  # ✅ Per-cluster scope
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = var.deployment_user_object_id  # ✅ Individual user
  description          = "Allows user to deploy Kubernetes workloads"
}
```

**Assessment:** ✅ Already isolated per user!

#### C. Subscription Reader Role
**Location:** `modules/aks/main.tf` line 235

```terraform
resource "azurerm_role_assignment" "subscription_reader" {
  scope                = "/subscriptions/${var.subscription_id}"  # ⚠️ Entire subscription
  role_definition_name = "Reader"
  principal_id         = var.deployment_user_object_id  # ✅ Individual user
  description          = "Allows user to view resources in subscription"
}
```

**Assessment:** ⚠️ Users can see other users' resources in same subscription
- User00 can see User02's resources (both in subscription slot_0)
- This is read-only, so acceptable for learning environment

#### D. Private DNS Zone Contributor
**Location:** `modules/aks/main.tf` line 298

```terraform
resource "azurerm_role_assignment" "private_dns_contributor_odaa" {
  for_each = local.private_dns_configs  # 4 DNS zones (FRA/PAR base/app)

  scope                = azurerm_private_dns_zone.odaa[each.key].id  # ✅ Per-zone scope
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = var.deployment_user_object_id  # ✅ Individual user
  description          = "Allows user to manage private DNS zone"
}
```

**Assessment:** ✅ Already isolated per user (each user has their own DNS zones)

### 3. Azure Policy Assignments
**Location:** `policies.tf`

```terraform
resource "azurerm_policy_definition" "oracle_autonomous_database_restrictions" {
  name                = "oracle-autonomous-database-restrictions"
  display_name        = "Oracle Autonomous Database Restrictions"
  management_group_id = data.azurerm_management_group.mhteams.id  # Management Group scope
  
  # Policy rules for ADB restrictions
}

resource "azurerm_management_group_policy_assignment" "oracle_autonomous_database_restrictions" {
  name                 = "oracle-adb-restrictions"
  management_group_id  = data.azurerm_management_group.mhteams.id
  policy_definition_id = azurerm_policy_definition.oracle_autonomous_database_restrictions.id
}
```

**Assessment:** ✅ This is fine - applies restrictions across all subscriptions

## RBAC Issues with Current Architecture

### Problem 1: Shared ODAA Resource Group Permissions

```
Current Situation:
┌────────────────────────────────────────┐
│ ODAA Subscription                      │
│  ┌────────────────────────────────┐   │
│  │ odaa-user00 (Resource Group)   │   │
│  │  ├─ user00's ADB               │   │
│  │  ├─ user01's ADB               │   │
│  │  └─ user02's ADB               │   │
│  └────────────────────────────────┘   │
│        ↑                               │
│        │ All users have "ADB Admin"    │
│        │ role on this RG               │
└────────────────────────────────────────┘

Result: User00 can delete User01's ADB! ❌
```

### Problem 2: Cross-User Visibility in AKS Subscriptions

```
AKS Subscription slot_0 (556f9b63...):
├─ aks-user00 (owned by user00)
├─ aks-user05 (owned by user05)
└─ aks-user10 (owned by user10)

Both user00 and user05 have "Reader" role on entire subscription
→ user00 can see user05's AKS cluster (read-only) ⚠️
```

**Note:** This is acceptable for training/learning environments

## Proposed RBAC Architecture (Per-User Isolation)

### Goal: Principle of Least Privilege
- Each user only has access to **their own resources**
- No cross-user access except necessary read-only permissions

### New Structure with Per-User ODAA VNets

```
ODAA Subscription:
├─ odaa-user00 (RG) → Only user00 has access
├─ odaa-user01 (RG) → Only user01 has access
├─ odaa-user02 (RG) → Only user02 has access
└─ odaa-user03 (RG) → Only user03 has access

AKS Subscriptions:
├─ aks-user00 (RG) → Only user00 has access
├─ aks-user01 (RG) → Only user01 has access
└─ aks-user02 (RG) → Only user02 has access
```

## Proposed RBAC Changes

### Change 1: Per-User ODAA Resource Group Permissions

**Remove:** Shared group assignment
```terraform
# DELETE THIS:
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_group" {
  provider             = azurerm.odaa
  scope                = module.odaa_shared.resource_group_id  # ❌ Shared RG
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = module.entra_id_users.group_object_id  # ❌ Entire group
}
```

**Add:** Per-user resource group assignments
```terraform
# ADD THIS:
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_per_user" {
  for_each = local.deployments  # One per user
  
  provider             = azurerm.odaa
  scope                = local.odaa_modules[each.key].resource_group_id  # ✅ Per-user RG
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = local.deployment_user_object_ids[each.key]  # ✅ Individual user only
  
  description = "Grants ${each.value.name} exclusive permissions to manage ADB in their resource group"
}
```

**Result:**
- User00 can only manage ADBs in `odaa-user00` RG ✅
- User00 CANNOT access `odaa-user01` RG ✅

### Change 2: Keep Read-Only Subscription Permissions

**Keep unchanged (already appropriate):**

```terraform
# ✅ KEEP - Users need to read DNS zones across subscription
resource "azurerm_role_assignment" "odaa_private_dns_zone_reader_group" {
  provider           = azurerm.odaa
  scope              = data.azurerm_subscription.odaa.id
  role_definition_id = azurerm_role_definition.private_dns_zone_reader.role_definition_resource_id
  principal_id       = module.entra_id_users.group_object_id
}

# ✅ KEEP - Users need to read Oracle subscription metadata
resource "azurerm_role_assignment" "odaa_subscription_manager_reader_group" {
  provider           = azurerm.odaa
  scope              = data.azurerm_subscription.odaa.id
  role_definition_id = azurerm_role_definition.oracle_subscriptions_manager_reader.role_definition_resource_id
  principal_id       = module.entra_id_users.group_object_id
}
```

**Rationale:** Read-only permissions at subscription level are safe and necessary

### Change 3: AKS Permissions (Already Correct!)

**No changes needed - already per-user:**

```terraform
# ✅ Already correct - scoped to individual cluster
resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.deployment_user_object_id  # Individual user
}

# ✅ Already correct - scoped to individual cluster
resource "azurerm_role_assignment" "aks_rbac_writer" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = var.deployment_user_object_id  # Individual user
}

# ✅ Already correct - scoped to user's DNS zones
resource "azurerm_role_assignment" "private_dns_contributor_odaa" {
  for_each             = local.private_dns_configs
  scope                = azurerm_private_dns_zone.odaa[each.key].id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = var.deployment_user_object_id  # Individual user
}
```

### Change 4: Consider Restricting AKS Subscription Reader (Optional)

**Current:**
```terraform
# Users can see ALL resources in their AKS subscription
resource "azurerm_role_assignment" "subscription_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = var.deployment_user_object_id
}
```

**Option A: Keep as-is (Recommended for training)**
- Users can see other users' resources in same subscription (read-only)
- Easier troubleshooting and learning
- No security risk (read-only)

**Option B: Restrict to Resource Group only**
```terraform
# Users can only see resources in their own RG
resource "azurerm_role_assignment" "resource_group_reader" {
  scope                = azurerm_resource_group.aks.id  # RG scope instead of subscription
  role_definition_name = "Reader"
  principal_id         = var.deployment_user_object_id
}
```

**Recommendation:** Keep Option A (subscription-level reader) for training environments

## Summary of RBAC Changes

### What Changes:
```diff
ODAA Subscription:
- ❌ DELETE: Group-level "ADB Admin" on shared RG
+ ✅ ADD: Per-user "ADB Admin" on their own RG only

+ ✅ KEEP: Group-level "DNS Reader" on subscription (read-only)
+ ✅ KEEP: Group-level "Oracle Subscription Reader" on subscription (read-only)
```

### What Stays the Same:
```
AKS Subscriptions:
✅ Per-user "Cluster User" on their cluster
✅ Per-user "RBAC Writer" on their cluster
✅ Per-user "Reader" on subscription (optional: scope to RG)
✅ Per-user "DNS Contributor" on their DNS zones

Management Group:
✅ Policy assignments (restrictions)
✅ Custom role definitions
```

## RBAC Comparison Matrix

| Permission | Current Scope | Current Principal | Proposed Scope | Proposed Principal | Risk Level |
|------------|---------------|-------------------|----------------|-------------------|------------|
| **ODAA - ADB Admin** | Shared RG | Group (all users) | Per-user RG | Individual user | 🔴→🟢 High→Low |
| **ODAA - DNS Reader** | Subscription | Group (all users) | Subscription | Group (all users) | 🟢 Low (read-only) |
| **ODAA - Oracle Sub Reader** | Subscription | Group (all users) | Subscription | Group (all users) | 🟢 Low (read-only) |
| **AKS - Cluster User** | Per-cluster | Individual user | Per-cluster | Individual user | 🟢 Low (already isolated) |
| **AKS - RBAC Writer** | Per-cluster | Individual user | Per-cluster | Individual user | 🟢 Low (already isolated) |
| **AKS - Subscription Reader** | Subscription | Individual user | Subscription | Individual user | 🟡 Medium (can see others' resources) |
| **AKS - DNS Contributor** | Per-DNS zone | Individual user | Per-DNS zone | Individual user | 🟢 Low (already isolated) |

**Legend:**
- 🔴 High Risk: Can modify/delete other users' resources
- 🟡 Medium Risk: Can see other users' resources (read-only)
- 🟢 Low Risk: Properly isolated or read-only necessary permissions

## Implementation Code

### In main.tf

**Replace lines 248-254:**

```terraform
# OLD (DELETE):
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_group" {
  provider             = azurerm.odaa
  scope                = module.odaa_shared.resource_group_id
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = module.entra_id_users.group_object_id
  description          = "Grants ${module.entra_id_users.group_display_name} permissions..."
}
```

**With:**

```terraform
# NEW (ADD):
resource "azurerm_role_assignment" "odaa_autonomous_database_admin_per_user" {
  for_each = local.deployments
  
  provider             = azurerm.odaa
  scope                = local.odaa_modules[each.key].resource_group_id
  role_definition_name = "Oracle.Database Autonomous Database Administrator"
  principal_id         = local.deployment_user_object_ids[each.key]
  
  description = "Grants ${each.value.name} exclusive admin permissions for ADB resources in ${local.odaa_modules[each.key].resource_group_name}"
}
```

## Testing RBAC Isolation

### Test 1: Verify User00 Cannot Access User01's ODAA Resources

```powershell
# Login as user00
az login -u user00@cptazure.org

# Try to list resources in user01's ODAA RG (should fail)
az resource list --resource-group odaa-user01
# Expected: Error - user00 has no permissions

# Try to list resources in own ODAA RG (should succeed)
az resource list --resource-group odaa-user00
# Expected: Success - shows user00's ADB

# Try to delete user01's ADB (should fail)
az oracle autonomous-database delete --name user01adb --resource-group odaa-user01
# Expected: Error - Forbidden
```

### Test 2: Verify User00 Can Access Own Resources

```powershell
# List own ADB
az oracle autonomous-database show --name user00adb --resource-group odaa-user00
# Expected: Success

# Stop own ADB
az oracle autonomous-database stop --name user00adb --resource-group odaa-user00
# Expected: Success

# Start own ADB
az oracle autonomous-database start --name user00adb --resource-group odaa-user00
# Expected: Success
```

### Test 3: Verify Read-Only Subscription Access Still Works

```powershell
# List all Oracle subscriptions (should succeed - read-only)
az oracle subscription list
# Expected: Success - shows subscription metadata

# List private DNS zones (should succeed - read-only)
az network private-dns zone list --subscription 4aecf0e8-2fe2-4187-bc93-0356bd2676f5
# Expected: Success - shows DNS zones (but cannot modify)
```

## Conclusion

### Current Issues:
- ❌ Users can delete each other's ADBs (shared ODAA RG permissions)
- ⚠️ Users can see each other's resources in shared AKS subscriptions (read-only)

### After Proposed Changes:
- ✅ Complete isolation: Users can only manage their own ODAA resources
- ✅ Network isolation: Per-user VNets (no cross-user connectivity)
- ✅ RBAC isolation: Per-user resource group permissions
- ✅ Maintained read-only shared access where necessary (DNS, subscriptions)

### Best Practice Alignment:
- ✅ Principle of Least Privilege
- ✅ Defense in Depth (network + RBAC isolation)
- ✅ Clear ownership boundaries (1 user = 1 RG)
- ✅ Appropriate shared read-only access
