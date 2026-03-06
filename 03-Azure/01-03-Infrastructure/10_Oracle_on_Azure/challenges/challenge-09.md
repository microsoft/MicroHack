# Challenge 9 - (Optional) Enable Microsoft Entra ID Authentication on Autonomous AI Database

[Previous Challenge](challenge-08.md) - **[Home](../Readme.md)** - [Next Challenge](finish.md)

## Goal 

The goal of this exercise is to enable Microsoft Entra ID authentication for your Oracle Autonomous Database, allowing Azure users to authenticate using their Entra ID credentials and OAuth2 tokens instead of traditional database passwords.

## Additional Context

Additional context and troubleshooting resources:
 * [Debugging Entra ID Auth](../DEBUG-ENTRAID-AUTH.md)
 * [Resolution for Entra ID Auth](../RESOLUTION-ENTRAID-AUTH.md)
 * [Token Refresh Strategies](../TOKEN-REFRESH-STRATEGIES.md)

## Actions

* Create an App Registration in Microsoft Entra ID for your Oracle Autonomous Database
* Configure the App ID URI and enable v2 access tokens in the manifest
* Enable external authentication on the Autonomous Database using `DBMS_CLOUD_ADMIN.ENABLE_EXTERNAL_AUTHENTICATION`
* Create a database user mapped to an Azure Entra ID user using the `IDENTIFIED GLOBALLY AS` clause
* Configure network ACLs to allow the database to access Entra ID endpoints (login.windows.net and login.microsoftonline.com)
* Download the database wallet and configure it for OAuth token authentication
* Generate an Entra ID access token and save it to a file
* Configure the SQL*Plus client with `TOKEN_AUTH=OAUTH` and `TOKEN_LOCATION` parameters
* Test the connection by connecting to the database using the OAuth token

## Success criteria

* You have successfully created an App Registration in Entra ID with the correct App ID URI
* External authentication is enabled on the database with `identity_provider_type` set to `AZURE_AD`
* You have created a global database user mapped to an Azure Entra ID user
* Network ACLs are configured to allow database access to Entra ID endpoints
* The wallet is configured with `TOKEN_AUTH=OAUTH` and `TOKEN_LOCATION` parameters
* You can successfully obtain an Entra ID access token for your database application
* You can connect to the Autonomous Database using SQL*Plus with the OAuth token (slash login)
* The connection shows the correct Entra ID-authenticated user in the database session

## Learning resources

* [Autonomous Database - Enable Microsoft Entra ID Authentication](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-azure-ad-enable.html#GUID-C69B47D7-E5B5-4BC5-BB57-EC5BACFAC1DC)
* [Authenticating and Authorizing Microsoft Entra ID Users for Oracle Databases](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/authenticating-and-authorizing-microsoft-entra-id-ms-ei-users-oracle-databases-oracle-exadata.html#GUID-CC8FFE52-DC3B-4F2F-B1CA-308E35288C73)
* [Configuring SQL*Plus for Azure AD Access Tokens](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/authenticating-and-authorizing-microsoft-entra-id-ms-ei-users-oracle-databases-oracle-exadata.html#GUID-89CB6E1E-E383-476A-8B46-4343CEF8512E)
* [Operational Flow for SQL*Plus Client Connection](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/authenticating-and-authorizing-microsoft-entra-id-ms-ei-users-oracle-databases-oracle-exadata.html#GUID-455CDC87-C5A1-4A58-801A-29D216CB66B5)
