function Get-MhhResponseHeaderValue {
    param(
        [System.Net.Http.Headers.HttpResponseHeaders]$Headers,
        [string]$Name
    )

    $header = $Headers | Where-Object { $_.Key -ieq $Name } | Select-Object -First 1
    return @($header.Value)[0]
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