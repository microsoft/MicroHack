param(
    [Parameter(Mandatory)]
    [string]$ManagedInstanceServer,

    [Parameter(Mandatory)]
    [string]$sqlusername,

    [Parameter(Mandatory)]
    [string]$sqlpassword,

    [string]$ServerInstance = 'localhost',

    # Name used only when no database mirroring endpoint exists yet
    [string]$EndpointName = 'MILink_Endpoint',
    [int]$EndpointPort = 5022,
    [int]$CertificateValidityYears = 2,

    # Default to the values of the VM (read from the instance metadata service)
    [string]$SubscriptionId,
    [string]$ResourceGroupName
)

# Errors must never abort the script. Every step catches its own errors and only writes a warning.
$ErrorActionPreference = 'Continue'

$logPath = 'C:\Windows\Temp\Configure-SQLMI-Link.log'
try { Start-Transcript -Path $logPath -Append | Out-Null } catch { Write-Warning "Could not start transcript: $($_.Exception.Message)" }

try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

$ArmApiVersion = '2023-08-01'
$script:FailedSteps = @()
$script:SqlCertName = $null
$script:SqlPublicKey = $null
$script:MiPublicKey = $null
$script:ActiveEndpointName = $EndpointName

# Root CAs trusted by Azure (https://learn.microsoft.com/azure/security/fundamentals/azure-certificate-authority-details)
$RootCertificates = @(
    @{ Name = 'DigiCert Global Root CA';                          Url = 'https://cacerts.digicert.com/DigiCertGlobalRootCA.crt' }
    @{ Name = 'DigiCert Global Root G2';                          Url = 'https://cacerts.digicert.com/DigiCertGlobalRootG2.crt' }
    @{ Name = 'DigiCert Global Root G3';                          Url = 'https://cacerts.digicert.com/DigiCertGlobalRootG3.crt' }
    @{ Name = 'DigiCert TLS ECC P384 Root G5';                    Url = 'https://cacerts.digicert.com/DigiCertTLSECCP384RootG5.crt' }
    @{ Name = 'DigiCert TLS RSA 4096 Root G5';                    Url = 'https://cacerts.digicert.com/DigiCertTLSRSA4096RootG5.crt' }
    @{ Name = 'Microsoft ECC Root Certificate Authority 2017';    Url = 'https://www.microsoft.com/pkiops/certs/Microsoft%20ECC%20Root%20Certificate%20Authority%202017.crt' }
    @{ Name = 'Microsoft RSA Root Certificate Authority 2017';    Url = 'https://www.microsoft.com/pkiops/certs/Microsoft%20RSA%20Root%20Certificate%20Authority%202017.crt' }
)

#region Helpers

function Invoke-Step {
    param([string]$Title, [scriptblock]$Action)

    Write-Host "==> $Title" -ForegroundColor Cyan
    $ErrorActionPreference = 'Stop'
    try {
        & $Action
    }
    catch {
        Write-Warning "Step '$Title' failed: $($_.Exception.Message)"
        $script:FailedSteps += $Title
    }
}

function ConvertTo-SqlIdentifier([string]$Name) { '[' + $Name.Replace(']', ']]') + ']' }
function ConvertTo-SqlString([string]$Value) { "N'" + $Value.Replace("'", "''") + "'" }

function Invoke-Sql {
    param([string]$Query)

    $connection = New-Object System.Data.SqlClient.SqlConnection("Data Source=$ServerInstance;Initial Catalog=master;TrustServerCertificate=True;")
    $securePassword = ConvertTo-SecureString -String $sqlpassword -AsPlainText -Force
    $securePassword.MakeReadOnly()
    $connection.Credential = New-Object System.Data.SqlClient.SqlCredential($sqlusername, $securePassword)

    try {
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = 120
        $table = New-Object System.Data.DataTable
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
        [void]$adapter.Fill($table)
        # Unary comma keeps the DataTable intact when it is returned through the pipeline
        return , $table
    }
    finally {
        $connection.Dispose()
    }
}

function ConvertTo-HexString([byte[]]$Bytes) { '0x' + (($Bytes | ForEach-Object { $_.ToString('X2') }) -join '') }

function ConvertFrom-HexString([string]$Hex) {
    $clean = $Hex.Trim() -replace '^0[xX]', ''
    $bytes = New-Object byte[] ($clean.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $bytes[$i] = [Convert]::ToByte($clean.Substring(2 * $i, 2), 16)
    }
    , $bytes
}

function Format-PublicKey([string]$Blob) {
    $clean = $Blob.Trim()
    if ($clean -notmatch '^0[xX]') { $clean = '0x' + $clean }
    if ($clean -notmatch '^0[xX][0-9A-Fa-f]+$') { throw 'Public key is not a valid hexadecimal string.' }
    $clean
}

function Get-Thumbprint([byte[]]$Bytes) {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(, $Bytes)
    $cert.Thumbprint.ToUpperInvariant()
}

function Get-SqlCertificateThumbprints {
    $result = @{}
    $table = Invoke-Sql "SELECT name, CONVERT(varchar(128), thumbprint, 2) AS thumbprint FROM sys.certificates"
    foreach ($row in $table.Rows) { $result[[string]$row.thumbprint] = [string]$row.name }
    $result
}

function Get-ArmToken {
    $uri = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F'
    (Invoke-RestMethod -Uri $uri -Headers @{ Metadata = 'true' } -Method Get -TimeoutSec 30).access_token
}

function Invoke-ArmRequest {
    param([string]$Method, [string]$Path, [object]$Body)

    $request = @{
        Uri             = "https://management.azure.com$Path`?api-version=$ArmApiVersion"
        Method          = $Method
        Headers         = @{ Authorization = "Bearer $(Get-ArmToken)" }
        UseBasicParsing = $true
        TimeoutSec      = 120
        ErrorAction     = 'Stop'
    }
    if ($null -ne $Body) {
        $request.Body = $Body | ConvertTo-Json -Depth 5 -Compress
        $request.ContentType = 'application/json'
    }

    try {
        $response = Invoke-WebRequest @request
        $json = $null
        if ($response.Content) { $json = $response.Content | ConvertFrom-Json }
        [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Json = $json; Error = $null }
    }
    catch {
        $code = 0
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        $message = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $message = $_.ErrorDetails.Message }
        [pscustomobject]@{ StatusCode = $code; Json = $null; Error = $message }
    }
}

# Retries while the role assignment of the VM identity is still propagating (401/403)
function Invoke-ArmRequestWithRetry {
    param([string]$Method, [string]$Path, [object]$Body, [int]$MaxAttempts = 15)

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $response = Invoke-ArmRequest -Method $Method -Path $Path -Body $Body
        if ($response.StatusCode -notin 0, 401, 403) { return $response }
        Write-Host "  ARM returned $($response.StatusCode) (attempt $attempt/$MaxAttempts), waiting for RBAC propagation..."
        Start-Sleep -Seconds 20
    }
    $response
}

function Wait-ArmResource {
    param([string]$Path, [int]$ExpectedStatus, [int]$MaxAttempts = 40)

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $response = Invoke-ArmRequest -Method GET -Path $Path
        if ($response.StatusCode -eq $ExpectedStatus) { return $response }
        Start-Sleep -Seconds 15
    }
    $null
}

#endregion

Write-Host "Configuring SQL Managed Instance link (certificates and endpoints)..."

$MiName = $ManagedInstanceServer.Split('.')[0]

Invoke-Step 'Resolve Azure context' {
    if (-not $SubscriptionId -or -not $ResourceGroupName) {
        $compute = Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01' -Headers @{ Metadata = 'true' } -Method Get -TimeoutSec 30
        if (-not $SubscriptionId) { $script:SubscriptionId = $compute.subscriptionId }
        if (-not $ResourceGroupName) { $script:ResourceGroupName = $compute.resourceGroupName }
    }
    Write-Host "  Managed instance: $MiName (subscription $script:SubscriptionId, resource group $script:ResourceGroupName)"
}

$MiResourcePath = "/subscriptions/$($script:SubscriptionId)/resourceGroups/$($script:ResourceGroupName)/providers/Microsoft.Sql/managedInstances/$MiName"

Invoke-Step 'Ensure database master key on legacySQL' {
    $query = "IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE symmetric_key_id = 101) CREATE MASTER KEY ENCRYPTION BY PASSWORD = $(ConvertTo-SqlString $sqlpassword)"
    [void](Invoke-Sql $query)
}

Invoke-Step 'Create certificate and create/extend database mirroring endpoint on legacySQL' {
    $serverName = [string](Invoke-Sql 'SELECT @@SERVERNAME AS name').Rows[0].name
    $defaultCertName = ('Cert_' + $serverName + '_endpoint').Replace('\', '_')

    $endpointQuery = @"
SELECT e.name, e.state_desc, e.connection_auth_desc, e.encryption_algorithm_desc, c.name AS cert_name, t.port
FROM sys.database_mirroring_endpoints e
JOIN sys.tcp_endpoints t ON t.endpoint_id = e.endpoint_id
LEFT JOIN sys.certificates c ON c.certificate_id = e.certificate_id
"@
    $endpoints = Invoke-Sql $endpointQuery
    $existing = $null
    if ($endpoints.Rows.Count -gt 0) { $existing = $endpoints.Rows[0] }

    # Reuse the certificate of an existing certificate-secured endpoint, otherwise use a dedicated one
    $existingCertName = ''
    if ($existing) { $existingCertName = [string]$existing.cert_name }

    if ($existingCertName) {
        $script:SqlCertName = $existingCertName
        Write-Host "  Using certificate '$existingCertName' of existing endpoint."
    }
    else {
        $script:SqlCertName = $defaultCertName
        $certExists = (Invoke-Sql "SELECT 1 AS found FROM sys.certificates WHERE name = $(ConvertTo-SqlString $defaultCertName)").Rows.Count -gt 0
        if ($certExists) {
            Write-Host "  Certificate '$defaultCertName' already exists."
        }
        else {
            $expiry = (Get-Date).AddYears($CertificateValidityYears).ToString('yyyyMMdd')
            $subject = "Certificate for $defaultCertName"
            [void](Invoke-Sql "CREATE CERTIFICATE $(ConvertTo-SqlIdentifier $defaultCertName) WITH SUBJECT = $(ConvertTo-SqlString $subject), EXPIRY_DATE = '$expiry'")
            Write-Host "  Created certificate '$defaultCertName' (expires $expiry)."
        }
    }

    $certIdentifier = ConvertTo-SqlIdentifier $script:SqlCertName

    if (-not $existing) {
        $script:ActiveEndpointName = $EndpointName
        $ddl = "CREATE ENDPOINT $(ConvertTo-SqlIdentifier $EndpointName) STATE = STARTED AS TCP (LISTENER_PORT = $EndpointPort, LISTENER_IP = ALL) FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = CERTIFICATE $certIdentifier, ENCRYPTION = REQUIRED ALGORITHM AES)"
        [void](Invoke-Sql $ddl)
        Write-Host "  Created endpoint '$EndpointName' on port $EndpointPort."
        return
    }

    $script:ActiveEndpointName = [string]$existing.name
    $auth = [string]$existing.connection_auth_desc
    $algorithm = [string]$existing.encryption_algorithm_desc

    # Keep an existing Windows authentication method (e.g. for existing availability groups) and add the certificate
    $windowsMethod = $null
    if ($auth -match 'NEGOTIATE' -or ($auth -match 'NTLM' -and $auth -match 'KERBEROS')) { $windowsMethod = 'NEGOTIATE' }
    elseif ($auth -match 'NTLM') { $windowsMethod = 'NTLM' }
    elseif ($auth -match 'KERBEROS') { $windowsMethod = 'KERBEROS' }

    $needsAuthChange = $auth -notmatch 'CERTIFICATE'
    $needsAesChange = $algorithm -notmatch 'AES'
    $needsStart = [string]$existing.state_desc -ne 'STARTED'

    if (-not ($needsAuthChange -or $needsAesChange -or $needsStart)) {
        Write-Host "  Endpoint '$($script:ActiveEndpointName)' already uses certificate authentication and AES (auth: $auth, encryption: $algorithm)."
        return
    }

    $authClause = "CERTIFICATE $certIdentifier"
    if ($windowsMethod) { $authClause = "WINDOWS $windowsMethod CERTIFICATE $certIdentifier" }

    $algorithmClause = 'AES'
    if ($algorithm -match 'RC4') { $algorithmClause = 'AES RC4' }

    $ddl = "ALTER ENDPOINT $(ConvertTo-SqlIdentifier $script:ActiveEndpointName) STATE = STARTED FOR DATABASE_MIRRORING (AUTHENTICATION = $authClause, ENCRYPTION = REQUIRED ALGORITHM $algorithmClause)"
    [void](Invoke-Sql $ddl)
    Write-Host "  Extended endpoint '$($script:ActiveEndpointName)' (was auth: $auth, encryption: $algorithm; now: $authClause, AES)."
}

Invoke-Step 'Read public key of the legacySQL endpoint certificate' {
    if (-not $script:SqlCertName) { throw 'No legacySQL certificate available (previous step failed).' }
    $table = Invoke-Sql "SELECT CERTENCODED(CERT_ID($(ConvertTo-SqlString $script:SqlCertName))) AS public_key"
    $value = $table.Rows[0].public_key
    if ($value -is [System.DBNull]) { throw "Certificate '$($script:SqlCertName)' not found." }
    $script:SqlPublicKey = ConvertTo-HexString ([byte[]]$value)
    Write-Host "  Public key read for certificate '$($script:SqlCertName)'."
}

Invoke-Step 'Upload legacySQL certificate to SQL MI (trust certificate)' {
    if (-not $script:SqlPublicKey) { throw 'No legacySQL public key available (previous step failed).' }
    if (-not $script:SubscriptionId -or -not $script:ResourceGroupName) { throw 'Azure context is unknown (previous step failed).' }

    $trustPath = "$MiResourcePath/serverTrustCertificates/$([uri]::EscapeDataString($script:SqlCertName))"
    $current = Invoke-ArmRequestWithRetry -Method GET -Path $trustPath

    if ($current.StatusCode -eq 200) {
        $currentBlob = ([string]$current.Json.properties.publicBlob) -replace '^0[xX]', ''
        if ($currentBlob -ieq ($script:SqlPublicKey -replace '^0x', '')) {
            Write-Host "  Certificate '$($script:SqlCertName)' is already trusted by $MiName."
            return
        }
        Write-Host '  Trusted certificate differs from the local one, replacing it...'
        $deleteResponse = Invoke-ArmRequestWithRetry -Method DELETE -Path $trustPath
        if ($deleteResponse.StatusCode -notin 200, 202, 204) { throw "Could not remove outdated trust certificate (HTTP $($deleteResponse.StatusCode)): $($deleteResponse.Error)" }
        [void](Wait-ArmResource -Path $trustPath -ExpectedStatus 404)
    }
    elseif ($current.StatusCode -ne 404) {
        throw "Could not read trust certificates of $MiName (HTTP $($current.StatusCode)): $($current.Error)"
    }

    $body = @{ properties = @{ publicBlob = $script:SqlPublicKey } }
    $put = Invoke-ArmRequestWithRetry -Method PUT -Path $trustPath -Body $body
    if ($put.StatusCode -in 200, 201) {
        Write-Host "  Uploaded certificate '$($script:SqlCertName)' to $MiName."
    }
    elseif ($put.StatusCode -eq 202) {
        if (Wait-ArmResource -Path $trustPath -ExpectedStatus 200) {
            Write-Host "  Uploaded certificate '$($script:SqlCertName)' to $MiName."
        }
        else {
            throw 'Timed out waiting for the trust certificate to be created on SQL MI.'
        }
    }
    else {
        throw "Upload to $MiName failed (HTTP $($put.StatusCode)): $($put.Error)"
    }
}

Invoke-Step 'Read public key of the SQL MI endpoint certificate' {
    if (-not $script:SubscriptionId -or -not $script:ResourceGroupName) { throw 'Azure context is unknown (previous step failed).' }

    $response = Invoke-ArmRequestWithRetry -Method GET -Path "$MiResourcePath/endpointCertificates/DATABASE_MIRRORING"
    if ($response.StatusCode -ne 200) { throw "Could not read endpoint certificate of $MiName (HTTP $($response.StatusCode)): $($response.Error)" }

    $script:MiPublicKey = Format-PublicKey ([string]$response.Json.properties.publicBlob)
    Write-Host "  Public key read from $MiName."
}

Invoke-Step 'Import Azure root CA certificates on legacySQL' {
    $known = Get-SqlCertificateThumbprints

    foreach ($root in $RootCertificates) {
        try {
            $response = Invoke-WebRequest -Uri $root.Url -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            $bytes = [byte[]]$response.Content
            $text = [System.Text.Encoding]::ASCII.GetString($bytes)
            if ($text -match '-----BEGIN CERTIFICATE-----') {
                $base64 = ($text -replace '-----(BEGIN|END) CERTIFICATE-----', '') -replace '\s', ''
                $bytes = [Convert]::FromBase64String($base64)
            }

            $thumbprint = Get-Thumbprint $bytes
            if ($known.ContainsKey($thumbprint)) {
                Write-Host "  '$($root.Name)' already present as '$($known[$thumbprint])'."
                continue
            }

            $certName = ConvertTo-SqlIdentifier $root.Name
            [void](Invoke-Sql "CREATE CERTIFICATE $certName FROM BINARY = $(ConvertTo-HexString $bytes)")

            # Trust certificates issued by this root authority for Azure database.windows.net domains
            [void](Invoke-Sql "DECLARE @certId int = CERT_ID($(ConvertTo-SqlString $root.Name)); EXEC sp_certificate_add_issuer @certId, N'*.database.windows.net'")
            $known[$thumbprint] = $root.Name
            Write-Host "  Imported '$($root.Name)'."
        }
        catch {
            Write-Warning "Could not import root certificate '$($root.Name)': $($_.Exception.Message)"
        }
    }
}

Invoke-Step 'Import SQL MI endpoint certificate on legacySQL' {
    if (-not $script:MiPublicKey) { throw 'No SQL MI public key available (previous step failed).' }

    $miBytes = ConvertFrom-HexString $script:MiPublicKey
    $miThumbprint = Get-Thumbprint $miBytes
    $known = Get-SqlCertificateThumbprints

    $sameName = $null
    foreach ($entry in $known.GetEnumerator()) {
        if ($entry.Value -ieq $ManagedInstanceServer) { $sameName = $entry.Key }
    }

    if ($sameName -eq $miThumbprint) {
        Write-Host "  Certificate '$ManagedInstanceServer' is already imported and up to date."
        return
    }

    if ($sameName) {
        Write-Host '  SQL MI certificate has changed, replacing the imported certificate...'
        $loginName = ConvertTo-SqlIdentifier "MILink_Login_$MiName"
        [void](Invoke-Sql "IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = $(ConvertTo-SqlString "MILink_Login_$MiName")) DROP LOGIN $loginName")
        [void](Invoke-Sql "DROP CERTIFICATE $(ConvertTo-SqlIdentifier $ManagedInstanceServer)")
    }

    # The certificate name must be the FQDN of the managed instance, otherwise the link does not work
    [void](Invoke-Sql "CREATE CERTIFICATE $(ConvertTo-SqlIdentifier $ManagedInstanceServer) FROM BINARY = $($script:MiPublicKey)")
    Write-Host "  Imported certificate '$ManagedInstanceServer'."
}

Invoke-Step 'Authorize the SQL MI certificate to connect to the legacySQL endpoint' {
    $loginName = "MILink_Login_$MiName"
    $certCreated = (Invoke-Sql "SELECT 1 AS found FROM sys.certificates WHERE name = $(ConvertTo-SqlString $ManagedInstanceServer)").Rows.Count -gt 0
    if (-not $certCreated) { throw "Certificate '$ManagedInstanceServer' does not exist on legacySQL (previous step failed)." }

    $loginQuery = "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = $(ConvertTo-SqlString $loginName)) CREATE LOGIN $(ConvertTo-SqlIdentifier $loginName) FROM CERTIFICATE $(ConvertTo-SqlIdentifier $ManagedInstanceServer)"
    [void](Invoke-Sql $loginQuery)
    [void](Invoke-Sql "GRANT CONNECT ON ENDPOINT::$(ConvertTo-SqlIdentifier $script:ActiveEndpointName) TO $(ConvertTo-SqlIdentifier $loginName)")
    Write-Host "  Granted CONNECT on endpoint '$($script:ActiveEndpointName)' to certificate login '$loginName'."
}

Invoke-Step 'Allow inbound traffic to the endpoint port in Windows Firewall' {
    $port = $EndpointPort
    $row = (Invoke-Sql "SELECT t.port FROM sys.database_mirroring_endpoints e JOIN sys.tcp_endpoints t ON t.endpoint_id = e.endpoint_id").Rows
    if ($row.Count -gt 0) { $port = [int]$row[0].port }

    $ruleName = "SQL Database Mirroring Endpoint ($port)"
    if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue) {
        Write-Host "  Firewall rule '$ruleName' already exists."
    }
    else {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -Profile Any | Out-Null
        Write-Host "  Created firewall rule '$ruleName'."
    }
}

Invoke-Step 'Verify configuration' {
    $endpointInfo = Invoke-Sql "SELECT name, state_desc, role_desc, connection_auth_desc, encryption_algorithm_desc FROM sys.database_mirroring_endpoints"
    Write-Host (($endpointInfo.Rows | Format-Table name, state_desc, role_desc, connection_auth_desc, encryption_algorithm_desc -AutoSize | Out-String).Trim())
    $certInfo = Invoke-Sql "SELECT name, expiry_date FROM sys.certificates WHERE name IN ($(ConvertTo-SqlString $script:SqlCertName), $(ConvertTo-SqlString $ManagedInstanceServer))"
    Write-Host (($certInfo.Rows | Format-Table name, expiry_date -AutoSize | Out-String).Trim())
}

if ($script:FailedSteps.Count -gt 0) {
    Write-Warning "SQL MI link preparation finished with warnings. Steps with problems: $($script:FailedSteps -join '; ')"
}
else {
    Write-Host 'SQL MI link preparation completed successfully.' -ForegroundColor Green
}

try { Stop-Transcript | Out-Null } catch { }
