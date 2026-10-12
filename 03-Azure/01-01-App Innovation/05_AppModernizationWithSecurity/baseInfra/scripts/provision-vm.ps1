<#
.SYNOPSIS
Provisions one frozen workshop stack on a Windows Server 2025 facilitator VM.

.DESCRIPTION
Installs only lock-file-pinned tools, verifies every downloaded artifact before use,
deploys the immutable application source, configures the native local database,
registers an automatic application task, and fails unless stack-specific smoke checks pass.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('dotnet', 'java')]
    [string]$Stack,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$SourceCommit,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://github\.com/CZSK-MicroHacks/MicroHack-AppInnovation/archive/[0-9a-f]{40}\.zip$')]
    [string]$SourceArchiveUrl,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$SourceArchiveSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = 'C:\MicroHack'
$DownloadRoot = Join-Path $Root 'downloads'
$SourceRoot = Join-Path $Root 'source'
# The data the running legacy application serves, held outside $SourceRoot on purpose.
# Challenge 1 has participants modernize the tree in $SourceRoot, and a plausible early step
# there -- moving the image corpus to Blob Storage -- used to stop the legacy application
# dead, because it served its images straight out of the tree being edited. Nothing the
# participant does to their checkout can reach this copy.
$LegacyDataRoot = Join-Path $Root 'legacy-data'
$ApplicationRoot = Join-Path $Root 'app'
$StatusRoot = Join-Path $Root 'status'
$SecretRoot = Join-Path $Root 'secrets'
$ProtectedRoot = 'C:\protected'
$MigrationRoot = 'C:\ProgramData\MicroHack\migration'
$LogRoot = Join-Path $Root 'logs'
$LogFile = Join-Path $LogRoot "provision-$Stack.log"

foreach ($Directory in @(
        $Root,
        $DownloadRoot,
        $ApplicationRoot,
        $StatusRoot,
        $SecretRoot,
        $LogRoot
    )) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

function Write-ProvisionLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $Line = '{0} [{1}] {2}' -f (Get-Date).ToUniversalTime().ToString('o'), $Stack, $Message
    Write-Host $Line
    Add-Content -Path $LogFile -Value $Line -Encoding UTF8
}

function Invoke-VerifiedDownload {
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [ValidateSet('SHA256', 'SHA512')]
        [string]$Algorithm,

        [Parameter(Mandatory)]
        [string]$ExpectedHash
    )

    if (Test-Path $Destination) {
        $ExistingHash = (Get-FileHash -Path $Destination -Algorithm $Algorithm).Hash.ToLowerInvariant()
        if ($ExistingHash -eq $ExpectedHash) {
            Write-ProvisionLog "Reusing verified download $(Split-Path $Destination -Leaf)."
            return
        }
        Remove-Item -Path $Destination -Force
    }

    $Temporary = "$Destination.download"
    Remove-Item -Path $Temporary -Force -ErrorAction SilentlyContinue
    Write-ProvisionLog "Downloading locked artifact $($Uri.AbsoluteUri)."
    Invoke-WebRequest -Uri $Uri -OutFile $Temporary -UseBasicParsing
    $ActualHash = (Get-FileHash -Path $Temporary -Algorithm $Algorithm).Hash.ToLowerInvariant()
    if ($ActualHash -ne $ExpectedHash) {
        Remove-Item -Path $Temporary -Force
        throw "Digest verification failed for $($Uri.AbsoluteUri)."
    }
    Move-Item -Path $Temporary -Destination $Destination -Force
}

function Assert-AuthenticodePublisher {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Publisher
    )

    $Signature = Get-AuthenticodeSignature -FilePath $Path
    if ($Signature.Status -ne [Management.Automation.SignatureStatus]::Valid) {
        throw "Authenticode signature is not valid for $(Split-Path $Path -Leaf)."
    }
    if ($null -eq $Signature.SignerCertificate -or
        $Signature.SignerCertificate.Subject -notmatch [regex]::Escape($Publisher)) {
        throw "Authenticode publisher mismatch for $(Split-Path $Path -Leaf)."
    }
}

function Get-NativeCommandOutput {
    <#
    .SYNOPSIS
    Runs a native executable and returns its merged stdout and stderr as an array of lines.

    .DESCRIPTION
    java.exe, code.cmd, SqlPackage.exe and sqlcmd all report version banners or warnings on
    stderr. Redirecting stderr into the success stream turns those lines into error records,
    which this script's file-wide 'Stop' preference then promotes to terminating errors, so
    every such version check aborts provisioning instead of returning a string. Demoting the
    preference for the duration of the call is what makes the merged output readable.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string[]]$Arguments = @()
    )

    $PreviousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        return @(& $Path @Arguments 2>&1 | ForEach-Object { [string]$_ })
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }
}

function Invoke-LockedInstaller {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [int[]]$AllowedExitCodes = @(0, 3010)
    )

    Write-ProvisionLog "Executing verified installer $(Split-Path $Path -Leaf)."
    $Process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    if ($Process.ExitCode -notin $AllowedExitCodes) {
        throw "Installer $(Split-Path $Path -Leaf) exited with code $($Process.ExitCode)."
    }
}

function Add-MachinePath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $MachinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $Entries = @($MachinePath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($Entries.TrimEnd('\') -notcontains $Path.TrimEnd('\')) {
        [Environment]::SetEnvironmentVariable(
            'Path',
            (($Entries + $Path) -join ';'),
            'Machine'
        )
    }
    if (($env:Path -split ';').TrimEnd('\') -notcontains $Path.TrimEnd('\')) {
        $env:Path = "$env:Path;$Path"
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [int]$Attempts = 60,

        [int]$DelaySeconds = 5
    )

    for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
        try {
            & $Action
            Write-ProvisionLog "$Description succeeded on attempt $Attempt."
            return
        }
        catch {
            if ($Attempt -eq $Attempts) {
                throw "$Description failed after $Attempts attempts: $($_.Exception.Message)"
            }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Set-ProtectedAcl {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Directory,

        # Optional account granted access alongside SYSTEM and Administrators. Used for
        # C:\protected, whose deployment parameter files the participant has to read from
        # the ordinary, non-elevated session they run az from, and for $MigrationRoot,
        # which the participant has to write into from that same session. The account is
        # already a local administrator, so this grants no capability it could not obtain
        # by elevating — it only removes a UAC filtered-token failure from the middle of
        # Challenge 1. The database passwords under $SecretRoot are never given this
        # parameter.
        [AllowEmptyString()]
        [string]$ReadPrincipal = '',

        # Rights for $ReadPrincipal. Read is the default because every other call site only
        # needs the file back; $MigrationRoot needs Modify because the participant creates
        # the database export inside it rather than reading something already there.
        [ValidateSet('Read', 'Modify')]
        [string]$PrincipalRights = 'Read'
    )

    $Acl = if ($Directory) {
        New-Object Security.AccessControl.DirectorySecurity
    }
    else {
        New-Object Security.AccessControl.FileSecurity
    }
    $Acl.SetAccessRuleProtection($true, $false)
    $Grants = [ordered]@{
        'NT AUTHORITY\SYSTEM'    = 'FullControl'
        'BUILTIN\Administrators' = 'FullControl'
    }
    if (-not [string]::IsNullOrWhiteSpace($ReadPrincipal) -and -not $Grants.Contains($ReadPrincipal)) {
        $Grants[$ReadPrincipal] = $PrincipalRights
    }
    foreach ($Grant in $Grants.GetEnumerator()) {
        if ($Directory) {
            $Rule = New-Object Security.AccessControl.FileSystemAccessRule(
                $Grant.Key,
                $Grant.Value,
                'ContainerInherit,ObjectInherit',
                'None',
                'Allow'
            )
        }
        else {
            $Rule = New-Object Security.AccessControl.FileSystemAccessRule(
                $Grant.Key,
                $Grant.Value,
                'Allow'
            )
        }
        $Acl.AddAccessRule($Rule)
    }
    Set-Acl -Path $Path -AclObject $Acl
}

function Save-ProtectedText {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [AllowEmptyString()]
        [string]$ReadPrincipal = ''
    )

    [IO.File]::WriteAllText(
        $Path,
        $Value,
        (New-Object Text.UTF8Encoding($false))
    )
    Set-ProtectedAcl -Path $Path -ReadPrincipal $ReadPrincipal
}

function Save-ProtectedConfiguration {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [Collections.IDictionary]$Values,

        # Nested documents such as ARM parameter files need more than ConvertTo-Json's
        # default of two levels; anything deeper is silently replaced by a type name.
        [ValidateRange(1, 20)]
        [int]$Depth = 2,

        [AllowEmptyString()]
        [string]$ReadPrincipal = ''
    )

    Save-ProtectedText -Path $Path -ReadPrincipal $ReadPrincipal `
        -Value (ConvertTo-Json -InputObject $Values -Depth $Depth)
}

function Remove-ProtectedFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $Length = (Get-Item -LiteralPath $Path).Length
    if ($Length -gt 0) {
        [IO.File]::WriteAllBytes($Path, (New-Object byte[] $Length))
    }
    Remove-Item -LiteralPath $Path -Force
}

function Get-ProvisioningSecrets {
    $PayloadPath = Join-Path $SecretRoot 'provisioning.json'
    if (-not (Test-Path -LiteralPath $PayloadPath)) {
        throw 'The protected provisioning payload is unavailable.'
    }
    Set-ProtectedAcl -Path $PayloadPath
    $Payload = Get-Content -LiteralPath $PayloadPath -Raw | ConvertFrom-Json
    foreach ($Field in @(
            'databasePassword',
            'performanceApiKey',
            'facilitatorPrincipalName',
            'facilitatorPrincipalObjectId',
            'resourceGroupName',
            'teamName',
            'adminUsername',
            'migrationSourceVirtualNetworkResourceId',
            'migrationSourceVmResourceId'
        )) {
        $Property = $Payload.PSObject.Properties[$Field]
        if ($null -eq $Property -or [string]::IsNullOrWhiteSpace([string]$Property.Value)) {
            throw "The protected provisioning payload is missing $Field."
        }
    }
    return $Payload
}

Set-ProtectedAcl -Path $SecretRoot -Directory
Set-ProtectedAcl -Path $PSCommandPath
$ProvisioningSecrets = Get-ProvisioningSecrets
$DatabasePassword = [string]$ProvisioningSecrets.databasePassword
$PerformanceApiKey = [string]$ProvisioningSecrets.performanceApiKey
$FacilitatorPrincipalName = [string]$ProvisioningSecrets.facilitatorPrincipalName
$FacilitatorPrincipalObjectId = [string]$ProvisioningSecrets.facilitatorPrincipalObjectId
$ParticipantResourceGroup = [string]$ProvisioningSecrets.resourceGroupName
$TeamName = [string]$ProvisioningSecrets.teamName
$AdminUsername = [string]$ProvisioningSecrets.adminUsername
$SourceVirtualNetworkResourceId = [string]$ProvisioningSecrets.migrationSourceVirtualNetworkResourceId
$SourceVmResourceId = [string]$ProvisioningSecrets.migrationSourceVmResourceId
$ProvisioningSecrets = $null

function New-MigrationExportDirectory {
    <#
    .SYNOPSIS
    Creates C:\ProgramData\MicroHack\migration with an explicit participant ACE.

    .DESCRIPTION
    Participants export the legacy database under this directory during Challenge 1.
    Provisioning creates C:\ProgramData\MicroHack as SYSTEM, so without an explicit ACE
    whether a non-elevated participant may create a subfolder there is left to inherited
    permissions. Creating it here with an explicit Modify ACE makes that predictable.
    #>

    New-Item -ItemType Directory -Path $MigrationRoot -Force | Out-Null
    Set-ProtectedAcl -Path $MigrationRoot -Directory -ReadPrincipal $AdminUsername `
        -PrincipalRights 'Modify'
    Write-ProvisionLog "Prepared $MigrationRoot with Modify for $AdminUsername."
}

function Install-CommonTools {
    $Artifacts = @{
        VsCode = @{
            Version   = '1.133.0'
            Uri       = 'https://update.code.visualstudio.com/1.133.0/win32-x64/stable'
            Hash      = 'de949a8904509a7661b93ea3b25ea312749b869c242938ad082ddc72d6741c3d'
            Publisher = 'Microsoft Corporation'
        }
        AzureCli = @{
            Version   = '2.80.0'
            Uri       = 'https://azcliprod.blob.core.windows.net/msi/azure-cli-2.80.0-x64.msi'
            Hash      = 'ab9d66e7d8537401d5bd734086daf80f60a9b7fe1ace9cb78470741e7bbaccf5'
            Publisher = 'Microsoft Corporation'
        }
        Uv = @{
            Version = '0.8.22'
            Uri     = 'https://github.com/astral-sh/uv/releases/download/0.8.22/uv-x86_64-pc-windows-msvc.zip'
            Hash    = '5049375aa2a5162f132b2c1cb992e25d42d47d934cab8c174dbe6f60973dcc12'
        }
        Git = @{
            Version   = '2.55.0.windows.5'
            Uri       = 'https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/Git-2.55.0.5-64-bit.exe'
            Hash      = 'd065a4e23c3d9a6b5073d609b5be0830227ec3ca053c083ba385061ddfaf94c6'
            Publisher = 'Johannes Schindelin'
        }
        # jq ships unsigned from upstream, so it is pinned by SHA-256 alone. The hash below
        # is the one published in the release's own sha256sum.txt.
        Jq = @{
            Version = '1.7.1'
            Uri     = 'https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe'
            Hash    = '7451fbbf37feffb9bf262bd97c54f0da558c63f0748e64152dd87b0a07b6d6ab'
        }
    }

    $VsCodeRoot = 'C:\Program Files\Microsoft VS Code'
    $CodeCommand = Join-Path $VsCodeRoot 'bin\code.cmd'
    $InstalledVsCodeVersion = if (Test-Path $CodeCommand) {
        (@(& $CodeCommand --version | Select-Object -First 1) -join '').Trim()
    }
    else {
        $null
    }
    if ($InstalledVsCodeVersion -ne $Artifacts.VsCode.Version) {
        $Installer = Join-Path $DownloadRoot 'VSCodeSetup-1.133.0.exe'
        Invoke-VerifiedDownload -Uri $Artifacts.VsCode.Uri -Destination $Installer `
            -Algorithm SHA256 -ExpectedHash $Artifacts.VsCode.Hash
        Assert-AuthenticodePublisher -Path $Installer -Publisher $Artifacts.VsCode.Publisher
        Invoke-LockedInstaller -Path $Installer -Arguments @(
            '/VERYSILENT',
            '/NORESTART',
            '/MERGETASKS=!runcode',
            "/DIR=`"$VsCodeRoot`""
        )
    }
    if (-not (Test-Path $CodeCommand)) {
        throw 'The pinned Visual Studio Code installer did not create code.cmd.'
    }
    Add-MachinePath -Path (Join-Path $VsCodeRoot 'bin')
    if ((@(& $CodeCommand --version | Select-Object -First 1) -join '').Trim() -ne $Artifacts.VsCode.Version) {
        throw 'Visual Studio Code version verification failed.'
    }

    $AzCommand = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
    $InstalledAzureCliVersion = if (Test-Path $AzCommand) {
        ((& $AzCommand version --output json | ConvertFrom-Json).'azure-cli')
    }
    else {
        $null
    }
    if ($InstalledAzureCliVersion -ne $Artifacts.AzureCli.Version) {
        $Installer = Join-Path $DownloadRoot 'azure-cli-2.80.0-x64.msi'
        Invoke-VerifiedDownload -Uri $Artifacts.AzureCli.Uri -Destination $Installer `
            -Algorithm SHA256 -ExpectedHash $Artifacts.AzureCli.Hash
        Assert-AuthenticodePublisher -Path $Installer -Publisher $Artifacts.AzureCli.Publisher
        Invoke-LockedInstaller -Path 'msiexec.exe' -Arguments @(
            '/i',
            "`"$Installer`"",
            '/qn',
            '/norestart'
        )
    }
    if (-not (Test-Path $AzCommand)) {
        throw 'The pinned Azure CLI installer did not create az.cmd.'
    }
    Add-MachinePath -Path (Split-Path $AzCommand -Parent)
    $AzureCliVersion = ((& $AzCommand version --output json | ConvertFrom-Json).'azure-cli')
    if ($AzureCliVersion -ne $Artifacts.AzureCli.Version) {
        throw 'Azure CLI version verification failed.'
    }

    $UvRoot = 'C:\Program Files\uv'
    $UvCommand = Join-Path $UvRoot 'uv.exe'
    # `uv --version` reports `uv 0.8.22 (ade2bdbd2 2025-09-23)`, so the build hash and date
    # have to be dropped as well as the `uv ` prefix before comparing with the pinned version.
    $UvVersionPattern = '^uv\s+(?<version>\S+)'
    $InstalledUvVersion = if (Test-Path $UvCommand) {
        if ((& $UvCommand --version) -match $UvVersionPattern) { $Matches.version } else { $null }
    }
    else {
        $null
    }
    if ($InstalledUvVersion -ne $Artifacts.Uv.Version) {
        $Archive = Join-Path $DownloadRoot 'uv-0.8.22.zip'
        $ExtractRoot = Join-Path $DownloadRoot 'uv-0.8.22'
        Invoke-VerifiedDownload -Uri $Artifacts.Uv.Uri -Destination $Archive `
            -Algorithm SHA256 -ExpectedHash $Artifacts.Uv.Hash
        Remove-Item -Path $ExtractRoot -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $Archive -DestinationPath $ExtractRoot -Force
        $ExtractedUv = Get-ChildItem -Path $ExtractRoot -Filter uv.exe -Recurse |
            Select-Object -First 1
        if ($null -eq $ExtractedUv) {
            throw 'The verified uv archive did not contain uv.exe.'
        }
        # Astral ships uv unsigned, so the pinned SHA-256 of the release archive verified by
        # Invoke-VerifiedDownload above is the integrity gate for this artifact.
        New-Item -ItemType Directory -Path $UvRoot -Force | Out-Null
        Copy-Item -Path (Join-Path $ExtractedUv.Directory.FullName '*.exe') `
            -Destination $UvRoot -Force
    }
    Add-MachinePath -Path $UvRoot
    if (-not ((& $UvCommand --version) -match $UvVersionPattern) -or
        $Matches.version -ne $Artifacts.Uv.Version) {
        throw 'uv version verification failed.'
    }

    # Git backs the commit provenance both GitHub Copilot Challenge 1 paths record.
    $GitRoot = 'C:\Program Files\Git'
    $GitCommand = Join-Path $GitRoot 'cmd\git.exe'
    $InstalledGitVersion = if (Test-Path $GitCommand) {
        ((@(& $GitCommand --version | Select-Object -First 1) -join '') -replace '^git version\s+', '').Trim()
    }
    else {
        $null
    }
    if ($InstalledGitVersion -ne $Artifacts.Git.Version) {
        $Installer = Join-Path $DownloadRoot 'Git-2.55.0.5-64-bit.exe'
        Invoke-VerifiedDownload -Uri $Artifacts.Git.Uri -Destination $Installer `
            -Algorithm SHA256 -ExpectedHash $Artifacts.Git.Hash
        Assert-AuthenticodePublisher -Path $Installer -Publisher $Artifacts.Git.Publisher
        Invoke-LockedInstaller -Path $Installer -Arguments @(
            '/VERYSILENT',
            '/NORESTART',
            '/NOCANCEL',
            '/SP-',
            '/COMPONENTS="gitlfs,gcm"',
            "/DIR=`"$GitRoot`""
        )
    }
    if (-not (Test-Path $GitCommand)) {
        throw 'The pinned Git for Windows installer did not create git.exe.'
    }
    Add-MachinePath -Path (Join-Path $GitRoot 'cmd')
    # Challenges 2 through 6 render evidence with Bash-era tools. Git for Windows already
    # ships bash, curl and the coreutils, but only under usr\bin, which the installer does
    # not add to PATH.
    Add-MachinePath -Path (Join-Path $GitRoot 'usr\bin')
    if (((@(& $GitCommand --version | Select-Object -First 1) -join '') -replace '^git version\s+', '').Trim() -ne $Artifacts.Git.Version) {
        throw 'Git version verification failed.'
    }

    # jq backs every evidence-rendering block in the later chapters. It is a single
    # executable, so "installing" it is a verified download into a directory on PATH.
    $JqRoot = 'C:\Program Files\jq'
    $JqCommand = Join-Path $JqRoot 'jq.exe'
    $InstalledJqVersion = if (Test-Path $JqCommand) {
        ((@(& $JqCommand --version | Select-Object -First 1) -join '') -replace '^jq-', '').Trim()
    }
    else {
        $null
    }
    if ($InstalledJqVersion -ne $Artifacts.Jq.Version) {
        New-Item -ItemType Directory -Path $JqRoot -Force | Out-Null
        Invoke-VerifiedDownload -Uri $Artifacts.Jq.Uri -Destination $JqCommand `
            -Algorithm SHA256 -ExpectedHash $Artifacts.Jq.Hash
    }
    Add-MachinePath -Path $JqRoot
    if (((@(& $JqCommand --version | Select-Object -First 1) -join '') -replace '^jq-', '').Trim() -ne $Artifacts.Jq.Version) {
        throw 'jq version verification failed.'
    }

    $UvPythonRoot = 'C:\ProgramData\uv\python'
    [Environment]::SetEnvironmentVariable('UV_PYTHON_INSTALL_DIR', $UvPythonRoot, 'Machine')
    $env:UV_PYTHON_INSTALL_DIR = $UvPythonRoot
    & $UvCommand python install 3.12.10
    if ($LASTEXITCODE -ne 0) {
        throw 'uv failed to install the pinned Python 3.12.10 runtime.'
    }
    $PythonPath = (@(& $UvCommand python find 3.12.10 | Select-Object -First 1) -join '').Trim()
    if (-not (Test-Path $PythonPath)) {
        throw 'uv did not resolve the pinned Python 3.12.10 runtime.'
    }

    $Extensions = @{
        'github.copilot'                   = '1.388.0'
        'github.copilot-chat'              = '0.48.1'
        'vscjava.migrate-java-to-azure'    = '1.23.26081703'
    }
    if ($Stack -eq 'dotnet') {
        $Extensions['ms-dotnettools.vscode-dotnet-modernize'] = '1.0.1161'
        $Extensions['ms-dotnettools.upgrade-agent'] = '1.1.290'
    }
    else {
        $Extensions['vscjava.vscode-java-upgrade'] = '2.1.2'
    }

    $ExtensionRoot = 'C:\ProgramData\MicroHack\vscode-extensions'
    New-Item -ItemType Directory -Path $ExtensionRoot -Force | Out-Null
    [Environment]::SetEnvironmentVariable('VSCODE_EXTENSIONS', $ExtensionRoot, 'Machine')
    # Visual Studio Code 1.133.0 ships GitHub Copilot and Copilot Chat as built-in extensions
    # at versions newer than the pins below and refuses to downgrade a built-in. A newer
    # built-in still satisfies the workshop, so that specific refusal is accepted and the
    # extension is dropped from the exact-version verification that follows.
    $BuiltInExtensions = @()
    foreach ($Extension in $Extensions.GetEnumerator()) {
        # The refusal message is joined onto one line because VS Code wraps it, and a wrapped
        # message would not match the check below.
        $Output = (Get-NativeCommandOutput -Path $CodeCommand -Arguments @(
                '--install-extension', "$($Extension.Key)@$($Extension.Value)",
                '--force', '--extensions-dir', $ExtensionRoot
            )) -join ' '
        if ($LASTEXITCODE -ne 0) {
            if ($Output -match 'is a built-in extension') {
                Write-ProvisionLog -Message (
                    "$($Extension.Key) is built into Visual Studio Code at a newer version " +
                    "than the pinned $($Extension.Value); keeping the built-in."
                )
                $BuiltInExtensions += $Extension.Key
                continue
            }
            throw "Visual Studio Code failed to install $($Extension.Key)@$($Extension.Value)."
        }
    }
    $InstalledExtensions = @(
        & $CodeCommand --list-extensions --show-versions --extensions-dir $ExtensionRoot
    )
    foreach ($Extension in $Extensions.GetEnumerator()) {
        if ($BuiltInExtensions -contains $Extension.Key) {
            continue
        }
        if ($InstalledExtensions -notcontains "$($Extension.Key)@$($Extension.Value)") {
            throw "Visual Studio Code extension verification failed for $($Extension.Key)."
        }
    }
}

function Install-DotNetDatabase {
    $DotNet = @{
        Uri       = 'https://download.microsoft.com/download/6141e558-e0ef-473c-8dc2-122d381f9bc8/988b5e46-33a0-4cfe-8fb1-d8b90ec1d280/dotnet-sdk-8.0.424-win-x64.exe'
        Hash      = 'e79e34bdd8cce378786aaf8846412ff5f9ba4b035ce1869e9cbff751de6da6cd'
        Publisher = 'Microsoft Corporation'
    }
    $SqlServer = @{
        Uri       = 'https://download.microsoft.com/download/3/8/d/38de7036-2433-4207-8eae-06e247e17b25/SQLEXPR_x64_ENU.exe'
        Hash      = '2e61c8bbde6021f9026c54ad9db4bbb1227e68761d4c00a6a50a2c70fe7afe05'
        Publisher = 'Microsoft Corporation'
    }
    $SqlCmd = @{
        Uri       = 'https://github.com/microsoft/go-sqlcmd/releases/download/v1.7.0/sqlcmd-amd64.msi'
        Hash      = 'c8fc4ba484d25aa5f7687c4538f8a09052d4a6f35ccf17ff38e76c44922c627d'
        Publisher = 'Microsoft Corporation'
    }
    $SqlPackage = @{
        Uri       = 'https://download.microsoft.com/download/46a13f8c-5548-42fb-b547-7e69ebc3fcca/sqlpackage-win-x64-en-170.4.83.3.zip'
        Hash      = 'f1c80c38a6c4e55fe2b8787de9119ee52313b900a05873be9d0084102344666a'
        Publisher = 'Microsoft Corporation'
    }

    $DotNetRoot = 'C:\Program Files\dotnet'
    $DotNetCommand = Join-Path $DotNetRoot 'dotnet.exe'
    $InstalledSdks = if (Test-Path $DotNetCommand) { @(& $DotNetCommand --list-sdks) } else { @() }
    if (-not ($InstalledSdks | Where-Object { $_ -match '^8\.0\.424\s' })) {
        $Installer = Join-Path $DownloadRoot 'dotnet-sdk-8.0.424-win-x64.exe'
        Invoke-VerifiedDownload -Uri $DotNet.Uri -Destination $Installer `
            -Algorithm SHA256 -ExpectedHash $DotNet.Hash
        Assert-AuthenticodePublisher -Path $Installer -Publisher $DotNet.Publisher
        Invoke-LockedInstaller -Path $Installer -Arguments @('/install', '/quiet', '/norestart')
    }
    [Environment]::SetEnvironmentVariable('DOTNET_ROOT', $DotNetRoot, 'Machine')
    Add-MachinePath -Path $DotNetRoot
    if (-not (@(& $DotNetCommand --list-sdks) | Where-Object { $_ -match '^8\.0\.424\s' })) {
        throw '.NET SDK 8.0.424 version verification failed.'
    }

    $SqlServiceName = 'MSSQL$SQLEXPRESS'
    if ($null -eq (Get-Service -Name $SqlServiceName -ErrorAction SilentlyContinue)) {
        $Installer = Join-Path $DownloadRoot 'SQLEXPR_x64_ENU-2022.2025.01.29.exe'
        Invoke-VerifiedDownload -Uri $SqlServer.Uri -Destination $Installer `
            -Algorithm SHA256 -ExpectedHash $SqlServer.Hash
        Assert-AuthenticodePublisher -Path $Installer -Publisher $SqlServer.Publisher
        $SetupConfiguration = Join-Path $SecretRoot 'sqlserver-setup.ini'
        try {
            Save-ProtectedText -Path $SetupConfiguration -Value @"
[OPTIONS]
ACTION="Install"
FEATURES=SQLENGINE
QUIET="True"
SUPPRESSPRIVACYSTATEMENTNOTICE="True"
INSTANCENAME="SQLEXPRESS"
SECURITYMODE="SQL"
SAPWD="$DatabasePassword"
SQLSVCACCOUNT="NT AUTHORITY\NETWORK SERVICE"
TCPENABLED="1"
NPENABLED="0"
BROWSERSVCSTARTUPTYPE="Automatic"
IACCEPTSQLSERVERLICENSETERMS="True"
"@
            # SQLEXPR_x64_ENU.exe is a self-extracting bootstrapper, not setup itself. It does
            # not understand /ConfigurationFile and, given only that, it raises its extraction
            # dialog and waits for a click that never arrives on a headless VM. Extracting
            # quietly first and then running the real setup.exe is the only unattended path.
            $ExtractRoot = Join-Path $DownloadRoot 'sqlexpress-setup'
            if (Test-Path $ExtractRoot) {
                Remove-Item -Path $ExtractRoot -Recurse -Force
            }
            Invoke-LockedInstaller -Path $Installer -Arguments @(
                '/Q', "/X:`"$ExtractRoot`""
            )
            $SetupExecutable = Join-Path $ExtractRoot 'setup.exe'
            if (-not (Test-Path $SetupExecutable)) {
                throw 'The SQL Server Express package did not extract a setup.exe.'
            }
            Invoke-LockedInstaller -Path $SetupExecutable -Arguments @(
                "/ConfigurationFile=`"$SetupConfiguration`""
            )
        }
        finally {
            Remove-ProtectedFile -Path $SetupConfiguration
        }
    }
    Set-Service -Name $SqlServiceName -StartupType Automatic
    Start-Service -Name $SqlServiceName

    $InstanceRegistry = Get-ItemProperty `
        'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'
    $InstanceId = $InstanceRegistry.SQLEXPRESS
    if ([string]::IsNullOrWhiteSpace($InstanceId)) {
        throw 'SQL Server Express instance registration is missing.'
    }
    $IpAllPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceId\MSSQLServer\SuperSocketNetLib\Tcp\IPAll"
    $TcpProperties = Get-ItemProperty -Path $IpAllPath
    $RestartSql = $false
    if (-not [string]::IsNullOrEmpty($TcpProperties.TcpDynamicPorts)) {
        Set-ItemProperty -Path $IpAllPath -Name TcpDynamicPorts -Value ''
        $RestartSql = $true
    }
    if ($TcpProperties.TcpPort -ne '1433') {
        Set-ItemProperty -Path $IpAllPath -Name TcpPort -Value '1433'
        $RestartSql = $true
    }
    if ($RestartSql) {
        Restart-Service -Name $SqlServiceName -Force
    }
    Invoke-WithRetry -Description 'SQL Server Express readiness' -Action {
        if ((Get-Service -Name $SqlServiceName).Status -ne 'Running') {
            throw 'SQL Server Express is not running.'
        }
        $Client = New-Object Net.Sockets.TcpClient
        try {
            $Client.Connect('localhost', 1433)
        }
        finally {
            $Client.Dispose()
        }
    }

    $SqlCmdCommand = 'C:\Program Files\sqlcmd\sqlcmd.exe'
    if (-not (Test-Path $SqlCmdCommand)) {
        $Installer = Join-Path $DownloadRoot 'sqlcmd-1.7.0-amd64.msi'
        Invoke-VerifiedDownload -Uri $SqlCmd.Uri -Destination $Installer `
            -Algorithm SHA256 -ExpectedHash $SqlCmd.Hash
        Assert-AuthenticodePublisher -Path $Installer -Publisher $SqlCmd.Publisher
        Invoke-LockedInstaller -Path 'msiexec.exe' -Arguments @(
            '/i',
            "`"$Installer`"",
            '/qn',
            '/norestart'
        )
    }
    if (-not (Test-Path $SqlCmdCommand)) {
        $SqlCmdCommand = (
            Get-ChildItem -Path 'C:\Program Files' -Filter sqlcmd.exe -Recurse |
                Select-Object -First 1
        ).FullName
    }
    if ([string]::IsNullOrWhiteSpace($SqlCmdCommand) -or -not (Test-Path $SqlCmdCommand)) {
        throw 'The pinned go-sqlcmd client was not found after installation.'
    }
    # -notmatch against an array filters it rather than returning a boolean, and sqlcmd
    # prints its version inside a multi-line banner, so the lines are joined before matching.
    if (((Get-NativeCommandOutput -Path $SqlCmdCommand -Arguments '--version') -join ' ') `
            -notmatch '1\.7\.0') {
        throw 'go-sqlcmd version verification failed.'
    }

    $SqlPackageRoot = 'C:\Program Files\SqlPackage'
    $SqlPackageCommand = Join-Path $SqlPackageRoot 'SqlPackage.exe'
    # Without the else branch this assignment yields an empty collection rather than $null,
    # and an empty collection -notmatch anything is an empty array, which is false. That
    # silently skipped the install below and left SqlPackage.exe missing.
    $SqlPackageVersion = if (Test-Path $SqlPackageCommand) {
        (Get-NativeCommandOutput -Path $SqlPackageCommand -Arguments '/Version' |
            Select-Object -First 1)
    }
    else {
        ''
    }
    if ($SqlPackageVersion -notmatch '^170\.4\.83\.3$') {
        $Archive = Join-Path $DownloadRoot 'sqlpackage-win-x64-en-170.4.83.3.zip'
        Invoke-VerifiedDownload -Uri $SqlPackage.Uri -Destination $Archive `
            -Algorithm SHA256 -ExpectedHash $SqlPackage.Hash
        $SqlPackageStaging = "$SqlPackageRoot.staging"
        Remove-Item -LiteralPath $SqlPackageStaging -Recurse -Force `
            -ErrorAction SilentlyContinue
        Expand-Archive -LiteralPath $Archive -DestinationPath $SqlPackageStaging -Force
        $StagedSqlPackage = Join-Path $SqlPackageStaging 'SqlPackage.exe'
        if (-not (Test-Path -LiteralPath $StagedSqlPackage -PathType Leaf)) {
            throw 'The pinned SqlPackage archive did not contain SqlPackage.exe.'
        }
        Assert-AuthenticodePublisher -Path $StagedSqlPackage `
            -Publisher $SqlPackage.Publisher
        if ((Get-NativeCommandOutput -Path $StagedSqlPackage -Arguments '/Version' |
                Select-Object -First 1) -notmatch '^170\.4\.83\.3$') {
            throw 'SqlPackage staged version verification failed.'
        }
        Install-StagedDirectory -StagingPath $SqlPackageStaging `
            -DestinationPath $SqlPackageRoot
    }
    Add-MachinePath -Path $SqlPackageRoot
    if ((Get-NativeCommandOutput -Path $SqlPackageCommand -Arguments '/Version' |
            Select-Object -First 1) -notmatch '^170\.4\.83\.3$') {
        throw 'SqlPackage version verification failed.'
    }

    $env:SQLCMDPASSWORD = $DatabasePassword
    # SERVERPROPERTY returns sql_variant, which CONCAT refuses to convert implicitly, and
    # sqlcmd reports that as a Msg 257 on stdout while still exiting 0 -- so the cast is what
    # keeps this check from silently matching nothing. -b makes a future failure loud.
    $SqlIdentityQuery = @(
        'SET NOCOUNT ON;'
        "SELECT CAST(SERVERPROPERTY('ProductMajorVersion') AS nvarchar(128))"
        "+ '|' + CAST(SERVERPROPERTY('Edition') AS nvarchar(128));"
    ) -join ' '
    $SqlIdentityOutput = Get-NativeCommandOutput -Path $SqlCmdCommand -Arguments @(
        '-S', 'localhost,1433', '-U', 'sa', '-b', '-h', '-1', '-W', '-Q', $SqlIdentityQuery
    )
    $SqlIdentity = (
        $SqlIdentityOutput |
            Where-Object { $_ -match '^\s*16\|.*Express' } |
            Select-Object -First 1
    )
    if ([string]::IsNullOrWhiteSpace($SqlIdentity)) {
        throw (
            'The local database is not SQL Server 2022 Express. sqlcmd returned: ' +
            ((@($SqlIdentityOutput) -join ' ') -replace '\s+', ' ')
        )
    }

    $EscapedPassword = $DatabasePassword.Replace("'", "''")
    $SqlInput = Join-Path $SecretRoot 'sqlserver-login.sql'
    try {
        Save-ProtectedText -Path $SqlInput -Value @"
IF DB_ID(N'LegoCatalog') IS NULL CREATE DATABASE [LegoCatalog];
GO
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'catalog')
    CREATE LOGIN [catalog] WITH PASSWORD = N'$EscapedPassword', CHECK_POLICY = ON;
ELSE
    ALTER LOGIN [catalog] WITH PASSWORD = N'$EscapedPassword';
GO
USE [LegoCatalog];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'catalog')
BEGIN
    CREATE USER [catalog] FOR LOGIN [catalog];
    ALTER ROLE [db_owner] ADD MEMBER [catalog];
END;
GO
"@
        $SqlLoginOutput = Get-NativeCommandOutput -Path $SqlCmdCommand -Arguments @(
            '-S', 'localhost,1433', '-U', 'sa', '-b', '-i', $SqlInput
        )
        if ($LASTEXITCODE -ne 0) {
            throw (
                'SQL Server database and login provisioning failed: ' +
                (($SqlLoginOutput -join ' ') -replace '\s+', ' ')
            )
        }
    }
    finally {
        Remove-ProtectedFile -Path $SqlInput
    }

    return @{
        DotNetCommand = $DotNetCommand
        SqlCmdCommand = $SqlCmdCommand
    }
}

function Install-JavaDatabase {
    $Java = @{
        Uri       = 'https://aka.ms/download-jdk/microsoft-jdk-17.0.20-windows-x64.msi#winget'
        Hash      = '96115e7ba251f476544e38f4b214562b57b609618d64533dff1104bb74d328fc'
        Publisher = 'Microsoft Corporation'
    }
    $PostgreSql = @{
        Uri       = 'https://get.enterprisedb.com/postgresql/postgresql-18.6-1-windows-x64.exe'
        Hash      = 'cae561e98d09f3f4a1a95759249240f86f66d71dcf33d14b6f7be894078401d1'
        Publisher = 'EnterpriseDB Corporation'
    }
    $Maven = @{
        Uri  = 'https://archive.apache.org/dist/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.zip'
        Hash = 'ed41650d42485cfc243fad22158caf9cbb5dc408ce7a09ddb94dd42a019de929ca43065bfa450612cf12bf78b5cafa3884b96c090de326ff590448c933454af3'
    }

    $JavaRoot = 'C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot'
    $JavaCommand = Join-Path $JavaRoot 'bin\java.exe'
    $InstalledJava = if (Test-Path $JavaCommand) {
        (Get-NativeCommandOutput -Path $JavaCommand -Arguments '-version') -join "`n"
    }
    else { '' }
    if ($InstalledJava -notmatch 'build 17\.0\.20\+8') {
        $Installer = Join-Path $DownloadRoot 'microsoft-jdk-17.0.20-windows-x64.msi'
        Invoke-VerifiedDownload -Uri $Java.Uri -Destination $Installer `
            -Algorithm SHA256 -ExpectedHash $Java.Hash
        Assert-AuthenticodePublisher -Path $Installer -Publisher $Java.Publisher
        Invoke-LockedInstaller -Path 'msiexec.exe' -Arguments @(
            '/i',
            "`"$Installer`"",
            '/qn',
            '/norestart',
            'ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome'
        )
        $JavaCommand = (
            Get-ChildItem -Path 'C:\Program Files\Microsoft' -Filter java.exe -Recurse |
                Where-Object { $_.FullName -match 'jdk-17\.0\.20' } |
                Select-Object -First 1
        ).FullName
        $JavaRoot = Split-Path (Split-Path $JavaCommand -Parent) -Parent
    }
    if ([string]::IsNullOrWhiteSpace($JavaCommand) -or -not (Test-Path $JavaCommand)) {
        throw 'Microsoft OpenJDK 17.0.20+8 was not found after installation.'
    }
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $JavaRoot, 'Machine')
    $env:JAVA_HOME = $JavaRoot
    Add-MachinePath -Path (Join-Path $JavaRoot 'bin')
    if (((Get-NativeCommandOutput -Path $JavaCommand -Arguments '-version') -join "`n") -notmatch 'build 17\.0\.20\+8') {
        throw 'Microsoft OpenJDK version verification failed.'
    }

    $PostgreSqlRoot = 'C:\Program Files\PostgreSQL\18'
    $PsqlCommand = Join-Path $PostgreSqlRoot 'bin\psql.exe'
    $PostgreSqlService = 'postgresql-x64-18'
    if ($null -eq (Get-Service -Name $PostgreSqlService -ErrorAction SilentlyContinue)) {
        $Installer = Join-Path $DownloadRoot 'postgresql-18.6-1-windows-x64.exe'
        Invoke-VerifiedDownload -Uri $PostgreSql.Uri -Destination $Installer `
            -Algorithm SHA256 -ExpectedHash $PostgreSql.Hash
        Assert-AuthenticodePublisher -Path $Installer -Publisher $PostgreSql.Publisher
        $SetupOptions = Join-Path $SecretRoot 'postgresql-setup.conf'
        try {
            Save-ProtectedText -Path $SetupOptions -Value @"
mode=unattended
unattendedmodeui=none
prefix=$PostgreSqlRoot
datadir=$PostgreSqlRoot\data
serverport=5432
servicename=$PostgreSqlService
superaccount=postgres
superpassword=$DatabasePassword
"@
            Invoke-LockedInstaller -Path $Installer -Arguments @(
                '--optionfile',
                "`"$SetupOptions`""
            )
        }
        finally {
            Remove-ProtectedFile -Path $SetupOptions
        }
    }
    Set-Service -Name $PostgreSqlService -StartupType Automatic
    Start-Service -Name $PostgreSqlService
    if (-not (Test-Path $PsqlCommand)) {
        throw 'The PostgreSQL 18.6 psql client was not found after installation.'
    }
    if ((& $PsqlCommand --version) -notmatch '18\.6') {
        throw 'PostgreSQL client version verification failed.'
    }

    $env:PGPASSWORD = $DatabasePassword
    Invoke-WithRetry -Description 'PostgreSQL readiness' -Action {
        & $PsqlCommand -h localhost -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 `
            -tAc 'SELECT 1' | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'PostgreSQL is not accepting local connections.'
        }
        $PostgreSqlVersion = (@(
                & $PsqlCommand -h localhost -p 5432 -U postgres -d postgres -tAc `
                    'SHOW server_version'
            ) -join '').Trim()
        if ($PostgreSqlVersion -notmatch '^18\.6(?:\s|$)') {
            throw "The local PostgreSQL server version is $PostgreSqlVersion instead of 18.6."
        }
    }
    $EscapedPassword = $DatabasePassword.Replace("'", "''")
    # psql -tAc emits nothing when the query matches no rows. An empty pipeline is not $null
    # but AutomationNull, which a [string] cast leaves null instead of turning into '', so the
    # result is collected into an array and joined to get a string that can be trimmed.
    $RoleExists = (@(& $PsqlCommand -h localhost -p 5432 -U postgres -d postgres -tAc `
                "SELECT 1 FROM pg_roles WHERE rolname = 'catalog'") -join '').Trim()
    $RoleInput = Join-Path $SecretRoot 'postgresql-role.sql'
    try {
        $RoleSql = if ($RoleExists -ne '1') {
            "CREATE ROLE catalog LOGIN PASSWORD '$EscapedPassword';"
        }
        else {
            "ALTER ROLE catalog PASSWORD '$EscapedPassword';"
        }
        Save-ProtectedText -Path $RoleInput -Value $RoleSql
        & $PsqlCommand -h localhost -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 `
            -f $RoleInput | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'PostgreSQL application role provisioning failed.'
        }
    }
    finally {
        Remove-ProtectedFile -Path $RoleInput
        $RoleSql = $null
    }
    $DatabaseExists = (@(& $PsqlCommand -h localhost -p 5432 -U postgres -d postgres -tAc `
                "SELECT 1 FROM pg_database WHERE datname = 'catalog'") -join '').Trim()
    if ($DatabaseExists -ne '1') {
        & $PsqlCommand -h localhost -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 `
            -c 'CREATE DATABASE catalog OWNER catalog' | Out-Null
    }
    else {
        & $PsqlCommand -h localhost -p 5432 -U postgres -d postgres -v ON_ERROR_STOP=1 `
            -c 'ALTER DATABASE catalog OWNER TO catalog' | Out-Null
    }
    if ($LASTEXITCODE -ne 0) {
        throw 'PostgreSQL application database provisioning failed.'
    }

    $MavenArchive = Join-Path $DownloadRoot 'apache-maven-3.9.16-bin.zip'
    $MavenRoot = 'C:\Program Files\Apache\maven-3.9.16'
    Invoke-VerifiedDownload -Uri $Maven.Uri -Destination $MavenArchive `
        -Algorithm SHA512 -ExpectedHash $Maven.Hash
    if (-not (Test-Path (Join-Path $MavenRoot 'bin\mvn.cmd'))) {
        $MavenExtract = Join-Path $DownloadRoot 'maven-3.9.16'
        Remove-Item -Path $MavenExtract -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $MavenArchive -DestinationPath $MavenExtract -Force
        $ExtractedMaven = Get-ChildItem -Path $MavenExtract -Directory |
            Where-Object { Test-Path (Join-Path $_.FullName 'bin\mvn.cmd') } |
            Select-Object -First 1
        if ($null -eq $ExtractedMaven) {
            throw 'The verified Maven archive did not contain mvn.cmd.'
        }
        New-Item -ItemType Directory -Path (Split-Path $MavenRoot -Parent) -Force | Out-Null
        Remove-Item -Path $MavenRoot -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item -Path $ExtractedMaven.FullName -Destination $MavenRoot
    }
    [Environment]::SetEnvironmentVariable('MAVEN_HOME', $MavenRoot, 'Machine')
    Add-MachinePath -Path (Join-Path $MavenRoot 'bin')
    if ((& (Join-Path $MavenRoot 'bin\mvn.cmd') --version | Select-Object -First 1) -notmatch '3\.9\.16') {
        throw 'Apache Maven version verification failed.'
    }

    return @{
        JavaCommand = $JavaCommand
        PsqlCommand = $PsqlCommand
        MavenRoot   = $MavenRoot
    }
}

function Test-SourceArchiveChallenge {
    <#
    .SYNOPSIS
    Recognizes the flat ch01 guide or the legacy challenge directory in an extracted archive.
    #>
    param([Parameter(Mandatory)][string]$ArchiveRoot)

    $ChallengeRoot = Join-Path $ArchiveRoot 'challenges'
    return ((Test-Path (Join-Path $ChallengeRoot 'ch01.md')) -or
        (Test-Path (Join-Path $ChallengeRoot 'ch01')))
}

function Install-SourceArchive {
    # Re-provisioning is the facilitator's first response to a broken stack, and by that
    # point the participant's Challenge 1 commits live only in $SourceRoot\.git. Replacing
    # the directory would destroy the very commit their work lives on, so
    # an already-correct tree is left exactly as it is.
    $ExistingMarker = Join-Path $SourceRoot '.source-commit'
    if ((Test-Path (Join-Path $SourceRoot '.git')) -and (Test-Path $ExistingMarker) -and
        ((Get-Content -Path $ExistingMarker -Raw).Trim() -eq $SourceCommit)) {
        Write-ProvisionLog ("Source tree already at {0} and carries Git history; leaving participant work untouched." -f $SourceCommit)
        return
    }

    $Archive = Join-Path $DownloadRoot "source-$SourceCommit.zip"
    Invoke-VerifiedDownload -Uri $SourceArchiveUrl -Destination $Archive `
        -Algorithm SHA256 -ExpectedHash $SourceArchiveSha256

    $Staging = Join-Path $Root "source-$SourceCommit.staging"
    Remove-Item -Path $Staging -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $Staging -Force | Out-Null
    Expand-Archive -Path $Archive -DestinationPath $Staging -Force
    $ArchiveRoot = Get-ChildItem -Path $Staging -Directory | Select-Object -First 1
    # The pinned commit must carry the application sources and the canonical catalog the
    # guides drive.
    if ($null -eq $ArchiveRoot -or
        -not (Test-Path (Join-Path $ArchiveRoot.FullName 'data\manifest.json')) -or
        -not (Test-Path (Join-Path $ArchiveRoot.FullName 'dotnet')) -or
        -not (Test-Path (Join-Path $ArchiveRoot.FullName 'java')) -or
        -not (Test-SourceArchiveChallenge -ArchiveRoot $ArchiveRoot.FullName)) {
        throw ("The verified source archive does not carry the workshop content this " +
            "provisioner expects. Re-pin source_commit - see docs/Facilitator.md.")
    }

    $Previous = Join-Path $Root 'source.previous'
    Remove-Item -Path $Previous -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $SourceRoot) {
        Move-Item -Path $SourceRoot -Destination $Previous
    }
    try {
        Move-Item -Path $ArchiveRoot.FullName -Destination $SourceRoot
        $CommitMarker = Join-Path $SourceRoot '.source-commit'
        Set-Content -Path $CommitMarker -Value $SourceCommit -Encoding ASCII
        Initialize-SourceRepository -SourceCommit $SourceCommit
        # $Previous is deliberately kept. If this replaced a tree that held participant
        # work, it is the only copy left.
    }
    catch {
        Remove-Item -Path $SourceRoot -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $Previous) {
            Move-Item -Path $Previous -Destination $SourceRoot
        }
        throw
    }
    finally {
        Remove-Item -Path $Staging -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-SourceRepository {
    <#
        .SYNOPSIS
        Turn the extracted archive into a Git working tree holding one baseline commit.

        .DESCRIPTION
        The workshop source arrives as a signed zip archive rather than a clone, so it
        carries no history. Both GitHub Copilot Challenge 1 paths record their own work
        as a commit and read it back with `git rev-parse HEAD`, which requires a
        repository. This creates one whose single commit is the frozen baseline, so a
        participant's first commit is their own modernization and nothing else.

        The upstream provenance stays in `.source-commit`; this local commit is
        deliberately unrelated to the published commit SHA and must not be used as
        archive provenance.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SourceCommit
    )

    $GitCommand = 'C:\Program Files\Git\cmd\git.exe'
    if (-not (Test-Path $GitCommand)) {
        throw 'The pinned Git client is required to initialize the source repository.'
    }
    if (Test-Path (Join-Path $SourceRoot '.git')) {
        return
    }

    Push-Location $SourceRoot
    try {
        & $GitCommand init --initial-branch=workshop --quiet
        if ($LASTEXITCODE -ne 0) { throw 'git init failed for the source tree.' }
        & $GitCommand config user.name 'MicroHack Participant'
        & $GitCommand config user.email 'participant@microhack.invalid'
        & $GitCommand config core.autocrlf false
        & $GitCommand add --all
        if ($LASTEXITCODE -ne 0) { throw 'git add failed for the source tree.' }
        & $GitCommand commit --quiet --message "Workshop baseline $SourceCommit"
        if ($LASTEXITCODE -ne 0) { throw 'git commit failed for the source tree.' }
    }
    finally {
        Pop-Location
    }
}

function Sync-LegacyDataRoot {
    <#
    .SYNOPSIS
        Publishes the canonical dataset to $LegacyDataRoot, which the application reads.
    .DESCRIPTION
        Copied rather than referenced in place so that Challenge 1 cannot take the legacy
        application down: participants edit, delete from, and run `git clean` inside
        $SourceRoot, and the application must survive all of it to remain a usable "before".
        The copy is refreshed on every provisioning run, so re-provisioning repairs a
        participant who damaged it, and it is verified afterwards rather than trusted.
    #>

    $Staging = "$LegacyDataRoot.staging"
    $Previous = "$LegacyDataRoot.previous"
    foreach ($Path in @($Staging, $Previous)) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }

    New-Item -Path $Staging -ItemType Directory -Force | Out-Null
    Copy-Item -Path (Join-Path $SourceRoot 'data\images') -Destination $Staging -Recurse -Force
    foreach ($File in @('catalog.json', 'categories.json', 'manifest.json')) {
        Copy-Item -Path (Join-Path $SourceRoot "data\$File") -Destination $Staging -Force
    }

    $Images = @(Get-ChildItem -Path (Join-Path $Staging 'images') -File -Filter '*.png')
    if ($Images.Count -ne 198) {
        Remove-Item -Path $Staging -Recurse -Force -ErrorAction SilentlyContinue
        throw "Legacy data copy holds $($Images.Count) images instead of 198."
    }

    # Swap through a temporary name so a failed copy leaves the previous dataset in place
    # rather than an empty directory the application would start against and fail readiness.
    if (Test-Path $LegacyDataRoot) {
        Move-Item -LiteralPath $LegacyDataRoot -Destination $Previous
    }
    try {
        Move-Item -LiteralPath $Staging -Destination $LegacyDataRoot
        Remove-Item -Path $Previous -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Remove-Item -Path $LegacyDataRoot -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $Previous) {
            Move-Item -LiteralPath $Previous -Destination $LegacyDataRoot
        }
        throw
    }

    Write-ProvisionLog "Published the canonical dataset to $LegacyDataRoot."
}

function Assert-CanonicalData {
    $ManifestPath = Join-Path $SourceRoot 'data\manifest.json'
    $CatalogPath = Join-Path $SourceRoot 'data\catalog.json'
    $CategoriesPath = Join-Path $SourceRoot 'data\categories.json'
    $ImagesPath = Join-Path $SourceRoot 'data\images'
    $Manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
    # ConvertFrom-Json writes the decoded array to the pipeline as a single object without
    # enumerating it, so @(Get-Content ... | ConvertFrom-Json) counts 1 rather than 198.
    # Assigning first and wrapping the variable is what makes the count meaningful.
    $CatalogJson = Get-Content -Path $CatalogPath -Raw | ConvertFrom-Json
    $CategoriesJson = Get-Content -Path $CategoriesPath -Raw | ConvertFrom-Json
    $Catalog = @($CatalogJson)
    $Categories = @($CategoriesJson)
    $Images = @(Get-ChildItem -Path $ImagesPath -File -Filter '*.png')

    if ($Manifest.counts.figures -ne 198 -or
        $Manifest.counts.categories -ne 20 -or
        $Manifest.counts.images -ne 198 -or
        $Catalog.Count -ne 198 -or
        $Categories.Count -ne 20 -or
        $Images.Count -ne 198) {
        throw 'Canonical data does not contain 198 figures, 20 categories, and 198 images.'
    }
    if ((Get-FileHash -Path $CatalogPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne
        $Manifest.hashes.catalogSha256) {
        throw 'Canonical catalog digest does not match data/manifest.json.'
    }
    if ((Get-FileHash -Path $CategoriesPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne
        $Manifest.hashes.categoriesSha256) {
        throw 'Canonical category digest does not match data/manifest.json.'
    }
}

function ConvertFrom-WindowsCommandLine {
    param(
        [Parameter(Mandatory)]
        [string]$CommandLine
    )

    if ($null -eq ('MicroHack.NativeCommandLine' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace MicroHack
{
    public static class NativeCommandLine
    {
        [DllImport("shell32.dll", SetLastError = true)]
        private static extern IntPtr CommandLineToArgvW(
            [MarshalAs(UnmanagedType.LPWStr)] string commandLine,
            out int argumentCount
        );

        [DllImport("kernel32.dll")]
        private static extern IntPtr LocalFree(IntPtr memory);

        public static string[] Split(string commandLine)
        {
            int argumentCount;
            IntPtr argumentVector = CommandLineToArgvW(commandLine, out argumentCount);
            if (argumentVector == IntPtr.Zero)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }

            try
            {
                string[] arguments = new string[argumentCount];
                for (int index = 0; index < argumentCount; index++)
                {
                    IntPtr argument = Marshal.ReadIntPtr(
                        argumentVector,
                        index * IntPtr.Size
                    );
                    arguments[index] = Marshal.PtrToStringUni(argument);
                }
                return arguments;
            }
            finally
            {
                LocalFree(argumentVector);
            }
        }
    }
}
'@ | Out-Null
    }

    return [MicroHack.NativeCommandLine]::Split($CommandLine)
}

function Get-StackApplicationProcesses {
    $Executable = if ($Stack -eq 'dotnet') { 'dotnet.exe' } else { 'java.exe' }
    $ApplicationArgument = if ($Stack -eq 'dotnet') {
        'C:\MicroHack\app\dotnet\LegoCatalog.App.dll'
    }
    else {
        'C:\MicroHack\app\java\catalog-java.jar'
    }

    return @(
        Get-CimInstance -ClassName Win32_Process -Filter "Name = '$Executable'" |
            Where-Object {
                if ([string]::IsNullOrWhiteSpace($_.CommandLine)) {
                    $false
                }
                else {
                    $Arguments = @(ConvertFrom-WindowsCommandLine -CommandLine $_.CommandLine)
                    if ($Stack -eq 'dotnet') {
                        $Arguments.Count -ge 2 -and $Arguments[1].Equals(
                            $ApplicationArgument,
                            [StringComparison]::OrdinalIgnoreCase
                        )
                    }
                    else {
                        $Arguments.Count -ge 3 -and
                            $Arguments[1].Equals(
                                '-jar',
                                [StringComparison]::OrdinalIgnoreCase
                            ) -and
                            $Arguments[2].Equals(
                                $ApplicationArgument,
                                [StringComparison]::OrdinalIgnoreCase
                            )
                    }
                }
            }
    )
}

function Stop-ApplicationTask {
    $TaskName = "MicroHack-$Stack"
    $Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $Existing) {
        Write-ProvisionLog "Disabling $TaskName before replacing source or application output."
        Disable-ScheduledTask -TaskName $TaskName | Out-Null
        $Current = Get-ScheduledTask -TaskName $TaskName
        if ($Current.State -eq 'Running') {
            Stop-ScheduledTask -TaskName $TaskName
        }
    }

    for ($Attempt = 1; $Attempt -le 60; $Attempt++) {
        $Processes = @(Get-StackApplicationProcesses)
        if ($Processes.Count -eq 0) {
            return
        }
        foreach ($Process in $Processes) {
            Stop-Process -Id $Process.ProcessId -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 1
    }

    throw "$TaskName or its exact stack application process did not stop within 60 seconds."
}

function Install-StagedDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$StagingPath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    $PreviousPath = "$DestinationPath.previous"
    if (-not (Test-Path -LiteralPath $StagingPath -PathType Container)) {
        throw "Staged application directory is missing: $StagingPath"
    }
    if (-not (Test-Path -LiteralPath $DestinationPath) -and
        (Test-Path -LiteralPath $PreviousPath -PathType Container)) {
        Move-Item -LiteralPath $PreviousPath -Destination $DestinationPath
    }
    if ((Test-Path -LiteralPath $DestinationPath) -and
        -not (Test-Path -LiteralPath $DestinationPath -PathType Container)) {
        throw "Current application path is not a directory: $DestinationPath"
    }

    if (Test-Path -LiteralPath $DestinationPath -PathType Container) {
        Remove-Item -Path $PreviousPath -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item -LiteralPath $DestinationPath -Destination $PreviousPath
    }
    try {
        Move-Item -LiteralPath $StagingPath -Destination $DestinationPath
        Remove-Item -Path $PreviousPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Remove-Item -Path $DestinationPath -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $PreviousPath) {
            Move-Item -LiteralPath $PreviousPath -Destination $DestinationPath
        }
        throw
    }
}

function Register-ApplicationTask {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    $TaskName = "MicroHack-$Stack"
    $Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $Existing -and $Existing.State -eq 'Running') {
        throw "$TaskName must be stopped before task registration."
    }
    $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
        "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`""
    )
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount `
        -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 5 `
        -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
        -Principal $Principal -Settings $Settings -Force | Out-Null
    Enable-ScheduledTask -TaskName $TaskName | Out-Null
    Start-ScheduledTask -TaskName $TaskName
}

function Set-CatalogEnvironmentForParticipants {
    <#
    .SYNOPSIS
        Persists the non-secret catalog settings at Machine scope.
    .DESCRIPTION
        The application receives these through the scheduled-task start script, whose
        variables live only in that task's process. Participants read the same names in
        their own shells, because the acceptance runbooks reference $env:CATALOG_*
        directly. Without Machine-scope persistence those reads expand to empty.

        CATALOG_DATABASE_PASSWORD is deliberately excluded: it stays in
        C:\MicroHack\secrets and is passed explicitly where it is needed.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )

    foreach ($Name in ($Settings.Keys | Sort-Object)) {
        [Environment]::SetEnvironmentVariable($Name, $Settings[$Name], 'Machine')
        Write-ProvisionLog -Message ('Persisted {0} for participant shells.' -f $Name)
    }
}

function Publish-DotNetApplication {
    param(
        [Parameter(Mandatory)]
        [string]$DotNetCommand,

        [Parameter(Mandatory)]
        [string]$SqlCmdCommand
    )

    $Project = Join-Path $SourceRoot 'dotnet\src\LegoCatalog.App\LegoCatalog.App.csproj'
    $DotNetSource = Join-Path $SourceRoot 'dotnet'
    @{
        sdk = @{
            version     = '8.0.424'
            rollForward = 'disable'
        }
    } | ConvertTo-Json -Depth 3 | Set-Content `
        -Path (Join-Path $DotNetSource 'global.json') -Encoding UTF8
    $PublishRoot = Join-Path $ApplicationRoot 'dotnet'
    $PublishStaging = "$PublishRoot.staging"
    Remove-Item -Path $PublishStaging -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $PublishStaging -Force | Out-Null
    Push-Location $DotNetSource
    try {
        & $DotNetCommand publish $Project --configuration Release --output $PublishStaging
        if ($LASTEXITCODE -ne 0) {
            throw '.NET application publish failed.'
        }
    }
    finally {
        Pop-Location
    }
    if (-not (Test-Path (Join-Path $PublishStaging 'LegoCatalog.App.dll'))) {
        throw '.NET staged publish is missing LegoCatalog.App.dll.'
    }
    Install-StagedDirectory -StagingPath $PublishStaging -DestinationPath $PublishRoot

    $ConfigurationPath = Join-Path $SecretRoot 'dotnet.json'
    Save-ProtectedConfiguration -Path $ConfigurationPath -Values @{
        DatabasePassword = $DatabasePassword
        PerformanceApiKey = $PerformanceApiKey
    }
    $StartScript = Join-Path $Root 'start-dotnet.ps1'
    @'
$ErrorActionPreference = 'Stop'

function Invoke-BoundedNativeProbe {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory)]
        [int]$TimeoutMilliseconds,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $Process = $null
    try {
        $Process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList `
            -WindowStyle Hidden -PassThru
        if (-not $Process.WaitForExit($TimeoutMilliseconds)) {
            $ProcessId = $Process.Id
            Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
            $Process.WaitForExit(5000) | Out-Null
            throw "$Description exceeded its process deadline."
        }
        if ($Process.ExitCode -ne 0) {
            throw "$Description exited with code $($Process.ExitCode)."
        }
    }
    finally {
        if ($null -ne $Process) {
            if (-not $Process.HasExited) {
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            }
            $Process.Dispose()
        }
    }
}

$Configuration = Get-Content 'C:\MicroHack\secrets\dotnet.json' -Raw | ConvertFrom-Json
$DatabaseReady = $false
$LastDatabaseError = 'SQL Server readiness was not attempted.'
$ReadinessDeadline = [DateTime]::UtcNow.AddMinutes(5)
while (-not $DatabaseReady -and [DateTime]::UtcNow -lt $ReadinessDeadline) {
    try {
        if ((Get-Service -Name 'MSSQL$SQLEXPRESS').Status -ne 'Running') {
            throw 'SQL Server Express service is not running.'
        }
        $RemainingMilliseconds = [int][Math]::Max(
            1,
            [Math]::Min(
                10000,
                ($ReadinessDeadline - [DateTime]::UtcNow).TotalMilliseconds
            )
        )
        $env:SQLCMDPASSWORD = $Configuration.DatabasePassword
        Invoke-BoundedNativeProbe -FilePath '__SQLCMD_COMMAND__' -ArgumentList @(
            '-S',
            'localhost,1433',
            '-U',
            'catalog',
            '-d',
            'LegoCatalog',
            '-b',
            '-l',
            '5',
            '-t',
            '5',
            '-Q',
            '"SET NOCOUNT ON; SELECT 1;"'
        ) -TimeoutMilliseconds $RemainingMilliseconds -Description 'sqlcmd readiness probe'
        $DatabaseReady = $true
    }
    catch {
        $LastDatabaseError = $_.Exception.Message -replace '[\r\n]+', ' '
    }
    finally {
        $env:SQLCMDPASSWORD = $null
    }
    if (-not $DatabaseReady) {
        $SleepMilliseconds = [int][Math]::Max(
            0,
            [Math]::Min(
                5000,
                ($ReadinessDeadline - [DateTime]::UtcNow).TotalMilliseconds
            )
        )
        if ($SleepMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $SleepMilliseconds
        }
    }
}
if (-not $DatabaseReady) {
    $Failure = '{0} [dotnet] SQL Server readiness failed after five minutes: {1}' -f `
        [DateTime]::UtcNow.ToString('o'), $LastDatabaseError
    Add-Content -LiteralPath 'C:\MicroHack\logs\dotnet-app.log' -Value $Failure -Encoding UTF8
    throw $Failure
}
$env:CATALOG_DATABASE_HOST = 'localhost'
$env:CATALOG_DATABASE_PORT = '1433'
$env:CATALOG_DATABASE_NAME = 'LegoCatalog'
$env:CATALOG_DATABASE_USERNAME = 'catalog'
$env:CATALOG_DATABASE_PASSWORD = $Configuration.DatabasePassword
$env:CATALOG_IMAGES_PATH = 'C:\MicroHack\legacy-data\images'
$env:CATALOG_SEED_PATH = 'C:\MicroHack\legacy-data\catalog.json'
$env:CATALOG_STARTUP_IMPORT_ENABLED = 'true'
$env:PERFTEST_API_KEY = $Configuration.PerformanceApiKey
$env:PERFTEST_WORK_FACTOR = '10'
$env:OTEL_SERVICE_VERSION = '__SOURCE_COMMIT__'
$env:DEPLOYMENT_ENVIRONMENT = 'lab'
$env:CONTAINER_APP_REVISION = 'facilitator-vm'
$env:ASPNETCORE_URLS = 'http://0.0.0.0:5000'
& 'C:\Program Files\dotnet\dotnet.exe' 'C:\MicroHack\app\dotnet\LegoCatalog.App.dll' `
    *>> 'C:\MicroHack\logs\dotnet-app.log'
exit $LASTEXITCODE
'@.Replace('__SOURCE_COMMIT__', $SourceCommit).Replace('__SQLCMD_COMMAND__', $SqlCmdCommand) |
        Set-Content -Path $StartScript -Encoding UTF8
    Set-CatalogEnvironmentForParticipants -Settings @{
        CATALOG_DATABASE_HOST     = 'localhost'
        CATALOG_DATABASE_PORT     = '1433'
        CATALOG_DATABASE_NAME     = 'LegoCatalog'
        CATALOG_DATABASE_USERNAME = 'catalog'
        CATALOG_IMAGES_PATH       = 'C:\MicroHack\legacy-data\images'
        CATALOG_SEED_PATH         = 'C:\MicroHack\legacy-data\catalog.json'
        CATALOG_BASE_URL          = 'http://localhost:5000'
    }
    Register-ApplicationTask -ScriptPath $StartScript
}

function Publish-JavaApplication {
    param(
        [Parameter(Mandatory)]
        [hashtable]$JavaTools
    )

    $JavaSource = Join-Path $SourceRoot 'java'
    $MavenProperties = Get-Content `
        (Join-Path $JavaSource '.mvn\wrapper\maven-wrapper.properties') -Raw |
        ConvertFrom-StringData
    if ($MavenProperties.distributionUrl -notmatch '/apache-maven/3\.9\.16/' -or
        $MavenProperties.distributionSha256Sum -ne
        '5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce') {
        throw 'The frozen Maven Wrapper distribution contract is not present.'
    }

    $MavenUserHome = 'C:\ProgramData\MicroHack\m2'
    $DistributionName = 'apache-maven-3.9.16'
    $UrlBytes = [byte[]][char[]]$MavenProperties.distributionUrl
    $UrlHash = (
        [Security.Cryptography.SHA256]::Create().ComputeHash($UrlBytes) |
            ForEach-Object { $_.ToString('x2') }
    ) -join ''
    $WrapperHome = Join-Path $MavenUserHome "wrapper\dists\$DistributionName\$UrlHash"
    if (-not (Test-Path (Join-Path $WrapperHome 'bin\mvn.cmd'))) {
        New-Item -ItemType Directory -Path $WrapperHome -Force | Out-Null
        Copy-Item -Path (Join-Path $JavaTools.MavenRoot '*') -Destination $WrapperHome `
            -Recurse -Force
    }

    $env:JAVA_HOME = Split-Path (Split-Path $JavaTools.JavaCommand -Parent) -Parent
    $env:MAVEN_USER_HOME = $MavenUserHome
    Push-Location $JavaSource
    try {
        & '.\mvnw.cmd' -DskipTests package
        if ($LASTEXITCODE -ne 0) {
            throw 'Java application Maven Wrapper package failed.'
        }
    }
    finally {
        Pop-Location
    }

    $Jar = Get-ChildItem -Path (Join-Path $JavaSource 'target') `
        -Filter 'catalog-java-*.jar' -File |
        Where-Object { $_.Name -notmatch '\.original$' } |
        Select-Object -First 1
    if ($null -eq $Jar) {
        throw 'The Java package did not produce the expected application JAR.'
    }
    $PublishRoot = Join-Path $ApplicationRoot 'java'
    $PublishStaging = "$PublishRoot.staging"
    Remove-Item -Path $PublishStaging -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $PublishStaging -Force | Out-Null
    Copy-Item -Path $Jar.FullName `
        -Destination (Join-Path $PublishStaging 'catalog-java.jar') -Force
    if (-not (Test-Path (Join-Path $PublishStaging 'catalog-java.jar'))) {
        throw 'Java staged publish is missing catalog-java.jar.'
    }
    Install-StagedDirectory -StagingPath $PublishStaging -DestinationPath $PublishRoot

    $ConfigurationPath = Join-Path $SecretRoot 'java.json'
    Save-ProtectedConfiguration -Path $ConfigurationPath -Values @{
        DatabasePassword = $DatabasePassword
        PerformanceApiKey = $PerformanceApiKey
    }
    $StartScript = Join-Path $Root 'start-java.ps1'
    @'
$ErrorActionPreference = 'Stop'

function Invoke-BoundedNativeProbe {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory)]
        [int]$TimeoutMilliseconds,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $Process = $null
    try {
        $Process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList `
            -WindowStyle Hidden -PassThru
        if (-not $Process.WaitForExit($TimeoutMilliseconds)) {
            $ProcessId = $Process.Id
            Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
            $Process.WaitForExit(5000) | Out-Null
            throw "$Description exceeded its process deadline."
        }
        if ($Process.ExitCode -ne 0) {
            throw "$Description exited with code $($Process.ExitCode)."
        }
    }
    finally {
        if ($null -ne $Process) {
            if (-not $Process.HasExited) {
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            }
            $Process.Dispose()
        }
    }
}

$Configuration = Get-Content 'C:\MicroHack\secrets\java.json' -Raw | ConvertFrom-Json
$DatabaseReady = $false
$LastDatabaseError = 'PostgreSQL readiness was not attempted.'
$ReadinessDeadline = [DateTime]::UtcNow.AddMinutes(5)
while (-not $DatabaseReady -and [DateTime]::UtcNow -lt $ReadinessDeadline) {
    try {
        if ((Get-Service -Name 'postgresql-x64-18').Status -ne 'Running') {
            throw 'PostgreSQL service is not running.'
        }
        $RemainingMilliseconds = [int][Math]::Max(
            1,
            [Math]::Min(
                10000,
                ($ReadinessDeadline - [DateTime]::UtcNow).TotalMilliseconds
            )
        )
        $env:PGPASSWORD = $Configuration.DatabasePassword
        $env:PGCONNECT_TIMEOUT = '5'
        $env:PGOPTIONS = '-c statement_timeout=5000'
        Invoke-BoundedNativeProbe `
            -FilePath 'C:\Program Files\PostgreSQL\18\bin\psql.exe' `
            -ArgumentList @(
            '-h',
            'localhost',
            '-p',
            '5432',
            '-U',
            'catalog',
            '-d',
            'catalog',
            '-w',
            '-v',
            'ON_ERROR_STOP=1',
            '-tAc',
            '"SELECT 1;"'
        ) -TimeoutMilliseconds $RemainingMilliseconds -Description 'psql readiness probe'
        $DatabaseReady = $true
    }
    catch {
        $LastDatabaseError = $_.Exception.Message -replace '[\r\n]+', ' '
    }
    finally {
        $env:PGPASSWORD = $null
        $env:PGCONNECT_TIMEOUT = $null
        $env:PGOPTIONS = $null
    }
    if (-not $DatabaseReady) {
        $SleepMilliseconds = [int][Math]::Max(
            0,
            [Math]::Min(
                5000,
                ($ReadinessDeadline - [DateTime]::UtcNow).TotalMilliseconds
            )
        )
        if ($SleepMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $SleepMilliseconds
        }
    }
}
if (-not $DatabaseReady) {
    $Failure = '{0} [java] PostgreSQL readiness failed after five minutes: {1}' -f `
        [DateTime]::UtcNow.ToString('o'), $LastDatabaseError
    Add-Content -LiteralPath 'C:\MicroHack\logs\java-app.log' -Value $Failure -Encoding UTF8
    throw $Failure
}
$env:CATALOG_DATABASE_HOST = 'localhost'
$env:CATALOG_DATABASE_PORT = '5432'
$env:CATALOG_DATABASE_NAME = 'catalog'
$env:CATALOG_DATABASE_USERNAME = 'catalog'
$env:CATALOG_DATABASE_PASSWORD = $Configuration.DatabasePassword
$env:CATALOG_DATABASE_SSL_MODE = 'disable'
$env:CATALOG_IMAGES_PATH = 'C:\MicroHack\legacy-data\images'
$env:CATALOG_SEED_PATH = 'C:\MicroHack\legacy-data\catalog.json'
$env:CATALOG_STARTUP_IMPORT_ENABLED = 'true'
$env:PERFTEST_API_KEY = $Configuration.PerformanceApiKey
$env:PERFTEST_WORK_FACTOR = '10'
$env:OTEL_EXPORTER_OTLP_ENDPOINT = 'http://localhost:4317'
$env:OTEL_SERVICE_VERSION = '__SOURCE_COMMIT__'
$env:DEPLOYMENT_ENVIRONMENT = 'lab'
$env:CONTAINER_APP_REVISION = 'facilitator-vm'
$env:OTEL_SDK_DISABLED = 'true'
& '__JAVA_COMMAND__' -jar 'C:\MicroHack\app\java\catalog-java.jar' `
    *>> 'C:\MicroHack\logs\java-app.log'
exit $LASTEXITCODE
'@.Replace('__SOURCE_COMMIT__', $SourceCommit).Replace('__JAVA_COMMAND__', $JavaTools.JavaCommand) |
        Set-Content -Path $StartScript -Encoding UTF8
    Set-CatalogEnvironmentForParticipants -Settings @{
        CATALOG_DATABASE_HOST     = 'localhost'
        CATALOG_DATABASE_PORT     = '5432'
        CATALOG_DATABASE_NAME     = 'catalog'
        CATALOG_DATABASE_USERNAME = 'catalog'
        CATALOG_DATABASE_SSL_MODE = 'disable'
        CATALOG_IMAGES_PATH       = 'C:\MicroHack\legacy-data\images'
        CATALOG_SEED_PATH         = 'C:\MicroHack\legacy-data\catalog.json'
        CATALOG_BASE_URL          = 'http://localhost:8080'
    }
    Register-ApplicationTask -ScriptPath $StartScript
}

function Invoke-StackSmokeCheck {
    param(
        [Parameter(Mandatory)]
        [string]$NativeClient
    )

    $Port = if ($Stack -eq 'dotnet') { 5000 } else { 8080 }
    $BaseUrl = "http://localhost:$Port"
    Invoke-WithRetry -Description "$Stack liveness" -Action {
        $Response = Invoke-WebRequest -Uri "$BaseUrl/healthz" -UseBasicParsing
        if ($Response.StatusCode -ne 200) {
            throw "Unexpected /healthz status $($Response.StatusCode)."
        }
    } -Attempts 120
    Invoke-WithRetry -Description "$Stack readiness" -Action {
        $Response = Invoke-WebRequest -Uri "$BaseUrl/readyz" -UseBasicParsing
        if ($Response.StatusCode -ne 200) {
            throw "Unexpected /readyz status $($Response.StatusCode)."
        }
    } -Attempts 120

    # Read the dataset the application was actually pointed at, not the participant-editable
    # tree it was copied from, so this check keeps meaning once Challenge 1 is under way.
    $CatalogJson = Get-Content (Join-Path $LegacyDataRoot 'catalog.json') -Raw | ConvertFrom-Json
    $Catalog = @($CatalogJson)
    $ImageName = [string]$Catalog[0].filename
    if ($ImageName -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$') {
        throw 'The canonical smoke image is not a lowercase UUID PNG path.'
    }
    $ImageProbe = Join-Path $env:TEMP "$Stack-canonical-image.png"
    $ImageResponse = Invoke-WebRequest -Uri "$BaseUrl/images/$ImageName" `
        -OutFile $ImageProbe -PassThru -UseBasicParsing
    if ($ImageResponse.StatusCode -ne 200 -or
        $ImageResponse.Headers.'Content-Type' -notmatch '^image/png' -or
        (Get-Item $ImageProbe).Length -le 0) {
        throw 'Canonical image smoke check failed.'
    }
    Remove-Item -Path $ImageProbe -Force

    if ($Stack -eq 'dotnet') {
        $env:SQLCMDPASSWORD = $DatabasePassword
        $FigureCount = (@(
            Get-NativeCommandOutput -Path $NativeClient -Arguments @(
                '-S', 'localhost,1433', '-U', 'catalog', '-d', 'LegoCatalog', '-b',
                '-h', '-1', '-W', '-Q', 'SET NOCOUNT ON; SELECT COUNT(*) FROM Figures;'
            ) | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1
        ) -join '').Trim()
        $CategoryCount = (@(
            Get-NativeCommandOutput -Path $NativeClient -Arguments @(
                '-S', 'localhost,1433', '-U', 'catalog', '-d', 'LegoCatalog', '-b',
                '-h', '-1', '-W', '-Q', 'SET NOCOUNT ON; SELECT COUNT(*) FROM Categories;'
            ) | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1
        ) -join '').Trim()
    }
    else {
        $env:PGPASSWORD = $DatabasePassword
        $FigureCount = (@(
            & $NativeClient -h localhost -p 5432 -U catalog -d catalog -tAc `
                'SELECT COUNT(*) FROM figures'
        ) -join '').Trim()
        $CategoryCount = (@(
            & $NativeClient -h localhost -p 5432 -U catalog -d catalog -tAc `
                'SELECT COUNT(*) FROM categories'
        ) -join '').Trim()
    }
    if ($FigureCount -ne '198' -or $CategoryCount -ne '20') {
        throw "Native database smoke check returned $FigureCount figures and $CategoryCount categories."
    }

    @{
        stack          = $Stack
        sourceCommit   = $SourceCommit
        healthRoute    = '/healthz'
        readinessRoute = '/readyz'
        canonicalImage = "/images/$ImageName"
        figures        = 198
        categories     = 20
        images         = 198
        verifiedAtUtc  = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json | Set-Content -Path (Join-Path $StatusRoot "$Stack-smoke.json") `
        -Encoding UTF8
}

try {
    Write-ProvisionLog "Starting idempotent provisioning for source commit $SourceCommit."
    New-MigrationExportDirectory
    Stop-ApplicationTask
    Install-CommonTools
    Install-SourceArchive
    Assert-CanonicalData
    Sync-LegacyDataRoot

    if ($Stack -eq 'dotnet') {
        $Tools = Install-DotNetDatabase
        Publish-DotNetApplication -DotNetCommand $Tools.DotNetCommand `
            -SqlCmdCommand $Tools.SqlCmdCommand
        Invoke-StackSmokeCheck -NativeClient $Tools.SqlCmdCommand
    }
    else {
        $Tools = Install-JavaDatabase
        Publish-JavaApplication -JavaTools $Tools
        Invoke-StackSmokeCheck -NativeClient $Tools.PsqlCommand
    }

    Write-ProvisionLog 'Provisioning and all local smoke checks completed successfully.'
}
finally {
    $DatabasePassword = $null
    $PerformanceApiKey = $null
    $env:SQLCMDPASSWORD = $null
    $env:PGPASSWORD = $null
}
