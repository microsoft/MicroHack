function Get-LocalBoxConsoleGroupCredential {
    [CmdletBinding()]
    param()

    $group = Get-MhhDefaultLabGroup -ErrorAction Stop
    $objectId = [guid]::Empty
    if (-not [guid]::TryParse([string]$group.ObjectId, [ref]$objectId) -or $objectId -eq [guid]::Empty -or
        [string]::IsNullOrWhiteSpace($group.GroupName) -or [string]::IsNullOrWhiteSpace($group.DisplayName)) {
        throw 'Console did not return a valid default lab group. Complete Entra user/group creation before shared deployment.'
    }

    @{ HackboxCredential = @{ name = 'Lab Group ObjectId'; value = [string]$group.ObjectId; note = 'Use as AksAdminGroupObjectId for LocalBox preparation' } }
    @{ HackboxCredential = @{ name = 'Lab Group GroupName'; value = $group.GroupName; note = '' } }
    @{ HackboxCredential = @{ name = 'Lab Group DisplayName'; value = $group.DisplayName; note = '' } }
}

function Get-LocalBoxDeploymentFailure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$DeploymentName,
        [ValidateRange(0, 5)][int]$Depth = 0
    )

    Update-MhhToken | Out-Null
    $operations = @(Get-AzResourceGroupDeploymentOperation -ResourceGroupName $ResourceGroupName -DeploymentName $DeploymentName -ErrorAction Stop |
        Where-Object { $_.Properties.ProvisioningState -eq 'Failed' })
    if (-not $operations.Count) {
        return [pscustomobject]@{ Code = 'UnknownDeploymentFailure'; Message = 'No failed operation details were returned; inspect the deployment in Azure.' }
    }
    foreach ($operation in $operations) {
        $status = $operation.Properties.StatusMessage
        if ($status -is [string]) {
            $status = $status | ConvertFrom-Json -ErrorAction Stop
        }
        $pending = [Collections.Generic.Queue[object]]::new()
        if ($status.error) { $pending.Enqueue($status.error) }
        $details = @(
            while ($pending.Count) {
                $errorDetail = $pending.Dequeue()
                if ($errorDetail.details.Count) {
                    foreach ($child in $errorDetail.details) { $pending.Enqueue($child) }
                }
                else {
                    [pscustomobject]@{ Code = [string]$errorDetail.code; Message = [string]$errorDetail.message }
                }
            }
        )
        $target = $operation.Properties.TargetResource
        if ($Depth -lt 5 -and $target.ResourceType -eq 'Microsoft.Resources/deployments' -and
            $target.Id -match "^/subscriptions/$([regex]::Escape((Get-AzContext -ErrorAction Stop).Subscription.Id))/resourceGroups/$([regex]::Escape($ResourceGroupName))/providers/Microsoft.Resources/deployments/[^/]+$" -and
            ($details.Count -eq 0 -or @($details | Where-Object { $_.Code -notin @('DeploymentFailed', 'InvalidTemplateDeployment') }).Count -eq 0)) {
            Get-LocalBoxDeploymentFailure -ResourceGroupName $ResourceGroupName -DeploymentName $target.ResourceName -Depth ($Depth + 1)
        }
        elseif ($details.Count) { $details }
        else {
            [pscustomobject]@{ Code = 'UnknownDeploymentFailure'; Message = 'Failed operation has no usable error details; inspect the deployment in Azure.' }
        }
    }
}

function Test-LocalBoxCapacityFailure {
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$Failure)

    if ($Failure.Exception.Data.Contains('LocalBoxCapacityFailure')) {
        return $Failure.Exception.Data['LocalBoxCapacityFailure'] -eq $true
    }
    $message = "$($Failure.Exception.Message) $($Failure.ErrorDetails.Message)"
    if ($message -match 'AuthorizationFailed|Forbidden|RequestDisallowedByPolicy|InvalidAuthenticationToken') { return $false }
    return $message -match '\b(SkuNotAvailable|AllocationFailed|ZonalAllocationFailed|QuotaExceeded)\b|VM size .+ unavailable|At least 32 unused'
}

function Wait-LocalBoxDeployment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$DeploymentName,
        [ValidateRange(1, 21600)][int]$TimeoutSeconds = 21600
    )

    $deadline = (Get-Date -AsUTC).AddSeconds($TimeoutSeconds)
    do {
        Update-MhhToken | Out-Null
        $deployment = Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Name $DeploymentName -ErrorAction Stop
        if ($deployment.ProvisioningState -eq 'Succeeded') {
            break
        }
        if ($deployment.ProvisioningState -in @('Failed', 'Canceled')) {
            $failure = [InvalidOperationException]::new("LocalBox deployment '$DeploymentName' ended as $($deployment.ProvisioningState).")
            $failure.Data['LocalBoxCapacityFailure'] = $false
            if ($deployment.ProvisioningState -eq 'Failed') {
                try {
                    $details = @(Get-LocalBoxDeploymentFailure -ResourceGroupName $ResourceGroupName -DeploymentName $DeploymentName)
                    $summary = ($details | ForEach-Object { "[$($_.Code)] $($_.Message)" }) -join '; '
                    $failure = [InvalidOperationException]::new("$($failure.Message) $(ConvertTo-LocalBoxDiagnosticText $summary 2000)")
                    $failure.Data['LocalBoxCapacityFailure'] = $details.Count -gt 0 -and
                        @($details | Where-Object { $_.Code -notin @('SkuNotAvailable', 'AllocationFailed', 'ZonalAllocationFailed', 'QuotaExceeded') }).Count -eq 0
                }
                catch {
                    $failure = [InvalidOperationException]::new("$($failure.Message) Could not retrieve deployment failure details: $(ConvertTo-LocalBoxDiagnosticText $_.Exception.Message 400). Inspect Azure deployment operations before retrying.")
                    $failure.Data['LocalBoxCapacityFailure'] = $false
                }
            }
            throw $failure
        }
        if ((Get-Date -AsUTC) -ge $deadline) {
            throw "Timed out waiting for LocalBox deployment '$DeploymentName'. Rerun the global event hook after investigating the deployment."
        }
        Write-Host "Waiting for LocalBox ARM deployment '$DeploymentName' ($($deployment.ProvisioningState))..."
        Start-Sleep -Seconds 30
    } while ($true)
}