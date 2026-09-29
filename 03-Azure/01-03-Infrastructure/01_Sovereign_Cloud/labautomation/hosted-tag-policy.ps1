function Initialize-MhhHostedTagPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,

        [Parameter(Mandatory)]
        [string]$Location
    )

    Update-MhhToken | Out-Null
    $context = Get-AzContext -ErrorAction Stop
    if ($context.Subscription.Id -ne $SubscriptionId) {
        throw "The Azure context must target hosted subscription $SubscriptionId before assigning the tag initiative."
    }

    Write-Host "Assigning hosted MCAPS control-tag initiative in subscription $SubscriptionId..."
    $deployment = New-AzSubscriptionDeployment `
        -Name "sov-hosted-tags-$Location" `
        -Location $Location `
        -TemplateFile (Join-Path $PSScriptRoot 'infra/hosted-tag-policy.bicep') `
        -ErrorAction Stop
    if ($deployment.ProvisioningState -ne 'Succeeded') {
        throw "Hosted control-tag policy deployment did not succeed: $($deployment.ProvisioningState)."
    }

    $probeGroupName = "rg-sov-tag-check-$([guid]::NewGuid().ToString('N'))"
    $probeTags = @{ MicroHackPurpose = 'HostedTagPolicyCheck' }
    $probeGroupCreated = $false
    try {
        for ($attempt = 1; $attempt -le 30; $attempt++) {
            Update-MhhToken | Out-Null
            # Omit both control tags so the read-back verifies policy, not the request.
            New-AzResourceGroup -Name $probeGroupName -Location $Location `
                -Tag $probeTags -Force -ErrorAction Stop | Out-Null
            $probeGroupCreated = $true
            New-AzNetworkSecurityGroup -Name 'tag-policy-check' -ResourceGroupName $probeGroupName `
                -Location $Location -Tag $probeTags -Force -ErrorAction Stop | Out-Null

            $group = Get-AzResourceGroup -Name $probeGroupName -ErrorAction Stop
            $resource = Get-AzNetworkSecurityGroup -Name 'tag-policy-check' `
                -ResourceGroupName $probeGroupName -ErrorAction Stop
            $ready = $true
            foreach ($target in @($group, $resource)) {
                if ($target.Tags.SecurityControl -cne 'Ignore' -or
                    $target.Tags.CostControl -cne 'Ignore' -or
                    $target.Tags.MicroHackPurpose -cne $probeTags.MicroHackPurpose) {
                    $ready = $false
                }
            }
            if ($ready) {
                Write-Host 'Hosted control-tag policies are effective for resource groups and resources.' -ForegroundColor Green
                return
            }
            if ($attempt -lt 30) {
                Write-Host "Waiting for hosted control-tag policy propagation ($attempt/30)..."
                Start-Sleep -Seconds 10
            }
        }
        throw 'Hosted control-tag policies did not apply both Ignore tags after 30 attempts. Stop provisioning and inspect the subscription policy assignment.'
    }
    finally {
        if ($probeGroupCreated) {
            Update-MhhToken | Out-Null
            Remove-AzResourceGroup -Name $probeGroupName -Force -ErrorAction Stop | Out-Null
        }
    }
}
