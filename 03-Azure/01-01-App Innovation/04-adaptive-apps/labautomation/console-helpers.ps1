function Invoke-AdaptiveAz {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $result = & az @Arguments --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed (exit $LASTEXITCODE): az $($Arguments[0..([Math]::Min(2, $Arguments.Length - 1))] -join ' ')"
    }
    if ($result) { ($result -join "`n") | ConvertFrom-Json }
}

function Assert-AdaptiveContext {
    param([string]$SubscriptionId)
    if ((Get-AzContext -ErrorAction Stop).Subscription.Id -ne $SubscriptionId) {
        throw "Az PowerShell context must target $SubscriptionId. Console must supply authentication."
    }
    $account = Invoke-AdaptiveAz -Arguments @('account', 'show')
    if ($account.id -ne $SubscriptionId) {
        throw "Azure CLI context must target $SubscriptionId. Console must supply authentication."
    }
}

function Test-AdaptiveRegion {
    param(
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][ValidateRange(1, 1000)][int]$LabCount
    )
    $required = 16 * $LabCount
    $skus = @(Invoke-AdaptiveAz -Arguments @('vm', 'list-skus', '--location', $Location, '--resource-type', 'virtualMachines', '--size', 'Standard_D4s_v5', '--all'))
    $sku = $skus | Where-Object {
        $_.name -eq 'Standard_D4s_v5' -and
        -not ($_.restrictions | Where-Object { $_.type -eq 'Location' })
    } | Select-Object -First 1
    if (-not $sku) { throw "$Location does not expose unrestricted Standard_D4s_v5 for this subscription." }
    $usage = @(Invoke-AdaptiveAz -Arguments @('vm', 'list-usage', '--location', $Location))
    foreach ($quotaName in @('cores', 'standardDSv5Family')) {
        $quota = $usage | Where-Object { $_.name.value -ieq $quotaName } | Select-Object -First 1
        if (-not $quota -or ($quota.limit - $quota.currentValue) -lt $required) {
            throw "$Location needs $required FREE $quotaName vCPUs ($LabCount labs, 12 baseline + 4 surge each). Ask the organizer to raise quota or select another RG region."
        }
    }
    $postgres = @(Invoke-AdaptiveAz -Arguments @('postgres', 'flexible-server', 'list-skus', '--location', $Location))
    $postgresReady = $false
    foreach ($capability in $postgres) {
        if ($capability.status -and $capability.status -ne 'Available') { continue }
        if ($capability.supportedFeatures | Where-Object { $_.name -eq 'OfferRestricted' -and $_.status -eq 'Enabled' }) { continue }
        # Current CLI uses server editions; older runners return flexible editions per zone.
        $burst = @($capability.supportedServerEditions | Where-Object { $_.name -eq 'Burstable' })
        $versions = @($capability.supportedServerVersions | Where-Object { $_.name -eq '16' })
        if ($versions.Count -gt 0 -and ($burst.supportedServerSkus | Where-Object { $_.name -eq 'Standard_B1ms' })) {
            $postgresReady = $true
        }
        $legacyBurst = @($capability.supportedFlexibleServerEditions | Where-Object { $_.name -eq 'Burstable' })
        $legacyVersion = @($legacyBurst.supportedServerVersions | Where-Object { $_.name -eq '16' })
        if ($legacyVersion.supportedVcores | Where-Object { $_.name -eq 'Standard_B1ms' }) {
            $postgresReady = $true
        }
    }
    if (-not $postgresReady) {
        throw "$Location does not advertise PostgreSQL 16 Burstable Standard_B1ms required by the default recipe."
    }
    return $Location
}

function Invoke-AdaptiveBash {
    param(
        [Parameter(Mandatory)][string]$Script,
        [string[]]$Arguments = @()
    )
    Update-MhhToken | Out-Null
    & bash $Script @Arguments | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "Console Bash phase '$Script $($Arguments -join ' ')' failed with exit code $LASTEXITCODE."
    }
}

function Assert-AdaptivePackage {
    param([Parameter(Mandatory)][string]$LabRoot)
    foreach ($path in @(
        'resources/install-console-tools.sh', 'resources/bootstrap-console.sh',
        'resources/azure-session.sh', 'resources/console-session.sh', 'resources/verify-recipes.sh',
        'resources/connect-console.sh', 'resources/prepare-k3s-azure-vm.sh',
        'resources/deploy-radius-aks.sh', 'resources/deploy-radius-k3s.sh',
        'resources/configure-resource-types-aks.sh', 'resources/configure-resource-types-k3s.sh',
        'resources/configure-recipes.sh', 'iac/bicepconfig.json',
        'iac/aks-env.bicep', 'iac/local-env.bicep', 'iac/sql-databases.yaml',
        'iac/recipes/postgres-azure-flex.bicep', 'iac/recipes/postgres-kubernetes.bicep',
        'iac/recipes/sql-server.bicep', 'iac/recipes/trading-schema.sql'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $LabRoot $path))) {
            throw "Incomplete Adaptive Apps package: missing '$path'. Package the entire MicroHack, including resources/ and iac/, not just labautomation/."
        }
    }
}
