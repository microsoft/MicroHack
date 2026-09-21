<#
.SYNOPSIS
    Build and deploy the Visual Attestation Demo v2 web UI to Azure Container Instances.

.DESCRIPTION
    Builds the container image SERVER-SIDE in Azure Container Registry via
    `az acr build` (no local Docker required), then deploys the resulting image
    to Azure Container Instances on either the Confidential SKU (AMD SEV-SNP,
    attestation succeeds) or Standard SKU (no TEE, attestation fails - shown
    for educational comparison).

.PARAMETER Build
    Create resource group, ACR, and run `az acr build` to produce the image.

.PARAMETER Deploy
    Deploy a single container group. Confidential by default. Pass -NoAcc to
    deploy on Standard SKU instead (so you can see attestation fail).

.PARAMETER Compare
    Deploy BOTH a confidential and a standard container side-by-side using
    the already-built image. Confidential requires Docker + the confcom CLI
    extension on the local machine for CCE policy generation.

.PARAMETER Cleanup
    Delete the entire resource group created by -Build.

.PARAMETER NoAcc
    With -Deploy: use the Standard SKU template (attestation will fail).

.PARAMETER SkipBrowser
    Don't auto-open Edge after a successful deploy.

.PARAMETER RegistryName
    Optional ACR name to reuse. If omitted, a random name is generated and
    persisted to acr-config.json.

.PARAMETER Location
    Azure region. Defaults to eastus (matches confidential ACI availability).

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
    [Parameter(ParameterSetName='Build')]   [string]$Prefix = 'sgall',
    [string]$Location = 'eastus'
)

# UTF-8 console for nicer output on Windows
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Stop'

$ImageName  = 'cc-attest'
$ImageTag   = '1.0'
$ConfigPath = Join-Path $PSScriptRoot 'acr-config.json'

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

    if (-not $RegistryName) {
        $rand = -join ((97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })
        $RegistryName = "acr$rand"
        Write-Warn2 "No -RegistryName given. Generated: $RegistryName"
    }
    $ResourceGroup = "$Prefix-$RegistryName-rg"

    Write-Host "Resource Group: $ResourceGroup"
    Write-Host "Registry      : $RegistryName"
    Write-Host "Location      : $Location"
    Write-Host "Image         : ${ImageName}:${ImageTag}"
    Write-Host ""

    Write-Host "Creating resource group..."
    az group create --name $ResourceGroup --location $Location | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "az group create failed" }

    Write-Host "Creating ACR (Basic, admin user enabled)..."
    az acr create --resource-group $ResourceGroup --name $RegistryName --sku Basic --admin-enabled true | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "az acr create failed" }

    Write-Host "Running az acr build (server-side Docker build, no local daemon needed)..."
    Write-Host "This typically takes 4-6 minutes (apt-get + cvm-attestation-tools clone + pip install)..."
    az acr build --registry $RegistryName --image "${ImageName}:${ImageTag}" --file Dockerfile --no-logs $PSScriptRoot
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
    $stamp = Get-Date -Format 'MMddHHmm'
    $rand  = -join ((97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })

    if ($NoAcc) {
        Write-Warn2 "*** Standard SKU mode - no TEE, no vTPM, attestation WILL fail ***"
        $name     = "cc-attest-std-$stamp$rand"
        $dns      = "cc-attest-std-$stamp$rand"
        $template = Join-Path $PSScriptRoot 'deployment-template-standard.json'
        $params   = Join-Path $PSScriptRoot 'deployment-params-standard.json'
        New-ParamsFile -Path $params -Name $name -Image $cfg.fullImage `
            -Server $cfg.loginServer -User $creds.Username -Pass $creds.Password -Dns $dns
    }
    else {
        Test-ConfidentialPrereqs
        Invoke-AcrLoginForConfcom $cfg $creds

        $name     = "cc-attest-conf-$stamp$rand"
        $dns      = "cc-attest-conf-$stamp$rand"
        $template = Join-Path $PSScriptRoot 'deployment-template-confidential.json'
        $params   = Join-Path $PSScriptRoot 'deployment-params-confidential.json'
        New-ParamsFile -Path $params -Name $name -Image $cfg.fullImage `
            -Server $cfg.loginServer -User $creds.Username -Pass $creds.Password -Dns $dns

        Write-Host "Generating CCE policy via 'az confcom acipolicygen' (this can take a few minutes)..."
        az confcom acipolicygen -a $template --parameters $params --disable-stdio
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

    $stamp = Get-Date -Format 'MMddHHmm'
    $name_conf = "cc-attest-conf-$stamp"
    $name_std  = "cc-attest-std-$stamp"
    $dns_conf  = "cc-attest-conf-$stamp"
    $dns_std   = "cc-attest-std-$stamp"

    $tpl_conf  = Join-Path $PSScriptRoot 'deployment-template-confidential.json'
    $tpl_std   = Join-Path $PSScriptRoot 'deployment-template-standard.json'
    $par_conf  = Join-Path $PSScriptRoot 'deployment-params-confidential.json'
    $par_std   = Join-Path $PSScriptRoot 'deployment-params-standard.json'

    New-ParamsFile -Path $par_conf -Name $name_conf -Image $cfg.fullImage `
        -Server $cfg.loginServer -User $creds.Username -Pass $creds.Password -Dns $dns_conf
    New-ParamsFile -Path $par_std  -Name $name_std  -Image $cfg.fullImage `
        -Server $cfg.loginServer -User $creds.Username -Pass $creds.Password -Dns $dns_std

    Write-Host "Generating CCE policy for confidential container..."
    az confcom acipolicygen -a $tpl_conf --parameters $par_conf --disable-stdio
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

    Write-Warn2 "About to DELETE resource group: $($cfg.resourceGroup)"
    Write-Warn2 "This removes the ACR, the image, and all container groups in that RG."
    $confirm = Read-Host "Type the resource group name to confirm"
    if ($confirm -ne $cfg.resourceGroup) {
        Write-Host "Cancelled."
        return
    }
    az group delete --name $cfg.resourceGroup --yes --no-wait
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Delete submitted (running in background)."
        Remove-Item $ConfigPath -Force -ErrorAction SilentlyContinue
        Get-ChildItem $PSScriptRoot -Filter 'deployment-params-*.json' -ErrorAction SilentlyContinue | Remove-Item -Force
    } else {
        throw "az group delete failed"
    }
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
