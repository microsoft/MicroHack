# 🔐 Enable Microsoft Entra ID Authentication on Autonomous AI Database

[Back to workspace README](../../README.md)

- [Oracle guide to enabling Entra ID authentication](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-azure-ad-enable.html#GUID-C69B47D7-E5B5-4BC5-BB57-EC5BACFAC1DC)
- [Oracle database authentication steps](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/authenticating-and-authorizing-microsoft-entra-id-ms-ei-users-oracle-databases-oracle-exadata.html#GUID-CC8FFE52-DC3B-4F2F-B1CA-308E35288C73)

---

## 🧾 Oracle AI Database Requirements for the Microsoft Entra ID Integration

Before you can configure an Oracle AI Database instance with Microsoft Entra ID, you must ensure that your environment meets special requirements.

For an on-premises, non-cloud Oracle AI Database, follow the steps in this document. If your Oracle AI Database is in one of the following DBaaS platforms, then refer to the platform documentation for additional requirements.
Using Oracle Autonomous AI Database Serverless
Using Oracle Autonomous Database on Dedicated Exadata Infrastructure
Use Azure Active Directory Authentication with Oracle Base Database Service
Use Azure Active Directory Authentication with Oracle Exadata Database Service on Dedicated Infrastructure
Note the following:

The Oracle AI Database server must be able to request the Entra ID public key. Depending on the enterprise network connectivity setup, you may need to configure a proxy setting.
Users and applications that need to request an Entra ID token must also be able to have network connectivity to Entra ID. You may need to configure a proxy setting for the connection.
You must configure Transport Layer Security (TLS) between the Oracle AI Database client and the Oracle AI Database server so that the token can be transported securely. This TLS connection can be either one-way or mutual.
You can create the TLS server certificate to be self-signed or be signed by a well known certificate authority. The advantage of using a certificate that is signed by a well known Certificate Authority (CA) is that the database client can use the system default certificate store to validate the Oracle AI Database server certificate instead of having to create and maintain a local wallet with the root certificate. Note that this applies to Linux and Windows clients only.

Set the App ID URI, in the Application ID URI field, enter the app ID URI for the database connection using the following format, and then click Save:

your_tenancy_url/application_(client)_id
`https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e`

### 🔁 8.2.3 Enabling Microsoft Entra ID v2 Access Tokens

We did add the following to the manifest of the app registration:

~~~json
  "id": "9bda9b0b-fcab-4472-9815-58dc3b908439",
  "accessTokenAcceptedVersion": 2,
~~~

~~~powershell
# Prompt for the password that will be used for all three components
$password = Read-Host -Prompt "Enter the shared password"
$rgName="odaa-user00"
$prefix="odaa-user00"
$location="francecentral" # e.g. germanywestcentral
# login to aks if not already done
az aks get-credentials -g $rgName -n $prefix --overwrite-existing
# extract the pod name of the instantcleint as it contains a random suffix
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
# login to the pod ogghack-goldengate-microhack-sample-instantclient-5985df84vc5xs
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
~~~

Log in to the Oracle Database instance as a user who has been granted the ALTER SYSTEM system privilege

~~~bash
sqlplus admin@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
~~~

Output should look as follow:

~~~text
Version 23.4.0.24.05

Copyright (c) 1982, 2024, Oracle.  All rights reserved.

Enter password:
Last Successful login time: Wed Oct 15 2025 09:03:47 +00:00

Connected to:
Oracle Database 23ai Enterprise Edition Release 23.0.0.0.0 - for Oracle Cloud and Engineered Systems
Version 23.10.0.25.10
~~~

turn on external authentication on the database:

~~~sql
BEGIN
  DBMS_CLOUD_ADMIN.ENABLE_EXTERNAL_AUTHENTICATION(
      type   =>'AZURE_AD',
      params => JSON_OBJECT('tenant_id' VALUE 'f71980b2-590a-4de9-90d5-6fbc867da951',
                            'application_id' VALUE '7d22ece1-dd60-4279-a911-4b7b95934f2e',
                            'application_id_uri' VALUE 'https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e'),
      force  => TRUE
  );
END;
/
-- Ensure that you set the IDENTITY_PROVIDER_TYPE parameter correctly.
SELECT NAME, VALUE FROM V$PARAMETER WHERE NAME='identity_provider_type';
~~~

The following output should appear:

~~~text
NAME
--------------------------------------------------------------------------------
VALUE
--------------------------------------------------------------------------------
identity_provider_type
AZURE_AD
~~~

### 🗺️ Exclusively Mapping an Oracle Database Schema to a Microsoft Azure User

You can exclusively map an Oracle Database schema to a Microsoft Azure user.

Log in to the Oracle Database instance as a user who has been granted the CREATE USER or ALTER USER system privilege.

Run the CREATE USER or ALTER USER statement with the IDENTIFIED GLOBALLY AS clause specifying the Azure user name.
For example, to create a new database schema user named peter_fitch and map this user to an existing Azure user named `ga1@cptazure.org`:

~~~sql
CREATE USER ga1 IDENTIFIED GLOBALLY AS 'AZURE_USER=ga1@cptazure.org';
-- Grant the CREATE SESSION privilege to the user.
GRANT CREATE SESSION TO ga1;
-- List all users
SELECT username, user_id, account_status FROM dba_users WHERE username='GA1';

-- Create ACLs for Entra Domains, run as a DBA/ADMIN user 
-- to first test with ADMIN user, then add ACEs for your app user
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
     host        => 'login.windows.net',   -- you can also use 'login.microsoftonline.com'
     ace         => xs$ace_type(
                      privilege_list => xs$name_list('connect','resolve'),
                      principal_name => 'ADMIN',  -- your DBA user
                      principal_type => xs_acl.ptype_db));
END;
/
COMMIT;

BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
     host        => 'login.microsoftonline.com',   -- you can also use ''
     ace         => xs$ace_type(
                      privilege_list => xs$name_list('connect','resolve'),
                      principal_name => 'ADMIN',  -- your DBA user
                      principal_type => xs_acl.ptype_db));
END;
/
COMMIT;
-- then add ACEs for your app user
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
     host        => 'login.windows.net',   -- you can also use 'login.microsoftonline.com'
     ace         => xs$ace_type(
                      privilege_list => xs$name_list('connect','resolve'),
                      principal_name => 'GA1',  -- your DBA user
                      principal_type => xs_acl.ptype_db));
END;
/
COMMIT;

BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
     host        => 'login.microsoftonline.com',   -- you can also use ''
     ace         => xs$ace_type(
                      privilege_list => xs$name_list('connect','resolve'),
                      principal_name => 'GA1',  -- your DBA user
                      principal_type => xs_acl.ptype_db));
END;
/
COMMIT;
--- check
DESCRIBE DBMS_NETWORK_ACL_ADMIN;

-- verify access via http request
SELECT host, lower_port, upper_port, principal, privilege
FROM   dba_host_aces
WHERE  host LIKE 'login%';

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
END;
/

-- 1. See current user (in the session that runs UTL_HTTP)
SELECT USER FROM dual;

-- 2. Inspect existing host ACEs for login*
SELECT host, lower_port, upper_port, principal, privilege
FROM dba_host_aces
WHERE host LIKE 'login%' ORDER BY host, principal, privilege;

-- Remove ACEs for your app user 
BEGIN
DBMS_NETWORK_ACL_ADMIN.REMOVE_HOST_ACE(
  host => '*',
  ace  =>  xs$ace_type(privilege_list => xs$name_list('connect'),
                       principal_name => 'GA1',
                       principal_type => xs_acl.ptype_db));
END;
/

~~~

### ⚙️ 8.4.4 Operational Flow for SQL*Plus Client Connection in PowerShell to Oracle Database

(source: [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/authenticating-and-authorizing-microsoft-entra-id-ms-ei-users-oracle-databases-oracle-exadata.html#GUID-455CDC87-C5A1-4A58-801A-29D216CB66B5))

#### 💼 Get Wallet

Download the Wallet from the Azure portal and unzip it to a secure directory.

The Azure user requests an Azure AD access token for the database in PowerShell and the returned token is written into a file called token at a file location.

~~~powershell
# login to azure with the tenant id of the app registration
az login --tenant "f71980b2-590a-4de9-90d5-6fbc867da951" --scope "https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e/session:scope:connect"
# get access token for the app registration
$token=az account get-access-token --resource 'https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e' --query accessToken --output tsv
$token=az account get-access-token --scope "https://cptazure.org/7d22ece1-dd60-4279-a911-4b7b95934f2e/.default" --query accessToken -o tsv
$token | Out-File -FilePath .\misc\token.txt -Encoding ascii
# view the jwt content
./resources/scripts/jwt.ps1 -Jwt $token 
# write token to file
$token | Out-File -FilePath .\misc\token.txt -Encoding ascii
code .\misc\token.txt

# extract the pod name of the instantcleint as it contains a random suffix
$podInstanteClientName=kubectl get pods -n microhacks | Select-String 'ogghack-goldengate-microhack-sample-instantclient' | ForEach-Object { ($_ -split '\s+')[0] }
# upload all files under folder misc/wallet to the pod 
kubectl cp misc/wallet ${podInstanteClientName}:/tmp -n microhacks

# upload all files under folder misc/wallet to the pod 
kubectl cp ./misc/token.txt ${podInstanteClientName}:/tmp/wallet -n microhacks

# login to the pod ogghack-goldengate-microhack-sample-instantclient-5985df84vc5xs
kubectl exec -it -n microhacks $podInstanteClientName -- /bin/bash
cd /tmp/wallet
ls -l /tmp/wallet
cat /tmp/wallet/token.txt
exit
~~~

#### 🛠️ 8.4.7 Configuring SQL*Plus for Azure AD Access Tokens

(source: [Oracle documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/authenticating-and-authorizing-microsoft-entra-id-ms-ei-users-oracle-databases-oracle-exadata.html#GUID-89CB6E1E-E383-476A-8B46-4343CEF8512E))

##### ✅ Ensure you have an Azure AD user account

##### 🔍 Check with an Azure AD administrator or Oracle Database administrator

For one of the following:

- An application client ID that you can use to get Azure AD tokens. If you have Azure AD privileges to do so, then create your own client app registration, similar to registering the Oracle Database instance with an Azure AD tenancy.
- You are mapped to a global schema in the database.
- Ensure that you are using the latest release updates for the Oracle Database client releases 19c.
- This configuration only works with the Oracle Database client release 19c.

##### 📥 Follow the existing process to download the wallet from the Oracle Database instance and then configure SQL*Plus

##### ⚙️ Set the sqlnet.ora parameters on the client

Check for the parameter SSL_SERVER_DN_MATCH = ON to ensure that DN matching is enabled.

~~~bash
# edit the sqlnet.ora file
vi /tmp/wallet/sqlnet.ora
# change to "SSL_SERVER_DN_MATCH=ON" 
[esc]:x
# verify
cat /tmp/wallet/sqlnet.ora
~~~

Set the TOKEN_AUTH parameter to enable the client to use the Azure AD token. Include the TOKEN_LOCATION parameter to point to the token location. For example:

~~~bash
cat <<'EOF' >> /tmp/wallet/sqlnet.ora
TOKEN_AUTH=OAUTH
TOKEN_LOCATION="/tmp/wallet/token.txt"
EOF
# verify
cat /tmp/wallet/sqlnet.ora
~~~

Note that there is no default location. If the token is named token, then you only need to specify the file directory (for example, /test/oracle/aad-token). If the token name is different from token (for example, azure.token), then you must include this name in the path (for example, /test/oracle/aad-token/azure.token).

You can specify the TOKEN_AUTH and TOKEN_LOCATION parameters in tnsnames.ora, as well as in sqlnet.ora. The TOKEN_AUTH and TOKEN_LOCATION values in the tnsnames.ora connect strings take precedence over the sqlnet.ora settings for that connection. For example:

~~~bash
# verfiy current content of tnsnames.ora
cat /tmp/wallet/tnsnames.ora
~~~

Generell example of a connect string with the TOKEN_AUTH and TOKEN_LOCATION parameters:

~~~text
(description= 
  (retry_count=20)(retry_delay=3)
  (address=(protocol=tcps)(port=1522)
  (host=example.us-phoenix-1.oraclecloud.com))
  (connect_data=(service_name=aaabbbccc_exampledb_high.example.oraclecloud.com))
  (security=(ssl_server_cert_dn="CN=example.uscom-east-1.oraclecloud.com, 
     OU=Oracle BMCS US, O=Example Corporation, 
     L=Redwood City, ST=California, C=US")
  (TOKEN_AUTH=OAUTH)(TOKEN_LOCATION="/test/oracle/aad-token"))
~~~

> NOTE: We did modify the sqlnet.ora file directly instead of the tnsnames.ora file. Therefore the connect strings in the tnsnames.ora file do not contain the TOKEN_AUTH and TOKEN_LOCATION parameters.

~~~text
adbger_high = (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))

adbger_low = (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_low.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))

adbger_medium = (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))

adbger_tp = (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_tp.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))

adbger_tpurgent = (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_tpurgent.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))
~~~

After the connect string is updated with the TOKEN_AUTH and TOKEN_LOCATION parameters, the Azure user can log in to the Oracle Database instance by running the following command to start SQL*Plus. You can include the connect descriptor itself or use the name of the descriptor from the tnsnames.ora file.

The Azure user connects to the database using / slash login. Either the sqlnet.ora or tnsnames.ora connection string tells the instant client that an Azure AD OAuth2 token is needed and to retrieve it from a specified file location. The access token is sent to the database.

~~~bash
# set TNS_ADMIN to the wallet directory
export TNS_ADMIN=/tmp/wallet
# verify
echo $TNS_ADMIN
# delete TNS_ADMIN
# unset TNS_ADMIN

# connect to the database
sqlplus /nolog
connect /@adbger_high # did not work

# connect with user GA1 connection string directly
sqlplus /@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=on))(TOKEN_AUTH=OAUTH)(TOKEN_LOCATION="/tmp/wallet/token.txt"))'
ga1

# connect with user GA1 connection string directly
sqlplus admin@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
~~~

#### Debug

(TOKEN_AUTH=OAUTH)(TOKEN_LOCATION="/test/oracle/aad-token")

~~~bash
sqlplus admin@'(description=(retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=eqsmjgp2.adb.eu-frankfurt-1.oraclecloud.com))(connect_data=(service_name=g6425a1dbd2e95a_adbger_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))'
~~~

~~~sql
-- Ensure that you set the IDENTITY_PROVIDER_TYPE parameter correctly.
SELECT NAME, VALUE FROM V$PARAMETER WHERE NAME='identity_provider_type';
~~~

~~~text
NAME
--------------------------------------------------------------------------------
VALUE
--------------------------------------------------------------------------------
identity_provider_type
AZURE_AD
~~~

On the Autonomous Database, check that the mapped database user exists and is global: select username, authentication_type from dba_users where username = 'GA1'; should show GLOBAL. If not, recreate it with the right tenant ID, app (audience) and optional group/role claims using DBMS_CLOUD_ADMIN.CREATE_CLOUD_IDENTITY.

~~~sql
-- check that the mapped database user exists and is global
select username, authentication_type from dba_users where username = 'GA1';
~~~

~~~text
USERNAME
--------------------------------------------------------------------------------
AUTHENTI
--------
GA1
GLOBAL
~~~

[Back to workspace README](../../README.md)