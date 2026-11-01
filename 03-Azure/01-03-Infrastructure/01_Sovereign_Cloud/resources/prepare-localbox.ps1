#Requires -Version 7.0
<#
.SYNOPSIS
Prepares an already deployed Jumpstart LocalBox for the Sovereign Cloud MicroHack.
.DESCRIPTION
Run elevated on LocalBox-Client. Azure operations use its managed identity;
nested Windows operations use a supplied PSCredential or the administrator
credential from the installed Jumpstart configuration. Passwords are not logged.
Missing required Azure CLI extensions are installed without upgrading existing
versions, including during WhatIf. Azure, Hyper-V and storage changes remain
simulated during WhatIf.
AKS preparation grants its Entra admin group the cluster-scoped Azure Arc Enabled
Kubernetes Cluster User Role for proxy access, reusing applicable existing grants.
It also installs the MetalLB Arc extension and an ARP pool from the configured
service VIP reservation. The Runtime provider object ID comes from the organizer,
not a Graph lookup using the Client managed identity.
IncludeReferenceVm defaults to true and creates sov-ref-vm for participant inspection,
with a generated, locally encrypted credential, guest management and periodic update assessment.
Operations run without confirmation under the default PowerShell preference;
use Confirm to request prompts or WhatIf to preview changes.
Assumes the standard greenfield LocalBox network configuration. Configured address
ranges and known reservations are validated; live DHCP leases are not inspected.
New image imports resolve latest from this cluster's Edge Marketplace catalog,
not the Azure Compute catalog; existing working images are reused unchanged.
Dot-source this file to load its functions without running provisioning.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SubscriptionId = $env:subscriptionId,
    [string]$ResourceGroupName = $env:resourceGroup,
    [string]$ConfigPath = $env:LocalBoxConfigFile,
    [string]$AksAdminGroupObjectId,
    [string]$KubernetesRuntimeObjectId,
    [switch]$SkipAks,
    [switch]$IncludeReferenceVm = $true,
    [pscredential]$ReferenceVmCredential,
    [pscredential]$NodeCredential,
    [string]$VmSwitchName,
    [string]$ImageName = '2025-datacenter-azure-edition-smalldisk-01',
    [string]$ImageVersion = 'latest',
    [string]$VmPoolStart = '192.168.200.10',
    [string]$VmPoolEnd = '192.168.200.199',
    [string]$AksClusterName = 'localbox-aks',
    [string]$KubernetesVersion,
    [string]$NodeVmSize = 'Standard_A4_v2',
    [string]$ControlPlaneVmSize = 'Standard_A4_v2',
    [ValidateRange(1, 10)][int]$NodeCount = 3,
    [ValidateRange(512, 4096)][int]$StorageSizeGB = 1024,
    [switch]$RemoveUserStorage2,
    [ValidateRange(1, 720)][int]$TimeoutMinutes = 360,
    [string]$ManifestPath = 'C:\LocalBox\sovereign-localbox.json'
)

function Resolve-LocalBoxNodeCredential {
    param([hashtable]$Configuration, [pscredential]$Credential)
    if ($Credential) { return $Credential }
    $domain = ([string]$Configuration.SDNDomainFQDN).Split('.')[0]
    if ($domain -notmatch '^[a-zA-Z0-9][a-zA-Z0-9-]{0,14}$' -or
        $Configuration.SDNAdminPassword -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Configuration.SDNAdminPassword)) {
        throw 'The installed LocalBox configuration lacks a usable SDNDomainFQDN or SDNAdminPassword. Supply -NodeCredential for the nested administrator; do not print or share the configuration.'
    }
    $password = [Security.SecureString]::new()
    foreach ($character in $Configuration.SDNAdminPassword.GetEnumerator()) {
        $password.AppendChar($character)
    }
    $password.MakeReadOnly()
    return [pscredential]::new("$domain\Administrator", $password)
}

function ConvertTo-LocalBoxIPv4Number {
    param([Parameter(Mandatory)][string]$Address)
    $parsed = [System.Net.IPAddress]::Parse($Address)
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Expected IPv4: $Address"
    }
    $bytes = $parsed.GetAddressBytes()
    return [uint64]$bytes[0] * 16777216 + [uint64]$bytes[1] * 65536 + [uint64]$bytes[2] * 256 + $bytes[3]
}

function Test-LocalBoxAddressPool {
    param(
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Start,
        [Parameter(Mandatory)][string]$End,
        [Parameter(Mandatory)][string]$Gateway,
        [string[]]$Reserved = @(),
        [hashtable[]]$ReservedRanges = @()
    )
    $parts = $Prefix.Split('/')
    if ($parts.Count -ne 2 -or $parts[1] -notmatch '^([1-9]|[12][0-9]|30)$') {
        throw "Invalid IPv4 subnet: $Prefix"
    }
    $size = [uint64][math]::Pow(2, 32 - [int]$parts[1])
    $network = ConvertTo-LocalBoxIPv4Number $parts[0]
    if ($network % $size -ne 0) { throw "Subnet must use its network address: $Prefix" }
    $broadcast = $network + $size - 1
    $first = ConvertTo-LocalBoxIPv4Number $Start
    $last = ConvertTo-LocalBoxIPv4Number $End
    $gatewayNumber = ConvertTo-LocalBoxIPv4Number $Gateway
    if ($first -le $network -or $last -ge $broadcast -or $first -gt $last) {
        throw "Pool $Start-$End must contain only usable addresses within $Prefix."
    }
    if ($gatewayNumber -le $network -or $gatewayNumber -ge $broadcast) {
        throw "Gateway $Gateway is outside the usable subnet."
    }
    foreach ($address in @($Gateway) + $Reserved) {
        $number = ConvertTo-LocalBoxIPv4Number $address
        if ($number -ge $first -and $number -le $last) { throw "Pool includes reserved address $address." }
    }
    foreach ($range in $ReservedRanges) {
        $rangeStart = ConvertTo-LocalBoxIPv4Number $range.Start
        $rangeEnd = ConvertTo-LocalBoxIPv4Number $range.End
        if ($rangeStart -gt $rangeEnd) { throw 'Invalid reserved range.' }
        if ($first -le $rangeEnd -and $last -ge $rangeStart) { throw "Pool overlaps reserved range $($range.Start)-$($range.End)." }
    }
}

function Assert-LocalBoxGroupId {
    param([Parameter(Mandatory)][string]$Value)
    $identifier = [guid]::Empty
    if (-not [guid]::TryParse($Value, [ref]$identifier) -or $identifier -eq [guid]::Empty) {
        throw 'Supply a nonempty Entra security-group object ID, not a name or application ID.'
    }
    return $identifier.ToString()
}

function Read-LocalBoxGroupId {
    param([string]$Value, [switch]$SkipAks)
    if ($SkipAks) { return $null }
    if (-not $Value) { $Value = Read-Host 'Entra AKS admin-group object ID (provided by Console; group must already exist)' }
    return Assert-LocalBoxGroupId $Value
}

function Get-LocalBoxAzInvocation {
    param([string]$CommandPath = (Get-Command az -ErrorAction Stop).Source)
    if ([IO.Path]::GetExtension($CommandPath) -in @('.cmd', '.bat')) {
        $python = [IO.Path]::GetFullPath((Join-Path (Split-Path $CommandPath) '../python.exe'))
        if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
            throw 'Cannot locate the Azure CLI bundled Python. Use a supported Azure CLI installation; the batch wrapper is unsafe for switch names containing parentheses.'
        }
        return @{ Executable = $python; Prefix = @('-IBm', 'azure.cli') }
    }
    return @{ Executable = $CommandPath; Prefix = @() }
}

function Invoke-LocalBoxAz {
    param([Parameter(Mandatory)][string[]]$Arguments, [int]$TimeoutSeconds = 300, [switch]$NoOutput)
    $invocation = Get-LocalBoxAzInvocation
    $job = Start-Job -ArgumentList $invocation, $Arguments, ([bool]$NoOutput) -ScriptBlock {
        param($Invocation, $CommandArguments, $DiscardOutput)
        $PSNativeCommandUseErrorActionPreference = $false
        $prefix = $Invocation.Prefix
        $format = if ($DiscardOutput) { 'none' } else { 'json' }
        $output = @(& $Invocation.Executable @prefix @CommandArguments --only-show-errors --output $format 2>&1)
        $exitCode = $LASTEXITCODE
        $operation = (@($CommandArguments | Select-Object -First 2) -join ' ')
        if ($CommandArguments -contains '--validate') { $operation += ' --validate' }
        $stderr = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $text = ($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
        if ($exitCode -ne 0) { throw "Azure CLI 'az $operation' failed (exit code $exitCode): $($stderr -join "`n")" }
        if ($DiscardOutput) { return }
        if ($text.Trim()) {
            try { $text | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
            catch {
                throw "Azure CLI 'az $operation' returned non-JSON stdout despite --output json (exit code $exitCode). Raw output is omitted because it may contain sensitive data. Inspect the resource state before retrying; a submitted operation may still be running."
            }
        }
    }
    try {
        if (-not (Wait-Job $job -Timeout $TimeoutSeconds)) {
            throw "Azure CLI timed out. A submitted Azure operation may still be running; inspect it before retrying."
        }
        Receive-Job $job -ErrorAction Stop
    }
    finally { Remove-Job $job -Force -ErrorAction SilentlyContinue -WhatIf:$false -Confirm:$false }
}

function Initialize-LocalBoxCliExtension {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    $installed = @(Invoke-LocalBoxAz @('extension', 'list'))
    $ready = $true
    foreach ($extension in @('stack-hci-vm', 'customlocation', 'aksarc')) {
        if ($extension -notin $installed.name) {
            if (-not $PSCmdlet.ShouldProcess($extension, 'Install missing Azure CLI extension')) {
                $ready = $false
                continue
            }
            Write-Host "Installing missing Azure CLI extension $extension..."
            Invoke-LocalBoxAz @('extension', 'add', '--name', $extension) -TimeoutSeconds 900 | Out-Null
        }
        $details = Invoke-LocalBoxAz @('extension', 'show', '--name', $extension)
        if ($details.name -ne $extension -or [string]::IsNullOrWhiteSpace($details.version)) {
            throw "Azure CLI extension $extension could not be verified. Preparation has stopped."
        }
        Write-Host "$extension $($details.version)"
    }
    return $ready
}

function Get-LocalBoxResource {
    param([string]$Id)
    $arguments = @('resource', 'show', '--ids', $Id)
    if ($Id -match '/providers/Microsoft\.HybridContainerService/provisionedClusterInstances/') {
        $arguments += @('--api-version', '2024-01-01')
    }
    elseif ($Id -match '/providers/Microsoft\.KubernetesConfiguration/extensions/') {
        $arguments += @('--api-version', '2023-05-01')
    }
    elseif ($Id -match '/providers/Microsoft\.KubernetesRuntime/loadBalancers/') {
        $arguments += @('--api-version', '2024-08-01')
    }
    elseif ($Id -match '/providers/Microsoft\.AzureStackHCI/virtualMachineInstances/') {
        $arguments += @('--api-version', '2024-01-01')
    }
    elseif ($Id -match '/providers/Microsoft\.HybridCompute/machines/') {
        $arguments += @('--api-version', '2024-07-10')
    }
    Invoke-LocalBoxAz $arguments
}

function New-LocalBoxVmTemplate {
    param([switch]$EnablePeriodicAssessment)
    $machineId = "[resourceId('Microsoft.HybridCompute/machines', parameters('name'))]"
    $nicId = "[resourceId('Microsoft.AzureStackHCI/networkInterfaces', concat(parameters('name'), '-nic'))]"
    $extendedLocation = @{ type = 'CustomLocation'; name = "[parameters('customLocationId')]" }
    $machine = @{
        type = 'Microsoft.HybridCompute/machines'; apiVersion = '2023-10-03-preview'
        name = "[parameters('name')]"; location = "[parameters('location')]"
        kind = 'HCI'; identity = @{ type = 'SystemAssigned' }; tags = "[parameters('tags')]"
    }
    if ($EnablePeriodicAssessment) {
        $machine.apiVersion = '2024-07-10'
        $machine.properties = @{ osProfile = @{ windowsConfiguration = @{
            patchSettings = @{ assessmentMode = 'AutomaticByPlatform' }
        } } }
    }
    @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            name = @{ type = 'string'; minLength = 1; maxLength = 15 }; location = @{ type = 'string' }
            customLocationId = @{ type = 'string' }; imageId = @{ type = 'string' }
            networkId = @{ type = 'string' }; storageId = @{ type = 'string' }
            processors = @{ type = 'int' }; memoryMB = @{ type = 'int' }
            adminUsername = @{ type = 'string' }; adminPassword = @{ type = 'securestring' }
            tags = @{ type = 'object' }
        }
        resources = @(
            $machine
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

function Initialize-LocalBoxPrivateDirectory {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Expected a private directory, not a file or link: $Path"
        }
    }
    elseif ($IsWindows) {
        New-Item -ItemType Directory -Path $Path -ErrorAction Stop | Out-Null
    }
    else {
        [IO.Directory]::CreateDirectory($Path, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute) | Out-Null
    }
    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $acl = [Security.AccessControl.DirectorySecurity]::new()
        $acl.SetOwner($identity)
        $acl.SetAccessRuleProtection($true, $false)
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($identity, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
    }
    else {
        [IO.File]::SetUnixFileMode($Path, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute)
    }
}

function New-LocalBoxVmCredential {
    $password = 'Lb!' + [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(30)) + '9a'
    try {
        $secure = [Security.SecureString]::new()
        foreach ($character in $password.GetEnumerator()) { $secure.AppendChar($character) }
        $secure.MakeReadOnly()
        return [pscredential]::new('localadmin', $secure)
    }
    finally { $password = $null }
}

function Get-LocalBoxReferenceVmCredential {
    param(
        [Parameter(Mandatory)][string]$MachineId,
        [string]$Path = 'C:\LocalBox\credentials\sov-ref-vm\credential.clixml'
    )
    if (-not $IsWindows) { throw 'Reference-VM credential persistence requires Windows DPAPI on LocalBox-Client.' }
    $directory = Split-Path -Parent $Path
    Initialize-LocalBoxPrivateDirectory $directory
    if (Test-Path -LiteralPath $Path) {
        if ((Get-Item -LiteralPath $Path -Force -ErrorAction Stop).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to load a linked credential file: $Path"
        }
        try { $saved = Import-Clixml -LiteralPath $Path -ErrorAction Stop }
        catch { throw "Cannot read or decrypt $Path. Use the same Windows account on this LocalBox-Client that created it. No credential was replaced." }
        if ($saved.MachineId -ine $MachineId -or $saved.Credential -isnot [pscredential] -or
            $saved.Credential.UserName -ne 'localadmin' -or $saved.Credential.Password.Length -eq 0) {
            throw "Saved reference-VM credential in $Path is invalid or belongs to a different resource. No credential was replaced."
        }
        Write-Host "Reusing the encrypted reference-VM credential in $Path."
        return $saved.Credential
    }
    $credential = New-LocalBoxVmCredential
    $temporary = Join-Path $directory "$([guid]::NewGuid()).tmp"
    try {
        @{ MachineId = $MachineId; Credential = $credential } |
            Export-Clixml -LiteralPath $temporary -Depth 5 -ErrorAction Stop
        [IO.File]::Move($temporary, $Path, $false)
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction Stop }
    }
    Write-Host "Generated reference-VM administrator credential; encrypted copy saved to $Path."
    return $credential
}

function Submit-LocalBoxVM {
    param([hashtable]$State, [hashtable]$Entry, [pscredential]$Credential, [hashtable]$Tags, [switch]$EnablePeriodicAssessment)
    if ($Entry.Name -notmatch '^(?=.{1,15}$)(?=.*[a-zA-Z])[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$') {
        throw 'VM computer name must contain 1-15 letters, digits or internal hyphens, and cannot be all numeric.'
    }
    $directory = Join-Path ([IO.Path]::GetTempPath()) "lbvm-$([guid]::NewGuid())"
    try {
        Initialize-LocalBoxPrivateDirectory $directory
        $templatePath = Join-Path $directory 'vm.json'
        New-LocalBoxVmTemplate -EnablePeriodicAssessment:$EnablePeriodicAssessment | ConvertTo-Json -Depth 30 |
            Set-Content -LiteralPath $templatePath -ErrorAction Stop
        $values = @{
            name = $Entry.Name; location = $State.Location; customLocationId = $State.CustomLocationId
            imageId = $State.ImageId; networkId = $State.NetworkId; storageId = $State.StorageId
            processors = $State.ProcessorCount; memoryMB = $State.MemoryMB
            adminUsername = $Credential.UserName; adminPassword = $Credential.GetNetworkCredential().Password
            tags = $Tags
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
            $Entry.SubmissionError = 'ARM what-if did not confirm exactly the three new VM resources with no changes to existing resources.'
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

function Get-LocalBoxReferenceVmReadiness {
    param([string]$MachineId)
    $machine = Get-LocalBoxResource $MachineId
    $instance = Get-LocalBoxResource "$MachineId/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default"
    if ($machine.properties -isnot [System.Collections.IDictionary] -or -not $instance.properties.status.powerState) {
        throw "Reference VM $MachineId returned incomplete machine/power data. Inspect its provisioning state."
    }
    $extensions = @(Get-LocalBoxArmCollection "https://management.azure.com$MachineId/extensions?api-version=2024-07-10")
    $mde = @($extensions | Where-Object { $_.properties.publisher -eq 'Microsoft.Azure.AzureDefenderForServers' -and $_.properties.type -eq 'MDE.Windows' })
    if ($mde.Count -gt 1 -or ($mde.Count -eq 1 -and -not $mde[0].properties.provisioningState)) {
        throw "Reference VM $MachineId returned unexpected MDE extension status."
    }
    @{
        ObservedAt = [datetime]::UtcNow.ToString('o')
        PowerState = $instance.properties.status.powerState
        ArcStatus = if ($machine.properties.status) { $machine.properties.status } else { 'NotReported' }
        MdeProvisioningState = if ($mde.Count) { $mde[0].properties.provisioningState } else { 'Pending' }
        PeriodicAssessmentMode = $machine.properties.osProfile.windowsConfiguration.patchSettings.assessmentMode
        DefenderAssessments = 'NotVerified'
        UpdateAssessmentResults = 'NotVerified'
    }
}

function Sync-LocalBoxReferenceVm {
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Settings, [string]$Location, [string]$CustomLocationId, [string]$ImageId, [string]$NetworkId, [string]$StorageId)
    if (-not $Settings.IncludeReferenceVm) { return }
    $name = 'sov-ref-vm'
    $scope = "/subscriptions/$($Settings.SubscriptionId)/resourceGroups/$($Settings.ResourceGroupName)"
    $machineId = "$scope/providers/Microsoft.HybridCompute/machines/$name"
    $nicId = "$scope/providers/Microsoft.AzureStackHCI/networkInterfaces/$name-nic"
    $instanceId = "$machineId/providers/Microsoft.AzureStackHCI/virtualMachineInstances/default"
    $tags = @{ MicroHackPurpose = 'LocalBoxReferenceVM'; SecurityControl = 'Ignore'; CostControl = 'Ignore' }
    $expected = @{
        extendedLocation = @{ name = $CustomLocationId }
        properties = @{
            hardwareProfile = @{ vmSize = 'Custom'; processors = 2; memoryMB = 4096 }
            osProfile = @{ computerName = $name; windowsConfiguration = @{ provisionVMAgent = $true; provisionVMConfigAgent = $true } }
            storageProfile = @{ vmConfigStoragePathId = $StorageId; imageReference = @{ id = $ImageId } }
            networkProfile = @{ networkInterfaces = @(@{ id = $nicId }) }
        }
    }
    $machineExpected = @{ kind = 'HCI'; location = $Location; tags = $tags; identity = @{ type = 'SystemAssigned' }
        properties = @{ osProfile = @{ windowsConfiguration = @{ patchSettings = @{ assessmentMode = 'AutomaticByPlatform' } } } } }
    $nicExpected = @{ location = $Location; extendedLocation = @{ name = $CustomLocationId }; tags = $tags
        properties = @{ ipConfigurations = @(@{ properties = @{ subnet = @{ id = $NetworkId } } }) } }
    $resources = @(Invoke-LocalBoxAz @('resource', 'list', '--subscription', $Settings.SubscriptionId, '--resource-group', $Settings.ResourceGroupName))
    $existing = @($resources | Where-Object id -ieq $machineId)
    if ($existing.Count) {
        Assert-LocalBoxProperties (Get-LocalBoxResource $machineId) $machineExpected
        Assert-LocalBoxProperties (Get-LocalBoxResource $nicId) $nicExpected
        Assert-LocalBoxProperties (Get-LocalBoxResource $instanceId) $expected
        Write-Host "Reusing reference VM $name without changing credentials or configuration."
    }
    elseif (@($resources | Where-Object { $_.id -iin @($nicId, $instanceId) }).Count) {
        throw 'Partial or conflicting reference-VM resources exist. Inspect them before retrying; preparation will not overwrite or delete them.'
    }
    elseif ($PSCmdlet.ShouldProcess($machineId, 'Create shared reference VM (2 vCPU, 4 GiB RAM, guest management and periodic update assessment)')) {
        $credential = $Settings.ReferenceVmCredential
        if (-not $credential) {
            $credential = Get-LocalBoxReferenceVmCredential -MachineId $machineId
        }
        if (-not $credential) { throw 'A separate reference-VM credential is required; nested domain credentials are not reused.' }
        $state = @{
            SubscriptionId = $Settings.SubscriptionId; ResourceGroupName = $Settings.ResourceGroupName; Location = $Location
            CustomLocationId = $CustomLocationId; ImageId = $ImageId; NetworkId = $NetworkId; StorageId = $StorageId
            ProcessorCount = 2; MemoryMB = 4096
        }
        Submit-LocalBoxVM -State $state -Entry @{ Name = $name } -Credential $credential -Tags $tags -EnablePeriodicAssessment
        Wait-LocalBoxResource "$scope/providers/Microsoft.Resources/deployments/$name" -TimeoutSeconds ($Settings.TimeoutMinutes * 60) | Out-Null
    }
    else { return }
    if ($WhatIfPreference) { return }
    Assert-LocalBoxProperties (Wait-LocalBoxResource $instanceId -TimeoutSeconds ($Settings.TimeoutMinutes * 60)) $expected
    Assert-LocalBoxProperties (Get-LocalBoxResource $machineId) $machineExpected
    Assert-LocalBoxProperties (Get-LocalBoxResource $nicId) $nicExpected
    $readiness = Get-LocalBoxReferenceVmReadiness $machineId
    Write-Host "Reference VM: power=$($readiness.PowerState), Arc=$($readiness.ArcStatus), MDE=$($readiness.MdeProvisioningState)."
    Write-Warning 'Reference VM is for inspection only, not enforced read-only by RBAC. Verify Defender and Update Manager assessment results before the event; provisioning does not prove assessment completion.'
    @{
        Name = $name; MachineId = $machineId; InstanceId = $instanceId; NicId = $nicId
        Expected = $expected; MachineExpected = $machineExpected; NicExpected = $nicExpected
        Readiness = $readiness
    }
}

function Resolve-LocalBoxStoragePath {
    param(
        [array]$Resources,
        [ValidateSet('UserStorage1', 'UserStorage2')][string]$Name,
        [string]$CustomLocationId,
        [switch]$AllowMissing
    )
    $matches = @($Resources | Where-Object {
        $_.type -ieq 'Microsoft.AzureStackHCI/storageContainers' -and $_.name -match "^$Name(-[a-zA-Z0-9]+)?$"
    })
    if ($matches.Count -eq 0 -and $AllowMissing) { return $null }
    if ($matches.Count -ne 1) { throw "Expected exactly one $Name storage path; found $($matches.Count)." }
    $storage = Get-LocalBoxResource $matches[0].id
    if ($storage.extendedLocation.name -ine $CustomLocationId) { throw "$Name belongs to a different custom location." }
    if ($storage.properties.provisioningState -ne 'Succeeded') { throw "$Name storage path is not ready." }
    return $storage
}

function Wait-LocalBoxResource {
    param([string]$Id, [int]$TimeoutSeconds = 3600)
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $resource = Get-LocalBoxResource $Id
        $state = $resource.properties.provisioningState
        if ($state -eq 'Succeeded') { return $resource }
        if ($state -in @('Failed', 'Canceled', 'Deleting')) { throw "$Id is $state. Inspect resource deployment errors; no resources were rolled back." }
        if ([datetime]::UtcNow -ge $deadline) { throw "Timed out waiting for $Id (state: $state)." }
        Write-Host "Waiting for $Id ($state)..."
        Start-Sleep -Seconds 15
    } while ($true)
}

function Assert-LocalBoxProperties {
    param($Actual, $Expected, [string]$Path = 'resource')
    if ($Expected -is [System.Collections.IDictionary]) {
        foreach ($key in $Expected.Keys) {
            if ($null -eq $Actual -or -not $Actual.Contains($key)) { throw "Missing $Path.$key" }
            Assert-LocalBoxProperties $Actual[$key] $Expected[$key] "$Path.$key"
        }
    }
    elseif ($Expected -is [array]) {
        if (@($Actual).Count -ne $Expected.Count) { throw "Conflicting array at $Path" }
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            Assert-LocalBoxProperties @($Actual)[$index] $Expected[$index] "$Path[$index]"
        }
    }
    elseif ([string]$Actual -ine [string]$Expected) {
        throw "Conflicting $Path. Expected '$Expected', found '$Actual'. Existing resources are not replaced."
    }
}

function Sync-LocalBoxResource {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Id, [hashtable]$Expected, [string[]]$CreateArguments, [int]$TimeoutSeconds = 21600)
    $parts = $Id.Split('/')
    $resources = @(Invoke-LocalBoxAz @('resource', 'list', '--subscription', $parts[2], '--resource-group', $parts[4]))
    $existing = @($resources | Where-Object { $_.id -ieq $Id })
    if ($existing.Count -gt 0) {
        $resource = Wait-LocalBoxResource $Id -TimeoutSeconds $TimeoutSeconds
        Assert-LocalBoxProperties $resource $Expected
        Write-Host "Reusing $Id"
        return $resource
    }
    if ($PSCmdlet.ShouldProcess($Id, 'Create resource')) {
        Invoke-LocalBoxAz $CreateArguments -TimeoutSeconds $TimeoutSeconds | Out-Null
        $resource = Wait-LocalBoxResource $Id -TimeoutSeconds $TimeoutSeconds
        Assert-LocalBoxProperties $resource $Expected
        return $resource
    }
}

function Resolve-LocalBoxImageVersion {
    param(
        [Parameter(Mandatory)][string]$ClusterId,
        [Parameter(Mandatory)][hashtable]$Identifier,
        [ValidateNotNullOrEmpty()][string]$RequestedVersion = 'latest'
    )
    if ($ClusterId -notmatch '^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.AzureStackHCI/clusters/[^/]+$') {
        throw 'Image version discovery requires the Azure Local cluster resource ID.'
    }
    foreach ($field in @('publisher', 'offer', 'sku')) {
        if ([string]::IsNullOrWhiteSpace($Identifier[$field])) { throw "Image identifier is missing $field." }
    }
    $offerId = [uri]::EscapeDataString("$($Identifier.publisher):$($Identifier.offer)")
    $offer = Invoke-LocalBoxAz @('rest', '--method', 'get', '--url',
        "https://management.azure.com$ClusterId/providers/Microsoft.EdgeMarketplace/offers/${offerId}?api-version=2023-08-01")
    if ($offer.properties.marketplaceSkus -isnot [System.Collections.IList]) {
        throw 'Edge Marketplace returned no valid SKU catalog for this cluster; no image import or deletion was attempted.'
    }
    $skus = @($offer.properties.marketplaceSkus | Where-Object marketplaceSkuId -eq $Identifier.sku)
    if ($skus.Count -ne 1 -or $skus[0].marketplaceSkuVersions -isnot [System.Collections.IList] -or
        $skus[0].marketplaceSkuVersions.Count -eq 0) {
        throw "Edge Marketplace does not advertise one usable version list for SKU '$($Identifier.sku)' on this cluster."
    }
    $versions = @($skus[0].marketplaceSkuVersions | ForEach-Object {
        $parsed = $null
        if (-not [version]::TryParse($_.name, [ref]$parsed)) { throw 'Edge Marketplace returned an invalid image version.' }
        [string]$_.name
    })
    if ($RequestedVersion -eq 'latest') {
        $selected = $versions | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
    }
    elseif ($RequestedVersion -in $versions) { $selected = $RequestedVersion }
    else {
        throw "Image version '$RequestedVersion' is not advertised by this cluster's Edge Marketplace catalog for '$($Identifier.sku)'. Select a listed version or use latest."
    }
    Write-Host "Using Edge Marketplace image version $selected for $($Identifier.sku)."
    return $selected
}

function Sync-LocalBoxImage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Id, [hashtable]$Expected, [string[]]$CreateArguments,
        [Parameter(Mandatory)][string]$ClusterId, [int]$TimeoutSeconds = 21600
    )
    if ($Id -notmatch '^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\.AzureStackHCI/marketplaceGalleryImages/[^/]+$') {
        throw 'Image recovery requires an exact Azure Local Marketplace image resource ID.'
    }
    $listArguments = @('resource', 'list', '--subscription', $Matches[1], '--resource-group', $Matches[2])
    $existing = @((Invoke-LocalBoxAz $listArguments) | Where-Object id -ieq $Id)
    if ($existing.Count) {
        $image = Get-LocalBoxResource $Id
        if ($image.properties.provisioningState -notin @('Failed', 'Deleting')) {
            return Sync-LocalBoxResource -Id $Id -Expected $Expected -CreateArguments $CreateArguments -TimeoutSeconds $TimeoutSeconds -WhatIf:$WhatIfPreference
        }
        Assert-LocalBoxProperties $image $Expected
    }
    $requestedVersion = if ($Expected.properties.Contains('version')) { $Expected.properties.version.name } else { 'latest' }
    $version = Resolve-LocalBoxImageVersion -ClusterId $ClusterId -Identifier $Expected.properties.identifier -RequestedVersion $requestedVersion
    $createExpected = $Expected.Clone()
    $createExpected.properties = $Expected.properties.Clone()
    $createExpected.properties.version = @{ name = $version }
    if ($existing.Count) {
        if ($image.properties.provisioningState -eq 'Failed') {
            Write-Warning "Image import failed for $Id. Retrying with catalog-listed version $version."
            if (-not $PSCmdlet.ShouldProcess($Id, 'Delete matching Failed image and retry import once')) {
                if ($WhatIfPreference) { return }
                throw 'Failed-image recovery was declined. No image was deleted; preparation cannot continue with this image.'
            }
            Invoke-LocalBoxAz @('resource', 'delete', '--ids', $Id, '--api-version', '2024-01-01') -TimeoutSeconds $TimeoutSeconds -NoOutput
        }
        if ($WhatIfPreference) {
            Write-Host "Image deletion is in progress; a real run will wait for removal before importing $Id."
            return
        }
        $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
        while (@((Invoke-LocalBoxAz $listArguments) | Where-Object id -ieq $Id).Count) {
            if ([datetime]::UtcNow -ge $deadline) { throw "Timed out waiting for image deletion: $Id. No replacement import was started." }
            Write-Host "Waiting for failed image removal: $Id..."
            Start-Sleep -Seconds 15
        }
    }
    Sync-LocalBoxResource -Id $Id -Expected $createExpected -CreateArguments ($CreateArguments + @('--version', $version)) -TimeoutSeconds $TimeoutSeconds -WhatIf:$WhatIfPreference
}

function Get-LocalBoxMetalLbPlan {
    param([Parameter(Mandatory)][hashtable]$Configuration, [Parameter(Mandatory)][string]$ClusterId)
    if ($ClusterId -notmatch '^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.Kubernetes/connectedClusters/[^/]+$') {
        throw 'MetalLB must target an Azure Arc connected-cluster resource.'
    }
    Test-LocalBoxAddressPool $Configuration.AKSIPPrefix $Configuration.AKSVIPStartIP $Configuration.AKSVIPEndIP `
        $Configuration.AKSGWIP @($Configuration.AKSControlPlaneIP) `
        -ReservedRanges @(@{ Start = $Configuration.AKSNodeStartIP; End = $Configuration.AKSNodeEndIP })
    return @{
        ExtensionId = "$ClusterId/providers/Microsoft.KubernetesConfiguration/extensions/arcnetworking"
        PoolId = "$ClusterId/providers/Microsoft.KubernetesRuntime/loadBalancers/aks-pool"
        PoolExpected = @{ properties = @{
            addresses = @("$($Configuration.AKSVIPStartIP)-$($Configuration.AKSVIPEndIP)")
            advertiseMode = 'ARP'
        } }
    }
}

function Get-LocalBoxArmCollection {
    param([Parameter(Mandatory)][string]$Url)
    do {
        $page = Invoke-LocalBoxAz @('rest', '--method', 'get', '--url', $Url)
        # Background-job deserialization turns nested JSON arrays into ArrayList.
        if ($page -isnot [System.Collections.IDictionary] -or -not $page.Contains('value') -or
            $page.value -isnot [System.Collections.IList]) {
            throw "Invalid ARM collection response for $Url; existing resources cannot be determined."
        }
        $page.value
        $Url = $page.nextLink
        if ($Url -and -not $Url.StartsWith('https://management.azure.com/', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unexpected ARM pagination URL.'
        }
    } while ($Url)
}

function Sync-LocalBoxMetalLb {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ClusterId,
        [Parameter(Mandatory)][hashtable]$Plan,
        [Parameter(Mandatory)][string]$RuntimeObjectId,
        [int]$TimeoutSeconds = 3600
    )
    $objectId = [guid]::Empty
    if (-not [guid]::TryParse($RuntimeObjectId, [ref]$objectId) -or $objectId -eq [guid]::Empty -or
        $objectId -eq [guid]'087fca6e-4606-4d41-b3f6-5ebdf75b8b4c') {
        throw 'Supply the tenant-specific Microsoft.KubernetesRuntime service-principal object ID, not its application ID.'
    }
    $extensionExpected = @{
        identity = @{ type = 'SystemAssigned' }
        properties = @{
            extensionType = 'microsoft.arcnetworking'
            configurationSettings = @{ k8sRuntimeFpaObjectId = $objectId.ToString() }
            autoUpgradeMinorVersion = $true
        }
    }
    if ($WhatIfPreference) {
        $null = $PSCmdlet.ShouldProcess($Plan.ExtensionId, 'Install or verify MetalLB Arc extension')
        $null = $PSCmdlet.ShouldProcess($Plan.PoolId, 'Create or verify reserved ARP address pool')
        return
    }
    $provider = Invoke-LocalBoxAz @('provider', 'show', '--namespace', 'Microsoft.KubernetesRuntime')
    if ($provider.registrationState -ne 'Registered') {
        throw 'Ask the subscription owner to register Microsoft.KubernetesRuntime before MetalLB preparation.'
    }
    $resources = @(
        @{ Id = $Plan.ExtensionId; ApiVersion = '2023-05-01'; Expected = $extensionExpected }
        @{ Id = $Plan.PoolId; ApiVersion = '2024-08-01'; Expected = $Plan.PoolExpected }
    )
    # The Runtime API needs the extension before it can manage in-cluster pools.
    foreach ($entry in $resources) {
        $collectionId = $entry.Id.Substring(0, $entry.Id.LastIndexOf('/'))
        $existing = @(Get-LocalBoxArmCollection "https://management.azure.com${collectionId}?api-version=$($entry.ApiVersion)")
        $others = @($existing | Where-Object { $_.id -ine $entry.Id })
        if ($entry.Id -eq $Plan.ExtensionId -and @($others | Where-Object { $_.properties.extensionType -ieq 'microsoft.arcnetworking' }).Count) {
            throw 'A differently named MetalLB extension exists. Ask the organizer to review it; no second extension will be installed.'
        }
        if ($entry.Id -eq $Plan.PoolId -and $others.Count) {
            throw 'An additional MetalLB address pool exists. Have the organizer review address overlap and service selection before continuing; existing pools are not changed.'
        }
        if (-not @($existing | Where-Object id -ieq $entry.Id).Count) {
            if (-not $PSCmdlet.ShouldProcess($entry.Id, 'Create shared MetalLB resource')) {
                throw 'MetalLB creation was declined; preparation is incomplete.'
            }
            $body = $entry.Expected | ConvertTo-Json -Depth 10 -Compress
            Invoke-LocalBoxAz @('rest', '--method', 'put', '--url',
                "https://management.azure.com$($entry.Id)?api-version=$($entry.ApiVersion)", '--body', $body) `
                -TimeoutSeconds $TimeoutSeconds | Out-Null
        }
        $actual = Wait-LocalBoxResource $entry.Id -TimeoutSeconds $TimeoutSeconds
        Assert-LocalBoxProperties $actual $entry.Expected
        if ($entry.Id -eq $Plan.PoolId -and $actual.properties.serviceSelector.Count -gt 0) {
            throw 'The MetalLB pool has a service selector; organizer review is required.'
        }
    }
    Write-Host "MetalLB extension and ARP pool are provisioned: $($Plan.PoolExpected.properties.addresses -join ', '). Run Full health checks to verify in-cluster readiness."
}

function Sync-LocalBoxAksProxyRole {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$ClusterId, [Parameter(Mandatory)][string]$GroupObjectId)
    if ($ClusterId -notmatch '^/subscriptions/([^/]+)/resourceGroups/[^/]+/providers/Microsoft\.Kubernetes/connectedClusters/[^/]+$') {
        throw 'The Arc proxy role must be scoped to an Azure Arc connected-cluster resource.'
    }
    $subscription = $Matches[1]
    $groupId = Assert-LocalBoxGroupId $GroupObjectId
    $roleId = '00493d72-78f6-4148-b6c5-d3ce8e4799dd'
    $roleDefinitionId = "/subscriptions/$subscription/providers/Microsoft.Authorization/roleDefinitions/$roleId"
    $action = "Assign Azure Arc Enabled Kubernetes Cluster User Role to group $groupId"
    if ($WhatIfPreference) {
        $null = $PSCmdlet.ShouldProcess($ClusterId, $action)
        return
    }
    try {
        $assignments = @(Invoke-LocalBoxAz @('role', 'assignment', 'list', '--subscription', $subscription,
            '--scope', $ClusterId, '--include-inherited', '--fill-principal-name', 'false', '--fill-role-definition-name', 'false'))
    }
    catch { throw "Cannot inspect Arc proxy RBAC on $ClusterId. The Client managed identity needs Microsoft.Authorization/roleAssignments/read at this scope. $($_.Exception.Message)" }
    $matching = @($assignments | Where-Object {
        $_.principalId -ieq $groupId -and ([string]$_.roleDefinitionId).Split('/')[-1] -ieq $roleId -and
        $_.scope -and ($_.scope -ieq $ClusterId -or $ClusterId.StartsWith(([string]$_.scope).TrimEnd('/') + '/', [StringComparison]::OrdinalIgnoreCase))
    })
    if (@($matching | Where-Object { -not $_.condition }).Count) {
        Write-Host "Reusing Azure Arc Enabled Kubernetes Cluster User Role for group $groupId on $ClusterId (direct or inherited)."
        return
    }
    if ($matching.Count) {
        throw 'An existing applicable Arc proxy role assignment has a condition. Have the access administrator review it; preparation will not replace or bypass its restrictions.'
    }
    if ($PSCmdlet.ShouldProcess($ClusterId, $action)) {
        $algorithm = [Security.Cryptography.SHA256]::Create()
        try { $hash = $algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes("$ClusterId|$groupId|$roleId".ToLowerInvariant())) }
        finally { $algorithm.Dispose() }
        $assignmentName = [guid]::new([byte[]]$hash[0..15]).ToString()
        Write-Host "Assigning Azure Arc Enabled Kubernetes Cluster User Role to group $groupId on $ClusterId..."
        try {
            $assignment = Invoke-LocalBoxAz @('role', 'assignment', 'create', '--subscription', $subscription,
                '--name', $assignmentName, '--assignee-object-id', $groupId, '--assignee-principal-type', 'Group',
                '--role', $roleDefinitionId, '--scope', $ClusterId)
        }
        catch { throw "Cannot assign Arc proxy RBAC on $ClusterId. Have an authorized administrator grant this role to group $groupId, or authorize the Client managed identity for Microsoft.Authorization/roleAssignments/write at this scope, then rerun. Preparation does not elevate its identity. $($_.Exception.Message)" }
        Assert-LocalBoxProperties $assignment @{ scope = $ClusterId; principalId = $groupId; principalType = 'Group'; roleDefinitionId = $roleDefinitionId }
        if ($assignment.condition) { throw 'The returned Arc proxy role assignment is conditional; access has not been established.' }
    }
}

function Assert-LocalBoxImagePlacement {
    param([array]$Resources, [string]$ImageId, [string]$StorageId)
    if (@($Resources | Where-Object { $_.id -ieq $ImageId }).Count -eq 0) { return }
    $image = Get-LocalBoxResource $ImageId
    if ($image.properties.containerId -ine $StorageId) {
        throw "Image '$ImageId' is on storage '$($image.properties.containerId)', but preparation requires '$StorageId' (UserStorage1). Have the facilitator review image dependencies and resolve the conflicting placement, then rerun with the documented image name. Existing images are never deleted or moved automatically."
    }
}

function Get-LocalBoxNodeState {
    param([string]$Node, [pscredential]$Credential)
    $state = Invoke-Command -VMName $Node -Credential $Credential -ErrorAction Stop -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $pool = Get-StoragePool -FriendlyName 'SU1_Pool'
        $disk = Get-VirtualDisk -FriendlyName 'UserStorage_1'
        $volume = Get-Volume -FileSystemLabel 'UserStorage_1'
        $secondary = @(Get-VirtualDisk | Where-Object FriendlyName -eq 'UserStorage_2')
        $secondaryVolume = @(Get-Volume | Where-Object FileSystemLabel -eq 'UserStorage_2')
        $secondaryCsv = @(Get-ClusterSharedVolume | Where-Object { $_.SharedVolumeInfo.Partition.Name -in $secondaryVolume.Path })
        $files = @()
        if ($secondary.Count) {
            if ($secondaryVolume.Count -ne 1 -or $secondaryCsv.Count -ne 1) { throw 'Cannot uniquely resolve UserStorage_2 volume and CSV. Removal is unsafe.' }
            $files = @(Get-ChildItem -LiteralPath $secondaryCsv[0].SharedVolumeInfo.FriendlyVolumeName -Force |
                Where-Object Name -ne 'System Volume Information')
        }
        @{
            Switches = @(Get-VMSwitch -SwitchType External | Select-Object -ExpandProperty Name)
            PoolHealth = [string]$pool.HealthStatus
            DiskHealth = [string]$disk.HealthStatus
            VolumeHealth = [string]$volume.HealthStatus
            Size = $disk.Size
            Free = $volume.SizeRemaining
            PoolFree = $pool.Size - $pool.AllocatedSize
            Copies = $disk.NumberOfDataCopies
            SecondaryPresent = $secondary.Count -gt 0
            SecondaryFiles = @($files | Select-Object -ExpandProperty Name)
            SecondaryCsv = if ($secondaryCsv.Count) { $secondaryCsv[0].Name } else { '' }
            NodesUp = @(Get-ClusterNode | Where-Object State -ne 'Up').Count -eq 0
            StorageJobs = 0
            StorageJobStates = @(Get-StorageJob | ForEach-Object { [string]$_.JobState })
            UnhealthyPhysicalDisks = @(Get-PhysicalDisk -StoragePool $pool | Where-Object HealthStatus -ne 'Healthy').Count
        }
    }
    $state.StorageJobs = @($state.StorageJobStates | Where-Object { $_ -ne 'Completed' }).Count
    return $state
}

function Assert-LocalBoxStorageRemoval {
    param($State, [array]$Resources)
    if (-not $State.NodesUp -or $State.PoolHealth -ne 'Healthy' -or $State.StorageJobs -ne 0 -or $State.UnhealthyPhysicalDisks -ne 0) {
        throw 'Storage/cluster is not healthy and idle; refusing removal.'
    }
    if (@($State.SecondaryFiles).Count) { throw 'UserStorage_2 is not empty. No files or workloads will be removed.' }
    $workloads = @($Resources | Where-Object {
        $_.type -in @('Microsoft.AzureStackHCI/virtualMachineInstances', 'Microsoft.AzureStackHCI/virtualMachines',
            'Microsoft.AzureStackHCI/virtualHardDisks', 'Microsoft.AzureStackHCI/galleryImages',
            'Microsoft.AzureStackHCI/marketplaceGalleryImages', 'Microsoft.Kubernetes/connectedClusters')
    })
    if ($workloads.Count) { throw 'Existing LocalBox workloads/images/disks found. Review and consolidate storage manually before provisioning.' }
}

function Wait-LocalBoxStorageReady {
    param([string]$Node, [pscredential]$Credential, [int]$TimeoutSeconds = 1800)
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $state = Get-LocalBoxNodeState $Node $Credential
        if ($state.PoolHealth -eq 'Healthy' -and $state.DiskHealth -eq 'Healthy' -and $state.VolumeHealth -eq 'Healthy' -and
            $state.NodesUp -and $state.StorageJobs -eq 0 -and $state.UnhealthyPhysicalDisks -eq 0) { return $state }
        if ([datetime]::UtcNow -ge $deadline) { throw "Timed out waiting for healthy, idle storage on $Node. No dependent operations were started." }
        Write-Host "Waiting for storage on $Node (pool=$($state.PoolHealth), jobs=$($state.StorageJobs), unhealthy disks=$($state.UnhealthyPhysicalDisks))..."
        Start-Sleep -Seconds 15
    } while ($true)
}

function Get-LocalBoxPartitionState {
    param([string]$Node, [pscredential]$Credential)
    $state = Invoke-Command -VMName $Node -Credential $Credential -ErrorAction Stop -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        $partitions = @(Get-Volume -FileSystemLabel 'UserStorage_1' | Get-Partition)
        if ($partitions.Count -ne 1) { throw 'Cannot uniquely resolve the UserStorage_1 partition.' }
        $partition = $partitions[0]
        $disk = $partition | Get-Disk
        if ($partition.Size -le 0 -or $partition.Offset -lt 0 -or $disk.Size -lt ($partition.Offset + $partition.Size)) {
            throw 'Invalid UserStorage_1 disk/partition sizes; refusing partition expansion.'
        }
        # Ignore the alignment/GPT tail, without running the costly supported-size query on every rerun.
        @{
            Size = $partition.Size
            NeedsExpansion = ($disk.Size - $partition.Offset - $partition.Size) -gt 1MB
        }
    }
    if ($state.NeedsExpansion -isnot [bool] -or $state.Size -le 0) {
        throw 'No valid UserStorage_1 partition state was returned; preparation cannot safely skip or perform expansion.'
    }
    return $state
}

function Initialize-LocalBoxStorage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [hashtable]$Configuration, [pscredential]$Credential, [int]$DesiredSizeGB,
        [string]$Subscription, [string]$ResourceGroup, [switch]$RemoveSecondary
    )
    $nodes = @($Configuration.NodeHostConfig.Hostname)
    $drive = Get-Volume -DriveLetter $Configuration.HostVMDriveLetter -ErrorAction Stop
    if ($drive.HealthStatus -ne 'Healthy' -or $drive.SizeRemaining -lt 200GB) {
        throw 'The backing host volume must be healthy with at least 200 GiB free. Dynamic VHDX capacity is not physical capacity.'
    }
    foreach ($node in $nodes) {
        $path = Join-Path $Configuration.HostVMPath "$node-microhack-s2d.vhdx"
        if (Test-Path -LiteralPath $path) {
            $disk = Get-VHD -Path $path -ErrorAction Stop
            if ($disk.Size -ne 1TB -or $disk.VhdType -ne 'Dynamic') { throw "Unexpected existing disk: $path" }
        }
        elseif ($PSCmdlet.ShouldProcess($path, 'Create 1 TiB dynamic nested data disk')) {
            New-VHD -Path $path -SizeBytes 1TB -Dynamic -ErrorAction Stop | Out-Null
        }
        $attached = @(Get-VMHardDiskDrive -VMName $node -ErrorAction Stop | Where-Object Path -eq $path)
        if (-not $attached.Count -and $PSCmdlet.ShouldProcess($node, "Attach $path")) {
            Add-VMHardDiskDrive -VMName $node -Path $path -ErrorAction Stop
        }
    }
    $state = Wait-LocalBoxStorageReady $nodes[0] $Credential
    if ($RemoveSecondary) {
        $resources = @(Invoke-LocalBoxAz @('resource', 'list', '--subscription', $Subscription, '--resource-group', $ResourceGroup))
        $customLocationId = "/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.ExtendedLocation/customLocations/$($Configuration.rbCustomLocationName)"
        $path = Resolve-LocalBoxStoragePath -Resources $resources -Name UserStorage2 -CustomLocationId $customLocationId -AllowMissing
        if ($state.SecondaryPresent -or $path) {
            Assert-LocalBoxStorageRemoval $state $resources
            if ($PSCmdlet.ShouldProcess('UserStorage2 / UserStorage_2', 'Permanently remove EMPTY storage path, CSV and virtual disk')) {
                if ($path) { Invoke-LocalBoxAz @('resource', 'delete', '--ids', $path.id) | Out-Null }
                if ($state.SecondaryPresent) {
                    Invoke-Command -VMName $nodes[0] -Credential $Credential -ErrorAction Stop -ScriptBlock {
                        $ErrorActionPreference = 'Stop'
                        $volume = Get-Volume -FileSystemLabel 'UserStorage_2'
                        $csv = @(Get-ClusterSharedVolume | Where-Object { $_.SharedVolumeInfo.Partition.Name -eq $volume.Path })
                        if ($csv.Count -ne 1) { throw 'Cannot uniquely resolve secondary CSV.' }
                        $content = @(Get-ChildItem -LiteralPath $csv[0].SharedVolumeInfo.FriendlyVolumeName -Force |
                            Where-Object Name -ne 'System Volume Information')
                        if ($content.Count) { throw 'Secondary volume is no longer empty; stopping.' }
                        Remove-ClusterSharedVolume -Name $csv[0].Name -ErrorAction Stop
                        Remove-VirtualDisk -FriendlyName 'UserStorage_2' -Confirm:$false -ErrorAction Stop
                    }
                }
            }
        }
    }
    if ($state.Size -lt ([uint64]$DesiredSizeGB * 1GB) -and $PSCmdlet.ShouldProcess('UserStorage_1', "Grow to $DesiredSizeGB GiB")) {
        Invoke-Command -VMName $nodes[0] -Credential $Credential -ArgumentList $DesiredSizeGB -ErrorAction Stop -ScriptBlock {
            param($TargetGB)
            $ErrorActionPreference = 'Stop'
            $pool = Get-StoragePool -FriendlyName 'SU1_Pool'
            $disk = Get-VirtualDisk -FriendlyName 'UserStorage_1'
            $target = [uint64]$TargetGB * 1GB
            $supported = Get-VirtualDiskSupportedSize -StoragePoolFriendlyName 'SU1_Pool' -ResiliencySettingName $disk.ResiliencySettingName
            $growth = $target - $disk.Size
            if ($disk.NumberOfDataCopies -lt 1 -or $growth -gt $supported.VirtualDiskSizeMax -or
                ($growth * $disk.NumberOfDataCopies + 100GB) -gt ($pool.Size - $pool.AllocatedSize)) {
                throw 'Insufficient supported storage capacity including resiliency and reserve. No resize performed.'
            }
            Resize-VirtualDisk -FriendlyName 'UserStorage_1' -Size $target
            Update-HostStorageCache -ErrorAction Stop
        }
    }
    $partitionState = Get-LocalBoxPartitionState $nodes[0] $Credential
    $needsExpansion = $partitionState.NeedsExpansion -or ($WhatIfPreference -and $state.Size -lt ([uint64]$DesiredSizeGB * 1GB))
    if ($needsExpansion -and $PSCmdlet.ShouldProcess('UserStorage_1 partition', 'Extend partition to existing virtual disk size')) {
        Invoke-Command -VMName $nodes[0] -Credential $Credential -ErrorAction Stop -ScriptBlock {
            $ErrorActionPreference = 'Stop'
            $partition = Get-Volume -FileSystemLabel 'UserStorage_1' | Get-Partition
            $maximum = ($partition | Get-PartitionSupportedSize).SizeMax
            if ($maximum -gt $partition.Size) { $partition | Resize-Partition -Size $maximum }
        }
        if ((Get-LocalBoxPartitionState $nodes[0] $Credential).NeedsExpansion) {
            throw 'UserStorage_1 still has unexpanded partition space. Inspect the disk/partition state before retrying.'
        }
    }
    elseif (-not $needsExpansion) {
        Write-Host 'UserStorage_1 partition already fills the disk; no partition expansion needed.'
    }
}

function Invoke-LocalBoxPreparation {
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Settings)
    $ErrorActionPreference = 'Stop'
    if (-not $IsWindows -or $env:COMPUTERNAME -ine 'LocalBox-Client') { throw 'Run on the Windows LocalBox-Client VM.' }
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Open PowerShell 7 as Administrator.' }
    foreach ($command in @('az', 'Get-VM', 'Get-VHD', 'Invoke-Command')) { Get-Command $command -ErrorAction Stop | Out-Null }
    $config = Import-PowerShellDataFile -LiteralPath $Settings.ConfigPath
    foreach ($required in @('SubscriptionId', 'ResourceGroupName')) {
        if (-not $Settings[$required]) { throw "$required must be supplied or available in the LocalBox environment." }
    }
    if ($Settings.SubscriptionId -ine $env:subscriptionId -or $Settings.ResourceGroupName -ine $env:resourceGroup) {
        throw 'Requested Azure scope does not match this LocalBox deployment.'
    }
    $groupId = Read-LocalBoxGroupId -Value $Settings.AksAdminGroupObjectId -SkipAks:$Settings.SkipAks
    Test-LocalBoxAddressPool $config.vmIpPrefix $Settings.VmPoolStart $Settings.VmPoolEnd $config.vmGateway @($config.dcVLAN200IP)
    $vipRange = @{ Start = $config.AKSVIPStartIP; End = $config.AKSVIPEndIP }
    Test-LocalBoxAddressPool $config.AKSIPPrefix $config.AKSNodeStartIP $config.AKSNodeEndIP $config.AKSGWIP @($config.AKSControlPlaneIP) -ReservedRanges @($vipRange)
    Test-LocalBoxAddressPool $config.AKSIPPrefix $config.AKSControlPlaneIP $config.AKSControlPlaneIP $config.AKSGWIP -ReservedRanges @($vipRange)
    if ($config.vmVLAN -eq $config.AKSVLAN -or $config.vmIpPrefix -eq $config.AKSIPPrefix) { throw 'VMs and AKS must use separate VLANs and subnets.' }
    $Settings.NodeCredential = Resolve-LocalBoxNodeCredential -Configuration $config -Credential $Settings.NodeCredential
    $previousConfig = $env:AZURE_CONFIG_DIR
    $previousExtensions = $env:AZURE_EXTENSION_DIR
    $previousDynamicInstall = $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL
    $profile = Join-Path ([IO.Path]::GetTempPath()) "microhack-az-$([guid]::NewGuid())"
    $lock = [Threading.Mutex]::new($false, 'Global\MicroHackLocalBoxPreparation')
    $locked = $false
    try {
        $locked = $lock.WaitOne(0)
        if (-not $locked) { throw 'Another LocalBox preparation is running.' }
        if (-not $previousExtensions) {
            $base = if ($previousConfig) { $previousConfig } else { Join-Path $HOME '.azure' }
            $env:AZURE_EXTENSION_DIR = Join-Path $base 'cliextensions'
        }
        $env:AZURE_CONFIG_DIR = $profile
        $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'no'
        Write-Host 'Checking managed identity, Azure resources and CLI prerequisites...'
        Invoke-LocalBoxAz @('login', '--identity') | Out-Null
        Invoke-LocalBoxAz @('account', 'set', '--subscription', $Settings.SubscriptionId) | Out-Null
        if (-not (Initialize-LocalBoxCliExtension -WhatIf:$false)) {
            Write-Warning 'Required CLI extension installation was declined. Remaining preparation checks were not run.'
            return
        }
        $scope = "/subscriptions/$($Settings.SubscriptionId)/resourceGroups/$($Settings.ResourceGroupName)"
        $metalLb = $null
        if (-not $Settings.SkipAks) {
            $metalLb = Get-LocalBoxMetalLbPlan -Configuration $config -ClusterId "$scope/providers/Microsoft.Kubernetes/connectedClusters/$($Settings.AksClusterName)"
            if (-not $Settings.KubernetesRuntimeObjectId) {
                $group = Invoke-LocalBoxAz @('group', 'show', '--subscription', $Settings.SubscriptionId, '--name', $Settings.ResourceGroupName)
                $Settings.KubernetesRuntimeObjectId = $group.tags.'microhack-k8s-runtime-object-id'
            }
            $runtimeId = [guid]::Empty
            if (-not [guid]::TryParse($Settings.KubernetesRuntimeObjectId, [ref]$runtimeId) -or $runtimeId -eq [guid]::Empty -or
                $runtimeId -eq [guid]'087fca6e-4606-4d41-b3f6-5ebdf75b8b4c') {
                throw 'Supply -KubernetesRuntimeObjectId from the subscription organizer, or rerun the updated Console shared setup to publish its resource-group tag. The Client does not query Graph.'
            }
        }
        $resources = @(Invoke-LocalBoxAz @('resource', 'list', '--resource-group', $Settings.ResourceGroupName))
        $cluster = @($resources | Where-Object { $_.type -ieq 'Microsoft.AzureStackHCI/clusters' -and $_.name -eq $config.ClusterName })
        if ($cluster.Count -ne 1) { throw 'Azure Local cluster not found; complete Jumpstart provisioning first.' }
        $clusterState = Get-LocalBoxResource $cluster[0].id
        if ($clusterState.properties.provisioningState -ne 'Succeeded' -or $clusterState.properties.connectivityStatus -ne 'Connected') { throw 'Azure Local is not provisioned and connected.' }
        $custom = Get-LocalBoxResource "$scope/providers/Microsoft.ExtendedLocation/customLocations/$($config.rbCustomLocationName)"
        if ($custom.properties.provisioningState -ne 'Succeeded') { throw 'Custom location is not ready.' }
        $bridges = @($resources | Where-Object type -ieq 'Microsoft.ResourceConnector/appliances')
        if ($bridges.Count -ne 1) { throw 'Expected one Arc Resource Bridge.' }
        $bridge = Get-LocalBoxResource $bridges[0].id
        if ($bridge.properties.provisioningState -ne 'Succeeded' -or $bridge.properties.status -ne 'Running') { throw 'Arc Resource Bridge is not running.' }
        $extensions = @($custom.properties.clusterExtensionIds | Where-Object { $_ -match '/hybridaksextension$' })
        if ($extensions.Count -ne 1 -or (Get-LocalBoxResource $extensions[0]).properties.provisioningState -ne 'Succeeded') { throw 'hybridaksextension is not ready.' }
        foreach ($node in $config.NodeHostConfig.Hostname) {
            Write-Host "Checking nested node $node and storage health..."
            if ((Get-VM -Name $node).State -ne 'Running') { throw "Nested node $node is not running." }
            $state = Get-LocalBoxNodeState $node $Settings.NodeCredential
            if (-not $state.NodesUp -or $state.PoolHealth -ne 'Healthy') { throw "Nested cluster/storage is not healthy on $node." }
            if (-not $Settings.VmSwitchName) {
                if ($state.Switches.Count -ne 1) { throw 'Specify -VmSwitchName when there is more than one external switch.' }
                $Settings.VmSwitchName = $state.Switches[0]
            }
            if ($Settings.VmSwitchName -notin $state.Switches) { throw "External switch not present on $node." }
        }
        $storage = Resolve-LocalBoxStoragePath -Resources $resources -Name UserStorage1 -CustomLocationId $custom.id
        $storageId = $storage.id
        $imageId = "$scope/providers/Microsoft.AzureStackHCI/marketplaceGalleryImages/$($Settings.ImageName)"
        Assert-LocalBoxImagePlacement -Resources $resources -ImageId $imageId -StorageId $storageId
        Write-Host 'Preparing nested disks and UserStorage_1; secondary storage is preserved unless explicitly requested...'
        Initialize-LocalBoxStorage -Configuration $config -Credential $Settings.NodeCredential -DesiredSizeGB $Settings.StorageSizeGB `
            -Subscription $Settings.SubscriptionId -ResourceGroup $Settings.ResourceGroupName -RemoveSecondary:$Settings.RemoveUserStorage2
        $state = Get-LocalBoxNodeState $config.NodeHostConfig[0].Hostname $Settings.NodeCredential
        if (-not $WhatIfPreference -and ($state.Size -lt ($Settings.StorageSizeGB * 1GB) -or $state.Free -lt 100GB)) { throw 'UserStorage_1 is too small or has less than 100 GiB free.' }
        $location = $custom.location
        $timeout = $Settings.TimeoutMinutes * 60
        $common = @('--subscription', $Settings.SubscriptionId, '--resource-group', $Settings.ResourceGroupName, '--location', $location, '--custom-location', $custom.id)
        $networks = @(
            @{ Name = 'localbox-vm-lnet-vlan200'; Prefix = $config.vmIpPrefix; Gateway = $config.vmGateway; Dns = $config.vmDNS; Vlan = $config.vmVLAN; Start = $Settings.VmPoolStart; End = $Settings.VmPoolEnd },
            @{ Name = 'localbox-aks-lnet-vlan110'; Prefix = $config.AKSIPPrefix; Gateway = $config.AKSGWIP; Dns = $config.AKSDNSIP; Vlan = $config.AKSVLAN; Start = $config.AKSNodeStartIP; End = $config.AKSNodeEndIP }
        )
        foreach ($network in $networks) {
            Write-Host "Preparing logical network $($network.Name)..."
            $network.Id = "$scope/providers/Microsoft.AzureStackHCI/logicalNetworks/$($network.Name)"
            $network.Expected = @{
                extendedLocation = @{ name = $custom.id }; location = $location
                properties = @{ vmSwitchName = $Settings.VmSwitchName; dhcpOptions = @{ dnsServers = @($network.Dns) }; subnets = @(@{
                    properties = @{ addressPrefix = $network.Prefix; ipAllocationMethod = 'Static'; vlan = [int]$network.Vlan
                        ipPools = @(@{ start = $network.Start; end = $network.End }); routeTable = @{ properties = @{ routes = @(@{ properties = @{ addressPrefix = '0.0.0.0/0'; nextHopIpAddress = $network.Gateway } }) } }
                    }
                }) }
            }
            Sync-LocalBoxResource -Id $network.Id -Expected $network.Expected -TimeoutSeconds $timeout -CreateArguments (@('stack-hci-vm', 'network', 'lnet', 'create') + $common + @(
                '--name', $network.Name, '--vm-switch-name', $Settings.VmSwitchName, '--ip-allocation-method', 'Static', '--address-prefixes', $network.Prefix,
                '--gateway', $network.Gateway, '--dns-servers', $network.Dns, '--vlan', $network.Vlan, '--ip-pool-start', $network.Start, '--ip-pool-end', $network.End)) | Out-Null
        }
        $aksId = "$scope/providers/Microsoft.Kubernetes/connectedClusters/$($Settings.AksClusterName)"
        $instanceId = "$aksId/providers/Microsoft.HybridContainerService/provisionedClusterInstances/default"
        $aksExpected = @{ extendedLocation = @{ name = $custom.id }; properties = @{
            controlPlane = @{ count = 1; vmSize = $Settings.ControlPlaneVmSize; controlPlaneEndpoint = @{ hostIP = $config.AKSControlPlaneIP } }
            cloudProviderProfile = @{ infraNetworkProfile = @{ vnetSubnetIds = @($networks[1].Id) } }
            agentPoolProfiles = @(@{ count = $Settings.NodeCount; vmSize = $Settings.NodeVmSize })
        } }
        if ($Settings.KubernetesVersion) { $aksExpected.properties.kubernetesVersion = $Settings.KubernetesVersion }
        $existingAks = @((Invoke-LocalBoxAz @('resource', 'list', '--resource-group', $Settings.ResourceGroupName)) | Where-Object id -ieq $aksId)
        if (-not $Settings.SkipAks -and -not $existingAks.Count) {
            $arguments = @('aksarc', 'create') + $common + @('--name', $Settings.AksClusterName, '--vnet-ids', $networks[1].Id,
                '--aad-admin-group-object-ids', $groupId, '--generate-ssh-keys', '--control-plane-ip', $config.AKSControlPlaneIP,
                '--node-count', [string]$Settings.NodeCount, '--node-vm-size', $Settings.NodeVmSize, '--control-plane-count', '1', '--control-plane-vm-size', $Settings.ControlPlaneVmSize)
            if ($Settings.KubernetesVersion) { $arguments += @('--kubernetes-version', $Settings.KubernetesVersion) }
            if ($PSCmdlet.ShouldProcess($aksId, 'Validate and create AKS on Azure Local')) {
                Write-Host "Validating AKS on Azure Local $($Settings.AksClusterName)..."
                Invoke-LocalBoxAz ($arguments + @('--validate')) -TimeoutSeconds $timeout -NoOutput
                Write-Host "Creating AKS on Azure Local $($Settings.AksClusterName)..."
                Invoke-LocalBoxAz $arguments -TimeoutSeconds $timeout -NoOutput
            }
        }
        if (-not $Settings.SkipAks -and -not $WhatIfPreference) {
            $instance = Wait-LocalBoxResource $instanceId -TimeoutSeconds $timeout
            Assert-LocalBoxProperties $instance $aksExpected
            $connected = Wait-LocalBoxResource $aksId -TimeoutSeconds $timeout
            Assert-LocalBoxProperties $connected @{ properties = @{ aadProfile = @{ adminGroupObjectIDs = @($groupId) } } }
            $deadline = [datetime]::UtcNow.AddSeconds($timeout)
            while ($connected.properties.connectivityStatus -ne 'Connected') {
                if ([datetime]::UtcNow -ge $deadline) { throw 'AKS exists but Azure Arc is not connected.' }
                Start-Sleep -Seconds 15
                $connected = Get-LocalBoxResource $aksId
            }
        }
        if (-not $Settings.SkipAks) {
            Sync-LocalBoxAksProxyRole -ClusterId $aksId -GroupObjectId $groupId -WhatIf:$WhatIfPreference
            Sync-LocalBoxMetalLb -ClusterId $aksId -Plan $metalLb -RuntimeObjectId $Settings.KubernetesRuntimeObjectId `
                -TimeoutSeconds $timeout -WhatIf:$WhatIfPreference
        }
        $provider = Invoke-LocalBoxAz @('provider', 'show', '--namespace', 'Microsoft.EdgeMarketplace')
        if ($provider.registrationState -ne 'Registered') { throw 'Ask the subscription administrator to register Microsoft.EdgeMarketplace before importing the image.' }
        $imageExpected = @{
            extendedLocation = @{ name = $custom.id }; location = $location
            properties = @{ containerId = $storageId; osType = 'Windows'; identifier = @{
                publisher = 'microsoftwindowsserver'; offer = 'windowsserver'; sku = '2025-datacenter-azure-edition-smalldisk'
            } }
        }
        if ($Settings.ImageVersion -ne 'latest') { $imageExpected.properties.version = @{ name = $Settings.ImageVersion } }
        Write-Host "Preparing VM image $($Settings.ImageName); download can take several hours..."
        $image = Sync-LocalBoxImage -Id $imageId -Expected $imageExpected -ClusterId $cluster[0].id -TimeoutSeconds $timeout -CreateArguments (@('stack-hci-vm', 'image', 'create') + $common + @(
            '--name', $Settings.ImageName, '--os-type', 'Windows', '--publisher', 'microsoftwindowsserver', '--offer', 'windowsserver',
            '--sku', '2025-datacenter-azure-edition-smalldisk', '--storage-path-id', $storageId))
        $referenceVm = Sync-LocalBoxReferenceVm -Settings $Settings -Location $location -CustomLocationId $custom.id `
            -ImageId $imageId -NetworkId $networks[0].Id -StorageId $storageId -WhatIf:$WhatIfPreference
        $manifest = @{
            SubscriptionId = $Settings.SubscriptionId; ResourceGroupName = $Settings.ResourceGroupName; CustomLocationId = $custom.id
            ClusterId = $cluster[0].id; BridgeId = $bridge.id; ExtensionId = $extensions[0]; StorageId = $storageId
            ImageId = $imageId; ImageExpected = $imageExpected; ImageVersion = $image.properties.version.name
            Networks = $networks; AksId = $aksId; AksInstanceId = $instanceId; AksExpected = $aksExpected; AksAdminGroupObjectId = $groupId
            NodeNames = @($config.NodeHostConfig.Hostname); StorageSizeGB = $Settings.StorageSizeGB; PreparedAt = [datetime]::UtcNow.ToString('o')
            FullHealthVerified = $false
            AksPreparationSkipped = [bool]$Settings.SkipAks
            MetalLb = $metalLb
        }
        if ($referenceVm) { $manifest.ReferenceVm = $referenceVm }
        elseif (Test-Path -LiteralPath $Settings.ManifestPath) {
            $previousManifest = Get-Content -LiteralPath $Settings.ManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable
            if ($previousManifest.SubscriptionId -ieq $Settings.SubscriptionId -and
                $previousManifest.ResourceGroupName -ieq $Settings.ResourceGroupName -and $previousManifest.ReferenceVm) {
                $manifest.ReferenceVm = $previousManifest.ReferenceVm
            }
        }
        if ($PSCmdlet.ShouldProcess($Settings.ManifestPath, 'Write nonsecret preparation manifest')) {
            $manifest | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Settings.ManifestPath -Encoding utf8
        }
        if ($Settings.SkipAks) { Write-Warning 'AKS was explicitly skipped. Rerun with an admin-group ID before full health validation; this environment is not event-ready.' }
        Write-Host 'Preparation finished. Run test-sovereign-cloud.ps1 before declaring the environment ready.'
    }
    finally {
        $env:AZURE_CONFIG_DIR = $previousConfig
        $env:AZURE_EXTENSION_DIR = $previousExtensions
        $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = $previousDynamicInstall
        if (Test-Path -LiteralPath $profile) { Remove-Item -LiteralPath $profile -Recurse -Force -WhatIf:$false }
        if ($locked) { $lock.ReleaseMutex() }
        $lock.Dispose()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $settings = @{
        SubscriptionId = $SubscriptionId; ResourceGroupName = $ResourceGroupName; ConfigPath = $ConfigPath
        AksAdminGroupObjectId = $AksAdminGroupObjectId; KubernetesRuntimeObjectId = $KubernetesRuntimeObjectId
        SkipAks = [bool]$SkipAks; NodeCredential = $NodeCredential; VmSwitchName = $VmSwitchName
        IncludeReferenceVm = [bool]$IncludeReferenceVm; ReferenceVmCredential = $ReferenceVmCredential
        ImageName = $ImageName; ImageVersion = $ImageVersion; VmPoolStart = $VmPoolStart; VmPoolEnd = $VmPoolEnd
        AksClusterName = $AksClusterName; KubernetesVersion = $KubernetesVersion; NodeVmSize = $NodeVmSize
        ControlPlaneVmSize = $ControlPlaneVmSize; NodeCount = $NodeCount; StorageSizeGB = $StorageSizeGB
        RemoveUserStorage2 = [bool]$RemoveUserStorage2
        TimeoutMinutes = $TimeoutMinutes; ManifestPath = $ManifestPath
    }
    Invoke-LocalBoxPreparation -Settings $settings
}