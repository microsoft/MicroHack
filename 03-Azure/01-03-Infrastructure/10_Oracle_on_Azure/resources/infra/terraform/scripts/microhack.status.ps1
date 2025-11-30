<#
.SYNOPSIS
    Checks the status of Private DNS Zones A records on AKS VNets for the MicroHack environment.

.DESCRIPTION
    This script iterates through all subscription targets defined in terraform.tfvars,
    finds Private DNS Zones linked to AKS VNets, and shows which ones have A records added.

.EXAMPLE
    .\scripts\microhack.status.ps1
#>

# Subscription targets from terraform.tfvars
$subscriptionTargets = @(
    @{ Id = "556f9b63-ebc9-4c7e-8437-9a05aa8cdb25"; Name = "sub-mh0" },
    @{ Id = "a0844269-41ae-442c-8277-415f1283d422"; Name = "sub-mh1" },
    @{ Id = "b1658f1f-33e5-4e48-9401-f66ba5e64cce"; Name = "sub-mh2" },
    @{ Id = "9aa72379-2067-4948-b51c-de59f4005d04"; Name = "sub-mh3" },
    @{ Id = "98525264-1eb4-493f-983d-16a330caa7f6"; Name = "sub-mh4" }
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MicroHack Private DNS Zone Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$results = @()

foreach ($sub in $subscriptionTargets) {
    Write-Host "Checking subscription: $($sub.Name) ($($sub.Id))" -ForegroundColor Yellow
    
    # Set the subscription context
    az account set --subscription $sub.Id 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Failed to set subscription context" -ForegroundColor Red
        continue
    }

    # Get all Private DNS Zones in the subscription
    $dnsZonesJson = az network private-dns zone list --query "[].{name:name, resourceGroup:resourceGroup}" -o json 2>$null
    $dnsZones = $dnsZonesJson | ConvertFrom-Json
    
    if (-not $dnsZones -or $dnsZones.Count -eq 0) {
        Write-Host "  No Private DNS Zones found" -ForegroundColor Gray
        continue
    }

    foreach ($zone in $dnsZones) {
        # Get A records for this zone
        $aRecordsJson = az network private-dns record-set a list --resource-group $zone.resourceGroup --zone-name $zone.name --query "[].{name:name, fqdn:fqdn, ttl:ttl, ipAddresses:aRecords[].ipv4Address}" -o json 2>$null
        $aRecords = $aRecordsJson | ConvertFrom-Json

        $hasARecords = $false
        if ($aRecords -and $aRecords.Count -gt 0) {
            $hasARecords = $true
        }

        # Get VNet links to determine if this is an AKS-related zone
        $vnetLinksJson = az network private-dns link vnet list --resource-group $zone.resourceGroup --zone-name $zone.name --query "[].{name:name, vnetId:virtualNetwork.id}" -o json 2>$null
        $vnetLinks = $vnetLinksJson | ConvertFrom-Json

        $linkedToAks = $false
        $linkedVnets = @()
        foreach ($link in $vnetLinks) {
            if ($link.vnetId -match "aks-user\d+") {
                $linkedToAks = $true
                $vnetName = ($link.vnetId -split "/")[-1]
                $linkedVnets += $vnetName
            }
        }

        if ($linkedToAks) {
            if ($hasARecords) {
                $status = "[YES] Has A Records"
                $statusColor = "Green"
            } else {
                $status = "[NO] No A Records"
                $statusColor = "Red"
            }
            
            Write-Host "  [$($zone.resourceGroup)] $($zone.name)" -ForegroundColor White -NoNewline
            Write-Host " - $status" -ForegroundColor $statusColor
            
            if ($hasARecords) {
                foreach ($record in $aRecords) {
                    $ips = $record.ipAddresses -join ", "
                    Write-Host "    -> $($record.name): $ips" -ForegroundColor Gray
                }
            }

            $aRecordCount = 0
            $aRecordStr = ""
            if ($aRecords) {
                $aRecordCount = $aRecords.Count
                $aRecordItems = @()
                foreach ($r in $aRecords) {
                    $ipStr = $r.ipAddresses -join ","
                    $aRecordItems += "$($r.name): $ipStr"
                }
                $aRecordStr = $aRecordItems -join "; "
            }

            $results += [PSCustomObject]@{
                Subscription    = $sub.Name
                SubscriptionId  = $sub.Id
                ResourceGroup   = $zone.resourceGroup
                ZoneName        = $zone.name
                HasARecords     = $hasARecords
                ARecordCount    = $aRecordCount
                LinkedVNets     = $linkedVnets -join ", "
                ARecords        = $aRecordStr
            }
        }
    }
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$withRecords = @($results | Where-Object { $_.HasARecords }).Count
$withoutRecords = @($results | Where-Object { -not $_.HasARecords }).Count
$total = $results.Count

Write-Host "Total Private DNS Zones linked to AKS VNets: $total" -ForegroundColor White
Write-Host "  With A Records:    $withRecords" -ForegroundColor Green
Write-Host "  Without A Records: $withoutRecords" -ForegroundColor Red
Write-Host ""

# Return results for further processing if needed
$results
