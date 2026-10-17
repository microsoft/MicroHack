<#
.SYNOPSIS
Provision the infrastructure for one Microsoft-hosted Adaptive Apps lab.
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('subscription', 'resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,
    [Parameter(Mandatory)][string]$SubscriptionId,
    [string]$ResourceGroupName = '',
    [string[]]$PreferredLocation = @(),
    [string[]]$AllowedEntraUserIds = @()
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'console-helpers.ps1')
if (-not $IsLinux) { throw 'Adaptive Apps Console automation requires a Linux runner.' }
if ($DeploymentType -ne 'resourcegroup' -or -not $ResourceGroupName) {
    throw 'This hook requires a Console-provisioned resourcegroup scope.'
}
if ($AllowedEntraUserIds.Count -eq 0) { throw 'Console must supply participant object IDs for node resource group Reader access.' }
if (-not $env:AZURE_CONFIG_DIR -or -not [IO.Path]::IsPathRooted($env:AZURE_CONFIG_DIR)) {
    throw 'Console must supply an absolute, isolated AZURE_CONFIG_DIR.'
}
$scratch = Join-Path ([IO.Path]::GetTempPath()) "adaptive-console-$([guid]::NewGuid().ToString('N'))"
try {
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    & chmod 700 $scratch
    if ($LASTEXITCODE -ne 0) { throw 'Unable to secure private deployment scratch directory.' }

    Update-MhhToken | Out-Null
    Write-Host 'Validating participant Azure contexts and shared region metadata...'
    Assert-AdaptiveContext -SubscriptionId $SubscriptionId
    $group = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    $region = $group.Location.ToLowerInvariant()
    $metadata = (Get-AzTag -ResourceId "/subscriptions/$SubscriptionId" -ErrorAction Stop).Properties.TagsProperty
    if (-not $metadata) { throw 'Shared region metadata is missing. Run shared-deploy-lab.ps1 first.' }
    $regions = @($metadata['microhack-adaptive-regions'] -split ',' | Where-Object { $_ })
    $preserve = $group.Tags -and ($group.Tags['adaptiveAppsReady'] -eq 'true' -or
        $group.Tags['adaptiveAppsInfrastructureReady'] -eq 'true' -or $group.Tags['adaptiveAppsPreserve'] -eq 'true')
    if ($regions.Count -eq 0 -or ($preserve -and $region -notin $regions)) {
        throw "No validated region is available for this lab. Run shared-deploy-lab.ps1 for the lab's region; an established lab will not be relocated."
    }
    $deploymentTags = @{
        adaptiveAppsReady = 'false'
        adaptiveAppsInfrastructureReady = 'false'
        SecurityControl = 'Ignore'
        CostControl = 'Ignore'
    }
    if ($preserve) { $deploymentTags.adaptiveAppsPreserve = 'true' }
    Update-AzTag -ResourceId $group.ResourceId -Operation Merge -Tag $deploymentTags -ErrorAction Stop | Out-Null

    Write-Host 'Preparing private infrastructure deployment parameters...'
    $parameterFile = Join-Path $scratch 'main.parameters.json'
    @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            adminPassword = @{ value = (New-MhhStablePassword -Purpose 'adaptive-apps-k3s-admin' -Length 24) }
        }
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $parameterFile -Encoding utf8
    & chmod 600 $parameterFile
    if ($LASTEXITCODE -ne 0) { throw 'Unable to secure infrastructure parameter file.' }
    Write-Host 'Submitting incremental Adaptive Apps infrastructure deployment...'
    try {
        if ($preserve) {
            $deployment = New-AzResourceGroupDeployment -Name 'adaptive-apps-console' `
                -ResourceGroupName $ResourceGroupName -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') `
                -TemplateParameterFile $parameterFile -Mode Incremental -ErrorAction Stop
        } else {
            Write-Warning "Initial provisioning may delete and recreate '$ResourceGroupName' on retryable infrastructure failures. Validated regions: $($regions -join ', ')."
            $result = Invoke-MhhDeploymentWithRegionFallback -PreferredLocations $regions `
                -ResourceGroupName $ResourceGroupName -RgOwnerEntraObjectIds $AllowedEntraUserIds `
                -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') -TemplateParameterFile $parameterFile `
                -DeploymentNamePrefix 'adaptive-apps-console' -Tag $deploymentTags -ErrorAction Stop
            if (-not $result.Success) { throw 'Initial infrastructure fallback did not report success.' }
            $deployment = $result.DeploymentResult
        }
    } finally {
        Remove-Item -LiteralPath $parameterFile -Force
    }
    if ($deployment.ProvisioningState -ne 'Succeeded') {
        throw "Infrastructure deployment failed: $($deployment.ProvisioningState). Infrastructure will not be marked ready."
    }
    $group = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    $region = $group.Location.ToLowerInvariant()
    if ($region -notin $regions) { throw "Deployment used unvalidated region '$region'." }
    # Keep this marker through failed reconciliations; readiness alone is not a deletion guard.
    Update-AzTag -ResourceId $group.ResourceId -Operation Merge -Tag @{ adaptiveAppsPreserve = 'true' } -ErrorAction Stop | Out-Null
    $acrName = $deployment.Outputs.acrName.Value
    $nodeGroup = $deployment.Outputs.nodeResourceGroup.Value
    if (-not $acrName -or -not $nodeGroup) { throw 'Infrastructure deployment omitted ACR or AKS node resource group outputs.' }
    Update-MhhToken | Out-Null
    $nodeScope = "/subscriptions/$SubscriptionId/resourceGroups/$nodeGroup"
    $readerId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    foreach ($objectId in ($AllowedEntraUserIds | Select-Object -Unique)) {
        # --assignee-object-id and --assignee-principal-type avoid all Microsoft Graph lookups.
        $assignments = @(Invoke-AdaptiveAz -Arguments @('role', 'assignment', 'list', '--scope', $nodeScope, '--fill-principal-name', 'false'))
        $exists = $assignments | Where-Object {
            $_.principalId -eq $objectId -and $_.roleDefinitionId -like "*/$readerId" -and $_.scope -ieq $nodeScope
        }
        if (-not $exists) {
            Invoke-AdaptiveAz -Arguments @('role', 'assignment', 'create', '--assignee-object-id', $objectId,
                '--assignee-principal-type', 'User', '--role', $readerId, '--scope', $nodeScope) | Out-Null
        }
    }
    Update-MhhToken | Out-Null
    Write-Host 'Installing and verifying K3s through VM Run Command...'
    $guest = Invoke-AdaptiveAz -Arguments @('vm', 'run-command', 'invoke', '--resource-group', $ResourceGroupName,
        '--name', 'vm-adaptive-apps-k3s', '--command-id', 'RunShellScript',
        '--scripts', "@$(Join-Path $PSScriptRoot 'install-k3s.sh')")
    if (($guest.value.message -join "`n") -notmatch '(?m)^ADAPTIVE_K3S_READY\r?$') {
        throw 'K3s Run Command did not return its readiness marker. Inspect VM Run Command and NAT outbound; credentials were not emitted.'
    }
    Update-AzTag -ResourceId $group.ResourceId -Operation Merge -Tag @{
        adaptiveAppsAcr = $acrName
    } -ErrorAction Stop | Out-Null
    Update-MhhToken | Out-Null
    Write-Host 'Verifying AKS nodes through Azure Run Command (no worker Kubernetes context)...'
    $aks = Invoke-AdaptiveAz -Arguments @('aks', 'command', 'invoke', '--resource-group', $ResourceGroupName,
        '--name', 'aks-adaptive-apps', '--command', 'kubectl wait --for=condition=Ready nodes --all --timeout=5m')
    if ($aks.provisioningState -ne 'Succeeded' -or $null -eq $aks.exitCode -or $aks.exitCode -ne 0) {
        throw 'AKS node readiness failed. Inspect AKS Run Command; infrastructure was not marked ready.'
    }
    Update-MhhToken | Out-Null
    $bastion = Invoke-AdaptiveAz -Arguments @('network', 'bastion', 'show', '--resource-group', $ResourceGroupName,
        '--name', 'bas-adaptive-apps', '--query', '{state:provisioningState,sku:sku.name,tunneling:enableTunneling}')
    if ($bastion.state -ne 'Succeeded' -or $bastion.sku -notin @('Standard', 'Premium') -or $bastion.tunneling -ne $true) {
        throw 'Bastion must be provisioned with native tunneling enabled before infrastructure is ready.'
    }
    $registry = Invoke-AdaptiveAz -Arguments @('acr', 'show', '--resource-group', $ResourceGroupName, '--name', $acrName)
    if ($registry.provisioningState -ne 'Succeeded' -or $registry.anonymousPullEnabled -ne $true) {
        throw 'The recipe registry must be provisioned with anonymous pull enabled before infrastructure is ready.'
    }
} finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
Update-MhhToken | Out-Null
Update-AzTag -ResourceId $group.ResourceId -Operation Merge -Tag @{ adaptiveAppsInfrastructureReady = 'true' } -ErrorAction Stop | Out-Null
@{ HackboxCredential = @{ name = 'Adaptive Apps Region'; value = $region; note = 'All resources and recipes use the supplied resource group location.' } }
@{ HackboxCredential = @{ name = 'Adaptive Apps Registry'; value = "$acrName.azurecr.io"; note = 'Anonymous recipe pull is enabled; do not publish sensitive artifacts.' } }
@{ HackboxCredential = @{ name = 'Adaptive Apps AKS'; value = 'aks-adaptive-apps'; note = "Node RG: $nodeGroup (Reader granted for recipe egress discovery)." } }
@{ HackboxCredential = @{ name = 'Adaptive Apps K3s'; value = 'vm-adaptive-apps-k3s'; note = 'Private VM via bas-adaptive-apps. Connect uses Run Command, not SSH/password.' } }
@{ HackboxCredential = @{
    name = 'Adaptive Apps Connect'
    value = "AZURE_SUBSCRIPTION='$SubscriptionId' RESOURCE_GROUP='$ResourceGroupName' bash resources/connect-console.sh"
    note = 'Run from the complete Adaptive Apps checkout after signing into your own participant Azure CLI account. Infrastructure only: install Radius in Challenge 03, then complete Challenges 04-05.'
} }
