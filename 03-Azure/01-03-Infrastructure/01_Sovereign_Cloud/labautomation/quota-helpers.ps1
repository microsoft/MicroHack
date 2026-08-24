function Get-MhhResponseHeaderValue {
    param(
        [System.Net.Http.Headers.HttpResponseHeaders]$Headers,
        [string]$Name
    )

    $header = $Headers | Where-Object { $_.Key -ieq $Name } | Select-Object -First 1
    return @($header.Value)[0]
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
        return [PSCustomObject]@{
            Succeeded = $state -eq 'Succeeded'
            State = $state
            ErrorCode = $content.properties.error.code
            Message = if($content.properties.error.message) {
                $content.properties.error.message
            } else {
                $content.properties.message
            }
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