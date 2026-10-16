# Portable copy of 03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/labautomation/hosted-tag-policy.ps1
# at d3e446889384325605e5db7e4e61ab1ed8af2cfd. Original names intentionally retained for reuse.
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
            # Az.Resources exposes Tags; Az.Network exposes Tag (singular).
            $targets = @(
                @{ Name = 'resource group'; Tags = $group.Tags }
                @{ Name = 'network security group'; Tags = $resource.Tag }
            )
            $mismatches = @(
                foreach ($target in $targets) {
                    foreach ($tagName in @('SecurityControl', 'CostControl', 'MicroHackPurpose')) {
                        $expected = if ($tagName -eq 'MicroHackPurpose') { $probeTags.MicroHackPurpose } else { 'Ignore' }
                        $actual = if ($null -ne $target.Tags) { $target.Tags[$tagName] } else { $null }
                        if ($actual -cne $expected) {
                            $observed = if ($null -eq $actual) { '<missing>' } else { $actual }
                            "$($target.Name)/${tagName}: expected '$expected', observed '$observed'"
                        }
                    }
                }
            )
            if ($mismatches.Count -eq 0) {
                Write-Host 'Hosted control-tag policies are effective for resource groups and resources.' -ForegroundColor Green
                return
            }
            if ($attempt -lt 30) {
                Write-Host "Waiting for hosted control-tag policy propagation ($attempt/30): $($mismatches -join '; ')"
                Start-Sleep -Seconds 10
            }
        }
        throw "Hosted control-tag policy verification failed after 30 attempts in subscription ${SubscriptionId}: $($mismatches -join '; '). Stop provisioning and inspect assignment sov-hosted-control-tags."
    }
    finally {
        if ($probeGroupCreated) {
            Update-MhhToken | Out-Null
            Remove-AzResourceGroup -Name $probeGroupName -Force -ErrorAction Stop | Out-Null
        }
    }
}
