<#
.SYNOPSIS
Checks the doubled facilitator VM quota plus the per-participant network footprint, and
estimates the monthly compute, OS-disk, and network cost.

.DESCRIPTION
Reads the selected VM SKU and current regional Azure compute and network usage, then fails
when the requested footprint exceeds regional or VM-family vCPU quota, VM count, Premium
managed-disk, or public-IP quota. Every participant receives two VMs and two Standard static
public IP addresses -- one per VM, used for RDP and for browsing the legacy application --
so those are counted here rather than treated as shared foundation.

Azure Bastion and the NAT gateway are no longer part of the topology: each VM carries its own
public IP, which provides both inbound access and an explicit outbound path. The Bastion and
NAT accounting below is retained but driven by per-participant counts of zero, so it
short-circuits; set those counts back above zero if the topology ever reintroduces them.

It queries the public Azure Retail Prices API for Windows consumption, Premium SSD
managed-disk, and public-IP rates, prints the exact footprint, and can enforce a facilitator
cost ceiling. Meters or quota metrics that Azure does not return are reported as unavailable
instead of being silently dropped.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F-]{36}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Locations,

    [Parameter(Mandatory)]
    [ValidateRange(1, 254)]
    [int]$ParticipantCount,

    [string]$VmSize = 'Standard_D2as_v5',

    [ValidateRange(127, 32768)]
    [int]$OsDiskSizeGiB = 127,

    [ValidateRange(1, 1000)]
    [int]$BastionHostsPerRegionLimit = 50,

    [ValidateRange(0.01, 1000000)]
    [decimal]$MaximumEstimatedMonthlyCostUsd
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Invoke-AzureCliJson {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $Output = & az @Arguments --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }
    return $Output | ConvertFrom-Json
}

function Get-RetailPrice {
    param(
        [Parameter(Mandatory)]
        [string]$Filter
    )

    $Price = Get-OptionalRetailPrice -Filter $Filter
    if ($null -eq $Price) {
        throw "Azure Retail Prices returned no consumption price for filter: $Filter"
    }
    return $Price
}

function Get-OptionalRetailPrice {
    param(
        [Parameter(Mandatory)]
        [string]$Filter
    )

    $EncodedFilter = [uri]::EscapeDataString($Filter)
    $Uri = "https://prices.azure.com/api/retail/prices?currencyCode=USD&`$filter=$EncodedFilter"
    $Response = Invoke-RestMethod -Uri $Uri
    $Price = @($Response.Items | Where-Object {
            $_.type -eq 'Consumption' -and $_.retailPrice -gt 0
        } | Sort-Object retailPrice | Select-Object -First 1)
    if ($Price.Count -ne 1) {
        return $null
    }
    return $Price[0]
}

function Get-UsageEntry {
    <#
    Azure returns different usage metric names per subscription and region, so match a
    caller-supplied list of candidates and let the caller decide whether absence is fatal.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Usage,

        [Parameter(Mandatory)]
        [string[]]$Names
    )

    foreach ($Name in $Names) {
        $Entry = $Usage |
            Where-Object { $_.name.value -eq $Name } |
            Select-Object -First 1
        if ($null -ne $Entry) {
            return $Entry
        }
    }
    return $null
}

function Get-PremiumDiskSku {
    param(
        [Parameter(Mandatory)]
        [int]$SizeGiB
    )

    $Tiers = @(
        @{ MaximumGiB = 64; Name = 'P6' },
        @{ MaximumGiB = 128; Name = 'P10' },
        @{ MaximumGiB = 256; Name = 'P15' },
        @{ MaximumGiB = 512; Name = 'P20' },
        @{ MaximumGiB = 1024; Name = 'P30' },
        @{ MaximumGiB = 2048; Name = 'P40' },
        @{ MaximumGiB = 4096; Name = 'P50' },
        @{ MaximumGiB = 8192; Name = 'P60' },
        @{ MaximumGiB = 16384; Name = 'P70' },
        @{ MaximumGiB = 32768; Name = 'P80' }
    )
    $Tier = $Tiers | Where-Object { $SizeGiB -le $_.MaximumGiB } | Select-Object -First 1
    if ($null -eq $Tier) {
        throw "No Premium SSD tier supports an operating-system disk of $SizeGiB GiB."
    }
    return $Tier.Name
}

$null = Invoke-AzureCliJson -Arguments @(
    'account',
    'show',
    '--subscription',
    $SubscriptionId
)

# Subscription capability gate. Quota alone is not enough: some tenants withhold the
# Microsoft.Network/AllowBringYourOwnPublicIpAddress feature, and without it every public IP
# allocation is refused regardless of available quota. That breaks the per-VM public IPs here
# in the base infrastructure, and it also breaks the Challenge 1 target, where an external
# Container Apps managed environment fails roughly eight minutes into the deployment after
# ~21 other resources have already been created. Surface it here, in seconds, instead of there.
$PublicIpFeature = Invoke-AzureCliJson -Arguments @(
    'feature',
    'show',
    '--namespace',
    'Microsoft.Network',
    '--name',
    'AllowBringYourOwnPublicIpAddress',
    '--subscription',
    $SubscriptionId
)
$PublicIpFeatureState = (@($PublicIpFeature.properties.state) -join '')
$PublicIpAllocationBlocked = $PublicIpFeatureState -ne 'Registered'
if ($PublicIpAllocationBlocked) {
    # Registering this feature is a two-step operation and the second step is easy to miss:
    # `az feature register` alone leaves the state unpropagated, so public IP creation keeps
    # failing and the subscription looks permanently governed against public IPs when it is
    # not. `az provider register` is what actually applies it.
    Write-Warning ("Subscription {0} reports Microsoft.Network/AllowBringYourOwnPublicIpAddress as '{1}' rather than 'Registered'. Public IP allocation will be refused, which blocks the per-VM public IPs the participants use for RDP and for browsing the legacy app, and the external Container Apps environment used by Challenge 1. Register it with: az feature register --namespace Microsoft.Network --name AllowBringYourOwnPublicIpAddress --subscription {0}; az provider register -n Microsoft.Network --subscription {0}. Both commands are required -- registering the feature without re-registering the provider does not take effect." -f $SubscriptionId, $PublicIpFeatureState)
}

# Per participant: one public IP per legacy VM, so participants can RDP in and browse the
# legacy application directly. Azure Bastion and the NAT gateway are no longer deployed --
# the VM public IPs provide both inbound access and an explicit outbound path -- so their
# per-participant counts are zero and the checks below short-circuit.
$PublicIpsPerParticipant = 2
$NatGatewaysPerParticipant = 0
$BastionHostsPerParticipant = 0

$ExistingBastionHosts = @()
if ($BastionHostsPerParticipant -gt 0) {
    $ExistingBastionHosts = @(
        Invoke-AzureCliJson -Arguments @(
            'network',
            'bastion',
            'list',
            '--subscription',
            $SubscriptionId
        )
    )
}

$TotalVmCount = $ParticipantCount * 2
$TotalDiskCount = $ParticipantCount * 2
$TotalDiskGiB = $TotalDiskCount * $OsDiskSizeGiB
$TotalPublicIpCount = $ParticipantCount * $PublicIpsPerParticipant
$TotalNatGatewayCount = $ParticipantCount * $NatGatewaysPerParticipant
$TotalBastionHostCount = $ParticipantCount * $BastionHostsPerParticipant
$MonthlyHours = 730
$RegionalResults = @()
$QuotaMetricsUnavailable = @()
$PricesUnavailable = @()
$TotalMonthlyCompute = [decimal]0
$TotalMonthlyDisks = [decimal]0
$TotalMonthlyNetwork = [decimal]0
$PremiumDiskSku = Get-PremiumDiskSku -SizeGiB $OsDiskSizeGiB

foreach ($Location in @($Locations | Select-Object -Unique)) {
    $Sku = @(
        Invoke-AzureCliJson -Arguments @(
            'vm',
            'list-skus',
            '--subscription',
            $SubscriptionId,
            '--location',
            $Location,
            '--size',
            $VmSize,
            '--all'
        ) | Where-Object {
            $_.name -eq $VmSize -and
            -not ($_.restrictions | Where-Object { $_.reasonCode -eq 'NotAvailableForSubscription' })
        } | Select-Object -First 1
    )
    if ($Sku.Count -ne 1) {
        throw "$VmSize is unavailable for subscription $SubscriptionId in $Location."
    }

    $VcpuCapability = $Sku[0].capabilities |
        Where-Object { $_.name -eq 'vCPUs' } |
        Select-Object -First 1
    if ($null -eq $VcpuCapability) {
        throw "Azure did not return a vCPU capability for $VmSize in $Location."
    }
    $VcpusPerVm = [int]$VcpuCapability.value
    $Family = [string]$Sku[0].family
    $ParticipantsInRegion = @(
        for ($Index = 0; $Index -lt $ParticipantCount; $Index++) {
            if ($Locations[$Index % $Locations.Count] -eq $Location) {
                $Index
            }
        }
    ).Count
    $RegionVmCount = $ParticipantsInRegion * 2
    $RequiredVcpus = $RegionVmCount * $VcpusPerVm

    $Usage = Invoke-AzureCliJson -Arguments @(
        'vm',
        'list-usage',
        '--subscription',
        $SubscriptionId,
        '--location',
        $Location
    )
    $RegionalQuota = $Usage |
        Where-Object { $_.name.value -eq 'cores' } |
        Select-Object -First 1
    $FamilyQuota = $Usage |
        Where-Object {
            $_.name.value -eq $Family -or
            $_.name.localizedValue -match [regex]::Escape($Family)
        } |
        Select-Object -First 1
    $VmQuota = $Usage |
        Where-Object { $_.name.value -eq 'virtualMachines' } |
        Select-Object -First 1
    # Azure renamed this metric; older regions still report the legacy name, so accept both
    # rather than failing preflight on a metric that is present under a different key.
    $DiskQuota = $Usage |
        Where-Object { $_.name.value -in @('PremiumStorageManagedDisks', 'PremiumDiskCount') } |
        Select-Object -First 1
    if ($null -eq $RegionalQuota -or $null -eq $FamilyQuota -or
        $null -eq $VmQuota -or $null -eq $DiskQuota) {
        throw "Azure quota data did not include regional cores, $Family, virtual machines, and Premium managed disks in $Location."
    }
    $RegionalAvailable = [int]$RegionalQuota.limit - [int]$RegionalQuota.currentValue
    $FamilyAvailable = [int]$FamilyQuota.limit - [int]$FamilyQuota.currentValue
    $VirtualMachinesAvailable = [int]$VmQuota.limit - [int]$VmQuota.currentValue
    $PremiumDisksAvailable = [int]$DiskQuota.limit - [int]$DiskQuota.currentValue
    if ($RequiredVcpus -gt $RegionalAvailable) {
        throw "$Location requires $RequiredVcpus vCPUs but only $RegionalAvailable regional vCPUs are available."
    }
    if ($RequiredVcpus -gt $FamilyAvailable) {
        throw "$Location requires $RequiredVcpus $Family vCPUs but only $FamilyAvailable are available."
    }
    if ($RegionVmCount -gt $VirtualMachinesAvailable) {
        throw "$Location requires $RegionVmCount VMs but only $VirtualMachinesAvailable are available."
    }
    if ($RegionVmCount -gt $PremiumDisksAvailable) {
        throw "$Location requires $RegionVmCount Premium OS disks but only $PremiumDisksAvailable are available."
    }

    $RequiredPublicIps = $ParticipantsInRegion * $PublicIpsPerParticipant
    $RequiredNatGateways = $ParticipantsInRegion * $NatGatewaysPerParticipant
    $RequiredBastionHosts = $ParticipantsInRegion * $BastionHostsPerParticipant

    $NetworkUsage = @(
        Invoke-AzureCliJson -Arguments @(
            'network',
            'list-usages',
            '--subscription',
            $SubscriptionId,
            '--location',
            $Location
        )
    )
    $PublicIpQuota = Get-UsageEntry -Usage $NetworkUsage -Names @(
        'StandardSkuPublicIpAddresses',
        'PublicIPAddresses',
        'StaticPublicIPAddresses'
    )
    $NatGatewayQuota = Get-UsageEntry -Usage $NetworkUsage -Names @(
        'NatGateways',
        'natGateways'
    )

    $PublicIpsAvailable = $null
    if ($null -eq $PublicIpQuota) {
        $QuotaMetricsUnavailable += "$Location`: Standard public IP addresses"
    }
    else {
        $PublicIpsAvailable = [int]$PublicIpQuota.limit - [int]$PublicIpQuota.currentValue
        if ($RequiredPublicIps -gt $PublicIpsAvailable) {
            throw "$Location requires $RequiredPublicIps Standard public IP addresses (one per legacy VM per participant) but only $PublicIpsAvailable are available."
        }
    }

    $NatGatewaysAvailable = $null
    if ($RequiredNatGateways -gt 0) {
        if ($null -eq $NatGatewayQuota) {
            $QuotaMetricsUnavailable += "$Location`: NAT gateways"
        }
        else {
            $NatGatewaysAvailable = [int]$NatGatewayQuota.limit - [int]$NatGatewayQuota.currentValue
            if ($RequiredNatGateways -gt $NatGatewaysAvailable) {
                throw "$Location requires $RequiredNatGateways NAT gateways but only $NatGatewaysAvailable are available."
            }
        }
    }

    # Azure exposes no Bastion usage metric, so compare deployed hosts against the configured
    # regional ceiling instead.
    $ExistingBastionHostsInRegion = @(
        $ExistingBastionHosts | Where-Object { $_.location -eq $Location }
    ).Count
    $BastionHostsAvailable = $BastionHostsPerRegionLimit - $ExistingBastionHostsInRegion
    if ($RequiredBastionHosts -gt $BastionHostsAvailable) {
        throw "$Location requires $RequiredBastionHosts Azure Bastion hosts but only $BastionHostsAvailable of the $BastionHostsPerRegionLimit regional limit remain ($ExistingBastionHostsInRegion already deployed)."
    }

    # The Retail Prices API matches armRegionName case-sensitively and publishes it in
    # lowercase, while az vm list-skus returns the mixed-case ARM form.
    $ArmLocation = ([string]$Sku[0].locations[0]).ToLowerInvariant()
    $VmPrice = Get-RetailPrice -Filter (
        "serviceName eq 'Virtual Machines' and armRegionName eq '$ArmLocation' " +
        "and armSkuName eq '$VmSize' and priceType eq 'Consumption' " +
        "and skuName eq '$VmSize' and contains(productName, 'Windows')"
    )
    $DiskPrice = Get-RetailPrice -Filter (
        "serviceName eq 'Storage' and armRegionName eq '$ArmLocation' " +
        "and armSkuName eq 'Premium_SSD_Managed_Disk_$PremiumDiskSku' " +
        "and meterName eq '$PremiumDiskSku LRS Disk' and priceType eq 'Consumption'"
    )
    # Bastion and NAT Gateway are only priced when the topology actually deploys them. Both
    # counts are zero now that participants reach the VMs over their own public IPs, so the
    # lookups are skipped rather than reported as unavailable prices.
    $BastionPrice = $null
    if ($RequiredBastionHosts -gt 0) {
        $BastionPrice = Get-OptionalRetailPrice -Filter (
            "serviceName eq 'Azure Bastion' and armRegionName eq '$ArmLocation' " +
            "and meterName eq 'Basic Gateway' and priceType eq 'Consumption'"
        )
    }
    $PublicIpPrice = Get-OptionalRetailPrice -Filter (
        "serviceName eq 'Virtual Network' and armRegionName eq '$ArmLocation' " +
        "and meterName eq 'Standard IPv4 Static Public IP' and priceType eq 'Consumption'"
    )
    # NAT Gateway is billed from a single global meter rather than a regional one.
    $NatGatewayPrice = $null
    if ($RequiredNatGateways -gt 0) {
        $NatGatewayPrice = Get-OptionalRetailPrice -Filter (
            "serviceName eq 'NAT Gateway' and armRegionName eq 'Global' " +
            "and skuName eq 'Standard' and meterName eq 'Standard Gateway' " +
            "and priceType eq 'Consumption'"
        )
    }

    $MonthlyCompute = [decimal]$VmPrice.retailPrice * $MonthlyHours * $RegionVmCount
    $MonthlyDisks = [decimal]$DiskPrice.retailPrice * $RegionVmCount

    $MonthlyBastion = [decimal]0
    if ($RequiredBastionHosts -gt 0) {
        if ($null -eq $BastionPrice) {
            $PricesUnavailable += "$Location`: Azure Bastion Basic gateway hour"
        }
        else {
            $MonthlyBastion = [decimal]$BastionPrice.retailPrice * $MonthlyHours * $RequiredBastionHosts
        }
    }

    $MonthlyPublicIps = [decimal]0
    if ($null -eq $PublicIpPrice) {
        $PricesUnavailable += "$Location`: Standard IPv4 static public IP hour"
    }
    else {
        $MonthlyPublicIps = [decimal]$PublicIpPrice.retailPrice * $MonthlyHours * $RequiredPublicIps
    }

    $MonthlyNatGateways = [decimal]0
    if ($RequiredNatGateways -gt 0) {
        if ($null -eq $NatGatewayPrice) {
            $PricesUnavailable += "$Location`: NAT gateway hour"
        }
        else {
            $MonthlyNatGateways = [decimal]$NatGatewayPrice.retailPrice * $MonthlyHours * $RequiredNatGateways
        }
    }

    $MonthlyNetwork = $MonthlyBastion + $MonthlyPublicIps + $MonthlyNatGateways
    $TotalMonthlyCompute += $MonthlyCompute
    $TotalMonthlyDisks += $MonthlyDisks
    $TotalMonthlyNetwork += $MonthlyNetwork

    $RegionalResults += [pscustomobject]@{
        location                 = $Location
        participants             = $ParticipantsInRegion
        virtualMachines          = $RegionVmCount
        vmFamily                 = $Family
        vcpusPerVm               = $VcpusPerVm
        requiredVcpus            = $RequiredVcpus
        regionalVcpusAvailable   = $RegionalAvailable
        familyVcpusAvailable     = $FamilyAvailable
        virtualMachinesAvailable = $VirtualMachinesAvailable
        premiumDisksAvailable    = $PremiumDisksAvailable
        premiumDiskSku           = $PremiumDiskSku
        requiredPublicIps        = $RequiredPublicIps
        publicIpsAvailable       = $PublicIpsAvailable
        requiredNatGateways      = $RequiredNatGateways
        natGatewaysAvailable     = $NatGatewaysAvailable
        requiredBastionHosts     = $RequiredBastionHosts
        bastionHostsDeployed     = $ExistingBastionHostsInRegion
        bastionHostsAvailable    = $BastionHostsAvailable
        monthlyComputeUsd        = [math]::Round($MonthlyCompute, 2)
        monthlyOsDiskUsd         = [math]::Round($MonthlyDisks, 2)
        monthlyBastionUsd        = [math]::Round($MonthlyBastion, 2)
        monthlyPublicIpUsd       = [math]::Round($MonthlyPublicIps, 2)
        monthlyNatGatewayUsd     = [math]::Round($MonthlyNatGateways, 2)
        monthlyNetworkUsd        = [math]::Round($MonthlyNetwork, 2)
    }
}

$TotalMonthly = $TotalMonthlyCompute + $TotalMonthlyDisks + $TotalMonthlyNetwork
$Result = [pscustomobject]@{
    subscriptionId               = $SubscriptionId
    participants                 = $ParticipantCount
    virtualMachines              = $TotalVmCount
    vmSize                       = $VmSize
    vcpusPerVm                   = $RegionalResults[0].vcpusPerVm
    osDisks                      = $TotalDiskCount
    osDiskGiB                    = $TotalDiskGiB
    bastionHosts                 = $TotalBastionHostCount
    natGateways                  = $TotalNatGatewayCount
    publicIpAddresses            = $TotalPublicIpCount
    publicIpFeatureState         = $PublicIpFeatureState
    publicIpAllocationBlocked    = $PublicIpAllocationBlocked
    perParticipantFootprint      = [pscustomobject]@{
        virtualMachines   = 2
        osDisks           = 2
        bastionHosts      = $BastionHostsPerParticipant
        natGateways       = $NatGatewaysPerParticipant
        publicIpAddresses = $PublicIpsPerParticipant
    }
    bastionHostsPerRegionLimit   = $BastionHostsPerRegionLimit
    estimatedMonthlyComputeUsd   = [math]::Round($TotalMonthlyCompute, 2)
    estimatedMonthlyOsDiskUsd    = [math]::Round($TotalMonthlyDisks, 2)
    estimatedMonthlyNetworkUsd   = [math]::Round($TotalMonthlyNetwork, 2)
    estimatedMonthlyTotalUsd     = [math]::Round($TotalMonthly, 2)
    quotaMetricsUnavailable      = @($QuotaMetricsUnavailable)
    pricesUnavailable            = @($PricesUnavailable)
    excludedFromEstimate         = @(
        'Container Apps, managed databases, and container registries created during the workshop',
        'Bastion, NAT gateway, and VM outbound data transfer',
        'Microsoft Defender for Cloud plans'
    )
    regions                      = $RegionalResults
}

$Result | ConvertTo-Json -Depth 5
if ($QuotaMetricsUnavailable.Count -gt 0) {
    Write-Warning ("Azure did not expose these quota metrics; confirm them in the portal under Subscription > Usage + quotas: " + ($QuotaMetricsUnavailable -join '; '))
}
if ($PricesUnavailable.Count -gt 0) {
    Write-Warning ("Azure Retail Prices returned no rate for these meters, so they are missing from the estimate; confirm them with the Azure Pricing Calculator: " + ($PricesUnavailable -join '; '))
}
if ($PSBoundParameters.ContainsKey('MaximumEstimatedMonthlyCostUsd') -and
    $TotalMonthly -gt $MaximumEstimatedMonthlyCostUsd) {
    throw "Estimated monthly VM, OS-disk, and network cost $TotalMonthly USD exceeds the configured ceiling $MaximumEstimatedMonthlyCostUsd USD."
}
