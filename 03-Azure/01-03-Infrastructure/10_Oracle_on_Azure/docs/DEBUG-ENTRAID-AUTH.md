# Debugging Entra ID Authentication to Oracle Autonomous Database

## Error Received
```
ORA-01017: invalid credential or not authorized; logon denied
```

## Step-by-Step Debugging Guide

### 1. Token Analysis ✅

**Your Token Details:**
- **User (upn):** ga1@cptazure.org
- **Audience (aud):** 7d22ece1-dd60-4279-a911-4b7b95934f2e ✅ (matches app registration)
- **Tenant (tid):** f71980b2-590a-4de9-90d5-6fbc867da951 ✅ (matches configuration)
- **Issuer (iss):** https://login.microsoftonline.com/f71980b2-590a-4de9-90d5-6fbc867da951/v2.0 ✅
- **Token Version:** 2.0 ✅ (correct - you set `accessTokenAcceptedVersion: 2`)
- **Scope (scp):** session:scope:connect ✅
- **Roles:** 1314ae09-ccc6-4f59-b68b-3837ff44465b, fa80ec82-2110-4b45-be28-b3341bf19661
- **Token Valid:** Yes (expires 10/17/2025 09:31:32)

**Token appears valid! ✅**

---

### 2. Database Configuration Checks

Connect to the database as ADMIN to verify configuration:

```powershell
# Get pod name
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }

# Connect to pod
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash

# Inside the pod, connect as ADMIN
sqlplus admin@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
```

#### Check 2.1: Verify Entra ID is Enabled

```sql
-- Should show AZURE_AD
SELECT NAME, VALUE FROM V$PARAMETER WHERE NAME='identity_provider_type';
```

**Expected Output:**
```
NAME                           VALUE
------------------------------ ----------
identity_provider_type         AZURE_AD
```

#### Check 2.2: Verify User GA1 Exists and is Global

```sql
-- Should show GLOBAL authentication
SELECT username, authentication_type, account_status, external_name 
FROM dba_users 
WHERE username = 'GA1';
```

**Expected Output:**
```
USERNAME  AUTHENTI  ACCOUNT_STATUS  EXTERNAL_NAME
--------- --------- --------------- ------------------------------
GA1       GLOBAL    OPEN            AZURE_USER=ga1@cptazure.org
```

⚠️ **CRITICAL CHECK:** The `EXTERNAL_NAME` must be exactly `AZURE_USER=ga1@cptazure.org`

#### Check 2.3: Verify User Privileges

```sql
-- GA1 must have CREATE SESSION privilege
SELECT * FROM dba_sys_privs WHERE grantee = 'GA1';
```

**Expected Output:**
```
GRANTEE  PRIVILEGE       ADMIN_OPTION
-------- --------------- ------------
GA1      CREATE SESSION  NO
```

#### Check 2.4: Verify Entra ID Configuration

```sql
-- Check Azure AD configuration
SELECT 
    param_name, 
    param_value 
FROM 
    dba_cloud_config
WHERE 
    param_name IN ('AZURE_TENANT_ID', 'AZURE_APPLICATION_ID', 'AZURE_APPLICATION_ID_URI')
ORDER BY 
    param_name;
```

**Expected Values:**
```
PARAM_NAME                 PARAM_VALUE
-------------------------- --------------------------------------------------
AZURE_TENANT_ID           f71980b2-590a-4de9-90d5-6fbc867da951
AZURE_APPLICATION_ID      7d22ece1-dd60-4279-a911-4b7b95934f2e
AZURE_APPLICATION_ID_URI  https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e
```

#### Check 2.5: Verify Network ACLs

```sql
-- Check if GA1 has network access to Entra ID endpoints
SELECT host, lower_port, upper_port, principal, privilege
FROM dba_host_aces
WHERE host LIKE 'login%' AND principal = 'GA1'
ORDER BY host, privilege;
```

**Expected Output:**
```
HOST                      PRINCIPAL  PRIVILEGE
------------------------- ---------- ---------
login.microsoftonline.com GA1        connect
login.microsoftonline.com GA1        resolve
login.windows.net         GA1        connect
login.windows.net         GA1        resolve
```

If missing, add them:

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
COMMIT;

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

#### Check 2.6: Test Database Can Reach Entra ID

```sql
-- Test HTTPS connectivity to Entra ID (as ADMIN)
SET SERVEROUTPUT ON SIZE 40000
DECLARE
  req UTL_HTTP.REQ;
  resp UTL_HTTP.RESP;
BEGIN
  UTL_HTTP.SET_WALLET(path => 'system:');
  req := UTL_HTTP.BEGIN_REQUEST('https://login.windows.net/common/discovery/keys');
  resp := UTL_HTTP.GET_RESPONSE(req);
  DBMS_OUTPUT.PUT_LINE('HTTP response status code: ' || resp.status_code);
  UTL_HTTP.END_RESPONSE(resp);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
```

**Expected Output:** `HTTP response status code: 200`

---

### 3. Client Configuration Checks

#### Check 3.1: Verify Token File Exists and is Readable

```bash
# Inside the pod
ls -la /tmp/wallet/token.txt
cat /tmp/wallet/token.txt | wc -c  # Should be ~1900 bytes (not empty!)
```

#### Check 3.2: Verify sqlnet.ora Configuration

```bash
# Check sqlnet.ora content
cat /tmp/wallet/sqlnet.ora
```

**Expected Content:**
```
WALLET_LOCATION = (SOURCE = (METHOD = file) (METHOD_DATA = (DIRECTORY="/tmp/wallet")))
SSL_SERVER_DN_MATCH=ON
SQLNET.AUTHENTICATION_SERVICES= (TCPS,NTS)
NAMES.DIRECTORY_PATH= (TNSNAMES, EZCONNECT)
TOKEN_AUTH=OAUTH
TOKEN_LOCATION="/tmp/wallet/token.txt"
```

⚠️ **CRITICAL CHECKS:**
- `SSL_SERVER_DN_MATCH=ON` (for Entra ID connections)
- `TOKEN_AUTH=OAUTH`
- `TOKEN_LOCATION="/tmp/wallet/token.txt"` (correct path)

#### Check 3.3: Verify TNS_ADMIN Environment Variable

```bash
# Should point to /tmp/wallet
echo $TNS_ADMIN
```

If not set:
```bash
export TNS_ADMIN=/tmp/wallet
```

#### Check 3.4: Test Token is Valid and Not Expired

```bash
# Check token expiry (you can decode it manually or check the exp claim)
# Your current token expires: 10/17/2025 09:31:32
date
```

If expired, regenerate:

```powershell
# On your local machine
az login --tenant "f71980b2-590a-4de9-90d5-6fbc867da951"
$token=az account get-access-token --scope "https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e/.default" --query accessToken -o tsv
$token | Out-File -FilePath .\misc\token.txt -Encoding ascii

# Upload to pod
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
kubectl cp ./misc/token.txt ${podInstanteClientName}:/tmp/wallet/token.txt -n microhacks
```

---

### 4. Database Alert Log and Trace Files

#### Check 4.1: Check Oracle Alert Log

If you have access to the database alert log (typically through Oracle Cloud Console):

**Look for entries like:**
- `ORA-01017` with additional context
- `OAUTH` or `AZURE_AD` authentication failures
- Token validation errors
- Network connectivity issues to Entra ID endpoints

**Location (on ADB):** Typically accessible through OCI Console → Autonomous Database → Performance Hub → SQL Monitoring

#### Check 4.2: Enable SQL*Net Tracing (if needed)

```bash
# Add to sqlnet.ora temporarily for debugging
cat <<'EOF' >> /tmp/wallet/sqlnet.ora
TRACE_LEVEL_CLIENT=16
TRACE_DIRECTORY_CLIENT=/tmp
TRACE_FILE_CLIENT=sqlnet_trace.log
EOF
```

Then retry connection and check `/tmp/sqlnet_trace.log`

---

### 5. Common Issues and Solutions

#### Issue 5.1: User Mapping Mismatch

**Problem:** Database expects exact UPN from token

**Solution:**
```sql
-- Recreate user with exact UPN from token
DROP USER GA1 CASCADE;
CREATE USER GA1 IDENTIFIED GLOBALLY AS 'AZURE_USER=ga1@cptazure.org';
GRANT CREATE SESSION TO GA1;
```

⚠️ **The UPN in the token is:** `ga1@cptazure.org`

#### Issue 5.2: Wrong Connection String

**Problem:** Using wrong security settings

**Current attempt:**
```
(security=(ssl_server_dn_match=on))
```

**Try with explicit token parameters:**
```bash
sqlplus /@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)(TOKEN_AUTH=OAUTH)(TOKEN_LOCATION="/tmp/wallet/token.txt")))'
```

Or use sqlnet.ora settings and simpler connection:
```bash
# Ensure TNS_ADMIN is set
export TNS_ADMIN=/tmp/wallet

# Try simple connection using tnsnames alias
sqlplus /@adbger_high
```

#### Issue 5.3: Token Encoding Issues

**Problem:** Token file has wrong encoding or line breaks

**Solution:**
```bash
# Check for line breaks or extra characters
od -c /tmp/wallet/token.txt | head -20

# Token should be ONE line, ASCII encoded
# If it has line breaks, fix it:
tr -d '\n\r' < /tmp/wallet/token.txt > /tmp/wallet/token_fixed.txt
mv /tmp/wallet/token_fixed.txt /tmp/wallet/token.txt
```

#### Issue 5.4: Missing App Role Assignment

**Problem:** User not assigned to app roles in Entra ID

**Check in Entra ID (Azure Portal):**
1. Go to Enterprise Applications → adbger (7d22ece1-dd60-4279-a911-4b7b95934f2e)
2. Users and groups → Check if ga1@cptazure.org is assigned
3. If using app roles, verify ga1 is assigned to correct role

From your token, I see these role GUIDs:
- `1314ae09-ccc6-4f59-b68b-3837ff44465b`
- `fa80ec82-2110-4b45-be28-b3341bf19661`

But your manifest only shows:
- `e9ea0527-85f2-4e84-9884-2ae95c4f5a17` (SH2_APP)

⚠️ **POTENTIAL ISSUE:** Role GUIDs in token don't match manifest!

---

### 6. Recommended Debugging Sequence

**Step 1:** Verify database configuration (run all SQL checks above)

**Step 2:** Verify token is current and properly formatted
```bash
# Inside pod
ls -la /tmp/wallet/token.txt
cat /tmp/wallet/token.txt | wc -c
# Should be ~1900 bytes
```

**Step 3:** Try simplified connection string
```bash
export TNS_ADMIN=/tmp/wallet
sqlplus /@adbger_high
```

**Step 4:** If still failing, check database logs via OCI Console

**Step 5:** Verify Entra ID app role assignments match user

---

### 7. Quick Diagnostic Commands

Run these in sequence to generate a diagnostic report:

```sql
-- Connect as ADMIN first
sqlplus admin@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'

SPOOL /tmp/entraid_diag.txt

-- Identity Provider
SELECT NAME, VALUE FROM V$PARAMETER WHERE NAME='identity_provider_type';

-- User Configuration
SELECT username, authentication_type, account_status, external_name 
FROM dba_users 
WHERE username = 'GA1';

-- User Privileges
SELECT * FROM dba_sys_privs WHERE grantee = 'GA1';

-- Azure AD Config
SELECT param_name, param_value 
FROM dba_cloud_config
WHERE param_name LIKE 'AZURE%'
ORDER BY param_name;

-- Network ACLs
SELECT host, principal, privilege
FROM dba_host_aces
WHERE host LIKE 'login%' 
ORDER BY host, principal, privilege;

SPOOL OFF
EXIT
```

Then copy diagnostic file:
```bash
# From pod
cat /tmp/entraid_diag.txt
```

---

### 8. Expected Log Files for Review

If the issue persists, check these log locations:

**On Autonomous Database (via OCI Console):**
1. **Alert Log:** 
   - OCI Console → Autonomous Database → Performance Hub → ASH Analytics
   - Look for ORA-01017 entries around your connection time

2. **Audit Trail:**
   ```sql
   SELECT timestamp, username, action_name, returncode, comment_text
   FROM unified_audit_trail
   WHERE username = 'GA1'
   ORDER BY timestamp DESC
   FETCH FIRST 10 ROWS ONLY;
   ```

3. **External Authentication Logs:**
   ```sql
   SELECT * FROM v$diag_alert_ext
   WHERE message_text LIKE '%AZURE%' OR message_text LIKE '%OAUTH%'
   ORDER BY originating_timestamp DESC
   FETCH FIRST 20 ROWS ONLY;
   ```

**On Client (pod):**
- SQL*Net trace: `/tmp/sqlnet_trace.log` (if tracing enabled)
- SQL*Plus log: Check terminal output carefully

---

## Most Likely Cause

Based on your configuration, the most likely issues are:

1. ⚠️ **App Role Mismatch:** The role GUIDs in your token don't match the app registration manifest
2. ⚠️ **User Mapping:** GA1 user external name might not exactly match the UPN in the token
3. ⚠️ **Network ACLs:** GA1 might not have network access to Entra ID endpoints

**Start with running all SQL checks in Step 2 above!**
