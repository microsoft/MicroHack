param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('subscription', 'resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = '',

    [string[]]$PreferredLocation = @(),

    [string[]]$AllowedEntraUserIds = @()
)

$ErrorActionPreference = 'Stop'
if ($DeploymentType -eq 'subscription' -or [string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    throw 'This Hack requires a platform-provided resource group. Select resourcegroup deployment type.'
}
if ($AllowedEntraUserIds.Count -eq 0) {
    throw 'AllowedEntraUserIds must contain at least one participant object ID.'
}
foreach ($participantId in $AllowedEntraUserIds) {
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse($participantId, [ref]$parsedId) -or $parsedId -eq [guid]::Empty) {
        throw "Invalid participant object ID: $participantId"
    }
}
$AllowedEntraUserIds = @($AllowedEntraUserIds | Sort-Object -Unique)

$sourceSettingsPath = Join-Path $PSScriptRoot 'deployment-settings.json'
$sourceSettings = Get-Content -LiteralPath $sourceSettingsPath -Raw | ConvertFrom-Json -AsHashtable -NoEnumerate
if ($sourceSettings -isnot [Collections.IDictionary] -or @($sourceSettings.Keys).Count -ne 2 -or
    @($sourceSettings.Keys | Where-Object { $_ -cnotin @('githubAccount', 'githubBranch') }).Count -gt 0) {
    throw 'deployment-settings.json must contain only githubAccount and githubBranch.'
}
foreach ($key in @('githubAccount', 'githubBranch')) {
    if ($sourceSettings[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($sourceSettings[$key])) {
        throw "deployment-settings.json requires a nonempty string for $key."
    }
}
$githubAccount = if ($env:MICROHACK_GITHUB_ACCOUNT) { $env:MICROHACK_GITHUB_ACCOUNT } else { $sourceSettings['githubAccount'] }
$githubBranch = if ($env:MICROHACK_GITHUB_BRANCH) { $env:MICROHACK_GITHUB_BRANCH } else { $sourceSettings['githubBranch'] }
if ($githubAccount -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$' -or
    $githubBranch -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or $githubBranch.Contains('..')) {
    throw 'Invalid GitHub artifact source in deployment-settings.json or MICROHACK_GITHUB_ACCOUNT/MICROHACK_GITHUB_BRANCH overrides.'
}

foreach ($helper in @('Get-MhhStableHash', 'New-MhhStablePassword', 'Update-MhhToken')) {
    Get-Command $helper -ErrorAction Stop | Out-Null
}
foreach ($module in @('Az.Accounts', 'Az.Resources', 'Az.Compute')) {
    Import-Module $module -ErrorAction Stop
}
if ((Get-AzContext).Subscription.Id -ne $SubscriptionId) {
    throw 'The authenticated subscription does not match SubscriptionId. Stop rather than deploy into another subscription.'
}
Update-MhhToken | Out-Null
$group = Get-AzResourceGroup -Name $ResourceGroupName
$groupTags = if ($null -eq $group.Tags) { @{} } else { $group.Tags }
$ResourceGroupName = $group.ResourceGroupName
$locations = @($PreferredLocation | ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim().Replace(' ', '').ToLowerInvariant() } | Where-Object { $_ } |
    Select-Object -Unique)
if ($locations.Count -eq 0) {
    $locations = @('swedencentral')
}
$labHash = Get-MhhStableHash -Value @($SubscriptionId.ToLowerInvariant(), $ResourceGroupName.ToLowerInvariant()) -Length 12
if ($labHash -cnotmatch '^[a-f0-9]{12}$') {
    throw 'The platform returned an invalid stable lab suffix.'
}
$labSuffix = $labHash.Substring(0, 8)
$hostName = "mh-$labSuffix-hv"
$deploymentName = "migration-$labSuffix"
$labVersion = 'single-rg-v1'
$hackName = '06_Migration_Secure_AI_Ready'
$resourceGroupId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"

if (($groupTags['Microhack'] -and $groupTags['Microhack'] -ne $hackName) -or
    ($groupTags['LabId'] -and $groupTags['LabId'] -ne $labSuffix)) {
    throw 'The supplied RG belongs to a different lab. No resources were changed.'
}
$existingResources = @(Get-AzResource -ResourceGroupName $ResourceGroupName)
if ($existingResources.Count -gt 0 -and $groupTags['Microhack'] -ne $hackName) {
    throw 'The supplied RG is not an empty platform scope or a recognized migration lab. It will not be adopted or cleared.'
}

$deployments = @(Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName)
$deployment = $deployments | Where-Object DeploymentName -EQ $deploymentName | Select-Object -First 1
$hostVm = $null
if ($existingResources.ResourceId -contains "$resourceGroupId/providers/Microsoft.Compute/virtualMachines/$hostName") {
    $hostVm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $hostName
}
$baselineCompleted = $null -ne $hostVm -and $null -ne $hostVm.Tags -and $hostVm.Tags['LabReady'] -eq $labVersion
$alreadyReady = $baselineCompleted -and $groupTags['LabVerified'] -eq $labVersion
if ($baselineCompleted -and ($null -eq $deployment -or $deployment.ProvisioningState -in @('Failed', 'Canceled'))) {
    throw 'A completed baseline exists without its successful deployment record. Inspect the lab; it will not be redeployed automatically.'
}
$recordedLocations = @(
    if ($groupTags['LabRegion']) { $groupTags['LabRegion'] }
    if ($null -ne $hostVm) { $hostVm.Location }
    if ($null -ne $deployment -and $null -ne $deployment.Parameters) { $deployment.Parameters['location'].Value }
) | Where-Object { $_ } | ForEach-Object { $_.Replace(' ', '').ToLowerInvariant() } | Select-Object -Unique
$recordedLocations = @($recordedLocations)
if ($recordedLocations.Count -gt 1) {
    throw 'The existing lab has conflicting resource regions. Inspect it; no resources will be moved or deleted.'
}
$location = if ($recordedLocations.Count -eq 1) { $recordedLocations[0] } else { $null }
if ($location -and $location -notin $locations) {
    throw "The existing lab is pinned to $location. Include it in PreferredLocation; retries never move or delete a lab."
}
if (-not $location -and ($existingResources.Count -gt 0 -or $null -ne $deployment)) {
    throw 'Cannot determine the existing lab region from its LabRegion tag, host, or deployment parameters. Inspect the lab before retrying.'
}
if (-not $alreadyReady -and $groupTags['LabVerified']) {
    Update-AzTag -ResourceId $resourceGroupId -Operation Merge -Tag @{ LabVerified = 'pending' } | Out-Null
}

$password = New-MhhStablePassword -Purpose 'migration-host-admin' -Length 24
$submissionJob = $null
$previousCorrelationId = $null
if (-not $alreadyReady -and ($null -eq $deployment -or $deployment.ProvisioningState -in @('Failed', 'Canceled'))) {
    if ($null -ne $deployment) {
        $previousCorrelationId = $deployment.CorrelationId
        if ([string]::IsNullOrWhiteSpace($previousCorrelationId)) {
            throw 'Cannot identify the previous deployment attempt. Inspect its correlation ID before retrying.'
        }
    }
    $providers = @{}
    foreach ($provider in @('Microsoft.Compute', 'Microsoft.Network', 'Microsoft.KeyVault', 'Microsoft.DevTestLab')) {
        Update-MhhToken | Out-Null
        $registration = Get-AzResourceProvider -ProviderNamespace $provider
        if ($registration.RegistrationState -notcontains 'Registered') {
            throw "$provider is not registered. Run the shared subscription preparation before deploying labs."
        }
        $providers[$provider] = $registration
    }

    if ($null -ne $hostVm -and $hostVm.HardwareProfile.VmSize -ne 'Standard_D16s_v5') {
        throw 'The existing host has an unexpected VM size. Inspect it instead of resizing an active lab automatically.'
    }
    $candidateLocations = if ($location) { @($location) } else { $locations }
    $location = $null
    # Developer SKU coverage is narrower than bastionHosts provider coverage.
    # https://learn.microsoft.com/azure/bastion/bastion-sku-comparison#regional-availability
    $bastionDeveloperLocations = @(
        'brazilsouth', 'canadacentral', 'canadaeast', 'centralus', 'centraluseuap',
        'eastus2', 'eastus2euap', 'mexicocentral', 'northcentralus', 'westcentralus', 'westus',
        'francecentral', 'germanywestcentral', 'italynorth', 'northeurope', 'norwayeast',
        'spaincentral', 'swedencentral', 'switzerlandnorth', 'uksouth', 'ukwest', 'westeurope',
        'australiacentral', 'australiaeast', 'australiasoutheast', 'centralindia', 'eastasia',
        'japaneast', 'japanwest', 'koreacentral', 'koreasouth', 'southindia', 'southeastasia',
        'southafricanorth', 'uaenorth'
    )
    foreach ($candidate in $candidateLocations) {
        Update-MhhToken | Out-Null
        $reasons = [Collections.Generic.List[string]]::new()
        if ($candidate -notin $bastionDeveloperLocations) {
            $reasons.Add('Bastion Developer is not in the documented regional availability list')
        }
        foreach ($requiredType in @(
            @{ Provider = 'Microsoft.Network'; Type = 'virtualNetworks' },
            @{ Provider = 'Microsoft.Network'; Type = 'natGateways' },
            @{ Provider = 'Microsoft.Network'; Type = 'bastionHosts' },
            @{ Provider = 'Microsoft.KeyVault'; Type = 'vaults' },
            @{ Provider = 'Microsoft.DevTestLab'; Type = 'schedules' }
        )) {
            $type = @($providers[$requiredType.Provider].ResourceTypes |
                Where-Object ResourceTypeName -EQ $requiredType.Type)
            $supported = @($type.Locations | Where-Object { $_ } |
                ForEach-Object { $_.Replace(' ', '').ToLowerInvariant() })
            if ($candidate -notin $supported) {
                $reasons.Add("$($requiredType.Provider)/$($requiredType.Type) is not advertised in this region")
            }
        }
        $skus = @(Get-AzComputeResourceSku -Location $candidate)
        foreach ($requiredSku in @(
            @{ Type = 'virtualMachines'; Name = 'Standard_D16s_v5' },
            @{ Type = 'disks'; Name = 'PremiumV2_LRS' }
        )) {
            $sku = @($skus | Where-Object { $_.ResourceType -eq $requiredSku.Type -and $_.Name -eq $requiredSku.Name })
            $zones = @($sku.LocationInfo | Where-Object Location -EQ $candidate | ForEach-Object Zones)
            $restricted = @($sku.Restrictions | Where-Object {
                $restrictedLocations = @($_.RestrictionInfo.Locations | Where-Object { $_ })
                if ($restrictedLocations.Count -eq 0 -and $_.Type -eq 'Location') {
                    $restrictedLocations = @($_.Values | Where-Object { $_ })
                }
                $appliesHere = $restrictedLocations.Count -eq 0 -or $restrictedLocations -contains $candidate
                $appliesHere -and ($_.Type -eq 'Location' -or
                    ($_.Type -eq 'Zone' -and $_.RestrictionInfo.Zones -contains '1'))
            })
            if ($sku.Count -ne 1 -or $zones -notcontains '1' -or $restricted.Count -gt 0) {
                $reasons.Add("$($requiredSku.Name) in zone 1 is unavailable")
            }
        }
        if ($null -eq $hostVm) {
            $usage = @(Get-AzVMUsage -Location $candidate)
            foreach ($quotaName in @('cores', 'standardDSv5Family')) {
                $quota = $usage | Where-Object { $_.Name.Value -ieq $quotaName } | Select-Object -First 1
                if ($null -eq $quota -or ($quota.Limit - $quota.CurrentValue) -lt 16) {
                    $reasons.Add("at least 16 available $quotaName vCPUs are required")
                }
            }
        }
        if ($reasons.Count -eq 0) {
            $location = $candidate
            break
        }
        Write-Warning "Skipping ${candidate}: $($reasons -join '; ')."
    }
    if (-not $location) {
        throw "No eligible deployment region among $($candidateLocations -join ', '). Resources are preserved; an existing lab cannot fall back to another region."
    }

    Write-Host "Artifact source: $githubAccount/MicroHack at $githubBranch"
    $artifactUrl = "https://raw.githubusercontent.com/$githubAccount/MicroHack/$githubBranch/03-Azure/01-03-Infrastructure/$hackName/resources/artifacts/Bootstrap.ps1"
    Invoke-WebRequest -Uri $artifactUrl -Method Head -UseBasicParsing -TimeoutSec 30 | Out-Null
    Update-AzTag -ResourceId $resourceGroupId -Operation Merge -Tag @{
        Microhack = $hackName
        LabId = $labSuffix
        LabRegion = $location
    } | Out-Null
    Update-MhhToken | Out-Null
    $deploymentParameters = @{
        Name = $deploymentName
        ResourceGroupName = $ResourceGroupName
        TemplateFile = Join-Path $PSScriptRoot 'bicep\main.bicep'
        Mode = 'Incremental'
        AsJob = $true
        TemplateParameterObject = @{
            labSuffix = $labSuffix
            participantObjectIds = $AllowedEntraUserIds
            location = $location
            # Use a JSON string here; Bicep's @secure() retains ARM secret protection.
            windowsAdminPassword = $password
            githubAccount = $githubAccount
            githubBranch = $githubBranch
        }
    }
    Write-Host "Deploying $deploymentName into $ResourceGroupName ($location). Both VNets remain in this RG."
    $submissionJob = New-AzResourceGroupDeployment @deploymentParameters
    $deployment = $null
} elseif ($null -ne $deployment -and $deployment.ProvisioningState -ne 'Succeeded') {
    Write-Host "Resuming ARM deployment '$deploymentName' in $location; no replacement deployment will be submitted."
}

if ($null -eq $deployment -or $deployment.ProvisioningState -ne 'Succeeded') {
    $armDeadline = (Get-Date).ToUniversalTime().AddMinutes(180)
    do {
        Update-MhhToken | Out-Null
        try {
            $deployment = Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $deploymentName -ErrorAction Stop
        } catch {
            $notRegistered = $_.FullyQualifiedErrorId -match 'DeploymentNotFound|ResourceNotFound' -or
                $_.ErrorDetails.Message -match '"code"\s*:\s*"(DeploymentNotFound|ResourceNotFound)"'
            # Az.Resources can wrap the HTTP response in an inner CloudException.
            for ($lookupError = $_.Exception; $null -ne $lookupError -and -not $notRegistered; $lookupError = $lookupError.InnerException) {
                $notRegistered = $lookupError.Response.StatusCode -eq 404 -or
                    $lookupError.Body.Code -in @('DeploymentNotFound', 'ResourceNotFound')
            }
            if (-not $notRegistered) { throw }
            $deployment = $null
        }
        if ($null -ne $deployment -and $previousCorrelationId -and $deployment.CorrelationId -eq $previousCorrelationId) {
            $deployment = $null
        }
        if ($null -ne $deployment) {
            Write-Host "ARM deployment: $($deployment.ProvisioningState)"
            if ($deployment.ProvisioningState -eq 'Succeeded') { break }
            if ($deployment.ProvisioningState -in @('Failed', 'Canceled')) {
                throw "ARM deployment ended as $($deployment.ProvisioningState). Inspect deployment operations; resources and the selected region are preserved."
            }
        } elseif ($null -ne $submissionJob -and $submissionJob.State -in @('Failed', 'Stopped')) {
            Write-Host "ARM submission job $($submissionJob.Id) ended as $($submissionJob.State); reading retained errors."
            Receive-Job -Job $submissionJob -Keep -ErrorAction Stop | Out-Null
            $reason = [string]$submissionJob.JobStateInfo.Reason
            if ([string]::IsNullOrWhiteSpace($reason)) {
                $reason = "Job $($submissionJob.Id) ended as $($submissionJob.State) with no retained error record. Inspect the runner's job diagnostics; resources are preserved."
            }
            throw "ARM submission failed before the deployment was registered: $reason"
        }
        if ((Get-Date).ToUniversalTime() -ge $armDeadline) {
            throw "ARM deployment '$deploymentName' timed out after 180 minutes. It may still be running; the RG is preserved and a rerun resumes polling."
        }
        if ($null -eq $deployment) {
            Write-Host "Waiting for ARM deployment '$deploymentName' to become visible; polling again in 30 seconds."
        }
        Start-Sleep -Seconds 30
    } while ($true)
}

if (-not $alreadyReady) {
    $deadline = [DateTime]::UtcNow.AddMinutes(120)
    do {
        Update-MhhToken | Out-Null
        $hostVm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $hostName
        $progress = if ($null -eq $hostVm.Tags) { '' } else { $hostVm.Tags['DeploymentProgress'] }
        Write-Host "Host provisioning: $progress"
        if ($progress -eq 'Deployment Failed') {
            throw "Host provisioning failed. Inspect C:\MHBox\Logs on $hostName; reruns never clear the lab RG."
        }
        $extension = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $hostName -Name 'Bootstrap' -Status
        if ($extension.ProvisioningState -eq 'Failed') {
            throw "The Bootstrap extension failed on $hostName. Inspect its instance view and C:\MHBox\Logs."
        }
        if ($progress -eq 'Deployment Completed' -and $hostVm.Tags['LabReady'] -eq $labVersion) {
            break
        }
        if ([DateTime]::UtcNow -ge $deadline) {
            throw "Timed out waiting for $hostName. Last progress: $progress. Resources are preserved for diagnosis."
        }
        Start-Sleep -Seconds 30
    } while ($true)

    $healthCheck = @'
$ErrorActionPreference = 'Stop'
$ready = Get-Content 'C:\MHBox\lab-ready.json' -Raw | ConvertFrom-Json
$expected = @('MHBox-AzMigSrv', 'MHBox-SQL', 'MHBox-Win2K22', 'MHBox-Ubuntu-01')
if ($ready.schemaVersion -ne 1 -or $ready.hostName -ine $env:COMPUTERNAME -or
    $ready.windowsHttpStatus -ne 200 -or $ready.linuxHttpStatus -ne 200 -or
    @(Compare-Object $expected @($ready.nestedVmNames)).Count -ne 0) {
    throw 'The baseline readiness marker is invalid.'
}
foreach ($name in $expected) {
    if ((Get-VM -Name $name -ErrorAction Stop).State -ne 'Running') {
        throw "Nested VM is not running: $name"
    }
}
'MICROHACK_BASELINE_READY_V1'
'@
    Update-MhhToken | Out-Null
    $check = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $hostName `
        -CommandId 'RunPowerShellScript' -ScriptString $healthCheck
    $messages = @($check.Value | ForEach-Object Message) -join "`n"
    if (($check.Value.Code -match '/failed$') -or
        (($messages -split '\r?\n') -notcontains 'MICROHACK_BASELINE_READY_V1')) {
        throw "Baseline readiness verification failed on $hostName. Inspect C:\MHBox\Logs; no credentials were published."
    }
    Update-AzTag -ResourceId $resourceGroupId -Operation Merge -Tag @{ LabVerified = $labVersion } | Out-Null
} else {
    Write-Host 'Reusing the completed baseline without changing resources or restarting nested VMs. Later learner work is preserved.'
}

$outputs = $deployment.Outputs
foreach ($name in @('hostVmName', 'keyVaultName', 'sourceVnetName', 'destinationVnetName', 'clientVmLogonUserName')) {
    if ([string]::IsNullOrWhiteSpace($outputs[$name].Value)) {
        throw "The deployment is missing the required output $name. Inspect the lab instead of guessing its resource names."
    }
}
if ($outputs['hostVmName'].Value -ne $hostName) {
    throw 'The deployment host output does not match the stable lab name.'
}

@{ HackboxCredential = @{ name = 'Migration Lab Host'; value = $hostName; note = 'Connect through the source VNet Bastion.' } }
@{ HackboxCredential = @{ name = 'Migration Host Username'; value = $outputs['clientVmLogonUserName'].Value } }
@{ HackboxCredential = @{ name = 'Migration Host Password'; value = $password; note = 'Lab credential; do not copy into logs or source control.' } }
@{ HackboxCredential = @{ name = 'Migration Lab Key Vault'; value = $outputs['keyVaultName'].Value } }
@{ HackboxCredential = @{ name = 'Migration Source VNet'; value = $outputs['sourceVnetName'].Value } }
@{ HackboxCredential = @{ name = 'Migration Destination VNet'; value = $outputs['destinationVnetName'].Value } }
@{ HackboxCredential = @{ name = 'Migration Lab Region'; value = $location } }
