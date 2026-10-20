function Initialize-MhhHostedDefender {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )

    $request = {
        param([string]$Path, [string]$Method, [hashtable]$Body)
        Update-MhhToken | Out-Null
        $context = Get-AzContext -ErrorAction Stop
        if ($context.Subscription.Id -ne $SubscriptionId) {
            throw "The Azure context must target hosted subscription $SubscriptionId before configuring Defender."
        }
        $arguments = @{ Path = $Path; Method = $Method; ErrorAction = 'Stop' }
        if ($null -ne $Body) {
            $arguments.Payload = $Body | ConvertTo-Json -Depth 30 -Compress
        }
        $response = Invoke-AzRestMethod @arguments
        $expectedStatus = if ($Method -eq 'PUT') { @(200, 201) } else { @(200) }
        if ($response.StatusCode -notin $expectedStatus) {
            throw "Defender $Method $Path failed (HTTP $($response.StatusCode)): $($response.Content)"
        }
        $response.Content | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }

    $basePath = "/subscriptions/$SubscriptionId/providers/Microsoft.Security"
    $pricingPath = "$basePath/pricings/VirtualMachines?api-version=2024-01-01"
    $endpointPath = "$basePath/settings/WDATP?api-version=2021-06-01"
    Write-Host "Enabling paid Defender for Servers P2 and Endpoint protection in hosted subscription $SubscriptionId..."
    $pricing = & $request $pricingPath 'GET'
    if (-not $pricing.properties -or -not $pricing.properties.pricingTier) {
        throw 'Defender pricing response is missing properties.pricingTier.'
    }
    if ($pricing.properties.pricingTier -ne 'Standard' -or $pricing.properties.subPlan -ne 'P2') {
        $properties = @{ pricingTier = 'Standard'; subPlan = 'P2' }
        if ($pricing.properties.ContainsKey('enforce')) {
            $properties.enforce = $pricing.properties.enforce
        }
        if ($pricing.properties.ContainsKey('extensions')) {
            # Preserve configured extensions, excluding read-only operation status.
            $properties.extensions = @(
                foreach ($extension in $pricing.properties.extensions) {
                    $item = @{ name = $extension.name; isEnabled = $extension.isEnabled }
                    if ($extension.ContainsKey('additionalExtensionProperties')) {
                        $item.additionalExtensionProperties = $extension.additionalExtensionProperties
                    }
                    $item
                }
            )
        }
        & $request $pricingPath 'PUT' @{ properties = $properties } | Out-Null
    }

    & $request $endpointPath 'PUT' @{
        kind = 'DataExportSettings'
        properties = @{ enabled = $true }
    } | Out-Null

    for ($attempt = 1; $attempt -le 12; $attempt++) {
        $pricing = & $request $pricingPath 'GET'
        $endpoint = & $request $endpointPath 'GET'
        if ($pricing.properties.pricingTier -eq 'Standard' -and
            $pricing.properties.subPlan -eq 'P2' -and
            $endpoint.properties.enabled -is [bool] -and $endpoint.properties.enabled) {
            Write-Host 'Verified Defender for Servers P2 and Endpoint protection. VM onboarding must still be validated.' -ForegroundColor Green
            return
        }
        if ($attempt -lt 12) {
            Write-Host "Waiting for Defender settings propagation ($attempt/12)..."
            Start-Sleep -Seconds 10
        }
    }
    throw "Defender verification failed in subscription $SubscriptionId after 12 attempts: tier=$($pricing.properties.pricingTier), plan=$($pricing.properties.subPlan), Endpoint protection=$($endpoint.properties.enabled). Stop provisioning and inspect Defender environment settings."
}
