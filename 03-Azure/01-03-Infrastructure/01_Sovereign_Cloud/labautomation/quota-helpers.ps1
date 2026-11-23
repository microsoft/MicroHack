function Get-MhhResponseHeaderValue {
    param(
        [System.Net.Http.Headers.HttpResponseHeaders]$Headers,
        [string]$Name
    )

    $header = $Headers | Where-Object { $_.Key -ieq $Name } | Select-Object -First 1
    return @($header.Value)[0]
}

function Get-MhhSovereignComputeRequirements {
    param([Parameter(Mandatory)][string]$ConfidentialQuotaName)

    $generalVcpus = (2 + 1) * 4
    $confidentialVcpus = 2 * 2
    @(
        @{ Name = $ConfidentialQuotaName; PerParticipant = $confidentialVcpus }
        @{ Name = 'StandardDSv5Family'; PerParticipant = $generalVcpus }
        @{ Name = 'cores'; PerParticipant = $generalVcpus + $confidentialVcpus }
    )
}

function Get-MhhConfidentialComputeCandidates {
    param(
        [string[]]$PreferredLocation
    )

    $families = @(
        [PSCustomObject]@{
            VmSize = 'Standard_DC2as_v5'
            QuotaName = 'standardDCASv5Family'
        }
        [PSCustomObject]@{
            VmSize = 'Standard_DC2as_v6'
            QuotaName = 'standardDCasv6Family'
        }
    )

    foreach($family in $families) {
        foreach($location in $PreferredLocation) {
            [PSCustomObject]@{
                Location = $location
                VmSize = $family.VmSize
                QuotaName = $family.QuotaName
            }
        }
    }
}

function Set-MhhConfidentialComputeSelection {
    param(
        [string]$SubscriptionId,
        [PSCustomObject]$Candidate
    )

    $subscriptionResourceId = "/subscriptions/$SubscriptionId"
    Update-AzTag -ResourceId $subscriptionResourceId -Operation Merge -Tag @{
        'microhack-sovereign-location' = $Candidate.Location
        'microhack-sovereign-confidential-vm-size' = $Candidate.VmSize
        'microhack-sovereign-confidential-quota' = $Candidate.QuotaName
    } -ErrorAction Stop | Out-Null
}

function Get-MhhConfidentialComputeSelection {
    param(
        [string]$SubscriptionId
    )

    $subscriptionResourceId = "/subscriptions/$SubscriptionId"
    $tags = (Get-AzTag -ResourceId $subscriptionResourceId -ErrorAction Stop).Properties.TagsProperty
    if(-not $tags) {
        return $null
    }

    return [PSCustomObject]@{
        Location = $tags.'microhack-sovereign-location'
        VmSize = $tags.'microhack-sovereign-confidential-vm-size'
        QuotaName = $tags.'microhack-sovereign-confidential-quota'
    }
}

function Get-MhhSovereignArmData {
    param([Parameter(Mandatory)][string]$Path)

    do {
        $arguments = @{ Method = 'GET'; ErrorAction = 'Stop' }
        if ($Path.StartsWith('https://')) { $arguments.Uri = $Path }
        else { $arguments.Path = $Path }
        $response = Invoke-AzRestMethod @arguments
        if ($response.StatusCode -ne 200) {
            throw "Unable to inventory existing lab compute: GET $Path returned HTTP $($response.StatusCode)."
        }
        $data = $response.Content | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $data) { throw "Empty compute inventory response from $Path." }
        if ($data.PSObject.Properties.Name -contains 'value') {
            if ($null -eq $data.value) { throw "Invalid compute inventory collection from $Path." }
            $data.value
        }
        else { $data }
        $Path = $data.nextLink
    } while ($Path)
}

function Test-MhhSovereignAllocatedInstance {
    param($Statuses, [string]$ResourceId)

    $power = @($Statuses | Where-Object { $_.code -like 'PowerState/*' })
    if ($power.Count -ne 1) {
        Write-Warning "No unambiguous power state for $ResourceId; not crediting it against new compute quota."
        return $false
    }
    return $power[0].code -in @('PowerState/running', 'PowerState/stopped')
}

function Get-MhhSovereignExistingCompute {
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [string[]]$NameSuffixes = @(),
        [string]$ResourceGroupName
    )

    $scope = "/subscriptions/$SubscriptionId"
    $resources = @()
    foreach ($kind in @(
        @{ Type = 'Microsoft.Compute/virtualMachines'; Version = '2024-11-01'; Prefix = 'vm-k3s-' },
        @{ Type = 'Microsoft.ContainerService/managedClusters'; Version = '2024-10-01'; Prefix = 'aks-sovereign-' },
        @{ Type = 'Microsoft.Network/virtualNetworks'; Version = '2024-05-01'; Prefix = 'vnet-sovereign-' }
    )) {
        $names = @($NameSuffixes | ForEach-Object { "$($kind.Prefix)$_" })
        $listed = @(Get-MhhSovereignArmData -Path "$scope/providers/$($kind.Type)?api-version=$($kind.Version)")
        if (-not $NameSuffixes.Count -and @($listed | Where-Object { $_.tags.workload -eq 'sovereign-lab' }).Count) {
            throw 'Participant IDs are required to safely account for existing Sovereign Cloud labs.'
        }
        $resources += @($listed | Where-Object {
            $_.name -iin $names -and
            (-not $ResourceGroupName -or $_.id.Split('/')[4] -ieq $ResourceGroupName)
        })
    }
    foreach ($resource in $resources) {
        if ($resource.tags.workload -ne 'sovereign-lab') {
            throw "Existing resource $($resource.id) does not carry the expected sovereign-lab ownership tag."
        }
    }
    $duplicates = @($resources | Group-Object type, name | Where-Object Count -gt 1)
    if ($duplicates.Count) { throw 'Ambiguous participant compute names across resource groups; refusing quota reuse.' }

    $allocations = @()
    $confidentialSizes = @()
    $clusters = @($resources | Where-Object type -eq 'Microsoft.ContainerService/managedClusters')
    $scaleSets = if ($clusters.Count) {
        @(Get-MhhSovereignArmData -Path "$scope/providers/Microsoft.Compute/virtualMachineScaleSets?api-version=2024-11-01")
    } else { @() }
    foreach ($vm in @($resources | Where-Object type -eq 'Microsoft.Compute/virtualMachines')) {
        if ($vm.properties.hardwareProfile.vmSize -ine 'Standard_D4s_v5') {
            throw "Existing K3s VM $($vm.id) has an incompatible size; refusing automatic resize or quota reuse."
        }
        $view = Get-MhhSovereignArmData -Path "$($vm.id)/instanceView?api-version=2024-11-01"
        if (Test-MhhSovereignAllocatedInstance -Statuses $view.statuses -ResourceId $vm.id) {
            $allocations += [pscustomobject]@{ Location = $vm.location; VmSize = 'Standard_D4s_v5'; Count = 1 }
        }
    }
    foreach ($cluster in $clusters) {
        foreach ($poolName in @('system', 'cvmnodepool')) {
            $pool = @($cluster.properties.agentPoolProfiles | Where-Object name -eq $poolName)
            if (-not $pool.Count) { continue }
            if ($pool.Count -ne 1) { throw "Ambiguous $poolName pool on $($cluster.id)." }
            $size = $pool[0].vmSize
            if (($poolName -eq 'system' -and $size -ine 'Standard_D4s_v5') -or
                ($poolName -eq 'cvmnodepool' -and $size -inotin @('Standard_DC2as_v5', 'Standard_DC2as_v6'))) {
                throw "Existing AKS pool $($cluster.id)/$poolName has an incompatible size."
            }
            if ($poolName -eq 'cvmnodepool') { $confidentialSizes += $size }
            $allocated = 0
            foreach ($scaleSet in @($scaleSets | Where-Object {
                $_.id.Split('/')[4] -ieq $cluster.properties.nodeResourceGroup -and
                $_.tags.'aks-managed-poolName' -eq $poolName
            })) {
                if ($scaleSet.sku.name -ine $size -or $scaleSet.location -ine $cluster.location) {
                    throw "Existing AKS scale set $($scaleSet.id) conflicts with its pool configuration."
                }
                $instances = @(Get-MhhSovereignArmData -Path "$($scaleSet.id)/virtualMachines?api-version=2024-11-01&`$expand=instanceView")
                foreach ($instance in $instances) {
                    if (Test-MhhSovereignAllocatedInstance -Statuses $instance.properties.instanceView.statuses -ResourceId $instance.id) {
                        $allocated++
                    }
                }
            }
            # Do not let surge nodes or an oversized pool pay for another participant's missing nodes.
            $allocations += [pscustomobject]@{ Location = $cluster.location; VmSize = $size; Count = [Math]::Min(2, $allocated) }
        }
    }
    return [pscustomobject]@{
        Resources = $resources
        Allocations = $allocations
        ConfidentialVmSizes = @($confidentialSizes | Select-Object -Unique)
    }
}

function Get-MhhSovereignResumeCandidate {
    param([string]$SubscriptionId, $ExistingCompute)

    $selection = Get-MhhConfidentialComputeSelection -SubscriptionId $SubscriptionId
    if (-not $selection.Location -and -not $selection.VmSize -and -not $selection.QuotaName) {
        if ($ExistingCompute.Resources.Count) {
            throw 'Existing lab resources have no saved compute selection. Restore the subscription selection tags before retrying.'
        }
        return $null
    }
    $candidate = @(Get-MhhConfidentialComputeCandidates -PreferredLocation @($selection.Location) | Where-Object {
        $_.Location -and $_.VmSize -ieq $selection.VmSize -and $_.QuotaName -ieq $selection.QuotaName
    })
    if ($candidate.Count -ne 1) { throw 'The saved compute selection is invalid; refusing to relocate existing labs.' }
    if (@($ExistingCompute.Resources | Where-Object { $_.location -ine $selection.Location }).Count -or
        @($ExistingCompute.ConfidentialVmSizes | Where-Object { $_ -ine $selection.VmSize }).Count) {
        throw 'Existing lab regions or confidential VM sizes conflict with the saved compute selection; refusing to relocate or resize labs.'
    }
    return $candidate[0]
}

function Get-MhhSovereignAdditionalCompute {
    param(
        [Parameter(Mandatory)]$Candidate,
        [Parameter(Mandatory)]$ExistingCompute,
        [ValidateRange(1, 100000)][int]$ParticipantCount = 1
    )

    $credited = @{ StandardDSv5Family = 0; cores = 0 }
    $credited[$Candidate.QuotaName] = 0
    foreach ($allocation in $ExistingCompute.Allocations) {
        if ($allocation.Location -ine $Candidate.Location) { continue }
        if ($allocation.VmSize -ieq 'Standard_D4s_v5') {
            $credited.StandardDSv5Family += 4 * $allocation.Count
            $credited.cores += 4 * $allocation.Count
        }
        elseif ($allocation.VmSize -ieq $Candidate.VmSize) {
            $credited[$Candidate.QuotaName] += 2 * $allocation.Count
            $credited.cores += 2 * $allocation.Count
        }
    }
    foreach ($requirement in @(Get-MhhSovereignComputeRequirements -ConfidentialQuotaName $Candidate.QuotaName)) {
        $desired = $requirement.PerParticipant * $ParticipantCount
        [pscustomobject]@{
            Name = $requirement.Name
            Desired = $desired
            Existing = [Math]::Min($desired, $credited[$requirement.Name])
            Additional = [Math]::Max(0, $desired - $credited[$requirement.Name])
        }
    }
}

function Wait-MhhQuotaRequest {
    param(
        [string]$OperationStatusUrl,
        [int]$RetryAfterSeconds = 5,
        [int]$MaxAttempts = 20
    )

    for($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Start-Sleep -Seconds $RetryAfterSeconds
        try {
            $response = Invoke-AzRestMethod -Uri $OperationStatusUrl -Method GET -ErrorAction Stop
        } catch {
            return [PSCustomObject]@{
                Succeeded = $false
                State = 'StatusCheckFailed'
                ErrorCode = 'QuotaStatusException'
                Message = $_.Exception.Message
            }
        }

        if($response.StatusCode -eq 202) {
            Write-Host "Quota request is still processing ($attempt/$MaxAttempts)..."
            continue
        }

        if($response.StatusCode -ne 200) {
            return [PSCustomObject]@{
                Succeeded = $false
                State = 'StatusCheckFailed'
                ErrorCode = "Http$($response.StatusCode)"
                Message = 'The quota request status endpoint returned an unexpected response.'
            }
        }

        $content = $response.Content | ConvertFrom-Json
        $state = $content.properties.provisioningState

        if($state -in @('InProgress', 'Accepted', 'Running')) {
            Write-Host "Quota request is still processing ($attempt/$MaxAttempts)..."
            continue
        }

        $error = if($content.properties.error) { $content.properties.error } else { $content.error }
        $errorCode = if($error.code) { $error.code } else { $content.properties.errorCode }
        $message = if($error.message) {
            $error.message
        } elseif($content.properties.message) {
            $content.properties.message
        } elseif($content.properties.errorMessage) {
            $content.properties.errorMessage
        } else {
            "Quota request ended in state '$state' without error details."
        }

        return [PSCustomObject]@{
            Succeeded = $state -eq 'Succeeded'
            State = $state
            ErrorCode = $errorCode
            Message = $message
        }
    }

    return [PSCustomObject]@{
        Succeeded = $false
        State = 'TimedOut'
        ErrorCode = 'QuotaRequestTimeout'
        Message = "Quota request did not complete after $MaxAttempts status checks."
    }
}

function Request-MhhComputeQuota {
    param(
        [string]$SubscriptionId,
        [string]$Location,
        [string]$QuotaName,
        [int]$NewLimit
    )

    $scope = "subscriptions/$SubscriptionId/providers/Microsoft.Compute/locations/$Location"
    $path = "/$scope/providers/Microsoft.Quota/quotas/${QuotaName}?api-version=2023-02-01"
    $payload = @{
        properties = @{
            name = @{ value = $QuotaName }
            limit = @{
                limitObjectType = 'LimitValue'
                value = $NewLimit
            }
        }
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-AzRestMethod -Path $path -Method PUT -Payload $payload -ErrorAction Stop
    } catch {
        return [PSCustomObject]@{
            Succeeded = $false
            State = 'RequestFailed'
            ErrorCode = 'QuotaRequestException'
            Message = $_.Exception.Message
        }
    }
    if($response.StatusCode -eq 200) {
        return [PSCustomObject]@{
            Succeeded = $true
            State = 'Succeeded'
            ErrorCode = $null
            Message = 'Quota limit updated.'
        }
    }

    if($response.StatusCode -ne 202) {
        return [PSCustomObject]@{
            Succeeded = $false
            State = 'RequestFailed'
            ErrorCode = "Http$($response.StatusCode)"
            Message = $response.Content
        }
    }

    $locationHeader = Get-MhhResponseHeaderValue -Headers $response.Headers -Name 'Location'
    if(-not $locationHeader) {
        return [PSCustomObject]@{
            Succeeded = $false
            State = 'MissingStatusUrl'
            ErrorCode = 'MissingLocationHeader'
            Message = 'Azure accepted the quota request but did not return a status URL.'
        }
    }

    $retryAfter = Get-MhhResponseHeaderValue -Headers $response.Headers -Name 'Retry-After'
    $retryAfterSeconds = if($retryAfter -as [int]) { [int]$retryAfter } else { 5 }
    return Wait-MhhQuotaRequest `
        -OperationStatusUrl $locationHeader `
        -RetryAfterSeconds $retryAfterSeconds
}