param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('subscription','resourcegroup','resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = "",
    [string[]]$PreferredLocation = @(),
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'

if ($DeploymentType -eq 'subscription') {
    throw 'This lab requires a platform-provisioned participant resource group.'
}
if ([string]::IsNullOrWhiteSpace($ResourceGroupName) -or $PreferredLocation.Count -eq 0 -or $AllowedEntraUserIds.Count -eq 0) {
    throw 'A participant resource group, preferred region and allowed user ID are required.'
}
# Pin the published workshop tree and its reviewed GitHub archive together.
$sourceCommit = '4e3d090e252fd7197b529ed06d5cd427f158b2df'
$sourceArchiveSha256 = '0a36f3a2ee45c893b9d95266668d248e63707956eb995145f45ecaba77ec6507'
$labUser = Get-MhhLabUser -UserId $AllowedEntraUserIds[0]
if ([string]::IsNullOrWhiteSpace($labUser.UserPrincipalName) -or $labUser.Id -ne $AllowedEntraUserIds[0]) {
    throw 'Could not resolve the lab participant identity for migration parameters.'
}

function Get-GzipBase64 {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $stream = [IO.MemoryStream]::new()
    $gzip = [IO.Compression.GZipStream]::new($stream, [IO.Compression.CompressionMode]::Compress, $true)
    try {
        $gzip.Write($bytes, 0, $bytes.Length)
    } finally {
        $gzip.Dispose()
    }
    try {
        return [Convert]::ToBase64String($stream.ToArray())
    } finally {
        $stream.Dispose()
    }
}

$provisionerPath = Join-Path $PSScriptRoot 'scripts/provision-vm.ps1'
$bootstrapPath = Join-Path $PSScriptRoot 'scripts/bootstrap-provision-vm.ps1'
$provisionerBody = Get-GzipBase64 -Path $provisionerPath
$bootstrap = [IO.File]::ReadAllText($bootstrapPath) -creplace '(?s)^<#.*?#>\s*', ''
$wrapper = @'
param(
    [Parameter(Mandatory)][ValidateSet('dotnet', 'java')][string]$Stack,
    [Parameter(Mandatory)][string]$SourceCommit,
    [Parameter(Mandatory)][string]$SourceArchiveUrl,
    [Parameter(Mandatory)][string]$SourceArchiveSha256
)
$ErrorActionPreference='Stop'
$b=[Convert]::FromBase64String('__BODY__')
$m=New-Object IO.MemoryStream(,$b)
$g=New-Object IO.Compression.GZipStream($m,[IO.Compression.CompressionMode]::Decompress)
$r=New-Object IO.StreamReader($g)
try{$s=$r.ReadToEnd()}finally{$r.Dispose();$g.Dispose();$m.Dispose()}
[IO.File]::WriteAllText('C:\AzureData\provision-vm-body.ps1',$s,(New-Object Text.UTF8Encoding($false)))
& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File 'C:\AzureData\provision-vm-body.ps1' -Stack $Stack -SourceCommit $SourceCommit -SourceArchiveUrl $SourceArchiveUrl -SourceArchiveSha256 $SourceArchiveSha256
exit $LASTEXITCODE
'@.Replace('__BODY__', $provisionerBody)

$suffix = Get-MhhStableHash -Value @($ResourceGroupName) -Length 12
$adminPassword = New-MhhStablePassword -Purpose 'vm-admin' -Length 32
$customData = @{}
$commands = @{}
$apiKeys = @{}
foreach ($stack in @('dotnet', 'java')) {
    $databasePassword = New-MhhStablePassword -Purpose "database-$stack" -Length 32
    $apiKeys[$stack] = New-MhhStablePassword -Purpose "performance-api-$stack" -Length 48
    $payload = @{
        databasePassword = $databasePassword
        performanceApiKey = $apiKeys[$stack]
        facilitatorPrincipalName = $labUser.UserPrincipalName
        facilitatorPrincipalObjectId = $labUser.Id
        resourceGroupName = $ResourceGroupName
        teamName = "user-$suffix"
        adminUsername = 'azureuser'
        migrationSourceVirtualNetworkResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/vnet-$suffix"
        migrationSourceVmResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/vm-$stack-$suffix"
    }
    $encodedPayload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress)))
    $bundle = "MICROHACK_CUSTOM_DATA_V2`n$encodedPayload`nMICROHACK_PROVISIONER_START`n$wrapper"
    $bundleBytes = [Text.Encoding]::UTF8.GetBytes($bundle)
    if ($bundleBytes.Length -gt 65535) {
        throw "The $stack VM custom data exceeds Azure's 65,535-byte limit."
    }
    $customData[$stack] = [Convert]::ToBase64String($bundleBytes)

    $bootstrapScript = "`$ErrorActionPreference='Stop'`n$bootstrap`nInvoke-ProvisioningBootstrap -Stack '$stack' -SourceCommit '$sourceCommit' -SourceArchiveSha256 '$sourceArchiveSha256'`nexit 0"
    $commands[$stack] = 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ' +
        [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrapScript))
    if ($commands[$stack].Length -gt 7800) {
        throw "The $stack extension command exceeds the 7,800-character Windows launch limit."
    }
}

$parameters = @{
    labSuffix = $suffix
    adminPassword = $adminPassword
    dotnetCustomData = $customData.dotnet
    javaCustomData = $customData.java
    dotnetBootstrapCommand = $commands.dotnet
    javaBootstrapCommand = $commands.java
    sourceCommit = $sourceCommit
    provisionerVersion = "$( (Get-FileHash $provisionerPath -Algorithm SHA256).Hash )-$( (Get-FileHash $bootstrapPath -Algorithm SHA256).Hash )"
    allowedEntraUserIds = $AllowedEntraUserIds
}
$result = Invoke-MhhDeploymentWithRegionFallback `
    -PreferredLocations $PreferredLocation `
    -ResourceGroupName $ResourceGroupName `
    -RgOwnerEntraObjectIds $AllowedEntraUserIds `
    -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') `
    -TemplateParameterObject $parameters `
    -DeploymentNamePrefix 'modernization' `
    -Tag @{ SecurityControl = 'ignore' }

foreach ($stack in @('dotnet', 'java')) {
    @{ HackboxCredential = @{ name = "$stack VM"; value = $result.Outputs.vmNames[$stack]; note = 'Windows Server 2025' } }
    @{ HackboxCredential = @{ name = "$stack RDP address"; value = $result.Outputs.publicIpAddresses[$stack]; note = 'Open RDP only for your IP in Challenge 0; browse the app at localhost inside the VM.' } }
    @{ HackboxCredential = @{ name = "$stack performance API key"; value = $apiKeys[$stack]; note = 'Use for the Challenge 2 load-test secret.' } }
}
@{ HackboxCredential = @{ name = 'VM admin username'; value = 'azureuser'; note = 'Both legacy VMs' } }
@{ HackboxCredential = @{ name = 'VM admin password'; value = $adminPassword; note = 'Both legacy VMs' } }
