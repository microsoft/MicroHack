<#
.SYNOPSIS
Deploys one event-wide LocalBox for Sovereign Cloud MicroHack labs.
.DESCRIPTION
Runs once per event in the Console-selected lowest-GUID subscription, before
shared subscription preparation. All event participants receive access and
nonsecret discovery credentials. Participant VMs remain in their assigned scopes.
For Microsoft-hosted environments only: assigns and verifies the MCAPS control-tag
initiative and enables paid Defender for Servers P2 with Endpoint protection before
deploying resources. Do not use this hook for BYOS setup.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string[]]$PreferredLocation = @(),

    [Parameter(Mandatory=$false)]
    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'localbox-credentials.ps1')
. (Join-Path $PSScriptRoot 'localbox-automation.ps1')
. (Join-Path $PSScriptRoot 'hosted-tag-policy.ps1')
. (Join-Path $PSScriptRoot 'hosted-defender.ps1')

Update-MhhToken | Out-Null
if ((Get-AzContext -ErrorAction Stop).Subscription.Id -ne $SubscriptionId) {
    throw "The Azure context must target global LocalBox subscription $SubscriptionId."
}
$participants = @($AllowedEntraUserIds | Sort-Object -Unique)
foreach ($participant in $participants) {
    $objectId = [guid]::Empty
    if (-not [guid]::TryParse($participant, [ref]$objectId) -or $objectId -eq [guid]::Empty) {
        throw 'AllowedEntraUserIds must contain valid event participant object IDs.'
    }
}
$groupCredentials = @(Get-LocalBoxConsoleGroupCredential)
$localBoxAutomationPackage = New-LocalBoxAutomationPackage

$azureLocalResourceProviderAppId = '1412d89f-b8a8-4111-b4fd-e82905cbd85d'
Update-MhhToken | Out-Null
$azureLocalResourceProviderObjectIds = @(
    & az ad sp list `
        --filter "appId eq '$azureLocalResourceProviderAppId'" `
        --query '[].id' `
        --output tsv `
        --only-show-errors
)
if($LASTEXITCODE -ne 0) {
    throw 'Unable to query Microsoft Graph for the Microsoft.AzureStackHCI service principal.'
}
$azureLocalResourceProviderObjectIds = @($azureLocalResourceProviderObjectIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if($azureLocalResourceProviderObjectIds.Count -ne 1) {
    throw "Expected exactly one Microsoft.AzureStackHCI service principal, found $($azureLocalResourceProviderObjectIds.Count)."
}
Write-Host "Resolved Microsoft.AzureStackHCI service-principal object ID: $($azureLocalResourceProviderObjectIds[0])" -ForegroundColor Green

Write-Host "Preparing subscription $SubscriptionId for the event-wide LocalBox..."
& (Join-Path $PSScriptRoot 'resource-providers.ps1')

if (-not $?) {
    throw "Resource provider registration failed for subscription $SubscriptionId."
}

$defaults = Get-Content (Join-Path $PSScriptRoot 'lab-defaults.json') -Raw | ConvertFrom-Json
if($PreferredLocation.Count -eq 0) {
    $PreferredLocation = @($defaults.preferredLocation)
}
$PreferredLocation = @($PreferredLocation | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

if ($PreferredLocation.Count -eq 0) { throw 'At least one preferred LocalBox host region is required.' }
Initialize-MhhHostedTagPolicy -SubscriptionId $SubscriptionId -Location $PreferredLocation[0]
Initialize-MhhHostedDefender -SubscriptionId $SubscriptionId

$localBoxResourceGroupName = 'rg-localbox-shared'
$localBoxLocations = @(
    $PreferredLocation |
        Where-Object { $_ } |
        Select-Object -Unique
)
$activeDeploymentStates = @('Accepted', 'Running', 'Ready', 'Creating', 'Created', 'Succeeded')
$resourceGroup = Get-AzResourceGroup -ErrorAction Stop | Where-Object ResourceGroupName -eq $localBoxResourceGroupName
if ($resourceGroup) {
    Update-AzTag `
        -ResourceId $resourceGroup.ResourceId `
        -Operation Merge `
        -Tag @{
            workload = 'sovereign-localbox'
            challenge = '6'
            SecurityControl = 'Ignore'
            CostControl = 'Ignore'
        } `
        -ErrorAction Stop | Out-Null
    Write-Host "Applied the temporary MCAPS security-control exemption to $localBoxResourceGroupName." -ForegroundColor Green
}
$localBoxDeployment = if ($resourceGroup) {
    Get-AzResourceGroupDeployment `
        -ResourceGroupName $localBoxResourceGroupName `
        -ErrorAction Stop |
        Where-Object {
            $_.DeploymentName -like 'localbox-*' -and
            $_.ProvisioningState -in $activeDeploymentStates
        } |
        Sort-Object Timestamp -Descending |
        Select-Object -First 1
}

if ($localBoxDeployment) {
    Write-Host "Reusing LocalBox deployment '$($localBoxDeployment.DeploymentName)' ($($localBoxDeployment.ProvisioningState))." -ForegroundColor Green
    $localBoxClient = Get-AzResource `
        -ResourceGroupName $localBoxResourceGroupName `
        -ResourceType 'Microsoft.Compute/virtualMachines' `
        -ErrorAction Stop |
        Where-Object Name -eq 'LocalBox-Client'
    if ($localBoxClient) {
        Update-AzTag `
            -ResourceId $localBoxClient.ResourceId `
            -Operation Merge `
            -Tag @{ CostControl = 'Ignore' } `
            -ErrorAction Stop | Out-Null
    }
    try {
        Wait-LocalBoxDeployment -ResourceGroupName $localBoxResourceGroupName -DeploymentName $localBoxDeployment.DeploymentName
    }
    catch {
        if (-not (Test-LocalBoxCapacityFailure $_)) { throw }
        Write-Warning $_.Exception.Message
        $localBoxDeployment = $null
    }
}

if (-not $localBoxDeployment) {
    $candidateFailures = [Collections.Generic.List[string]]::new()
    :locations foreach ($localBoxLocation in $localBoxLocations) {
        foreach ($localBoxVmSize in @('Standard_E32s_v6', 'Standard_E32s_v5')) {
            Update-MhhToken | Out-Null
            $existingGroup = Get-AzResourceGroup -ErrorAction Stop | Where-Object ResourceGroupName -eq $localBoxResourceGroupName
            $resources = if ($existingGroup) {
                @(Get-AzResource -ResourceGroupName $localBoxResourceGroupName -ErrorAction Stop)
            } else { @() }
            if (@($resources | Where-Object ResourceType -eq 'Microsoft.Compute/virtualMachines').Count) {
                throw "A VM already exists in $localBoxResourceGroupName. Automatic LocalBox SKU/region changes are blocked; inspect the failed deployment. No VM was resized or deleted."
            }
            $conflicts = @($resources | Where-Object {
                $_.ResourceType -notin @('Microsoft.Storage/storageAccounts', 'Microsoft.Resources/deployments') -and
                ($_.Location -replace '\s', '') -ine ($localBoxLocation -replace '\s', '') -and $_.Location -ine 'global'
            })
            if ($conflicts.Count) {
                $message = "Skipping ${localBoxLocation}: existing LocalBox resources are in another or unknown region. Preserve the partial environment; a region change requires a separately approved migration or fresh scope."
                Write-Warning $message
                $candidateFailures.Add($message)
                continue locations
            }
            try {
                Write-Host "Submitting shared LocalBox deployment in $localBoxLocation using $localBoxVmSize..." -ForegroundColor Cyan
                $localBoxDeployment = & (Join-Path $PSScriptRoot 'deploy-localbox.ps1') `
                    -SubscriptionId $SubscriptionId `
                    -ResourceGroupName $localBoxResourceGroupName `
                    -Location $localBoxLocation `
                    -VmSize $localBoxVmSize `
                    -AzureLocalResourceProviderObjectId $azureLocalResourceProviderObjectIds[0] `
                    -AzureLocalInstanceLocation 'australiaeast' `
                    -UseConsoleCredentials `
                    -NoWait

                if (-not $localBoxDeployment -or $localBoxDeployment.ProvisioningState -ne 'Submitted') {
                    throw "LocalBox deployment submission did not return the expected Submitted state."
                }
                Wait-LocalBoxDeployment -ResourceGroupName $localBoxResourceGroupName -DeploymentName $localBoxDeployment.DeploymentName
                break locations
            }
            catch {
                if (-not (Test-LocalBoxCapacityFailure $_)) { throw }
                $message = "$localBoxLocation/$localBoxVmSize : $(ConvertTo-LocalBoxDiagnosticText $_.Exception.Message 2000)"
                Write-Warning "LocalBox capacity candidate failed: $message"
                $candidateFailures.Add($message)
                $localBoxDeployment = $null
            }
        }
    }

    if (-not $localBoxDeployment) {
        throw "LocalBox capacity candidates exhausted for subscription $SubscriptionId. No resources were deleted or relocated. Retry after availability changes or arrange an approved fresh scope/migration. $($candidateFailures -join '; ')"
    }
}


$localBoxScope = "/subscriptions/$SubscriptionId/resourceGroups/$localBoxResourceGroupName"
for ($attempt = 1; $attempt -le 60; $attempt++) {
    Update-MhhToken | Out-Null
    $runtimeProvider = Get-AzResourceProvider -ProviderNamespace Microsoft.KubernetesRuntime -ErrorAction Stop
    if ($runtimeProvider.RegistrationState -eq 'Registered') { break }
    Start-Sleep -Seconds 10
}
if ($runtimeProvider.RegistrationState -ne 'Registered') {
    throw 'Microsoft.KubernetesRuntime registration did not complete. LocalBox MetalLB preparation is blocked.'
}
$runtimeObjectIds = @(& az ad sp list --filter "appId eq '087fca6e-4606-4d41-b3f6-5ebdf75b8b4c'" --query '[].id' --output tsv --only-show-errors)
if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve the Microsoft.KubernetesRuntime service principal for MetalLB.' }
$runtimeObjectIds = @($runtimeObjectIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$runtimeObjectId = [guid]::Empty
if ($runtimeObjectIds.Count -ne 1 -or -not [guid]::TryParse($runtimeObjectIds[0], [ref]$runtimeObjectId) -or $runtimeObjectId -eq [guid]::Empty) {
    throw 'Expected exactly one valid Microsoft.KubernetesRuntime service-principal object ID. Have the tenant administrator verify provider registration.'
}
Update-AzTag -ResourceId $localBoxScope -Operation Merge `
    -Tag @{ 'microhack-k8s-runtime-object-id' = $runtimeObjectId.ToString() } -ErrorAction Stop | Out-Null

foreach ($participantObjectId in $participants) {
    Update-MhhToken | Out-Null
    foreach ($roleName in @('Reader', 'Azure Stack HCI VM Contributor', 'Security Reader')) {
        $roleScope = if ($roleName -eq 'Security Reader') { "/subscriptions/$SubscriptionId" } else { $localBoxScope }
        $roleAssignment = Get-AzRoleAssignment `
            -ObjectId $participantObjectId `
            -RoleDefinitionName $roleName `
            -Scope $roleScope `
            -ErrorAction Stop

        if (-not $roleAssignment) {
            Write-Host "Assigning '$roleName' on shared LocalBox to $participantObjectId..."
            New-AzRoleAssignment `
                -ObjectId $participantObjectId `
                -RoleDefinitionName $roleName `
                -Scope $roleScope `
                -ErrorAction Stop | Out-Null
        }
    }
}

$groupId = ($groupCredentials.HackboxCredential | Where-Object name -eq 'Lab Group ObjectId').value
$automation = Invoke-LocalBoxHostedAutomation -SubscriptionId $SubscriptionId -ResourceGroupName $localBoxResourceGroupName `
    -AksAdminGroupObjectId $groupId -Package $localBoxAutomationPackage
Write-Host "LocalBox preparation and health checks completed. Private results: $($automation.ResultsUri)"

$groupCredentials
@{ HackboxCredential = @{
    name = 'Shared LocalBox Subscription ID'
    value = $SubscriptionId
    note = 'Event-wide LocalBox and AKS host; your own VM stays in your assigned subscription/resource group'
} }
@{ HackboxCredential = @{
    name = 'Shared LocalBox Resource Group ID'
    value = $localBoxScope
    note = 'Use this exact scope to find the event-wide LocalBox, even from another lab subscription'
} }
@{
    'HackboxCredential' = @{
        name = 'Shared LocalBox Resource Group'
        value = $localBoxResourceGroupName
        note = 'One Challenge 6 environment for the entire event; readiness is verified by the facilitator'
    }
}