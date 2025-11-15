# RBAC Access Rights Summary - Per User

This document provides a comprehensive overview of all access rights granted to a single user (e.g., user00) in the infrastructure.

## Overview

Each user receives isolated access to their own dedicated resources with **complete isolation** from other users. The architecture ensures users can only access their own AKS cluster, ODAA VNet, Oracle database resources, and Cloud Shell storage.

---

## User00 Example - Complete Access Rights

### 1. Azure Kubernetes Service (AKS) Permissions

**Cluster:** `aks-user00` (in subscription: depends on round-robin assignment)

| Role | Scope | Permissions | Purpose |
|------|-------|-------------|---------|
| **Azure Kubernetes Service Cluster User Role** | AKS Cluster `aks-user00` | Get cluster credentials | Allows user to run `az aks get-credentials` to obtain kubeconfig |
| **Azure Kubernetes Service RBAC Writer** | AKS Cluster `aks-user00` | Full Kubernetes RBAC write access | Allows user to deploy workloads, create namespaces, manage pods/services/deployments in ALL namespaces |
| **Reader** | AKS Subscription | Read all resources | View resources in the subscription (VNets, AKS clusters, resource groups) |

**What user CAN do in AKS:**
- ✅ Get kubeconfig and connect to cluster
- ✅ Create/delete/modify ANY namespace
- ✅ Deploy workloads to ANY namespace
- ✅ Create services, ingresses, secrets, configmaps
- ✅ View cluster nodes, pods, events
- ✅ Install helm charts anywhere in the cluster
- ✅ Run kubectl commands with admin-like privileges

**What user CANNOT do in AKS:**
- ❌ Access other users' AKS clusters (different subscriptions/clusters)
- ❌ Modify cluster-level settings (node pools, networking, upgrades)
- ❌ Create new AKS clusters

---

### 2. Oracle Database@Azure (ODAA) Permissions

**ODAA VNet:** `odaa-user00` (in ODAA subscription: `4aecf0e8-2fe2-4187-bc93-0356bd2676f5`)
**Resource Group:** `odaa-user00`

| Role | Scope | Permissions | Purpose |
|------|-------|-------------|---------|
| **Oracle.Database Autonomous Database Administrator** | Resource Group `odaa-user00` | Full admin on ADB resources | Create, delete, modify Oracle Autonomous Databases in their RG |
| **Private DNS Zone Reader** (custom) | ODAA Subscription | Read Private DNS Zones | View Oracle DNS zones for connectivity |
| **Oracle Subscriptions Manager Reader** (custom) | ODAA Subscription | Read Oracle subscription details | View Oracle subscription information |
| **Private DNS Zone Contributor** | Oracle Private DNS Zones | Manage DNS records | Create DNS records for ADB connectivity (4 zones) |

**What user CAN do in ODAA:**
- ✅ Create/delete/manage Oracle Autonomous Databases in their own RG (`odaa-user00`)
- ✅ View Oracle subscription details
- ✅ View Private DNS zones
- ✅ Create DNS A records in Oracle Private DNS zones
- ✅ Access their ODAA VNet resources

**What user CANNOT do in ODAA:**
- ❌ Access other users' ODAA resource groups (`odaa-user01`, `odaa-user02`, etc.)
- ❌ Create/delete/modify other users' databases
- ❌ View or access other users' ODAA VNets (network isolation)
- ❌ Modify ODAA subscription settings

---

### 3. Cloud Shell Storage Permissions

**Storage Account:** `odaamh` (shared by all users)
**File Share:** `cloudshell-user00` (dedicated to user00)
**Resource Group:** `odaa`

| Role | Scope | Permissions | Purpose |
|------|-------|-------------|---------|
| **Storage Blob Data Contributor** | Storage Account `odaamh` | Read/write/delete blobs | Access Cloud Shell state files and blobs |
| **Storage File Data SMB Share Contributor** | Storage Account `odaamh` | Full access to file shares | Access their Cloud Shell home directory |
| **Reader** | Resource Group `odaa` | Read resources | View storage account in Azure Portal during Cloud Shell setup |

**What user CAN do with Cloud Shell Storage:**
- ✅ Read/write files in their file share (`cloudshell-user00`)
- ✅ Store Cloud Shell state and profile
- ✅ Access their home directory in Cloud Shell
- ✅ View storage account details

**What user CANNOT do:**
- ❌ Access other users' file shares (`cloudshell-user01`, `cloudshell-user02`, etc.)
- ❌ Delete or modify the storage account
- ❌ View or access other users' Cloud Shell files

---

### 4. Entra ID / Azure AD Permissions

**User Account:** `user00@cptazure.org`
**Group Membership:** `mh-odaa-user-grp` (all users)

| Permission | Scope | Purpose |
|------------|-------|---------|
| **User** (standard) | Entra ID Tenant | Standard user account permissions |
| **Group Member** | `mh-odaa-user-grp` | Access to Oracle Cloud Infrastructure Console (app role assigned) |

**What user CAN do:**
- ✅ Log in to Azure Portal
- ✅ Access assigned subscriptions and resources
- ✅ Use Azure CLI / PowerShell with their credentials
- ✅ Access Oracle Cloud Infrastructure Console (via group membership)

**What user CANNOT do:**
- ❌ Create new users or modify other users
- ❌ Manage group memberships
- ❌ Modify Entra ID settings

---

## Network Isolation

### VNet Architecture (user00)

**AKS VNet:** `vnet-aks-user00` (CIDR: `10.0.0.0/16`)
- Subnet: `snet-aks-user00` (`10.0.0.0/23`)
- Service CIDR: `172.16.0.0/24` (unique per user)

**ODAA VNet:** `odaa-user00` (CIDR: `192.168.0.0/16`)
- Subnet: `snet-odaa-user00` (`192.168.0.0/24`)

**Peering:** `aks-user00 ↔ odaa-user00` (1:1 peering)

**Isolation:**
- ✅ user00's AKS VNet is peered ONLY to user00's ODAA VNet
- ✅ NO peering to other users' VNets
- ✅ All users use same CIDR ranges (isolation by VNet boundaries, not CIDR)
- ✅ Network traffic cannot cross between users

---

## Security Summary

### ✅ What Each User Has ACCESS To

| Resource Type | Scope | Access Level |
|---------------|-------|--------------|
| **AKS Cluster** | Their own cluster only | Full RBAC Writer (admin-like) |
| **AKS Subscription** | Read-only | View resources |
| **ODAA Resource Group** | Their own RG only | Full ADB Administrator |
| **ODAA VNet** | Their own VNet only | Network access via peering |
| **Private DNS Zones** | ODAA subscription | Contributor (create records) |
| **Cloud Shell Storage** | Shared storage account | Access only their file share |
| **Oracle Subscription** | ODAA subscription | Read-only (subscription details) |

### ❌ What Each User Does NOT Have Access To

| Resource Type | Restriction |
|---------------|-------------|
| **Other Users' AKS Clusters** | Complete isolation - different subscriptions/clusters |
| **Other Users' ODAA RGs** | No permissions - RBAC scoped to own RG only |
| **Other Users' ODAA VNets** | Network isolation - no peering to other users |
| **Other Users' Databases** | Cannot view, modify, or delete |
| **Other Users' Cloud Shell** | Cannot access file shares or files |
| **Cluster Admin Operations** | Cannot modify node pools, cluster settings |
| **Subscription Management** | Cannot create resources outside assigned scopes |

---

## Comparison: Current vs Previous Architecture

### Previous (Shared ODAA VNet)

| Issue | Risk Level |
|-------|-----------|
| All users in same ODAA VNet | **HIGH** - Network access to all databases |
| Group-level ADB Admin on shared RG | **HIGH** - user00 could delete user01's database |
| Same ODAA resource group | **MEDIUM** - Resource confusion/conflicts |

### Current (Per-User Isolation)

| Improvement | Benefit |
|-------------|---------|
| Per-user ODAA VNets | **Complete network isolation** |
| Per-user ODAA RGs | **Complete resource isolation** |
| Per-user RBAC scoping | **Cannot access other users' databases** |
| Per-user file shares | **Cloud Shell data isolation** |

---

## Permission Hierarchy

```
user00@cptazure.org
│
├── AKS Subscription (Round-robin assigned)
│   ├── AKS Cluster: aks-user00
│   │   ├── Cluster User Role ✅
│   │   └── RBAC Writer ✅ (FULL ACCESS TO ALL NAMESPACES)
│   └── Subscription Reader ✅
│
├── ODAA Subscription (4aecf0e8-2fe2-4187-bc93-0356bd2676f5)
│   ├── Resource Group: odaa-user00
│   │   └── ADB Administrator ✅ (scoped to this RG only)
│   ├── Private DNS Zones (4 zones)
│   │   └── Private DNS Zone Contributor ✅
│   └── Subscription Level
│       ├── Private DNS Zone Reader ✅
│       └── Oracle Subscriptions Manager Reader ✅
│
└── Cloud Shell Storage Subscription (09808f31-065f-4231-914d-776c2d6bbe34)
    └── Storage Account: odaamh
        ├── Storage Blob Data Contributor ✅
        ├── Storage File Data SMB Share Contributor ✅
        └── Resource Group Reader ✅
```

---

## Current Limitation: AKS Namespace Access

⚠️ **Users currently have FULL access to ALL namespaces in their AKS cluster**

The `Azure Kubernetes Service RBAC Writer` role grants:
- Full admin access to the entire cluster
- Can create/delete ANY namespace
- Can deploy to ANY namespace
- Can modify/delete ANY resource

### Recommendation: Implement Namespace Restrictions

See **Namespace-Based Access Control** section in the implementation plan below for details on how to restrict users to specific namespaces (e.g., `microhack` namespace only).

---

## Cost Per User (Approximate Monthly)

| Resource | Cost |
|----------|------|
| AKS Cluster (3 nodes) | ~$200-300 |
| ODAA VNet | Free |
| VNet Peering | ~$5 |
| Cloud Shell Storage (6 GB share) | ~$1.20 |
| Oracle Database (if created) | Variable |
| **Total (without ADB)** | **~$210/month** |

---

## Testing User Access

### Verify AKS Access

```bash
# Login as user00
az login -u user00@cptazure.org

# Get AKS credentials (should work)
az aks get-credentials --resource-group rg-aks-user00 --name aks-user00

# Deploy to cluster (should work)
kubectl create namespace test
kubectl run nginx --image=nginx -n test

# Try to access user01's cluster (should fail)
az aks get-credentials --resource-group rg-aks-user01 --name aks-user01
# Error: User does not have access
```

### Verify ODAA Access

```bash
# List databases in own RG (should work)
az oracle-database autonomous-database list --resource-group odaa-user00

# Try to list databases in user01's RG (should fail)
az oracle-database autonomous-database list --resource-group odaa-user01
# Error: Authorization failed
```

### Verify Cloud Shell Isolation

```bash
# Access own file share (works)
# Cloud Shell will mount cloudshell-user00

# Try to access another user's files (blocked by RBAC)
az storage file list --account-name odaamh --share-name cloudshell-user01
# Error: This request is not authorized
```

---

## Related Documentation

- `VNET_ISOLATION_CORRECT.md` - VNet isolation architecture
- `RBAC_ANALYSIS.md` - Detailed RBAC analysis and security assessment
- `CLOUDSHELL_SHARED_STORAGE.md` - Cloud Shell storage configuration
- `NAMESPACE_RBAC.md` - **NEW** - Namespace-based access control (to be created)
