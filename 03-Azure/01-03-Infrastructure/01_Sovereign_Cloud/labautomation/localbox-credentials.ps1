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
            throw "LocalBox deployment '$DeploymentName' ended as $($deployment.ProvisioningState)."
        }
        if ((Get-Date -AsUTC) -ge $deadline) {
            throw "Timed out waiting for LocalBox deployment '$DeploymentName'. Rerun the shared hook after investigating the deployment."
        }
        Write-Host "Waiting for LocalBox ARM deployment '$DeploymentName' ($($deployment.ProvisioningState))..."
        Start-Sleep -Seconds 30
    } while ($true)
}