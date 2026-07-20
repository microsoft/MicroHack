# Entra ID Authentication - RESOLUTION SUMMARY

## 🎉 **STATUS: WORKING** ✅

**Date:** October 17, 2025  
**Authentication Method:** TOKEN_GLOBAL  
**User:** ga1@cptazure.org → GA1

---

## Issues Found and Fixed

### 1. ❌ **Missing TOKEN Configuration in sqlnet.ora**
**Problem:** The `sqlnet.ora` file was missing TOKEN_AUTH and TOKEN_LOCATION parameters.

**Solution:** Updated `/tmp/wallet/sqlnet.ora` to include:
```
TOKEN_AUTH=OAUTH
TOKEN_LOCATION="/tmp/wallet/token.txt"
```

**Files Updated:**
- `c:\Users\chpinoto\workspace\msftmh\03-Azure\01-03-Infrastructure\10_Oracle_on_Azure\misc\wallet\sqlnet.ora`

---

### 2. ❌ **Token File Had Line Breaks**
**Problem:** The token file contained a newline character (1 line break), which can cause parsing issues.

**Solution:** Removed line breaks from token file to make it a single line.

**Verification:**
```bash
wc -l /tmp/wallet/token.txt  # Should show: 0
```

---

### 3. ❌ **Missing Network ACLs for GA1 User**
**Problem:** User GA1 had no network access control lists (ACLs) to reach Entra ID endpoints.

**Solution:** Added ACLs for GA1 to access:
- `login.windows.net` (connect, resolve)
- `login.microsoftonline.com` (connect, resolve)

**SQL Commands Used:**
```sql
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
     host        => 'login.windows.net',
     ace         => xs$ace_type(
                      privilege_list => xs$name_list('connect','resolve'),
                      principal_name => 'GA1',
                      principal_type => xs_acl.ptype_db));
END;
/

BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
     host        => 'login.microsoftonline.com',
     ace         => xs$ace_type(
                      privilege_list => xs$name_list('connect','resolve'),
                      principal_name => 'GA1',
                      principal_type => xs_acl.ptype_db));
END;
/
COMMIT;
```

---

### 4. ℹ️ **User External Name Case (Not an Issue)**
**Observation:** Oracle stores the external name in lowercase: `azure_user=ga1@cptazure.org`

**Resolution:** This is Oracle's normal behavior and does NOT affect authentication. The matching is case-insensitive.

---

## Working Configuration

### Database Configuration ✅
```
Identity Provider Type: AZURE_AD
User: GA1
Authentication Type: GLOBAL
External Name: azure_user=ga1@cptazure.org
Privileges: CREATE SESSION
Network ACLs: login.windows.net, login.microsoftonline.com
```

### Client Configuration ✅
**sqlnet.ora** (`/tmp/wallet/sqlnet.ora`):
```
WALLET_LOCATION = (SOURCE = (METHOD = file) (METHOD_DATA = (DIRECTORY="/tmp/wallet")))
SSL_SERVER_DN_MATCH=ON
SQLNET.AUTHENTICATION_SERVICES= (TCPS,NTS)
NAMES.DIRECTORY_PATH= (TNSNAMES, EZCONNECT)
TOKEN_AUTH=OAUTH
TOKEN_LOCATION="/tmp/wallet/token.txt"
```

**Environment Variables:**
```bash
export TNS_ADMIN=/tmp/wallet
export LD_LIBRARY_PATH=/opt/oracle/instantclient_23_4
export PATH=/opt/oracle/instantclient_23_4:$PATH
```

### Token Configuration ✅
- **File:** `/tmp/wallet/token.txt`
- **Size:** 1783 bytes
- **Line Breaks:** 0 (single line)
- **Encoding:** ASCII
- **Token Type:** JWT (JSON Web Token)
- **Version:** 2.0
- **Audience (aud):** 7d22ece1-dd60-4279-a911-4b7b95934f2e
- **Tenant (tid):** f71980b2-590a-4de9-90d5-6fbc867da951
- **UPN:** ga1@cptazure.org
- **Scope:** session:scope:connect

---

## Connection Test Results

### Successful Connection ✅
```bash
#!/bin/bash
export TNS_ADMIN=/tmp/wallet
export LD_LIBRARY_PATH=/opt/oracle/instantclient_23_4
export PATH=/opt/oracle/instantclient_23_4:$PATH

/opt/oracle/instantclient_23_4/sqlplus /@adbger_high
```

**Output:**
```
SQL*Plus: Release 23.0.0.0.0 - Production
Connected to:
Oracle Database 23ai Enterprise Edition Release 23.0.0.0.0

USER: GA1
CURRENT_USER: GA1
AUTH_METHOD: TOKEN_GLOBAL
```

---

## How to Test

### From PowerShell (Local Machine)
```powershell
# Get pod name
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }

# Test authentication
kubectl exec -n microhacks $podInstanteClientName -- bash /tmp/test_entraid_auth.sh
```

### Inside the Pod
```bash
# Connect to pod
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash

# Set environment
export TNS_ADMIN=/tmp/wallet
export LD_LIBRARY_PATH=/opt/oracle/instantclient_23_4
export PATH=/opt/oracle/instantclient_23_4:$PATH

# Connect using Entra ID token
sqlplus /@adbger_high

# Verify user
SQL> SELECT USER FROM DUAL;
# Should show: GA1

SQL> SELECT SYS_CONTEXT('USERENV', 'AUTHENTICATION_METHOD') FROM DUAL;
# Should show: TOKEN_GLOBAL
```

---

## Token Renewal

The token expires after **60-90 minutes**. For production use, you need automated token refresh.

### Manual Token Refresh (Testing Only)

```powershell
# On local machine
az login --tenant "f71980b2-590a-4de9-90d5-6fbc867da951"
$token=az account get-access-token --scope "https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e/.default" --query accessToken -o tsv
$token | Out-File -FilePath .\misc\token.txt -Encoding ascii -NoNewline

# Upload to pod
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
kubectl cp ./misc/token.txt ${podInstanteClientName}:/tmp/wallet/token.txt -n microhacks
```

### ⭐ Automated Token Refresh (Production)

**For production environments, see comprehensive token refresh strategies:**

📖 **[TOKEN-REFRESH-STRATEGIES.md](TOKEN-REFRESH-STRATEGIES.md)**

Recommended approaches:
1. **Sidecar Container** - Automatic refresh every 45 minutes (RECOMMENDED)
2. **CronJob** - Kubernetes CronJob for periodic refresh
3. **Application-Level** - Token refresh built into your application
4. **Azure Key Vault + CSI Driver** - Enterprise solution with auto-sync

The sidecar approach is recommended for Kubernetes deployments as it:
- ✅ Refreshes tokens automatically before expiration
- ✅ Uses Azure Workload Identity (no secrets in code)
- ✅ Requires no changes to application code
- ✅ Provides high availability with built-in retry logic

---

## Files Created for Debugging

1. **DEBUG-ENTRAID-AUTH.md** - Comprehensive debugging guide
2. **misc/diagnose.sql** - SQL diagnostic script
3. **misc/Run-EntraIDDiagnostics.ps1** - PowerShell diagnostic runner
4. **misc/db_diagnostics.sh** - Bash diagnostic script
5. **misc/db_diag_v2.sh** - Improved diagnostic script
6. **misc/fix_entraid.sh** - Script to fix configuration issues
7. **misc/test_entraid_auth.sh** - Authentication test script

---

## Key Learnings

1. **TOKEN_AUTH and TOKEN_LOCATION must be in sqlnet.ora** - Without these parameters, SQL*Plus won't use the token file.

2. **Token must be a single line** - Line breaks in the token file can cause authentication failures.

3. **Network ACLs are required** - The database user must have network access to Entra ID endpoints to validate tokens.

4. **Case sensitivity in external names doesn't matter** - Oracle stores external names in lowercase, but matching is case-insensitive.

5. **TNS_ADMIN must be set** - The environment variable must point to the wallet directory containing sqlnet.ora and tnsnames.ora.

---

## Troubleshooting Future Issues

If authentication stops working, check:

1. **Token expiry:** Tokens expire after ~90 minutes
2. **Token format:** Must be single line, ASCII encoding
3. **Network ACLs:** Check `dba_host_aces` for GA1 principal
4. **sqlnet.ora:** Verify TOKEN_AUTH=OAUTH and TOKEN_LOCATION are set
5. **Environment:** Ensure TNS_ADMIN, LD_LIBRARY_PATH, and PATH are set correctly

Run diagnostics:
```bash
kubectl exec -n microhacks $podInstanteClientName -- bash /tmp/db_diag_v2.sh
```

---

## References

- Oracle Documentation: [Authenticating Microsoft Entra ID Users in Oracle Databases](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/authenticating-and-authorizing-microsoft-entra-id-ms-ei-users-oracle-databases-oracle-exadata.html)
- Autonomous Database: [Enable Microsoft Entra ID Authentication](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-azure-ad-enable.html)
