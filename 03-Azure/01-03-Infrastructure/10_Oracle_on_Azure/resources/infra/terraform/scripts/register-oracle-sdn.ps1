<#
.SYNOPSIS
Registers the Oracle SDN appliance preview features and re-registers resource providers
for a list of subscriptions.

.DESCRIPTION
This script ensures that each target subscription has the
EnableRotterdamSdnApplianceForOracle feature enabled for both
Microsoft.Baremetal and Microsoft.Network namespaces. It waits for feature
registration to complete before re-registering the providers, following Azure
preview feature best practices.

.PARAMETER Subscriptions
Array of subscription IDs to process.

.EXAMPLE
PS> ./register-oracle-sdn.ps1

.EXAMPLE
PS> ./register-oracle-sdn.ps1 -Subscriptions @("<subId1>", "<subId2>")
#>
param (
    [string[]]
    $Subscriptions = @(
        "4aecf0e8-2fe2-4187-bc93-0356bd2676f5", # sub-mhodaa
        "556f9b63-ebc9-4c7e-8437-9a05aa8cdb25", # sub-t0
        "a0844269-41ae-442c-8277-415f1283d422", # sub-t1
        "b1658f1f-33e5-4e48-9401-f66ba5e64cce", # sub-t2
        "9aa72379-2067-4948-b51c-de59f4005d04", # sub-t3
        "98525264-1eb4-493f-983d-16a330caa7f6"  # sub-t4
    ),

    [int]
    $PollingIntervalSeconds = 30
)

$features = @(
    @{ Namespace = "Microsoft.Baremetal"; Name = "EnableRotterdamSdnApplianceForOracle" },
    @{ Namespace = "Microsoft.Network";   Name = "EnableRotterdamSdnApplianceForOracle" }
)

$providers = @(
    "Microsoft.Baremetal",
    "Microsoft.Network",
    "Microsoft.Compute",
    "Oracle.Database"
)

function Write-Section {
    param (
        [string] $Message
    )

    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Register-Feature {
    param (
        [string] $Namespace,
        [string] $Name
    )

    az feature register --namespace $Namespace --name $Name --only-show-errors | Out-Null
}

function Get-FeatureState {
    param (
        [string] $Namespace,
        [string] $Name
    )

    az feature show --namespace $Namespace --name $Name --query properties.state --output tsv
}

function Register-Provider {
    param (
        [string] $Namespace
    )

    az provider register --namespace $Namespace --only-show-errors | Out-Null
}

foreach ($subscription in $Subscriptions) {
    Write-Section "Processing subscription $subscription"

    az account set --subscription $subscription | Out-Null

    foreach ($feature in $features) {
        Write-Host "Registering feature $($feature.Namespace)/$($feature.Name)..."
        Register-Feature -Namespace $feature.Namespace -Name $feature.Name
    }

    Write-Host "Waiting for feature registration to complete..."
    do {
        Start-Sleep -Seconds $PollingIntervalSeconds

        $states = @{}
        foreach ($feature in $features) {
            $state = Get-FeatureState -Namespace $feature.Namespace -Name $feature.Name
            $states["$($feature.Namespace)/$($feature.Name)"] = $state
        }

        $statusLine = $states.GetEnumerator() | ForEach-Object { "{0}: {1}" -f $_.Key, $_.Value } | Sort-Object
        Write-Host "  $(($statusLine -join '; '))"

        $allRegistered = $states.Values -notcontains "Registering" -and $states.Values -notcontains "Pending"
    } while (-not $allRegistered)

    if ($states.Values -notcontains "Registered") {
        Write-Warning "One or more features failed to register for subscription $subscription."
        Write-Warning "Skipping provider re-registration for this subscription."
        continue
    }

    foreach ($provider in $providers) {
        Write-Host "Re-registering provider $provider..."
        Register-Provider -Namespace $provider
    }

    Write-Host "Completed feature setup for $subscription" -ForegroundColor Green
    Write-Host
}

Write-Section "All subscriptions processed"