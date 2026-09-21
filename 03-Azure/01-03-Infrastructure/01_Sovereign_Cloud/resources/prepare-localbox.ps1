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
Dot-source this file to load its functions without running provisioning.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SubscriptionId = $env:subscriptionId,
    [string]$ResourceGroupName = $env:resourceGroup,
    [string]$ConfigPath = $env:LocalBoxConfigFile,
    [string]$AksAdminGroupObjectId,
    [switch]$SkipAks,
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
    [switch]$AddressReservationsConfirmed,
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
    Invoke-LocalBoxAz $arguments
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

function Initialize-LocalBoxStorage {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
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
        }
    }
    if ($PSCmdlet.ShouldProcess('UserStorage_1 partition', 'Extend partition to existing virtual disk size')) {
        Invoke-Command -VMName $nodes[0] -Credential $Credential -ErrorAction Stop -ScriptBlock {
            $ErrorActionPreference = 'Stop'
            $partition = Get-Volume -FileSystemLabel 'UserStorage_1' | Get-Partition
            $maximum = ($partition | Get-PartitionSupportedSize).SizeMax
            if ($maximum -gt $partition.Size) { $partition | Resize-Partition -Size $maximum }
        }
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
    if (-not $Settings.AddressReservationsConfirmed) {
        throw 'Verify BOTH pools against DHCP leases/exclusions and static reservations, then pass -AddressReservationsConfirmed. The script does not alter DHCP/router configuration.'
    }
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
        $provider = Invoke-LocalBoxAz @('provider', 'show', '--namespace', 'Microsoft.EdgeMarketplace')
        if ($provider.registrationState -ne 'Registered') { throw 'Ask the subscription administrator to register Microsoft.EdgeMarketplace before importing the image.' }
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
        $imageExpected = @{
            extendedLocation = @{ name = $custom.id }; location = $location
            properties = @{ containerId = $storageId; osType = 'Windows'; identifier = @{
                publisher = 'microsoftwindowsserver'; offer = 'windowsserver'; sku = '2025-datacenter-azure-edition-smalldisk'
            } }
        }
        if ($Settings.ImageVersion -ne 'latest') { $imageExpected.properties.version = @{ name = $Settings.ImageVersion } }
        Write-Host "Preparing VM image $($Settings.ImageName); download can take several hours..."
        $image = Sync-LocalBoxResource -Id $imageId -Expected $imageExpected -TimeoutSeconds $timeout -CreateArguments (@('stack-hci-vm', 'image', 'create') + $common + @(
            '--name', $Settings.ImageName, '--os-type', 'Windows', '--publisher', 'microsoftwindowsserver', '--offer', 'windowsserver',
            '--sku', '2025-datacenter-azure-edition-smalldisk', '--version', $Settings.ImageVersion, '--storage-path-id', $storageId))
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
        $manifest = @{
            SubscriptionId = $Settings.SubscriptionId; ResourceGroupName = $Settings.ResourceGroupName; CustomLocationId = $custom.id
            ClusterId = $cluster[0].id; BridgeId = $bridge.id; ExtensionId = $extensions[0]; StorageId = $storageId
            ImageId = $imageId; ImageExpected = $imageExpected; ImageVersion = $image.properties.version.name
            Networks = $networks; AksId = $aksId; AksInstanceId = $instanceId; AksExpected = $aksExpected; AksAdminGroupObjectId = $groupId
            NodeNames = @($config.NodeHostConfig.Hostname); StorageSizeGB = $Settings.StorageSizeGB; PreparedAt = [datetime]::UtcNow.ToString('o')
            FullHealthVerified = $false
            AksPreparationSkipped = [bool]$Settings.SkipAks
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
        AksAdminGroupObjectId = $AksAdminGroupObjectId; SkipAks = [bool]$SkipAks; NodeCredential = $NodeCredential; VmSwitchName = $VmSwitchName
        ImageName = $ImageName; ImageVersion = $ImageVersion; VmPoolStart = $VmPoolStart; VmPoolEnd = $VmPoolEnd
        AksClusterName = $AksClusterName; KubernetesVersion = $KubernetesVersion; NodeVmSize = $NodeVmSize
        ControlPlaneVmSize = $ControlPlaneVmSize; NodeCount = $NodeCount; StorageSizeGB = $StorageSizeGB
        RemoveUserStorage2 = [bool]$RemoveUserStorage2; AddressReservationsConfirmed = [bool]$AddressReservationsConfirmed
        TimeoutMinutes = $TimeoutMinutes; ManifestPath = $ManifestPath
    }
    Invoke-LocalBoxPreparation -Settings $settings
}