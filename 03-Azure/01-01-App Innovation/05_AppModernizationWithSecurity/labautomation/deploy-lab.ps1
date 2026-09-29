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
$rgId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"
$ownerRoleId = "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
Update-MhhToken | Out-Null
$vmInventoryJson = az vm list --resource-group $ResourceGroupName --subscription $SubscriptionId --only-show-errors --output json
if ($LASTEXITCODE -ne 0) { throw "Could not inventory VMs in $ResourceGroupName." }
$vmInventory = @($vmInventoryJson | ConvertFrom-Json)
$existingVms = @()
foreach ($stack in @('dotnet', 'java')) {
    $vmName = "vm-$stack-$suffix"
    $vm = $vmInventory | Where-Object { $_.name -eq $vmName } | Select-Object -First 1
    if ($null -eq $vm) {
        $existingVms += $false
        continue
    }

    $extensionsJson = az vm extension list --resource-group $ResourceGroupName --vm-name $vmName `
        --subscription $SubscriptionId --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect extensions on $vmName." }
    $extension = @($extensionsJson | ConvertFrom-Json) |
        Where-Object { $_.name -eq "provision-$stack" } | Select-Object -First 1
    if ($null -ne $extension) {
        $state = az vm extension show --resource-group $ResourceGroupName --vm-name $vmName `
            --name "provision-$stack" --instance-view --subscription $SubscriptionId `
            --query 'instanceView.statuses[0].code' --output tsv --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "Could not inspect provisioning status on $vmName." }
    }
    else {
        $state = 'Missing'
    }

    if ($state -match '^ProvisioningState/succeeded') {
        $existingVms += $true
        Write-Host "Reusing successfully provisioned VM $vmName without updating its immutable custom data."
        continue
    }
    if ($state -ne 'Missing' -and $state -notmatch '^ProvisioningState/failed') {
        throw "VM $vmName has extension state '$state'; refusing to delete a VM that may still be provisioning."
    }

    if ([string]::IsNullOrWhiteSpace($vm.identity.principalId)) {
        throw "Cannot safely remove ${vmName}: its managed identity principal ID is unavailable."
    }
    $assignmentsJson = az role assignment list --scope $rgId `
        --assignee-object-id $vm.identity.principalId --fill-principal-name false `
        --subscription $SubscriptionId --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect role assignments for $vmName." }
    $oldVmOwnerAssignments = @(@($assignmentsJson | ConvertFrom-Json) | Where-Object {
        $_.scope -eq $rgId -and $_.principalId -eq $vm.identity.principalId -and
        $_.roleDefinitionId -eq $ownerRoleId
    })
    foreach ($assignment in $oldVmOwnerAssignments) {
        az role assignment delete --ids $assignment.id --subscription $SubscriptionId --only-show-errors --output none
        if ($LASTEXITCODE -ne 0) { throw "Could not remove the old managed identity Owner assignment for $vmName." }
    }
    for ($attempt = 1; $attempt -le 12 -and $oldVmOwnerAssignments.Count -gt 0; $attempt++) {
        Update-MhhToken | Out-Null
        $remainingJson = az role assignment list --scope $rgId `
            --assignee-object-id $vm.identity.principalId --fill-principal-name false `
            --subscription $SubscriptionId --only-show-errors --output json
        if ($LASTEXITCODE -ne 0) { throw "Could not verify role assignment removal for $vmName." }
        $remaining = @(@($remainingJson | ConvertFrom-Json) | Where-Object {
            $_.scope -eq $rgId -and $_.principalId -eq $vm.identity.principalId -and
            $_.roleDefinitionId -eq $ownerRoleId
        })
        if ($remaining.Count -eq 0) { break }
        if ($attempt -eq 12) { throw "Old managed identity Owner assignment for $vmName is still present." }
        Start-Sleep -Seconds 5
    }
    Write-Warning "Deleting failed VM $vmName so its immutable custom data can be replaced; its OS disk and VM-local work will be lost."
    az vm delete --resource-group $ResourceGroupName --name $vmName --subscription $SubscriptionId `
        --yes --only-show-errors --output none
    if ($LASTEXITCODE -ne 0) { throw "Could not delete failed VM $vmName." }
    $existingVms += $false
}

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
    existingVms = $existingVms
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
