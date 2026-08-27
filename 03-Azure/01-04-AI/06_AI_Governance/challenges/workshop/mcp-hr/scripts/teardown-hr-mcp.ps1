[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$NoWait,
    [switch]$KeepAzdEnv,
    [switch]$SkipApim,
    [switch]$SkipDns,
    [switch]$SkipRg,
    [switch]$SkipSubnet
)

# Tear down the HR MCP deployment created by deploy-hr-mcp.ps1 and published by
# publish-hr-mcp-apim.ps1. Every step is best-effort and idempotent: objects that
# were already removed (for example, deleted by hand in the portal) are skipped
# with a notice instead of failing the run. If deploy-hr-mcp expanded the Citadel
# hub VNet (HR_MCP_ACA_ADDED_VNET_PREFIX), that added address space is removed after
# the dedicated subnet is deleted. Finally, all HR_MCP_* values are cleared from the
# active azd environment so a stale backend URL can never leak into a later
# deploy/publish cycle.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) { $PSNativeCommandUseErrorActionPreference = $false }

function Write-Step { param([string]$Message) Write-Host "`n==> $Message" }
function Write-Note { param([string]$Message) Write-Host "   - $Message" }
function Assert-Command { param([string]$Name) if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "Required command not found: $Name" } }
function ConvertTo-TrimmedCliOutput { param([AllowNull()]$Value) if ($null -eq $Value) { return $null }; $text = [string]($Value | Select-Object -First 1); if ([string]::IsNullOrWhiteSpace($text)) { return $null }; return $text.Trim() }
function Get-AzdValue { param([string]$Name) $value = (& azd env get-value $Name 2>$null); if ($LASTEXITCODE -ne 0) { return $null }; return ConvertTo-TrimmedCliOutput $value }
function Get-FirstNonEmpty { param([AllowNull()][string[]]$Values) foreach ($value in $Values) { if (-not [string]::IsNullOrWhiteSpace($value)) { return $value } }; return $null }

function ConvertTo-IPv4UInt32 {
    param([string]$Address)
    $bytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function Test-CidrContains {
    # True when ChildCidr is fully contained within ParentCidr (IPv4 only).
    param([string]$ParentCidr, [string]$ChildCidr)
    if ($ParentCidr -match ':' -or $ChildCidr -match ':') { return $false }
    $parentParts = $ParentCidr.Split('/')
    $childParts = $ChildCidr.Split('/')
    $parentPrefix = [int]$parentParts[1]
    $childPrefix = [int]$childParts[1]
    if ($childPrefix -lt $parentPrefix) { return $false }
    $parentIp = ConvertTo-IPv4UInt32 $parentParts[0]
    $childIp = ConvertTo-IPv4UInt32 $childParts[0]
    $mask = if ($parentPrefix -eq 0) { [uint32]0 } else { [uint32]::MaxValue -shl (32 - $parentPrefix) }
    return (($parentIp -band $mask) -eq ($childIp -band $mask))
}

Assert-Command az
Assert-Command azd
& az account show *> $null
if ($LASTEXITCODE -ne 0) { throw 'Azure CLI is not logged in. Run az login, then rerun this script.' }

$subscriptionId = Get-FirstNonEmpty @($env:AZURE_SUBSCRIPTION_ID, (Get-AzdValue AZURE_SUBSCRIPTION_ID), (ConvertTo-TrimmedCliOutput (& az account show --query id -o tsv 2>$null)))
if ($subscriptionId) { & az account set --subscription $subscriptionId *> $null }

$mcpRg = Get-FirstNonEmpty @($env:HR_MCP_RESOURCE_GROUP, (Get-AzdValue HR_MCP_RESOURCE_GROUP))
$apimName = Get-FirstNonEmpty @($env:HR_MCP_APIM_NAME, (Get-AzdValue HR_MCP_APIM_NAME), $env:APIM_NAME, (Get-AzdValue APIM_NAME))
$apimRg = Get-FirstNonEmpty @($env:HR_MCP_APIM_RESOURCE_GROUP, (Get-AzdValue HR_MCP_APIM_RESOURCE_GROUP), (Get-AzdValue AZURE_RESOURCE_GROUP))
$apiName = Get-FirstNonEmpty @($env:HR_MCP_APIM_API_NAME, (Get-AzdValue HR_MCP_APIM_API_NAME), 'hr-mcp-api')
$backendName = Get-FirstNonEmpty @($env:HR_MCP_APIM_BACKEND_NAME, (Get-AzdValue HR_MCP_APIM_BACKEND_NAME), 'hr-mcp-aca-backend')
$productId = Get-FirstNonEmpty @($env:HR_MCP_APIM_PRODUCT_ID, (Get-AzdValue HR_MCP_APIM_PRODUCT_ID), 'MCP-HR-Tools-DEV')
$subscriptionName = Get-FirstNonEmpty @($env:HR_MCP_APIM_SUBSCRIPTION_NAME, (Get-AzdValue HR_MCP_APIM_SUBSCRIPTION_NAME), 'MCP-HR-Tools-DEV-SUB-01')
$dnsRg = Get-FirstNonEmpty @($env:HR_MCP_PRIVATE_DNS_RESOURCE_GROUP, (Get-AzdValue HR_MCP_PRIVATE_DNS_RESOURCE_GROUP))
$dnsZone = Get-FirstNonEmpty @($env:HR_MCP_PRIVATE_DNS_ZONE, (Get-AzdValue HR_MCP_PRIVATE_DNS_ZONE))
$dnsLinkName = 'lnk-hr-mcp-aca'

# Dedicated ACA subnet that deploy-hr-mcp creates inside the shared Citadel hub VNet. It is
# delegated to Microsoft.App/environments, so it can only be removed after the resource group
# (and its ACA environment) is gone.
$subnetId = Get-FirstNonEmpty @($env:HR_MCP_ACA_SUBNET_ID, (Get-AzdValue HR_MCP_ACA_SUBNET_ID))
$hubRg = Get-FirstNonEmpty @($env:HR_MCP_CITADEL_RESOURCE_GROUP, (Get-AzdValue HR_MCP_CITADEL_RESOURCE_GROUP))
$vnetName = Get-FirstNonEmpty @($env:HR_MCP_CITADEL_VNET_NAME, (Get-AzdValue HR_MCP_CITADEL_VNET_NAME))
$subnetName = Get-FirstNonEmpty @($env:HR_MCP_ACA_SUBNET_NAME, (Get-AzdValue HR_MCP_ACA_SUBNET_NAME))
# Address prefix deploy-hr-mcp added to the hub VNet when no free subnet was available.
# It is removed only after the dedicated subnet is gone, leaving the original space intact.
$addedVnetPrefix = Get-FirstNonEmpty @($env:HR_MCP_ACA_ADDED_VNET_PREFIX, (Get-AzdValue HR_MCP_ACA_ADDED_VNET_PREFIX))
if ($subnetId) {
    if (-not $hubRg -and $subnetId -match '/resourceGroups/([^/]+)/') { $hubRg = $Matches[1] }
    if (-not $vnetName -and $subnetId -match '/virtualNetworks/([^/]+)/') { $vnetName = $Matches[1] }
    if (-not $subnetName) { $subnetName = ($subnetId -split '/')[-1] }
}

Write-Step 'HR MCP teardown plan'
Write-Note ("Subscription:            {0}" -f ($(if ($subscriptionId) { $subscriptionId } else { '<unknown>' })))
if ($SkipApim) {
    Write-Note 'APIM publication:        SKIPPED (-SkipApim)'
} elseif ($apimName -and $apimRg) {
    Write-Note "APIM service:            $apimName ($apimRg)"
    Write-Note "  - subscription:        $subscriptionName"
    Write-Note "  - product:             $productId"
    Write-Note "  - API:                 $apiName"
    Write-Note "  - backend:             $backendName"
} else {
    Write-Note 'APIM publication:        SKIPPED (APIM name/resource group not resolved)'
}
if ($SkipDns) {
    Write-Note 'Private DNS zone:        SKIPPED (-SkipDns)'
} elseif ($dnsRg -and $dnsZone) {
    Write-Note "Private DNS zone:        $dnsZone ($dnsRg)"
} else {
    Write-Note 'Private DNS zone:        SKIPPED (zone/resource group not resolved)'
}
if ($SkipRg) {
    Write-Note 'Infrastructure RG:       SKIPPED (-SkipRg)'
} elseif ($mcpRg) {
    Write-Note "Infrastructure RG:       $mcpRg (DELETE)"
} else {
    Write-Note 'Infrastructure RG:       SKIPPED (HR_MCP_RESOURCE_GROUP not resolved)'
}
if ($SkipSubnet) {
    Write-Note 'ACA hub subnet:          SKIPPED (-SkipSubnet)'
} elseif ($hubRg -and $vnetName -and $subnetName) {
    Write-Note "ACA hub subnet:          $subnetName in $vnetName ($hubRg)"
    if ($addedVnetPrefix) {
        Write-Note "Added VNet address space: $addedVnetPrefix (REMOVE after subnet)"
    }
} else {
    Write-Note 'ACA hub subnet:          SKIPPED (subnet/VNet not resolved)'
}
if ($KeepAzdEnv) {
    Write-Note 'azd HR_MCP_* values:     KEPT (-KeepAzdEnv)'
} else {
    Write-Note 'azd HR_MCP_* values:     CLEARED'
}

if (-not $Yes) {
    $reply = Read-Host "`nProceed with teardown? Type 'yes' to continue"
    if ($reply -ne 'yes') {
        Write-Host "`nTeardown cancelled. No changes were made." -ForegroundColor Yellow
        exit 0
    }
}

function Remove-ApimChild {
    # Best-effort DELETE of an APIM child resource by relative path. A 404 (already
    # gone) or any other failure is reported and skipped rather than aborting.
    param([string]$Relative, [string]$Label, [string]$ExtraQuery = '')
    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$apimRg/providers/Microsoft.ApiManagement/service/$apimName/$Relative" + "?api-version=2024-06-01-preview$ExtraQuery"
    & az rest --method delete --url $url --only-show-errors -o none *> $null
    if ($LASTEXITCODE -eq 0) { Write-Note "Deleted APIM $Label" } else { Write-Note "APIM $Label already absent or not deletable (continuing)" }
}

if (-not $SkipApim -and $apimName -and $apimRg -and $subscriptionId) {
    & az apim show --name $apimName --resource-group $apimRg *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Step "Removing HR MCP publication objects from APIM: $apimName"
        Remove-ApimChild "subscriptions/$subscriptionName" "subscription '$subscriptionName'"
        Remove-ApimChild "products/$productId" "product '$productId'" '&deleteSubscriptions=true'
        Remove-ApimChild "apis/$apiName" "API '$apiName'"
        Remove-ApimChild "backends/$backendName" "backend '$backendName'"
    } else {
        Write-Step "APIM service '$apimName' not found in '$apimRg'; skipping APIM cleanup."
    }
}

if (-not $SkipDns -and $dnsRg -and $dnsZone) {
    & az network private-dns zone show --resource-group $dnsRg --name $dnsZone *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Step "Removing private DNS zone: $dnsZone"
        & az network private-dns link vnet show --resource-group $dnsRg --zone-name $dnsZone --name $dnsLinkName *> $null
        if ($LASTEXITCODE -eq 0) {
            & az network private-dns link vnet delete --resource-group $dnsRg --zone-name $dnsZone --name $dnsLinkName --yes --only-show-errors -o none *> $null
            if ($LASTEXITCODE -eq 0) { Write-Note "Deleted vnet link '$dnsLinkName'" } else { Write-Note "Could not delete vnet link '$dnsLinkName' (continuing)" }
        } else {
            Write-Note "Vnet link '$dnsLinkName' already absent (continuing)"
        }
        & az network private-dns zone delete --resource-group $dnsRg --name $dnsZone --yes --only-show-errors -o none *> $null
        if ($LASTEXITCODE -eq 0) { Write-Note "Deleted private DNS zone '$dnsZone'" } else { Write-Note "Could not delete private DNS zone '$dnsZone' (continuing)" }
    } else {
        Write-Step "Private DNS zone '$dnsZone' already absent (continuing)."
    }
}

$rgDeleteAsync = $false
if (-not $SkipRg -and $mcpRg) {
    & az group show --name $mcpRg *> $null
    if ($LASTEXITCODE -eq 0) {
        if ($NoWait) {
            Write-Step "Deleting resource group (no wait): $mcpRg"
            & az group delete --name $mcpRg --yes --no-wait -o none
            Write-Note 'Deletion started in the background.'
            $rgDeleteAsync = $true
        } else {
            Write-Step "Deleting resource group (this can take several minutes): $mcpRg"
            & az group delete --name $mcpRg --yes -o none
            Write-Note 'Resource group deleted.'
        }
    } else {
        Write-Step "Resource group '$mcpRg' already absent (continuing)."
    }
}

if (-not $SkipSubnet -and $hubRg -and $vnetName -and $subnetName) {
    & az network vnet subnet show --resource-group $hubRg --vnet-name $vnetName --name $subnetName *> $null
    if ($LASTEXITCODE -eq 0) {
        if ($rgDeleteAsync) {
            Write-Step "Deferring ACA subnet '$subnetName' deletion"
            Write-Note 'The subnet is still delegated to the ACA environment while the resource group deletes in the background.'
            Write-Note "Rerun: teardown-hr-mcp.ps1 -SkipApim -SkipDns -SkipRg -KeepAzdEnv  (after '$mcpRg' is gone)"
        } else {
            Write-Step "Deleting ACA subnet '$subnetName' from Citadel hub VNet '$vnetName'"
            & az network vnet subnet delete --resource-group $hubRg --vnet-name $vnetName --name $subnetName --only-show-errors -o none *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Note "Deleted subnet '$subnetName'"
                # Subnet is gone; now remove the address prefix deploy added (if any), but only
                # when no other subnet still sits inside it, so we never shrink space in use.
                if ($addedVnetPrefix) {
                    $vnetInfoJson = (& az network vnet show --resource-group $hubRg --name $vnetName --query '{addressPrefixes:addressSpace.addressPrefixes,subnetPrefixes:subnets[].addressPrefix}' -o json 2>$null)
                    $removeIndex = $null
                    if ($vnetInfoJson) {
                        $vnetInfo = $vnetInfoJson | ConvertFrom-Json
                        $remainingPrefixes = @($vnetInfo.addressPrefixes)
                        $remainingSubnets = @($vnetInfo.subnetPrefixes)
                        $inUse = $false
                        foreach ($s in $remainingSubnets) {
                            if ($s -and (Test-CidrContains -ParentCidr $addedVnetPrefix -ChildCidr $s)) { $inUse = $true; break }
                        }
                        if ($inUse) {
                            Write-Note "Address prefix '$addedVnetPrefix' still has subnets; leaving it on the VNet."
                        } else {
                            for ($i = 0; $i -lt $remainingPrefixes.Count; $i++) {
                                if ($remainingPrefixes[$i] -eq $addedVnetPrefix) { $removeIndex = $i; break }
                            }
                            if ($null -eq $removeIndex) {
                                Write-Note "Address prefix '$addedVnetPrefix' already absent from VNet (continuing)."
                            } else {
                                & az network vnet update --resource-group $hubRg --name $vnetName --remove addressSpace.addressPrefixes $removeIndex --only-show-errors -o none *> $null
                                if ($LASTEXITCODE -eq 0) { Write-Note "Removed added VNet address space '$addedVnetPrefix'" } else { Write-Warning "Could not remove added VNet address space '$addedVnetPrefix' (continuing). Remove it manually if no longer needed." }
                            }
                        }
                    }
                }
            } else {
                Write-Warning "Could not delete subnet '$subnetName'. It may still be in use by the ACA environment; rerun this script once '$mcpRg' has finished deleting."
            }
        }
    } else {
        Write-Step "Subnet '$subnetName' already absent (continuing)."
    }
}

if (-not $KeepAzdEnv) {
    Write-Step 'Clearing HR_MCP_* values from the active azd environment'
    $envListJson = (& azd env list -o json 2>$null)
    $dotenvPath = $null
    if ($LASTEXITCODE -eq 0 -and $envListJson) {
        try {
            $envs = $envListJson | ConvertFrom-Json
            foreach ($e in $envs) {
                $isDefault = $e.PSObject.Properties | Where-Object { $_.Name -ieq 'IsDefault' } | Select-Object -First 1
                if ($isDefault -and $isDefault.Value) {
                    $pathProp = $e.PSObject.Properties | Where-Object { $_.Name -ieq 'DotEnvPath' } | Select-Object -First 1
                    if ($pathProp) { $dotenvPath = [string]$pathProp.Value }
                    break
                }
            }
        } catch { $dotenvPath = $null }
    }
    if ($dotenvPath -and (Test-Path $dotenvPath)) {
        $kept = Get-Content -LiteralPath $dotenvPath | Where-Object { $_ -notmatch '^HR_MCP_[A-Z0-9_]+=' }
        Set-Content -LiteralPath $dotenvPath -Value $kept
        Write-Note "Removed HR_MCP_* entries from $dotenvPath"
    } else {
        Write-Warning 'Could not locate the active azd .env file; HR_MCP_* values were left in place. Select an azd environment or clear them manually.'
    }
}

Write-Step 'HR MCP teardown complete.'
Write-Host 'Re-run deploy-hr-mcp then publish-hr-mcp-apim to recreate a clean deployment.'
