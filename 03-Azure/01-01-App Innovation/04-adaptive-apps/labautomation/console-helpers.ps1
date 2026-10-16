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

function Install-AdaptiveJq {
    param([Parameter(Mandatory)][string]$BinDirectory)
    if (-not $IsLinux) { throw 'The Console jq bootstrap requires Linux.' }
    $version = '1.8.2'
    switch ([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()) {
        'X64' {
            $asset = 'jq-linux-amd64'
            $expectedHash = 'b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f'
        }
        'Arm64' {
            $asset = 'jq-linux-arm64'
            $expectedHash = '8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309'
        }
        default { throw "Unsupported jq bootstrap architecture: $([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)." }
    }
    New-Item -ItemType Directory -Path $BinDirectory -Force -ErrorAction Stop | Out-Null
    $download = Join-Path $BinDirectory ".jq-$([guid]::NewGuid().ToString('N'))"
    $target = Join-Path $BinDirectory 'jq'
    try {
        Invoke-WebRequest -Uri "https://github.com/jqlang/jq/releases/download/jq-$version/$asset" `
            -OutFile $download -TimeoutSec 60 -MaximumRetryCount 3 -RetryIntervalSec 2 -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256 -ErrorAction Stop).Hash -ne $expectedHash) {
            throw "SHA-256 verification failed for $asset (jq $version). The downloaded file will not run."
        }
        & chmod 700 $download
        if ($LASTEXITCODE -ne 0) { throw 'Unable to make the private jq binary executable.' }
        $installedVersion = & $download --version
        if ($LASTEXITCODE -ne 0 -or $installedVersion -cne "jq-$version") {
            throw "The verified jq $version binary failed its version check."
        }
        Move-Item -LiteralPath $download -Destination $target -Force -ErrorAction Stop
        Write-Host "Installed verified jq $version in the private Console tool directory."
    } finally {
        if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force -ErrorAction Stop }
    }
}

function Get-AdaptiveBootstrapFiles {
    @(
        'resources/install-console-tools.sh', 'resources/bootstrap-console.sh',
        'resources/azure-session.sh', 'resources/console-session.sh', 'resources/verify-recipes.sh',
        'resources/connect-console.sh', 'resources/prepare-k3s-azure-vm.sh',
        'resources/deploy-radius-aks.sh', 'resources/deploy-radius-k3s.sh',
        'resources/configure-resource-types-aks.sh', 'resources/configure-resource-types-k3s.sh',
        'resources/configure-recipes.sh', 'iac/bicepconfig.json',
        'iac/aks-env.bicep', 'iac/local-env.bicep', 'iac/sql-databases.yaml',
        'iac/recipes/postgres-azure-flex.bicep', 'iac/recipes/postgres-kubernetes.bicep',
        'iac/recipes/sql-server.bicep', 'iac/recipes/trading-schema.sql'
    )
}

function Assert-AdaptivePackage {
    param([Parameter(Mandatory)][string]$LabRoot)
    foreach ($path in Get-AdaptiveBootstrapFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $LabRoot $path))) {
            throw "Incomplete Adaptive Apps sources: missing '$path'. Verify the pinned source revision and refresh the Console content before retrying."
        }
    }
}

function Read-AdaptiveSourceManifest {
    param([Parameter(Mandatory)][string]$Path)
    $manifest = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    if ($manifest.commit -isnot [string] -or $manifest.commit -cnotmatch '^[0-9a-f]{40}$') {
        throw 'Bootstrap source must be pinned to a full, lowercase Git commit SHA; branches and tags are not accepted.'
    }
    $paths = @(Get-AdaptiveBootstrapFiles)
    if ($manifest.files -isnot [Collections.IDictionary] -or $manifest.files.Count -ne $paths.Count) {
        throw 'Bootstrap source manifest must contain exactly the required file allowlist.'
    }
    foreach ($path in $paths) {
        if ($manifest.files[$path] -isnot [string] -or $manifest.files[$path] -notmatch '^[0-9a-f]{64}$') {
            throw "Bootstrap source manifest is missing a valid SHA-256 hash for '$path'."
        }
    }
    return $manifest
}

function Save-AdaptiveSourceFile {
    param(
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Destination
    )
    if ($RelativePath -cnotin @(Get-AdaptiveBootstrapFiles)) {
        throw "Bootstrap download path '$RelativePath' is not allowlisted."
    }
    $repositoryPath = "03-Azure/01-01-App Innovation/04-adaptive-apps/$RelativePath"
    $encodedPath = ($repositoryPath.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    $uri = "https://raw.githubusercontent.com/microsoft/MicroHack/$Commit/$encodedPath"
    New-Item -ItemType Directory -Path (Split-Path $Destination -Parent) -Force -ErrorAction Stop | Out-Null
    try {
        Invoke-WebRequest -Uri $uri -OutFile $Destination -TimeoutSec 60 `
            -MaximumRetryCount 3 -RetryIntervalSec 2 -ErrorAction Stop
    } catch {
        throw "Unable to download '$RelativePath' at commit '$Commit': $($_.Exception.Message)"
    }
}

function Receive-AdaptiveBootstrap {
    param(
        [Parameter(Mandatory)][hashtable]$Manifest,
        [Parameter(Mandatory)][string]$Destination
    )
    foreach ($path in Get-AdaptiveBootstrapFiles) {
        $target = Join-Path $Destination $path
        Save-AdaptiveSourceFile -Commit $Manifest.commit -RelativePath $path -Destination $target
        $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256 -ErrorAction Stop).Hash
        if ($hash -ne $Manifest.files[$path]) {
            throw "SHA-256 verification failed for bootstrap file '$path' at commit '$($Manifest.commit)'. No bootstrap commands will run."
        }
    }
    Assert-AdaptivePackage -LabRoot $Destination
    Write-Host "Verified all $($Manifest.files.Count) bootstrap files from microsoft/MicroHack commit $($Manifest.commit)."
}
