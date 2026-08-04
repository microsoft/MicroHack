<#
.SYNOPSIS
    Build and deploy the Visual Attestation Demo v2 web UI to Azure Container Instances.

.DESCRIPTION
    Builds the container image SERVER-SIDE in Azure Container Registry via
    `az acr build` (no local Docker required), then deploys the resulting image
    to Azure Container Instances on either the Confidential SKU (AMD SEV-SNP,
    attestation succeeds) or Standard SKU (no TEE, attestation fails - shown
    for educational comparison). This MicroHack adaptation reuses the attendee
    resource group and removes only resources created by this challenge.

.PARAMETER Build
    Create an ACR in the existing attendee resource group and run `az acr build`
    to produce the image. Run -Cleanup before repeating a completed or failed
    Challenge 4 run with the same workshop values.

.PARAMETER Deploy
    Deploy a single container group. Confidential by default. Pass -NoAcc to
    deploy on Standard SKU instead (so you can see attestation fail).

.PARAMETER Compare
    Deploy BOTH a confidential and a standard container side-by-side using
    the already-built image. Confidential requires Docker + the confcom CLI
    extension on the local machine for CCE policy generation.

.PARAMETER Cleanup
    Delete the two challenge container groups, ACR, generated state, and tagged
    local Docker image. Retain the attendee resource group and resources created
    by other challenges.

.PARAMETER NoAcc
    With -Deploy: use the Standard SKU template (attestation will fail).

.PARAMETER SkipBrowser
    Don't auto-open Edge after a successful deploy.

.PARAMETER RegistryName
    Optional ACR name to reuse. If omitted, a deterministic name is generated
    from HASH_SUFFIX and persisted to acr-config.json.

.PARAMETER ResourceGroup
    Existing attendee resource group. Defaults to RESOURCE_GROUP.

.PARAMETER AttendeeId
    Attendee identifier used for resource tags. Defaults to ATTENDEE_ID.

.PARAMETER HashSuffix
    Stable suffix used for challenge resource names. Defaults to HASH_SUFFIX.

.PARAMETER Location
    Azure region. Defaults to LOCATION.

.EXAMPLE
    # Build the image once, deploy to Confidential ACI (attestation succeeds)
    ./Deploy-VisualAttestationV2.ps1 -Build
    ./Deploy-VisualAttestationV2.ps1 -Deploy

.EXAMPLE
    # Same image, deploy to Standard ACI (attestation FAILS - educational)
    ./Deploy-VisualAttestationV2.ps1 -Deploy -NoAcc

.EXAMPLE
    # Side-by-side comparison
    ./Deploy-VisualAttestationV2.ps1 -Compare

.EXAMPLE
    ./Deploy-VisualAttestationV2.ps1 -Cleanup
#>
[CmdletBinding(DefaultParameterSetName='Help')]
param(
    [Parameter(ParameterSetName='Build')]   [switch]$Build,
    [Parameter(ParameterSetName='Deploy')]  [switch]$Deploy,
    [Parameter(ParameterSetName='Compare')] [switch]$Compare,
    [Parameter(ParameterSetName='Cleanup')] [switch]$Cleanup,

    [Parameter(ParameterSetName='Deploy')]  [switch]$NoAcc,
    [Parameter(ParameterSetName='Deploy')]
    [Parameter(ParameterSetName='Compare')] [switch]$SkipBrowser,

    [Parameter(ParameterSetName='Build')]   [string]$RegistryName,
    [Parameter(ParameterSetName='Build')]   [string]$ResourceGroup = $env:RESOURCE_GROUP,
    [Parameter(ParameterSetName='Build')]   [string]$AttendeeId = $env:ATTENDEE_ID,
    [Parameter(ParameterSetName='Build')]   [string]$HashSuffix = $env:HASH_SUFFIX,
    [string]$Location = $env:LOCATION
)

# UTF-8 console for nicer output on Windows
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Stop'

$ImageName  = 'cc-attest'
$ImageTag   = '1.0'
$ConfigPath = Join-Path $PSScriptRoot 'acr-config.json'
$SampleDirectory = Join-Path $PSScriptRoot 'resources/visual-attestation-demo-v2'

# ============================================================================
# Helpers
# ============================================================================
function Write-Header   { param($m) Write-Host ""; Write-Host ("=" * 72) -ForegroundColor Cyan; Write-Host $m -ForegroundColor Cyan; Write-Host ("=" * 72) -ForegroundColor Cyan }
function Write-Success  { param($m) Write-Host "[OK]    $m" -ForegroundColor Green }
function Write-Warn2    { param($m) Write-Host "[WARN]  $m" -ForegroundColor Yellow }
function Write-Err2     { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }

function Get-Config {
    if (-not (Test-Path $ConfigPath)) { return $null }
    return Get-Content $ConfigPath -Raw | ConvertFrom-Json
}
function Save-Config { param($cfg) $cfg | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8 }

function Test-AzCli {
    $v = az version 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Azure CLI not found. Install from https://aka.ms/azcli" }
    $acct = az account show 2>$null | ConvertFrom-Json
    if (-not $acct) { throw "Not logged in. Run: az login" }
    Write-Host "Subscription: $($acct.name) ($($acct.id))"
}

# ============================================================================
# Build phase
# ============================================================================
function Invoke-Build {
    Write-Header "Build phase - creating ACR and building image server-side"
    Test-AzCli

    if (Test-Path $ConfigPath) {
        throw "An existing Challenge 4 deployment is recorded. Run .\Deploy-VisualAttestationV2.ps1 -Cleanup before rebuilding."
    }

    foreach ($requiredValue in @{
            RESOURCE_GROUP = $ResourceGroup
            ATTENDEE_ID = $AttendeeId
            HASH_SUFFIX = $HashSuffix
            LOCATION = $Location
        }.GetEnumerator()) {
        if ([string]::IsNullOrWhiteSpace($requiredValue.Value)) {
            throw "$($requiredValue.Key) is not set. Define the MicroHack environment variables before running -Build."
        }
    }

    $nameSuffix = (($HashSuffix -replace '[^a-zA-Z0-9]', '').ToLowerInvariant())
    if ($nameSuffix.Length -gt 10) { $nameSuffix = $nameSuffix.Substring(0, 10) }
    if (-not $nameSuffix) { throw 'HASH_SUFFIX must contain at least one letter or number.' }

    if (-not $RegistryName) {
        $RegistryName = "ccattest$nameSuffix"
    }

    Write-Host "Resource Group: $ResourceGroup"
    Write-Host "Registry      : $RegistryName"
    Write-Host "Location      : $Location"
    Write-Host "Image         : ${ImageName}:${ImageTag}"
    Write-Host ""

    Write-Host "Checking existing attendee resource group..."
    az group show --name $ResourceGroup | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Resource group '$ResourceGroup' was not found" }

    Write-Host "Creating ACR (Basic, admin user enabled)..."
    az acr create --resource-group $ResourceGroup --name $RegistryName --location $Location `
        --sku Basic --admin-enabled true --tags "AttendeeId=$AttendeeId" "Challenge=04" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "az acr create failed" }

    Write-Host "Running az acr build (server-side Docker build, no local daemon needed)..."
    Write-Host "This typically takes 4-6 minutes (apt-get + cvm-attestation-tools clone + pip install)..."
    az acr build --registry $RegistryName --image "${ImageName}:${ImageTag}" `
        --file (Join-Path $SampleDirectory 'Dockerfile') --no-logs $SampleDirectory
    if ($LASTEXITCODE -ne 0) {
        # Verify the image actually exists - some az acr build calls return non-zero on warnings
        az acr repository show --name $RegistryName --image "${ImageName}:${ImageTag}" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "az acr build failed" }
    }
    Write-Success "Image built and pushed to ACR"

    $loginServer = az acr show --name $RegistryName --query loginServer -o tsv
    $cfg = [pscustomobject]@{
        registryName  = $RegistryName
        resourceGroup = $ResourceGroup
        location      = $Location
        loginServer   = $loginServer
        imageName     = $ImageName
        imageTag      = $ImageTag
        fullImage     = "$loginServer/${ImageName}:${ImageTag}"
        nameSuffix    = $nameSuffix
        attendeeId    = $AttendeeId
    }
    Save-Config $cfg

    Write-Header "Build complete"
    Write-Host "Image: $($cfg.fullImage)"
    Write-Host "Config saved to: $ConfigPath"
    Write-Host ""
    Write-Host "Next step:"
    Write-Host "  ./Deploy-VisualAttestationV2.ps1 -Deploy           # Confidential SKU"
    Write-Host "  ./Deploy-VisualAttestationV2.ps1 -Deploy -NoAcc    # Standard SKU"
    Write-Host "  ./Deploy-VisualAttestationV2.ps1 -Compare          # both side-by-side"
}

# ============================================================================
# Deploy helpers
# ============================================================================
function Get-AcrCreds {
    param($cfg)
    $u = az acr credential show --name $cfg.registryName --query username -o tsv
    $p = az acr credential show --name $cfg.registryName --query "passwords[0].value" -o tsv
    if (-not $u -or -not $p) { throw "Failed to read ACR credentials" }
    return @{ Username = $u; Password = $p }
}

function New-ParamsFile {
    param($Path, $Name, $Image, $Server, $User, $Pass, $Dns)
    $obj = @{
        '$schema'        = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        'contentVersion' = '1.0.0.0'
        'parameters'     = @{
            containerGroupName = @{ value = $Name }
            location           = @{ value = $Location }
            appImage           = @{ value = $Image }
            registryServer     = @{ value = $Server }
            registryUsername   = @{ value = $User }
            registryPassword   = @{ value = $Pass }
            dnsNameLabel       = @{ value = $Dns }
        }
    }
    $obj | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
}

function Invoke-AcrLoginForConfcom {
    param($cfg, $creds)
    Write-Host "Logging into ACR (required for confcom CCE policy generation)..."
    az acr login --name $cfg.loginServer --username $creds.Username --password $creds.Password 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        docker login $cfg.loginServer -u $creds.Username -p $creds.Password 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "ACR login failed" }
    }
}

function Test-ConfidentialPrereqs {
    Write-Host "Checking prerequisites for Confidential ACI deploy..."
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker is not running. Required by 'az confcom acipolicygen' for CCE policy generation. Start Docker Desktop, or pass -NoAcc to deploy on Standard SKU."
    }
    az extension show -n confcom 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing 'confcom' Azure CLI extension..."
        az extension add -n confcom | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to install confcom extension" }
    }
    Write-Success "Docker running, confcom extension installed"
}

function Wait-ForContainer {
    param($Fqdn, $TimeoutSec = 240)
    Write-Host "Waiting for http://$Fqdn (timeout ${TimeoutSec}s)..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
        try {
            $r = Invoke-WebRequest -Uri "http://$Fqdn" -Method Head -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($r.StatusCode -eq 200) { Write-Success "Container responding"; return $true }
        } catch { }
        Start-Sleep -Seconds 5
        Write-Host ("  ... {0:n0}s elapsed" -f $sw.Elapsed.TotalSeconds)
    }
    Write-Warn2 "Container did not respond within ${TimeoutSec}s. It may still be pulling the image - try the URL in a browser."
    return $false
}

function New-ComparePage {
        param(
                [string]$ConfidentialUrl,
                [string]$StandardUrl,
                [string]$OutputPath
        )

        $html = @"
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>ACI Attestation Compare</title>
    <style>
        :root {
            --bg: #0b1020;
            --panel: #131a2f;
            --text: #f3f6ff;
            --muted: #9fb0d3;
            --ok: #2ac769;
            --warn: #ffb020;
            --border: #2a3558;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: Segoe UI, Helvetica, Arial, sans-serif;
            background: radial-gradient(1200px 500px at 20% -10%, #1f2a4a 0%, var(--bg) 60%);
            color: var(--text);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        header {
            padding: 12px 16px;
            border-bottom: 1px solid var(--border);
            background: rgba(11, 16, 32, 0.8);
            backdrop-filter: blur(6px);
        }
        h1 {
            margin: 0 0 6px 0;
            font-size: 18px;
            font-weight: 700;
        }
        .meta {
            color: var(--muted);
            font-size: 13px;
            display: flex;
            gap: 14px;
            flex-wrap: wrap;
        }
        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            padding: 12px;
            flex: 1;
            min-height: 0;
        }
        .card {
            background: var(--panel);
            border: 1px solid var(--border);
            border-radius: 10px;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            min-height: 0;
        }
        .bar {
            padding: 10px 12px;
            border-bottom: 1px solid var(--border);
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 8px;
            font-size: 13px;
        }
        .bar .left {
            font-weight: 700;
        }
        .pill {
            display: inline-block;
            border-radius: 999px;
            padding: 2px 8px;
            font-size: 12px;
            font-weight: 700;
        }
        .pill.ok {
            background: rgba(42, 199, 105, 0.18);
            color: var(--ok);
            border: 1px solid rgba(42, 199, 105, 0.35);
        }
        .pill.warn {
            background: rgba(255, 176, 32, 0.18);
            color: var(--warn);
            border: 1px solid rgba(255, 176, 32, 0.35);
        }
        iframe {
            border: 0;
            width: 100%;
            flex: 1;
            min-height: 0;
            background: #fff;
        }
        @media (max-width: 1100px) {
            .grid { grid-template-columns: 1fr; }
            .card { min-height: 55vh; }
        }
    </style>
</head>
<body>
    <header>
        <h1>ACI Runtime Attestation Compare</h1>
        <div class="meta">
            <span>Left: Confidential SKU (expected attestation success)</span>
            <span>Right: Standard SKU (expected attestation failure)</span>
        </div>
    </header>

    <main class="grid">
        <section class="card">
            <div class="bar">
                <div class="left">Confidential</div>
                <div>
                    <span class="pill ok">SEV-SNP expected</span>
                    <span>$ConfidentialUrl</span>
                </div>
            </div>
            <iframe src="$ConfidentialUrl" title="Confidential ACI"></iframe>
        </section>

        <section class="card">
            <div class="bar">
                <div class="left">Standard</div>
                <div>
                    <span class="pill warn">Expected /dev/sev-guest missing</span>
                    <span>$StandardUrl</span>
                </div>
            </div>
            <iframe src="$StandardUrl" title="Standard ACI"></iframe>
        </section>
    </main>
</body>
</html>
"@

        Set-Content -Path $OutputPath -Value $html -Encoding UTF8
}

# ============================================================================
# Deploy phase (single container group)
# ============================================================================
function Invoke-Deploy {
    if ($NoAcc) { Write-Header "Deploy phase - STANDARD SKU (attestation will FAIL)" }
    else        { Write-Header "Deploy phase - CONFIDENTIAL SKU (AMD SEV-SNP)" }
    Test-AzCli

    $cfg = Get-Config
    if (-not $cfg) { throw "acr-config.json not found. Run with -Build first." }

    $creds = Get-AcrCreds $cfg
    $skuName = if ($NoAcc) { 'standard' } else { 'confidential' }
    $workDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "microhack-ch04-$($cfg.nameSuffix)-$skuName"
    New-Item -ItemType Directory -Path $workDirectory -Force | Out-Null
    $template = Join-Path $workDirectory 'template.json'
    $params = Join-Path $workDirectory 'parameters.json'

    if ($NoAcc) {
        Write-Warn2 "*** Standard SKU mode - no TEE, no vTPM, attestation WILL fail ***"
        $name = "cc-attest-std-$($cfg.nameSuffix)"
        $dns = $name
        Copy-Item (Join-Path $SampleDirectory 'deployment-template-standard.json') $template -Force
        New-ParamsFile -Path $params -Name $name -Image $cfg.fullImage `
            -Server $cfg.loginServer -User $creds.Username -Pass $creds.Password -Dns $dns
    }
    else {
        Test-ConfidentialPrereqs
        Invoke-AcrLoginForConfcom $cfg $creds

        $name = "cc-attest-conf-$($cfg.nameSuffix)"
        $dns = $name
        Copy-Item (Join-Path $SampleDirectory 'deployment-template-confidential.json') $template -Force
        New-ParamsFile -Path $params -Name $name -Image $cfg.fullImage `
            -Server $cfg.loginServer -User $creds.Username -Pass $creds.Password -Dns $dns

        $templateJson = Get-Content $template -Raw | ConvertFrom-Json
        $containerGroup = @($templateJson.resources | Where-Object { $_.type -eq 'Microsoft.ContainerInstance/containerGroups' })[0]
        $containerGroup.properties.confidentialComputeProperties.ccePolicy = ''
        $templateJson | ConvertTo-Json -Depth 100 | Set-Content $template -Encoding UTF8

        Write-Host "Generating CCE policy via 'az confcom acipolicygen' (this can take a few minutes)..."
        az confcom acipolicygen -a $template --parameters $params --disable-stdio --approve-wildcards
        if ($LASTEXITCODE -ne 0) { throw "az confcom acipolicygen failed" }
        Write-Success "CCE policy injected into $template"
    }

    Write-Host "Container group: $name"
    Write-Host "DNS label      : $dns"
    Write-Host "Image          : $($cfg.fullImage)"
    Write-Host ""

    Write-Host "Submitting ARM deployment..."
    az deployment group create `
        --resource-group $cfg.resourceGroup `
        --template-file $template `
        --parameters "@$params" `
        --query "properties.outputs.fqdn.value" -o tsv | Tee-Object -Variable fqdn | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "az deployment group create failed" }
    Write-Success "Deployed: http://$fqdn"

    Wait-ForContainer -Fqdn $fqdn | Out-Null

    if ($NoAcc) {
        Write-Header "Diagnostics (Standard SKU - attestation expected to fail)"
        Write-Host "Last 25 lines of container logs:"
        az container logs --resource-group $cfg.resourceGroup --name $name --container-name cc-attest 2>&1 |
            Select-Object -Last 25 | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        Write-Host "Click the 'Run Attestation' button in the UI - it will return an error explaining"
        Write-Host "that no vTPM / no SEV-SNP hardware report is available on Standard SKU."
    }

    if (-not $SkipBrowser) {
        Start-Process "http://$fqdn"
    }

    Write-Host ""
    Write-Host "To view logs:    az container logs -g $($cfg.resourceGroup) -n $name --container-name cc-attest"
    Write-Host "To delete:       az container delete -g $($cfg.resourceGroup) -n $name --yes"
}

# ============================================================================
# Compare phase (both side-by-side)
# ============================================================================
function Invoke-Compare {
    Write-Header "Compare phase - Confidential AND Standard side-by-side"
    Test-AzCli

    $cfg = Get-Config
    if (-not $cfg) { throw "acr-config.json not found. Run with -Build first." }

    Test-ConfidentialPrereqs
    $creds = Get-AcrCreds $cfg
    Invoke-AcrLoginForConfcom $cfg $creds

    $name_conf = "cc-attest-conf-$($cfg.nameSuffix)"
    $name_std  = "cc-attest-std-$($cfg.nameSuffix)"
    $dns_conf  = $name_conf
    $dns_std   = $name_std

    $workDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "microhack-ch04-$($cfg.nameSuffix)-compare"
    New-Item -ItemType Directory -Path $workDirectory -Force | Out-Null
    $tpl_conf = Join-Path $workDirectory 'template-confidential.json'
    $tpl_std = Join-Path $workDirectory 'template-standard.json'
    $par_conf = Join-Path $workDirectory 'parameters-confidential.json'
    $par_std = Join-Path $workDirectory 'parameters-standard.json'
    Copy-Item (Join-Path $SampleDirectory 'deployment-template-confidential.json') $tpl_conf -Force
    Copy-Item (Join-Path $SampleDirectory 'deployment-template-standard.json') $tpl_std -Force

    New-ParamsFile -Path $par_conf -Name $name_conf -Image $cfg.fullImage `
        -Server $cfg.loginServer -User $creds.Username -Pass $creds.Password -Dns $dns_conf
    New-ParamsFile -Path $par_std  -Name $name_std  -Image $cfg.fullImage `
        -Server $cfg.loginServer -User $creds.Username -Pass $creds.Password -Dns $dns_std

    $templateJson = Get-Content $tpl_conf -Raw | ConvertFrom-Json
    $containerGroup = @($templateJson.resources | Where-Object { $_.type -eq 'Microsoft.ContainerInstance/containerGroups' })[0]
    $containerGroup.properties.confidentialComputeProperties.ccePolicy = ''
    $templateJson | ConvertTo-Json -Depth 100 | Set-Content $tpl_conf -Encoding UTF8

    Write-Host "Generating CCE policy for confidential container..."
    az confcom acipolicygen -a $tpl_conf --parameters $par_conf --disable-stdio --approve-wildcards
    if ($LASTEXITCODE -ne 0) { throw "az confcom acipolicygen failed" }
    Write-Success "CCE policy generated"

    Write-Header "Deploying CONFIDENTIAL container ($name_conf)"
    az deployment group create --resource-group $cfg.resourceGroup `
        --template-file $tpl_conf --parameters "@$par_conf" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Confidential deploy failed" }
    $fqdn_conf = az container show -g $cfg.resourceGroup -n $name_conf --query "ipAddress.fqdn" -o tsv
    Write-Success "Confidential: http://$fqdn_conf"

    Write-Header "Deploying STANDARD container ($name_std)"
    az deployment group create --resource-group $cfg.resourceGroup `
        --template-file $tpl_std --parameters "@$par_std" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Standard deploy failed" }
    $fqdn_std = az container show -g $cfg.resourceGroup -n $name_std --query "ipAddress.fqdn" -o tsv
    Write-Success "Standard    : http://$fqdn_std"

    Write-Host ""
    Write-Host "Waiting for both containers to come up..."
    Wait-ForContainer -Fqdn $fqdn_conf | Out-Null
    Wait-ForContainer -Fqdn $fqdn_std  | Out-Null

    Write-Header "Both containers deployed"

    # Retrieve SKU info
    $confSku = az container show -g $cfg.resourceGroup -n $name_conf --query "sku" -o tsv
    $stdSku  = az container show -g $cfg.resourceGroup -n $name_std  --query "sku" -o tsv

    # Output summary table
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗"
    Write-Host "║ Compare Deployment Summary                                    ║"
    Write-Host "╠════════════════════════════════════════════════════════════════╣"
    Write-Host "║ Confidential SKU (Attestation succeeds)                        ║"
    Write-Host "║   SKU: $($confSku.PadRight(54)) ║"
    Write-Host "║   URL: http://$($fqdn_conf.PadRight(49)) ║"
    Write-Host "╠════════════════════════════════════════════════════════════════╣"
    Write-Host "║ Standard SKU (Attestation FAILS)                              ║"
    Write-Host "║   SKU: $($stdSku.PadRight(54)) ║"
    Write-Host "║   URL: http://$($fqdn_std.PadRight(49)) ║"
    Write-Host "╚════════════════════════════════════════════════════════════════╝"
    Write-Host ""
    Write-Host "Click 'Attest' on each pane to see the difference:"
    Write-Host "  • Confidential: Hardware-rooted SEV-SNP attestation succeeds"
    Write-Host "  • Standard:     Attestation fails (no /dev/sev-guest)"
    Write-Host ""

    if (-not $SkipBrowser) {
        $confUrl = "http://$fqdn_conf"
        $stdUrl = "http://$fqdn_std"
        $comparePage = Join-Path $PSScriptRoot 'side-by-side-compare.html'
        New-ComparePage -ConfidentialUrl $confUrl -StandardUrl $stdUrl -OutputPath $comparePage
        Write-Success "Generated: $comparePage"
        Write-Host "Opening in new browser window..."
        Start-Process $comparePage
    }
}

# ============================================================================
# Cleanup phase
# ============================================================================
function Invoke-Cleanup {
    Write-Header "Cleanup phase"
    $cfg = Get-Config
    if (-not $cfg) { Write-Warn2 "No acr-config.json - nothing to delete."; return }

    Write-Warn2 "Removing Challenge 4 resources from '$($cfg.resourceGroup)'."
    foreach ($containerName in @("cc-attest-conf-$($cfg.nameSuffix)", "cc-attest-std-$($cfg.nameSuffix)")) {
        az container show --resource-group $cfg.resourceGroup --name $containerName 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            az container delete --resource-group $cfg.resourceGroup --name $containerName --yes | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Failed to delete container group '$containerName'" }
            Write-Success "Deleted container group: $containerName"
        }
    }

    az acr show --resource-group $cfg.resourceGroup --name $cfg.registryName 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        az acr delete --resource-group $cfg.resourceGroup --name $cfg.registryName --yes | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to delete ACR '$($cfg.registryName)'" }
        Write-Success "Deleted ACR: $($cfg.registryName)"
    }

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        docker image rm $cfg.fullImage 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Success "Removed local image: $($cfg.fullImage)" }
    }

    Remove-Item $ConfigPath -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $PSScriptRoot 'side-by-side-compare.html') -Force -ErrorAction SilentlyContinue
    Get-ChildItem ([System.IO.Path]::GetTempPath()) -Directory -Filter "microhack-ch04-$($cfg.nameSuffix)-*" -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Success "Cleanup complete. Resource group '$($cfg.resourceGroup)' was retained."
}

# ============================================================================
# Main
# ============================================================================
switch ($PSCmdlet.ParameterSetName) {
    'Build'   { Invoke-Build   }
    'Deploy'  { Invoke-Deploy  }
    'Compare' { Invoke-Compare }
    'Cleanup' { Invoke-Cleanup }
    default {
        Get-Help $PSCommandPath -Detailed
    }
}
