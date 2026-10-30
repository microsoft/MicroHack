<#
.SYNOPSIS
    Lokaler Test des SQLModAI MicroHack in der eigenen MCAPS-Umgebung.

.DESCRIPTION
    1. Anmeldung an Az PowerShell, Azure CLI und (optional) Microsoft Graph am MCAPS-Tenant
    2. Auswahl der MCAPS-Subscription
    3. Anlage der Shared RG (rg_shared) und der Lab-RG für die Lab-VM in swedencentral
    4. Start von shared-deploy-lab.ps1 (optional danach deploy-lab.ps1, wie es die Plattform tut)
    Der lokale Graph-Login nutzt nur den Prozess-Cache, nicht den persistenten
    Graph-Benutzercache. Das Shared-Deployment verbindet Graph separat über Az.
    Vor einem erneuten lokalen Graph-Login wird eine vorhandene Graph-Sitzung
    getrennt, damit deren Access-Token nicht als MSAL-Cache eingelesen wird.
    -SkipGraphLogin überspringt nur diesen Login; das Shared-Deployment verwendet
    dann weiterhin ein über Az bezogenes Graph-Token.

.NOTES
    Im adminpwsh-Container aus dem labautomation-Ordner ausführen:

        cd <...>\03-Azure\01-02 Data\<SQLModAI>\labautomation
        docker run -it -v '.\:/app' --rm "ghcr.io/qxsch/adminpwsh:latest"
        cd /app
        ./Start-LocalLabTest.ps1 -TenantId <MCAPS-Tenant-ID>

    Beispiele:
        ./Start-LocalLabTest.ps1 -TenantId <id>                                  # nur Shared-Stage
        ./Start-LocalLabTest.ps1 -TenantId <id> -RunLabDeployment                # Shared + Lab-VM
        ./Start-LocalLabTest.ps1 -TenantId <id> -SubscriptionId <sub-id>         # Subscription direkt
#>
[CmdletBinding()]
param(
    # Tenant-ID (GUID) oder Domain des MCAPS-Tenants
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    # Direkt eine Subscription vorgeben – sonst wird nach dem Namensfilter gesucht
    [string]$SubscriptionId = '',

    # Namensfilter für die MCAPS-Subscription
    [string]$SubscriptionNameFilter = 'MCAP',

    [string]$Location = 'swedencentral',

    [string]$SharedResourceGroupName = 'rg-sqlhack-shared',

    # Resource Group für die Lab-VM (lokale Simulation der Teilnehmer-RG)
    [string]$LabResourceGroupName = 'rg_lab_local',

    # Separaten Graph-Login überspringen; Shared-Deployment nutzt dann ein Az-Graph-Token
    [switch]$SkipGraphLogin,

    # Nach erfolgreicher Shared-Stage auch deploy-lab.ps1 starten
    [switch]$RunLabDeployment
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }

function Confirm-ResourceGroup {
    param([string]$Name, [string]$Location)
    $rg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if ($rg) {
        Write-Host "    RG '$Name' existiert bereits ($($rg.Location)) - wird wiederverwendet." -ForegroundColor Yellow
    }
    else {
        New-AzResourceGroup -Name $Name -Location $Location | Out-Null
        Write-Host "    RG '$Name' in '$Location' angelegt." -ForegroundColor Green
    }
}

function Show-HackboxCredentials {
    param($Output, [string]$Stage)
    $creds = @($Output | Where-Object { $_ -is [hashtable] -and $_.ContainsKey('HackboxCredential') } |
               ForEach-Object { [pscustomobject]$_.HackboxCredential })
    if ($creds.Count -gt 0) {
        Write-Host "`n    HackboxCredentials aus $($Stage):" -ForegroundColor Green
        $creds | Format-Table name, value, note -AutoSize | Out-Host
    }
}

# ---------------------------------------------------------------------------
# 1) Az PowerShell
# ---------------------------------------------------------------------------
Write-Step "Anmeldung Az PowerShell am Tenant '$TenantId' (Device Code)"
Connect-AzAccount -Tenant $TenantId -UseDeviceAuthentication | Out-Null

# ---------------------------------------------------------------------------
# 2) MCAPS-Subscription auswählen
# ---------------------------------------------------------------------------
Write-Step 'Subscription auswählen'
if (-not $SubscriptionId) {
    $subs = @(Get-AzSubscription -TenantId $TenantId |
              Where-Object { $_.State -eq 'Enabled' -and $_.Name -like "*$SubscriptionNameFilter*" } |
              Sort-Object Name)

    if ($subs.Count -eq 0) {
        throw "Keine aktive Subscription mit '$SubscriptionNameFilter' im Namen gefunden. Mit -SubscriptionId oder -SubscriptionNameFilter angeben."
    }
    elseif ($subs.Count -eq 1) {
        $selected = $subs[0]
    }
    else {
        for ($i = 0; $i -lt $subs.Count; $i++) {
            Write-Host ("    [{0}] {1}  ({2})" -f $i, $subs[$i].Name, $subs[$i].Id)
        }
        do {
            $choice = Read-Host '    Nummer der Subscription'
        } until ($choice -match '^\d+$' -and [int]$choice -lt $subs.Count)
        $selected = $subs[[int]$choice]
    }
    $SubscriptionId = $selected.Id
}

Set-AzContext -Tenant $TenantId -Subscription $SubscriptionId | Out-Null
$ctx = Get-AzContext
Write-Host "    Subscription: $($ctx.Subscription.Name) ($($ctx.Subscription.Id))" -ForegroundColor Green
Write-Host "    Konto:        $($ctx.Account.Id)"
Write-Host "    Location:     $Location"

# ---------------------------------------------------------------------------
# 3) Azure CLI (wird von az-Aufrufen in den Skripten genutzt)
# ---------------------------------------------------------------------------
Write-Step 'Anmeldung Azure CLI (Device Code)'
az login --tenant $TenantId --use-device-code --output none
if ($LASTEXITCODE -ne 0) { throw 'az login fehlgeschlagen.' }
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw 'az account set fehlgeschlagen.' }

# ---------------------------------------------------------------------------
# 4) Microsoft Graph (für Directory Readers der SQL MI)
# ---------------------------------------------------------------------------
if (-not $SkipGraphLogin) {
    Write-Step 'Anmeldung Microsoft Graph (Device Code)'
    # Das Shared-Deployment hinterlaesst ein Access-Token im Graph-Prozess-Cache, kein MSAL-JSON.
    if (Get-MgContext) {
        Write-Host '    Vorhandene Graph-Sitzung und Prozess-Cache werden zurueckgesetzt.'
        Disconnect-MgGraph -ErrorAction Stop | Out-Null
    }
    Connect-MgGraph -TenantId $TenantId -UseDeviceCode -NoWelcome `
        -ContextScope Process -Scopes 'Application.Read.All', 'RoleManagement.ReadWrite.Directory'
    Write-Host "    Graph verbunden als $((Get-MgContext).Account)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 5) Resource Groups anlegen
# ---------------------------------------------------------------------------
Write-Step 'Resource Groups prüfen / anlegen'
Confirm-ResourceGroup -Name $SharedResourceGroupName -Location $Location
Confirm-ResourceGroup -Name $LabResourceGroupName    -Location $Location

$me = (Get-AzADUser -SignedIn).Id
Write-Host "    AllowedEntraUserIds: $me"

# ---------------------------------------------------------------------------
# 6) shared-deploy-lab.ps1 starten
# ---------------------------------------------------------------------------
$sharedScript = Join-Path $PSScriptRoot 'shared-deploy-lab.ps1'
if (-not (Test-Path $sharedScript)) { throw "shared-deploy-lab.ps1 nicht gefunden in '$PSScriptRoot'." }

if (-not (Select-String -Path $sharedScript -SimpleMatch $SharedResourceGroupName -Quiet)) {
    Write-Warning "Der Name '$SharedResourceGroupName' kommt in shared-deploy-lab.ps1 nicht vor. Bitte dort `$sharedResourceGroup anpassen, sonst wird eine andere RG verwendet."
}

Write-Step 'Starte shared-deploy-lab.ps1'
$sharedOutput = & $sharedScript `
    -SubscriptionId      $SubscriptionId `
    -PreferredLocation   $Location `
    -AllowedEntraUserIds $me
Show-HackboxCredentials -Output $sharedOutput -Stage 'shared-deploy-lab.ps1'
Write-Host '    Shared-Stage abgeschlossen.' -ForegroundColor Green

# ---------------------------------------------------------------------------
# 7) Optional: deploy-lab.ps1 für die Lab-VM
# ---------------------------------------------------------------------------
if ($RunLabDeployment) {
    $labScript = Join-Path $PSScriptRoot 'deploy-lab.ps1'
    if (-not (Test-Path $labScript)) { throw "deploy-lab.ps1 nicht gefunden in '$PSScriptRoot'." }

    Write-Step "Starte deploy-lab.ps1 in '$LabResourceGroupName'"
    $labOutput = & $labScript `
        -DeploymentType      'resourcegroup' `
        -SubscriptionId      $SubscriptionId `
        -ResourceGroupName   $LabResourceGroupName `
        -PreferredLocation   $Location `
        -AllowedEntraUserIds $me
    Show-HackboxCredentials -Output $labOutput -Stage 'deploy-lab.ps1'
    Write-Host '    Lab-Deployment abgeschlossen.' -ForegroundColor Green
}
else {
    Write-Host "`nLab-VM noch nicht deployt. Mit -RunLabDeployment wird deploy-lab.ps1 in '$LabResourceGroupName' gestartet." -ForegroundColor Yellow
}
