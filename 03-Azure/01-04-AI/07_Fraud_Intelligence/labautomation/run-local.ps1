# Local-only wrapper to run deploy-lab.ps1 outside the MicroHack platform.
# Supplies the platform-provided helper (Get-MhhStableHash), pre-creates the
# resource group, and resolves the target user's Entra object ID from their UPN.
# NOT part of the hack deliverable — for local end-to-end verification only.

param(
    # Defaults to the current Az context subscription; pass to override.
    [string]$SubscriptionId = ((Get-AzContext -ErrorAction SilentlyContinue).Subscription.Id),
    [string]$ResourceGroupName = "",
    [string]$Location = "",
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName
)

$ErrorActionPreference = "Stop"

if (-not $SubscriptionId) {
    throw "No subscription in context. Run Connect-AzAccount first, or pass -SubscriptionId."
}

if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    if ($UserPrincipalName -notmatch '^(labuser-\d+)@') {
        throw "Could not derive a resource group name from '$UserPrincipalName'. Expected a UPN like labuser-1@domain."
    }
    $ResourceGroupName = "rg-$($Matches[1].ToLowerInvariant())"
}
Write-Host "Using resource group '$ResourceGroupName'."

$entraUser = Get-AzADUser -UserPrincipalName $UserPrincipalName -ErrorAction SilentlyContinue
if (-not $entraUser -or -not $entraUser.Id) {
    throw "Could not resolve Entra user '$UserPrincipalName'. Verify the active tenant and directory permissions."
}
$AllowedEntraUserIds = @($entraUser.Id)
Write-Host "Resolved '$UserPrincipalName' to object ID '$($entraUser.Id)'."

# Platform-provided helper shim: deterministic, DNS-safe, lowercase hash.
function Get-MhhStableHash {
    param([Parameter(ValueFromRemainingArguments = $true)][object[]]$InputValues, [int]$Length = 12)
    $strings = @()
    foreach ($v in $InputValues) { if ($v -is [array]) { $strings += $v } else { $strings += $v } }
    $joined = ($strings -join '|')
    if ([string]::IsNullOrEmpty($joined)) { $joined = "default" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($joined))
    $hex = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    return $hex.Substring(0, $Length)
}

# Platform-provided helper shim: classifies deployment failures as retryable-in-another-region
# (capacity/quota/SKU availability) or not. Without this shim a local run treats EVERY failure as
# retryable and burns all three regions on errors that are region-independent.
function Test-MhhDeploymentFailureRetryable {
    param([Parameter(Mandatory = $true)]$ErrorRecord)
    $msg = "$ErrorRecord"
    $retryablePatterns = @(
        'SkuNotAvailable', 'QuotaExceeded', 'InsufficientQuota', 'capacity',
        'not available in .* region', 'LocationNotAvailable', 'ServiceUnavailable',
        'SubscriptionDoesNotHaveServer', 'NotAvailableForSubscription'
    )
    foreach ($p in $retryablePatterns) {
        if ($msg -match $p) { return $true }
    }
    return $false
}

function Invoke-MhhDeploymentWithRegionFallback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$PreferredLocations,
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        [string[]]$RgOwnerEntraObjectIds = @(),
        [hashtable]$Tag = @{},
        [Parameter(Mandatory=$true)]
        [string]$TemplateFile,
        [hashtable]$TemplateParameterObject = @{},
        [string]$DeploymentNamePrefix = 'mhh',
        [ValidateRange(0, 50)]
        [int]$MaxAttempts = 0,
        [ValidateRange(0, 5)]
        [int]$SameRegionRetryBudget = 1,
        [switch]$AssumeRetryableOnUnknown
    )

    $locations = @($PreferredLocations | ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Where-Object { $_ } |
        Select-Object -Unique)
    if($locations.Count -eq 0) { throw 'At least one preferred location is required.' }
    if(-not (Test-Path -LiteralPath $TemplateFile -PathType Leaf)) {
        throw "Template file '$TemplateFile' does not exist."
    }

    $attempts = @()
    $existingResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    $reusedExistingResourceGroup = $null -ne $existingResourceGroup
    if($existingResourceGroup) {
        $existingLocation = $existingResourceGroup.Location.ToLowerInvariant()
        $locations = @($existingLocation) + @($locations | Where-Object { $_ -ne $existingLocation })
    }
    if($MaxAttempts -gt 0) { $locations = @($locations | Select-Object -First $MaxAttempts) }

    $regionRetryPattern = 'SkuNotAvailable|QuotaExceeded|LocationNotAvailable|LocationNotAvailableForResourceType|ResourceTypeUnavailable|ResourceProviderUnavailable|SubscriptionIsOverQuotaForSku|ZonalAllocationFailed|AllocationFailed'
    $transientPattern = 'TooManyRequests|OperationTimedOut|ServiceUnavailable|InternalServerError|AnotherOperationInProgress|Conflict|429|timeout|temporarily unavailable'

    foreach($location in $locations) {
        $phase = if($existingResourceGroup -and $existingResourceGroup.Location -eq $location) { 'Reuse' } else { 'Fresh' }
        $recycleCurrentRegion = $phase -eq 'Reuse'
        do {
            $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
            if($resourceGroup -and ($resourceGroup.Location -ne $location -or $phase -eq 'Recycle')) {
                Write-Warning "Removing resource group '$ResourceGroupName' before the $phase attempt in '$location'."
                Remove-AzResourceGroup -Name $ResourceGroupName -Force -ErrorAction Stop | Out-Null
                $resourceGroup = $null
            }
            if(-not $resourceGroup) {
                Write-Host "Creating resource group '$ResourceGroupName' in '$location'..."
                $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $location -Tag $Tag -ErrorAction Stop
            } elseif($Tag.Count -gt 0) {
                $mergedTags = @{}
                if($resourceGroup.Tags) {
                    foreach($key in $resourceGroup.Tags.Keys) { $mergedTags[$key] = $resourceGroup.Tags[$key] }
                }
                foreach($key in $Tag.Keys) { $mergedTags[$key] = $Tag[$key] }
                $resourceGroup = Set-AzResourceGroup -Name $ResourceGroupName -Tag $mergedTags -ErrorAction Stop
            }

            foreach($objectId in $RgOwnerEntraObjectIds) {
                try {
                    New-AzRoleAssignment -ObjectId $objectId -RoleDefinitionName 'Owner' `
                        -Scope $resourceGroup.ResourceId -ErrorAction Stop | Out-Null
                } catch {
                    if($_.Exception.Message -notmatch 'RoleAssignmentExists|role assignment already exists') { throw }
                }
            }

            $sameRegionRetry = 0
            $moveToNextRegion = $false
            while($true) {
                $deploymentName = '{0}-{1}-{2}' -f $DeploymentNamePrefix, $location, (Get-Date -Format 'yyyyMMddHHmmss')
                $startedAt = Get-Date
                try {
                    Write-Host "Deploying '$TemplateFile' to '$ResourceGroupName' in '$location' ($phase)..."
                    $deployment = New-AzResourceGroupDeployment -Name $deploymentName `
                        -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFile `
                        -TemplateParameterObject $TemplateParameterObject -Mode Incremental -ErrorAction Stop
                    $attempts += [pscustomobject]@{
                        Location = $location; Phase = $phase; Outcome = 'Succeeded'
                        Classification = 'None'; Duration = (Get-Date) - $startedAt
                    }
                    $outputs = @{}
                    if($deployment.Outputs) {
                        foreach($property in $deployment.Outputs.PSObject.Properties) {
                            $value = $property.Value
                            if($value -is [hashtable] -and $value.ContainsKey('Value')) { $value = $value.Value }
                            elseif($value.PSObject.Properties['Value']) { $value = $value.Value }
                            $outputs[$property.Name] = $value
                        }
                    }
                    return @{
                        Success = $true; LocationUsed = $location; DeploymentName = $deploymentName
                        Outputs = $outputs; DeploymentResult = $deployment; Attempts = $attempts
                        ReusedExistingResourceGroup = $reusedExistingResourceGroup
                    }
                } catch {
                    $deploymentError = $_
                    $diagnostics = @()
                    Write-Host "[ERROR] Deployment '$deploymentName' failed: $($deploymentError.Exception.Message)" -ForegroundColor Red
                    if($deploymentError.ErrorDetails -and $deploymentError.ErrorDetails.Message) {
                        $diagnostics += $deploymentError.ErrorDetails.Message
                        Write-Host "[ERROR] ARM error details: $($deploymentError.ErrorDetails.Message)" -ForegroundColor Red
                    }
                    $innerException = $deploymentError.Exception.InnerException
                    while($innerException) {
                        $diagnostics += $innerException.Message
                        Write-Host "[ERROR] Inner exception: $($innerException.Message)" -ForegroundColor Red
                        $innerException = $innerException.InnerException
                    }
                    try {
                        $failedOperations = @(Get-AzResourceGroupDeploymentOperation `
                            -ResourceGroupName $ResourceGroupName -DeploymentName $deploymentName -ErrorAction Stop |
                            Where-Object { $_.ProvisioningState -eq 'Failed' -or $_.Properties.ProvisioningState -eq 'Failed' })
                        foreach($failedOperation in $failedOperations) {
                            $target = if($failedOperation.TargetResource) { $failedOperation.TargetResource } else { $failedOperation.Properties.TargetResource }
                            $statusMessage = if($failedOperation.StatusMessage) { $failedOperation.StatusMessage } else { $failedOperation.Properties.StatusMessage }
                            $statusText = if($statusMessage -is [string]) { $statusMessage } else { $statusMessage | ConvertTo-Json -Depth 20 -Compress }
                            $diagnostics += $statusText
                            Write-Host "[ERROR] Failed resource: $($target.ResourceType)/$($target.ResourceName)" -ForegroundColor Red
                            Write-Host "[ERROR] Provider details: $statusText" -ForegroundColor Red
                        }
                    } catch {
                        Write-Warning "Could not retrieve failed operations for deployment '$deploymentName': $($_.Exception.Message)"
                    }
                    $errorText = @(($deploymentError | Out-String)) + $diagnostics -join [Environment]::NewLine
                    $classification = if($errorText -match $transientPattern) { 'SameRegionTransient' }
                        elseif($errorText -match $regionRetryPattern) { 'RetryNextRegion' }
                        elseif($AssumeRetryableOnUnknown) { 'RetryNextRegion' }
                        else { 'Fatal' }
                    $attempts += [pscustomobject]@{
                        Location = $location; Phase = $phase; Outcome = 'Failed'
                        Classification = $classification; Duration = (Get-Date) - $startedAt
                        Error = $deploymentError.Exception.Message
                    }
                    if($classification -eq 'Fatal') { throw $deploymentError }
                    if($classification -eq 'SameRegionTransient' -and $sameRegionRetry -lt $SameRegionRetryBudget) {
                        $sameRegionRetry++
                        $delaySeconds = [math]::Pow(2, $sameRegionRetry)
                        Write-Warning "Transient deployment failure in '$location'. Retrying in $delaySeconds seconds."
                        Start-Sleep -Seconds $delaySeconds
                        continue
                    }
                    $moveToNextRegion = $true
                    break
                }
            }
            if($moveToNextRegion -and $recycleCurrentRegion) {
                $phase = 'Recycle'
                $recycleCurrentRegion = $false
                $moveToNextRegion = $false
            } else { break }
        } while($true)
    }

    $summary = $attempts | ForEach-Object { "{0}/{1}: {2}" -f $_.Location, $_.Phase, $_.Classification }
    throw "RegionFallbackExhausted: Deployment failed in all preferred locations. $($summary -join '; ')"
}

& "$PSScriptRoot\deploy-lab.ps1" `
    -DeploymentType 'resourcegroup' `
    -SubscriptionId $SubscriptionId `
    -ResourceGroupName $ResourceGroupName `
    -PreferredLocation @("swedencentral", "germanywestcentral", "francecentral") `
    -AllowedEntraUserIds $AllowedEntraUserIds
