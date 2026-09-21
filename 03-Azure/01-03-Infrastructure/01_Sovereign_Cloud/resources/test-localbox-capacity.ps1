#Requires -Version 7.0
<#
.SYNOPSIS
Creates bounded, disposable Azure Local VM capacity tests on LocalBox-Client.
.DESCRIPTION
Uses existing Azure CLI authentication and the preparation manifest. Does not change
shared infrastructure, authentication, Defender plans or update policy.
Dot-source to load functions without provisioning.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Deploy', 'Status', 'Cleanup')][string]$Mode = 'Deploy',
    [string]$LocalBoxManifestPath = 'C:\LocalBox\sovereign-localbox.json',
    [string]$StatePath = 'C:\LocalBox\capacity-test\run.json',
    [string]$RemoteClusterId,
    [switch]$GenerateVmCredential,
    [switch]$SubmitNext,
    [switch]$SubmitBatch,
    [ValidateRange(1, 5)][int]$BatchSize = 1,
    [ValidateRange(1, 50)][int]$VmCount = 5,
    [ValidateRange(1, 8)][int]$ProcessorCount = 2,
    [ValidateRange(2048, 16384)][int]$MemoryMB = 4096,
    [ValidateRange(200, 2048)][int]$MinimumHostFreeGB = 300,
    [ValidateRange(100, 1024)][int]$MinimumCsvFreeGB = 150,
    [ValidateRange(8, 64)][int]$MinimumNodeFreeGB = 12,
    [ValidateRange(32, 256)][int]$DiskBudgetGB = 40,
    [ValidateRange(5, 120)][int]$TimeoutMinutes = 30,
    [pscredential]$VmCredential,
    [pscredential]$NodeCredential
)

function Get-LocalBoxCapacitySnapshot {
    param([hashtable]$LocalBox, [pscredential]$Credential)
    if ($LocalBox.RemoteClusterId) {
        return (Get-LocalBoxRemoteCapacityContext $LocalBox.RemoteClusterId $LocalBox.RemoteManifestPath).Snapshot
    }
    $volume = Get-Volume -DriveLetter V -ErrorAction Stop
    $nodes = @(foreach ($node in $LocalBox.NodeNames) {
        Invoke-Command -VMName $node -Credential $Credential -ErrorAction Stop -ScriptBlock {
            $ErrorActionPreference = 'Stop'
            $os = Get-CimInstance Win32_OperatingSystem
            $disk = Get-VirtualDisk -FriendlyName 'UserStorage_1'
            $csv = Get-Volume -FileSystemLabel 'UserStorage_1'
            $pool = Get-StoragePool -FriendlyName 'SU1_Pool'
            [pscustomobject]@{
                Name = $env:COMPUTERNAME
                FreeMemoryGB = $os.FreePhysicalMemory / 1MB
                TotalMemoryGB = $os.TotalVisibleMemorySize / 1MB
                CpuPercent = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
                CsvFreeGB = $csv.SizeRemaining / 1GB
                Copies = $disk.NumberOfDataCopies
                Healthy = $disk.HealthStatus -eq 'Healthy' -and $csv.HealthStatus -eq 'Healthy' -and
                    $pool.HealthStatus -eq 'Healthy' -and
                    @(Get-ClusterNode | Where-Object State -ne 'Up').Count -eq 0 -and
                    @(Get-StorageJob | Where-Object JobState -ne 'Completed').Count -eq 0
            }
        }
    })
    @{
        Timestamp = [datetime]::UtcNow.ToString('o')
        HostFreeGB = $volume.SizeRemaining / 1GB
        HostHealthy = $volume.HealthStatus -eq 'Healthy'
        Nodes = $nodes
    }
}

function Get-LocalBoxRemoteCapacityContext {
    param([string]$ClusterId, [string]$ManifestPath)
    if ($ClusterId -notmatch '^/subscriptions/([a-f0-9-]{36})/resourceGroups/([a-zA-Z0-9_.()-]+)/providers/Microsoft\.AzureStackHCI/clusters/[a-zA-Z0-9-]+$') {
        throw 'RemoteClusterId must identify the exact Azure Local cluster.'
    }
    $subscription = $Matches[1]
    $resourceGroup = $Matches[2]
    $pathData = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ManifestPath))
    $clusterData = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ClusterId))
    $probe = "function Get-LocalBoxCapacitySnapshot {`n${function:Get-LocalBoxCapacitySnapshot}`n}`n" +
        "function Resolve-LocalBoxNodeCredential {`n${function:Resolve-LocalBoxNodeCredential}`n}`n" + @'
$ErrorActionPreference = 'Stop'
try {
    $manifestPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__PATH__'))
    $clusterId = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__CLUSTER__'))
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
    if ($manifest.ClusterId -ine $clusterId) { throw 'Target mismatch' }
    $configPath = [Environment]::GetEnvironmentVariable('LocalBoxConfigFile', 'Machine')
    if (-not $configPath) { $configPath = $env:LocalBoxConfigFile }
    $configuration = Import-PowerShellDataFile -LiteralPath $configPath
    $credential = Resolve-LocalBoxNodeCredential -Configuration $configuration
    $snapshot = Get-LocalBoxCapacitySnapshot $manifest $credential
    $snapshot.Nodes = @($snapshot.Nodes | Select-Object Name, FreeMemoryGB, TotalMemoryGB, CpuPercent, CsvFreeGB, Copies, Healthy)
    $summary = @{}
    foreach ($key in @('SubscriptionId', 'ResourceGroupName', 'ClusterId', 'CustomLocationId', 'StorageId', 'ImageId', 'NodeNames')) { $summary[$key] = $manifest[$key] }
    $summary.Networks = @($manifest.Networks | ForEach-Object { @{ Name = $_.Name; Id = $_.Id } })
    'LB_CAPACITY_BEGIN'
    @{ LocalBox = $summary; Snapshot = $snapshot } | ConvertTo-Json -Depth 8 -Compress
    'LB_CAPACITY_END'
}
catch { Write-Error 'LocalBox telemetry failed. Check the manifest, installed configuration and nested-node access on the target Client; no configuration or credential values are returned.'; exit 1 }
'@
    $probe = $probe.Replace('__PATH__', $pathData).Replace('__CLUSTER__', $clusterData)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($probe))
    $command = "& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoLogo -NoProfile -NonInteractive -EncodedCommand '$encoded'"
    Write-Host "Reading LocalBox headroom through Run Command on $resourceGroup/LocalBox-Client..."
    $result = Invoke-LocalBoxAz @('vm', 'run-command', 'invoke', '--subscription', $subscription,
        '--resource-group', $resourceGroup, '--name', 'LocalBox-Client', '--command-id', 'RunPowerShellScript', '--scripts', $command) -TimeoutSeconds 300
    $output = ($result.value.message -join "`n")
    if ($output -notmatch '(?s)LB_CAPACITY_BEGIN\s*(\{.*?\})\s*LB_CAPACITY_END') {
        throw 'Remote telemetry returned no complete result. No VM will be submitted; inspect Run Command on the target Client.'
    }
    $context = $Matches[1] | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    if ($context.LocalBox.ClusterId -ine $ClusterId -or $context.LocalBox.SubscriptionId -ine $subscription -or
        $context.LocalBox.ResourceGroupName -ine $resourceGroup) { throw 'Remote telemetry does not match the requested LocalBox scope.' }
    $context.LocalBox.RemoteClusterId = $ClusterId
    $context.LocalBox.RemoteManifestPath = $ManifestPath
    return $context
}

function Assert-LocalBoxCapacityHeadroom {
    param([hashtable]$Snapshot, [hashtable]$Limits, [ValidateRange(1, 5)][int]$AdditionalVMs = 1)
    if (-not $Snapshot.HostHealthy -or @($Snapshot.Nodes).Count -ne 2 -or
        @($Snapshot.Nodes | Where-Object { -not $_.Healthy }).Count) {
        throw 'Capacity test stopped: host storage or the two-node cluster is not healthy and idle.'
    }
    if (@($Snapshot.Nodes | Where-Object { $_.Copies -lt 2 }).Count) { throw 'Cannot establish the storage resiliency copy count; no VM was submitted.' }
    $copies = ($Snapshot.Nodes | Measure-Object Copies -Maximum).Maximum
    if ($Snapshot.HostFreeGB -lt ($Limits.MinimumHostFreeGB + $Limits.DiskBudgetGB * $copies * $AdditionalVMs)) {
        throw 'Capacity test stopped at the host backing-volume reserve (including mirrored disk growth).'
    }
    foreach ($node in $Snapshot.Nodes) {
        if ($node.CsvFreeGB -lt ($Limits.MinimumCsvFreeGB + $Limits.DiskBudgetGB * $AdditionalVMs)) {
            throw 'Capacity test stopped at the UserStorage_1 free-space reserve.'
        }
        if ($node.FreeMemoryGB -lt ($Limits.MinimumNodeFreeGB + $Limits.MemoryMB / 1024 * $AdditionalVMs)) {
            throw "Capacity test stopped at the memory reserve on $($node.Name)."
        }
    }
}

function New-LocalBoxCapacityTemplate {
    $machineId = "[resourceId('Microsoft.HybridCompute/machines', parameters('name'))]"
    $nicId = "[resourceId('Microsoft.AzureStackHCI/networkInterfaces', concat(parameters('name'), '-nic'))]"
    $extendedLocation = @{ type = 'CustomLocation'; name = "[parameters('customLocationId')]" }
    @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            name = @{ type = 'string'; maxLength = 15 }; location = @{ type = 'string' }
            customLocationId = @{ type = 'string' }; imageId = @{ type = 'string' }
            networkId = @{ type = 'string' }; storageId = @{ type = 'string' }
            processors = @{ type = 'int' }; memoryMB = @{ type = 'int' }
            adminUsername = @{ type = 'string' }; adminPassword = @{ type = 'securestring' }
            tags = @{ type = 'object' }
        }
        resources = @(
            @{
                type = 'Microsoft.HybridCompute/machines'; apiVersion = '2023-10-03-preview'
                name = "[parameters('name')]"; location = "[parameters('location')]"
                kind = 'HCI'; identity = @{ type = 'SystemAssigned' }; tags = "[parameters('tags')]"
            }
            @{
                type = 'Microsoft.AzureStackHCI/networkInterfaces'; apiVersion = '2024-01-01'
                name = "[concat(parameters('name'), '-nic')]"; location = "[parameters('location')]"
                extendedLocation = $extendedLocation; tags = "[parameters('tags')]"
                properties = @{ ipConfigurations = @(@{
                    name = 'ipconfig1'; properties = @{ subnet = @{ id = "[parameters('networkId')]" } }
                }) }
            }
            @{
                type = 'Microsoft.AzureStackHCI/virtualMachineInstances'; apiVersion = '2024-01-01'
                name = 'default'; scope = $machineId; extendedLocation = $extendedLocation
                dependsOn = @($machineId, $nicId)
                properties = @{
                    hardwareProfile = @{ vmSize = 'Custom'; processors = "[parameters('processors')]"; memoryMB = "[parameters('memoryMB')]" }
                    osProfile = @{
                        adminUsername = "[parameters('adminUsername')]"; adminPassword = "[parameters('adminPassword')]"
                        computerName = "[parameters('name')]"
                        windowsConfiguration = @{ provisionVMAgent = $true; provisionVMConfigAgent = $true }
                    }
                    storageProfile = @{ vmConfigStoragePathId = "[parameters('storageId')]"; imageReference = @{ id = "[parameters('imageId')]" } }
                    networkProfile = @{ networkInterfaces = @(@{ id = $nicId }) }
                }
            }
        )
    }
}

function Save-LocalBoxCapacityState {
    param([hashtable]$State, [string]$Path)
    $State.UpdatedAt = [datetime]::UtcNow.ToString('o')
    $fullPath = [IO.Path]::GetFullPath($Path)
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($fullPath)) | Out-Null
    $temporary = "$fullPath.tmp"
    [IO.File]::WriteAllText($temporary, ($State | ConvertTo-Json -Depth 30))
    [IO.File]::Move($temporary, $fullPath, $true)
    $State.VMs | ForEach-Object { [pscustomobject]$_ } |
        Export-Csv -LiteralPath ([IO.Path]::ChangeExtension($fullPath, '.csv')) -NoTypeInformation -WhatIf:$false -Confirm:$false
}

function Assert-LocalBoxCapacityOwnership {
    param([hashtable]$State, [hashtable]$LocalBox, $Group, [array]$Resources)
    if ($State.SchemaVersion -ne 1 -or $State.RunId -notmatch '^[a-f0-9]{32}$' -or
        $State.ResourceGroupName -cne "rg-lbcap-$($State.RunId)" -or
        $State.SubscriptionId -ine $LocalBox.SubscriptionId -or $State.ClusterId -ine $LocalBox.ClusterId -or
        $State.ResourceGroupName -ieq $LocalBox.ResourceGroupName) {
        throw 'Invalid capacity-test journal or mismatched LocalBox scope; refusing to manage resources.'
    }
    $groupId = "/subscriptions/$($State.SubscriptionId)/resourceGroups/$($State.ResourceGroupName)"
    if ($Group.id -ine $groupId -or $Group.tags.MicroHackPurpose -cne 'LocalBoxCapacityTest' -or
        $Group.tags.MicroHackRunId -cne $State.RunId) {
        throw 'Resource-group ownership tags do not match this capacity-test journal.'
    }
    $allowedIds = @()
    $machineIds = @()
    foreach ($entry in $State.VMs) {
        $index = [int]$entry.Index
        if ($index -lt 1 -or $index -gt 50 -or $entry.Name -cne ('lc{0}-{1:D3}' -f $State.RunId.Substring(0, 8), $index)) {
            throw 'Invalid VM name in capacity-test journal.'
        }
        $machineIds += "$groupId/providers/Microsoft.HybridCompute/machines/$($entry.Name)"
        $allowedIds += "$groupId/providers/Microsoft.AzureStackHCI/networkInterfaces/$($entry.Name)-nic"
        $allowedIds += "$groupId/providers/Microsoft.Resources/deployments/$($entry.Name)"
    }
    foreach ($resource in $Resources) {
        $owned = $resource.id -iin ($allowedIds + $machineIds)
        foreach ($machineId in $machineIds) {
            if ($resource.id -ieq "$machineId/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default" -or
                $resource.id.StartsWith("$machineId/extensions/", [StringComparison]::OrdinalIgnoreCase)) { $owned = $true }
        }
        if (-not $owned) { throw "Unrelated resource $($resource.id) found in the test group; refusing modification or cleanup." }
    }
}

function Submit-LocalBoxCapacityVM {
    param([hashtable]$State, [hashtable]$Entry, [pscredential]$Credential)
    $directory = Join-Path ([IO.Path]::GetTempPath()) "lbcap-$([guid]::NewGuid())"
    try {
        if ($IsWindows) {
            New-Item -ItemType Directory -Path $directory -ErrorAction Stop | Out-Null
            $acl = Get-Acl -LiteralPath $directory
            $acl.SetAccessRuleProtection($true, $false)
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
            $rule = [Security.AccessControl.FileSystemAccessRule]::new($identity, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
            $acl.SetAccessRule($rule)
            Set-Acl -LiteralPath $directory -AclObject $acl -ErrorAction Stop
        }
        else { [IO.Directory]::CreateDirectory($directory, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute) | Out-Null }
        $templatePath = Join-Path $directory 'vm.json'
        New-LocalBoxCapacityTemplate | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $templatePath -ErrorAction Stop
        $values = @{
            name = $Entry.Name; location = $State.Location; customLocationId = $State.CustomLocationId
            imageId = $State.ImageId; networkId = $State.NetworkId; storageId = $State.StorageId
            processors = $State.ProcessorCount; memoryMB = $State.MemoryMB
            adminUsername = $Credential.UserName; adminPassword = $Credential.GetNetworkCredential().Password
            tags = @{ MicroHackPurpose = 'LocalBoxCapacityTest'; MicroHackRunId = $State.RunId }
        }
        $parameters = @{}
        foreach ($key in $values.Keys) { $parameters[$key] = @{ value = $values[$key] } }
        $parameterPath = Join-Path $directory 'parameters.json'
        @{ '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'; contentVersion = '1.0.0.0'; parameters = $parameters } |
            ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $parameterPath -ErrorAction Stop
        $arguments = @('--subscription', $State.SubscriptionId, '--resource-group', $State.ResourceGroupName,
            '--name', $Entry.Name, '--template-file', $templatePath, '--parameters', "@$parameterPath")
        $preview = Invoke-LocalBoxAz (@('deployment', 'group', 'what-if') + $arguments + @('--no-pretty-print', '--result-format', 'ResourceIdOnly'))
        $machineId = "/subscriptions/$($State.SubscriptionId)/resourceGroups/$($State.ResourceGroupName)/providers/Microsoft.HybridCompute/machines/$($Entry.Name)"
        $allowed = @($machineId, "$machineId/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default",
            "/subscriptions/$($State.SubscriptionId)/resourceGroups/$($State.ResourceGroupName)/providers/Microsoft.AzureStackHCI/networkInterfaces/$($Entry.Name)-nic")
        $creates = @($preview.changes | Where-Object changeType -eq 'Create')
        $unsafe = @($preview.changes | Where-Object {
            ($_.resourceId -iin $allowed -and $_.changeType -ne 'Create') -or
            ($_.resourceId -inotIn $allowed -and $_.changeType -notin @('Ignore', 'NoChange'))
        })
        if ($preview.status -ne 'Succeeded' -or $creates.Count -ne 3 -or
            @($creates.resourceId | Sort-Object -Unique).Count -ne 3 -or $unsafe.Count) {
            $Entry.SubmissionError = 'ARM what-if did not confirm exactly the three new test resources with no changes to existing resources.'
            throw $Entry.SubmissionError
        }
        Invoke-LocalBoxAz (@('deployment', 'group', 'create') + $arguments + @('--no-wait')) -NoOutput
    }
    catch { throw "VM submission failed for $($Entry.Name). Inspect its ARM deployment; resources may still be provisioning. CLI details are withheld to protect the VM credential." }
    finally {
        $values = $null
        $parameters = $null
        if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction Stop }
    }
}

function Update-LocalBoxCapacityVM {
    param([hashtable]$State, [hashtable]$Entry)
    $common = @('--subscription', $State.SubscriptionId, '--resource-group', $State.ResourceGroupName, '--name', $Entry.Name)
    $deployment = Invoke-LocalBoxAz (@('deployment', 'group', 'show') + $common)
    $Entry.DeploymentState = $deployment.properties.provisioningState
    if ($Entry.DeploymentState -in @('Failed', 'Canceled', 'Deleting')) {
        $Entry.Status = 'Failed'
        return
    }
    if ($Entry.DeploymentState -ne 'Succeeded') { $Entry.Status = 'Provisioning'; return }
    $machineId = "/subscriptions/$($State.SubscriptionId)/resourceGroups/$($State.ResourceGroupName)/providers/Microsoft.HybridCompute/machines/$($Entry.Name)"
    $instance = Invoke-LocalBoxAz @('resource', 'show', '--ids', "$machineId/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default", '--api-version', '2024-01-01')
    $machine = Invoke-LocalBoxAz @('resource', 'show', '--ids', $machineId, '--api-version', '2023-10-03-preview')
    $Entry.PowerState = $instance.properties.status.powerState
    $Entry.GuestStatus = $machine.properties.status
    if ($instance.properties.provisioningState -eq 'Failed') { $Entry.Status = 'Failed'; return }
    $Entry.Status = if ($instance.properties.provisioningState -eq 'Succeeded' -and
        $Entry.PowerState -eq 'Running' -and $Entry.GuestStatus -eq 'Connected') { 'Ready' } else { 'WaitingForGuest' }
    if ($Entry.Status -eq 'Ready' -and -not $Entry.ReadyAt) {
        $Entry.ReadyAt = [datetime]::UtcNow.ToString('o')
        $Entry.ElapsedSeconds = [math]::Round(([datetime]::UtcNow - [datetime]$Entry.SubmittedAt).TotalSeconds)
    }
}

function Remove-LocalBoxCapacityRun {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([hashtable]$State, [hashtable]$LocalBox, [string]$Path)
    $exists = Invoke-LocalBoxAz @('group', 'exists', '--subscription', $State.SubscriptionId, '--name', $State.ResourceGroupName)
    if (-not $exists) { Write-Host 'Test resource group is already absent.'; return }
    $group = Invoke-LocalBoxAz @('group', 'show', '--subscription', $State.SubscriptionId, '--name', $State.ResourceGroupName)
    $resources = @(Invoke-LocalBoxAz @('resource', 'list', '--subscription', $State.SubscriptionId, '--resource-group', $State.ResourceGroupName))
    Assert-LocalBoxCapacityOwnership $State $LocalBox $group $resources
    if ($PSCmdlet.ShouldProcess($State.ResourceGroupName, 'Permanently delete all capacity-test VMs, NICs, disks and the dedicated test resource group')) {
        Invoke-LocalBoxAz @('group', 'delete', '--subscription', $State.SubscriptionId, '--name', $State.ResourceGroupName, '--yes') -TimeoutSeconds 3600 -NoOutput
        if (Invoke-LocalBoxAz @('group', 'exists', '--subscription', $State.SubscriptionId, '--name', $State.ResourceGroupName)) {
            throw 'Test resource group still exists; cleanup is not verified.'
        }
        $State.Status = 'Deleted'
        Save-LocalBoxCapacityState $State $Path
    }
}

function Assert-LocalBoxCapacityHost {
    if (-not $IsWindows -or $env:COMPUTERNAME -ine 'LocalBox-Client') { throw 'Run in elevated PowerShell 7 on LocalBox-Client.' }
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run PowerShell 7 as Administrator.' }
}

function Repair-LocalBoxCapacityPendingSubmission {
    param([hashtable]$State)
    $pending = @($State.VMs | Where-Object Status -eq 'Submitting')
    if (-not $pending.Count) { return }
    if ($pending.Count -ne 1 -or $pending[0].Name -ne $State.VMs[-1].Name) {
        throw 'Ambiguous pending submissions; inspect the journal before continuing.'
    }
    $entry = $pending[0]
    $deployments = @(Invoke-LocalBoxAz @('deployment', 'group', 'list', '--subscription', $State.SubscriptionId, '--resource-group', $State.ResourceGroupName))
    if (@($deployments | Where-Object name -ieq $entry.Name).Count) { return }
    $resources = @(Invoke-LocalBoxAz @('resource', 'list', '--subscription', $State.SubscriptionId, '--resource-group', $State.ResourceGroupName))
    $scope = "/subscriptions/$($State.SubscriptionId)/resourceGroups/$($State.ResourceGroupName)"
    $machineId = "$scope/providers/Microsoft.HybridCompute/machines/$($entry.Name)"
    $nicId = "$scope/providers/Microsoft.AzureStackHCI/networkInterfaces/$($entry.Name)-nic"
    if (@($resources | Where-Object {
        $_.id -ieq $machineId -or $_.id -ieq $nicId -or
        ([string]$_.id).StartsWith("$machineId/", [StringComparison]::OrdinalIgnoreCase)
    }).Count) { throw 'Pending submission has resources but no deployment record; inspect manually before continuing.' }
    Write-Host "Retrying unsubmitted VM $($entry.Name): Azure confirms no deployment, machine or NIC exists."
    $State.UnsubmittedAttempts = @($State.UnsubmittedAttempts | Where-Object { $null -ne $_ }) + @{
        Name = $entry.Name; SubmittedAt = $entry.SubmittedAt; VerifiedAbsentAt = [datetime]::UtcNow.ToString('o')
    }
    $State.VMs = @($State.VMs | Where-Object Name -ine $entry.Name)
}

function Invoke-LocalBoxCapacityRun {
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Settings)
    $ErrorActionPreference = 'Stop'
    $batchSize = if ($Settings.BatchSize) { [int]$Settings.BatchSize } else { 1 }
    if ($batchSize -lt 1 -or $batchSize -gt 5) { throw 'BatchSize must be between 1 and 5.' }
    if ($Settings.SubmitNext -and ($batchSize -ne 1 -or $Settings.SubmitBatch)) {
        throw 'SubmitNext requires BatchSize 1. Use SubmitBatch for a concurrent batch.'
    }
    if ($Settings.RemoteClusterId) {
        $context = Get-LocalBoxRemoteCapacityContext $Settings.RemoteClusterId $Settings.LocalBoxManifestPath
        $localBox = $context.LocalBox
    }
    else {
        Assert-LocalBoxCapacityHost
        $localBox = Get-Content -LiteralPath $Settings.LocalBoxManifestPath -Raw | ConvertFrom-Json -AsHashtable
    }
    foreach ($key in @('SubscriptionId', 'ResourceGroupName', 'ClusterId', 'CustomLocationId', 'StorageId', 'ImageId', 'NodeNames', 'Networks')) {
        if (-not $localBox[$key]) { throw "Missing preparation manifest field $key." }
    }
    if (-not $Settings.RemoteClusterId -and ($localBox.SubscriptionId -ine $env:subscriptionId -or $localBox.ResourceGroupName -ine $env:resourceGroup)) {
        throw 'Manifest does not match this LocalBox deployment.'
    }
    $state = if (Test-Path -LiteralPath $Settings.StatePath) { Get-Content -LiteralPath $Settings.StatePath -Raw | ConvertFrom-Json -AsHashtable } else { $null }
    if ($Settings.Mode -eq 'Cleanup') {
        if (-not $state) { throw 'Cleanup requires the original capacity-test journal.' }
        Remove-LocalBoxCapacityRun $state $localBox $Settings.StatePath -WhatIf:$WhatIfPreference
        return
    }
    if ($state -and $state.Status -eq 'Deleted') { throw 'This run was deleted. Use a new StatePath for a new run.' }
    if ($state) {
        $group = Invoke-LocalBoxAz @('group', 'show', '--subscription', $state.SubscriptionId, '--name', $state.ResourceGroupName)
        $resources = @(Invoke-LocalBoxAz @('resource', 'list', '--subscription', $state.SubscriptionId, '--resource-group', $state.ResourceGroupName))
        Assert-LocalBoxCapacityOwnership $state $localBox $group $resources
        if ($state.MemoryMB -ne $Settings.MemoryMB -or $state.ProcessorCount -ne $Settings.ProcessorCount) {
            throw 'Do not change VM sizing within a capacity run; use the original sizing or a new StatePath.'
        }
    }
    elseif ($Settings.Mode -eq 'Status') { throw 'Status requires an existing capacity-test journal.' }
    $credential = $null
    if ($Settings.RemoteClusterId) { $snapshot = $context.Snapshot }
    else {
        $configuration = Import-PowerShellDataFile -LiteralPath $env:LocalBoxConfigFile
        $credential = Resolve-LocalBoxNodeCredential -Configuration $configuration -Credential $Settings.NodeCredential
        $snapshot = Get-LocalBoxCapacitySnapshot $localBox $credential
    }
    if ($Settings.Mode -eq 'Status') {
        foreach ($entry in $state.VMs) { Update-LocalBoxCapacityVM $state $entry }
        $state.LastSnapshot = $snapshot
        if (-not $WhatIfPreference) { Save-LocalBoxCapacityState $state $Settings.StatePath }
        $state.VMs | ForEach-Object { [pscustomobject]$_ } | Format-Table Name, Status, DeploymentState, PowerState, GuestStatus, ElapsedSeconds
        return
    }
    Assert-LocalBoxCapacityHeadroom $snapshot $Settings
    if (-not $state) {
        $custom = Get-LocalBoxResource $localBox.CustomLocationId
        $image = Get-LocalBoxResource $localBox.ImageId
        if ($image.properties.provisioningState -ne 'Succeeded' -or $image.properties.status.progressPercentage -ne 100 -or
            $image.properties.containerId -ine $localBox.StorageId) { throw 'The prepared image is not ready on UserStorage_1.' }
        $network = @($localBox.Networks | Where-Object Name -eq 'localbox-vm-lnet-vlan200')
        if ($network.Count -ne 1) { throw 'Cannot uniquely identify the prepared participant VM logical network.' }
        $runId = [guid]::NewGuid().ToString('N')
        $state = @{
            SchemaVersion = 1; RunId = $runId; SubscriptionId = $localBox.SubscriptionId; ClusterId = $localBox.ClusterId
            ResourceGroupName = "rg-lbcap-$runId"; Location = $custom.location
            CustomLocationId = $localBox.CustomLocationId; ImageId = $localBox.ImageId
            NetworkId = $network[0].Id; StorageId = $localBox.StorageId
            ProcessorCount = $Settings.ProcessorCount; MemoryMB = $Settings.MemoryMB
            Status = 'Planned'; VMs = @(); Baseline = $snapshot
        }
    }
    if ($WhatIfPreference) {
        $null = $PSCmdlet.ShouldProcess($state.ResourceGroupName, "Create up to $($Settings.VmCount) total VMs, $($Settings.ProcessorCount) vCPU / $($Settings.MemoryMB) MiB each, in batches of $batchSize with guest management")
        return
    }
    if (-not $PSCmdlet.ShouldProcess($state.ResourceGroupName, "Run capacity test up to $($Settings.VmCount) VMs")) { return }
    try {
        Repair-LocalBoxCapacityPendingSubmission $state
        if (-not $Settings.VmCredential -and @($state.VMs).Count -lt $Settings.VmCount) {
            if ($Settings.GenerateVmCredential) {
                $password = 'Lb!' + [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(30)) + '9a'
                $secure = [Security.SecureString]::new()
                foreach ($character in $password.GetEnumerator()) { $secure.AppendChar($character) }
                $secure.MakeReadOnly()
                $Settings.VmCredential = [pscredential]::new('localadmin', $secure)
                $password = $null
                Write-Host 'Generated a disposable test-VM password in memory. It is not saved; use a supplied VmCredential if interactive sign-in is needed.'
            }
            else { $Settings.VmCredential = Get-Credential -UserName 'localadmin' -Message 'Local administrator for disposable capacity-test VMs (not the LocalBox administrator)' }
        }
        if (@($state.VMs).Count -lt $Settings.VmCount -and -not $Settings.VmCredential) { throw 'A test-VM credential is required.' }
        if ($state.Status -eq 'Planned') {
            Save-LocalBoxCapacityState $state $Settings.StatePath
            if (Invoke-LocalBoxAz @('group', 'exists', '--subscription', $state.SubscriptionId, '--name', $state.ResourceGroupName)) {
                throw 'The new run resource group already exists; no resources were changed.'
            }
            Invoke-LocalBoxAz @('group', 'create', '--subscription', $state.SubscriptionId, '--name', $state.ResourceGroupName,
                '--location', $state.Location, '--tags', 'MicroHackPurpose=LocalBoxCapacityTest', "MicroHackRunId=$($state.RunId)") | Out-Null
        }
        foreach ($entry in $state.VMs) {
            Update-LocalBoxCapacityVM $state $entry
            if ($entry.Status -ne 'Ready') { throw "Existing test VM $($entry.Name) is $($entry.Status). Inspect it or clean up before adding VMs." }
        }
        $state.Status = 'Running'
        $state.StopReason = $null
        $state.RequestedCount = $Settings.VmCount
        $state.BatchSize = $batchSize
        $state.Limits = @{
            MinimumHostFreeGB = $Settings.MinimumHostFreeGB; MinimumCsvFreeGB = $Settings.MinimumCsvFreeGB
            MinimumNodeFreeGB = $Settings.MinimumNodeFreeGB; DiskBudgetGB = $Settings.DiskBudgetGB
        }
        while (@($state.VMs).Count -lt $Settings.VmCount) {
            $batchCount = [math]::Min($batchSize, $Settings.VmCount - @($state.VMs).Count)
            $snapshot = Get-LocalBoxCapacitySnapshot $localBox $credential
            $state.LastSnapshot = $snapshot
            Assert-LocalBoxCapacityHeadroom $snapshot $Settings -AdditionalVMs $batchCount
            $batch = @()
            $batchId = [guid]::NewGuid().ToString('N')
            for ($batchIndex = 0; $batchIndex -lt $batchCount; $batchIndex++) {
                $index = @($state.VMs).Count + 1
                $entry = @{
                    Index = $index; Name = ('lc{0}-{1:D3}' -f $state.RunId.Substring(0, 8), $index)
                    Status = 'Submitting'; SubmittedAt = [datetime]::UtcNow.ToString('o'); BatchId = $batchId
                    DeploymentState = ''; PowerState = ''; GuestStatus = ''; ReadyAt = ''; ElapsedSeconds = 0
                    HostFreeGBAfter = $null; MinimumNodeFreeGBAfter = $null; CsvFreeGBAfter = $null
                }
                $state.VMs += $entry
                $batch += $entry
                Save-LocalBoxCapacityState $state $Settings.StatePath
                Write-Host "[$index/$($Settings.VmCount)] Submitting $($entry.Name) in batch of $batchCount; host free before batch: $([math]::Round($snapshot.HostFreeGB)) GiB..."
                Submit-LocalBoxCapacityVM $state $entry $Settings.VmCredential
                $entry.Status = 'Submitted'
                Save-LocalBoxCapacityState $state $Settings.StatePath
            }
            if ($Settings.SubmitNext -or $Settings.SubmitBatch) {
                $state.Status = 'AwaitingReadiness'
                Write-Host "Submitted $batchCount VM(s). Azure continues provisioning; use Status before submitting another batch."
                return
            }
            $deadline = [datetime]::UtcNow.AddMinutes($Settings.TimeoutMinutes)
            do {
                foreach ($entry in $batch) {
                    Update-LocalBoxCapacityVM $state $entry
                    Write-Host "$($entry.Name): $($entry.Status); deployment=$($entry.DeploymentState), power=$($entry.PowerState), guest=$($entry.GuestStatus)"
                }
                Save-LocalBoxCapacityState $state $Settings.StatePath
                if (@($batch | Where-Object Status -eq 'Failed').Count) { throw 'A batch deployment failed. This is not necessarily capacity exhaustion; inspect its ARM deployment.' }
                if (-not @($batch | Where-Object Status -ne 'Ready').Count) { break }
                if ([datetime]::UtcNow -ge $deadline) { throw 'Timed out waiting for the batch. Azure operations may still be running; no additional VMs will be submitted.' }
                Start-Sleep -Seconds 15
            } while ($true)
            $state.LastSnapshot = Get-LocalBoxCapacitySnapshot $localBox $credential
            foreach ($entry in $batch) {
                $entry.HostFreeGBAfter = [math]::Round($state.LastSnapshot.HostFreeGB, 1)
                $entry.MinimumNodeFreeGBAfter = [math]::Round(($state.LastSnapshot.Nodes | Measure-Object FreeMemoryGB -Minimum).Minimum, 1)
                $entry.CsvFreeGBAfter = [math]::Round(($state.LastSnapshot.Nodes | Measure-Object CsvFreeGB -Minimum).Minimum, 1)
            }
            Save-LocalBoxCapacityState $state $Settings.StatePath
        }
        foreach ($entry in $state.VMs) {
            Update-LocalBoxCapacityVM $state $entry
            if ($entry.Status -ne 'Ready') { throw "Test VM $($entry.Name) is no longer ready. Check the final run state before choosing a participant count." }
        }
        $state.Status = 'TargetReached'
        Write-Host "Target reached: $(@($state.VMs | Where-Object Status -eq 'Ready').Count) guest-connected VMs. This is a tested count, not a maximum or a concurrent-workshop performance guarantee."
    }
    catch {
        $state.Status = 'Stopped'
        $state.StopReason = $_.Exception.Message
        throw
    }
    finally {
        Save-LocalBoxCapacityState $state $Settings.StatePath
    }
}

function Invoke-LocalBoxCapacityTest {
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Settings)
    $lock = [Threading.Mutex]::new($false, 'Global\MicroHackLocalBoxCapacity')
    $locked = $false
    try {
        $locked = $lock.WaitOne(0)
        if (-not $locked) { throw 'Another capacity-test session is running. Deployment, status and cleanup cannot overlap.' }
        Invoke-LocalBoxCapacityRun $Settings -WhatIf:$WhatIfPreference
    }
    finally {
        if ($locked) { $lock.ReleaseMutex() }
        $lock.Dispose()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($RemoteClusterId -and -not $PSBoundParameters.ContainsKey('StatePath')) { $StatePath = Join-Path $HOME '.microhack/capacity-test/run.json' }
    $settings = @{
        Mode = $Mode; LocalBoxManifestPath = $LocalBoxManifestPath; StatePath = $StatePath
        RemoteClusterId = $RemoteClusterId; GenerateVmCredential = [bool]$GenerateVmCredential
        SubmitNext = [bool]$SubmitNext
        SubmitBatch = [bool]$SubmitBatch; BatchSize = $BatchSize
        VmCount = $VmCount; ProcessorCount = $ProcessorCount; MemoryMB = $MemoryMB
        MinimumHostFreeGB = $MinimumHostFreeGB; MinimumCsvFreeGB = $MinimumCsvFreeGB
        MinimumNodeFreeGB = $MinimumNodeFreeGB; DiskBudgetGB = $DiskBudgetGB
        TimeoutMinutes = $TimeoutMinutes; VmCredential = $VmCredential; NodeCredential = $NodeCredential
    }
    . "$PSScriptRoot/prepare-localbox.ps1" -WhatIf:$WhatIfPreference
    Invoke-LocalBoxCapacityTest $settings -WhatIf:$WhatIfPreference
}