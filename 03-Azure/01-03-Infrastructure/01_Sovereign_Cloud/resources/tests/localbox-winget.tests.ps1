BeforeAll {
    . "$PSScriptRoot/../../labautomation/localbox-startup.ps1"
    . "$PSScriptRoot/../../labautomation/localbox-automation.ps1"
    function Repair-WinGetPackageManager { param($Version, [switch]$AllUsers, [switch]$Force) }
    function Get-WinGetVersion {}
    function Get-WinGetPackage {}
}

Describe 'WinGet repair and compatibility gate' {
    BeforeEach {
        Mock Get-Module { @{ Version = [version]'1.29.380' } } -ParameterFilter { $Name -eq 'Microsoft.WinGet.Client' }
        Mock Import-Module {} -ParameterFilter { $Name -eq 'Microsoft.WinGet.Client' }
        Mock Repair-WinGetPackageManager {}
        Mock Get-WinGetVersion { 'v1.29.380' }
        Mock Get-WinGetPackage { @{ Id = 'fixture' } }
        Mock Start-Sleep {}
    }
    It 'repairs the CLI to match the installed client and verifies COM enumeration' {
        Initialize-LocalBoxWinGet
        Should -Invoke Repair-WinGetPackageManager -Times 1 -Exactly -ParameterFilter { $Version -eq '1.29.380' -and $AllUsers -and $Force }
        Should -Invoke Get-WinGetPackage -Times 1 -Exactly
    }
    It 'retries the observed HTTP 504 instead of continuing with an incompatible CLI' {
        $repairCounter = @{ Value = 0 }
        Mock Repair-WinGetPackageManager {
            $repairCounter.Value++
            if ($repairCounter.Value -eq 1) { throw '504 Gateway Time-out' }
        }
        Initialize-LocalBoxWinGet
        Should -Invoke Repair-WinGetPackageManager -Times 2 -Exactly
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 30 }
        Should -Invoke Get-WinGetPackage -Times 1 -Exactly
    }
    It 'stops after three failed repairs and never proceeds to package enumeration' {
        Mock Repair-WinGetPackageManager { throw '504 Gateway Time-out' }
        { Initialize-LocalBoxWinGet } | Should -Throw '*504*'
        Should -Invoke Repair-WinGetPackageManager -Times 3 -Exactly
        Should -Invoke Get-WinGetPackage -Times 0
    }
    It 'rejects a stale CLI version even when repair reports success' {
        Mock Get-WinGetVersion { 'v1.11.510' }
        { Initialize-LocalBoxWinGet } | Should -Throw '*does not match*'
        Should -Invoke Get-WinGetPackage -Times 0
    }
    It 'rejects the exact RPC activation failure despite matching version strings' {
        Mock Get-WinGetPackage { throw 'Failed to create instance: -2147023174' }
        { Initialize-LocalBoxWinGet } | Should -Throw '*-2147023174*'
        Should -Invoke Get-WinGetPackage -Times 3 -Exactly
    }
}

Describe 'Native WinGet configuration outcomes' {
    BeforeEach {
        $oldLocalData = $env:LOCALAPPDATA
        $env:LOCALAPPDATA = $TestDrive
        New-Item -ItemType Directory -Path "$TestDrive/Microsoft/WindowsApps" -Force | Out-Null
        Set-Content "$TestDrive/Microsoft/WindowsApps/winget.exe" 'fixture'
        $configPath = "$TestDrive/packages.dsc.yml"
        Set-Content $configPath 'fixture'
        $wingetRun = @{ Complete = $true; Killed = $false; Disposed = $false }
        $native = [pscustomobject]@{ ExitCode = 0; HasExited = $true }
        $native | Add-Member ScriptMethod WaitForExit { param($milliseconds) return $wingetRun.Complete -or $wingetRun.Killed }
        $native | Add-Member ScriptMethod Kill { param($tree) $wingetRun.Killed = $true; $this.HasExited = $true }
        $native | Add-Member ScriptMethod Dispose { $wingetRun.Disposed = $true }
        Mock Start-Process { $native }
        Mock Start-Sleep {}
    }
    AfterEach { $env:LOCALAPPDATA = $oldLocalData }
    It 'accepts only a native zero exit and retains private logs' {
        Invoke-LocalBoxWinGetConfiguration -Path $configPath -LogDirectory $TestDrive
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $RedirectStandardOutput -like "$TestDrive/*stdout.log" -and $RedirectStandardError -like "$TestDrive/*stderr.log" }
        $wingetRun.Disposed | Should -BeTrue
    }
    It 'does not treat the observed DSC failure exit as success' {
        $native.ExitCode = -1978286075
        { Invoke-LocalBoxWinGetConfiguration -Path $configPath -LogDirectory $TestDrive } | Should -Throw '*-1978286075*'
        Should -Invoke Start-Process -Times 3 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly
    }
    It 'rejects a missing native exit code' {
        $native.ExitCode = $null
        { Invoke-LocalBoxWinGetConfiguration -Path $configPath -LogDirectory $TestDrive -Attempts 1 } | Should -Throw '*exit code*'
    }
    It 'bounds the native wait and terminates only its owned process' {
        $wingetRun.Complete = $false
        $native.HasExited = $false
        { Invoke-LocalBoxWinGetConfiguration -Path $configPath -LogDirectory $TestDrive -Attempts 1 } | Should -Throw '*900-second*'
        $wingetRun.Killed | Should -BeTrue
        $wingetRun.Disposed | Should -BeTrue
    }
}

Describe 'Upstream WinGet hardening transform' {
    BeforeEach {
        $path = "$TestDrive/WinGet.ps1"
        @'
$ErrorActionPreference = $env:ErrorActionPreference
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose
Repair-WinGetPackageManager -AllUsers -Force -Latest -Verbose
& $winget configure --file "$($Env:LocalBoxDir)\DSC\packages.dsc.yml" --accept-configuration-agreements --disable-interactivity
& $winget configure --file "$($Env:LocalBoxDir)\DSC\hyper-v.dsc.yml" --accept-configuration-agreements --disable-interactivity
Get-ScheduledTask *LogonScript* | Start-ScheduledTask
Unregister-ScheduledTask -TaskName 'WinGetLogonScript' -Confirm:$false
'@ | Set-Content $path
    }

    Describe 'Retired package removal' {
        BeforeEach {
            $path = "$TestDrive/packages.dsc.yml"
            $supported = @'
properties:
  resources:
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: azcopy
      settings:
        id: Microsoft.Azure.AZCopy.10
        source: winget
'@
            $retired = @'
    - resource: Microsoft.WinGet.DSC/WinGetPackage
      id: Microsoft.AzureDataStudio
      directives:
        description: Install Microsoft Azure Data Studio
      settings:
        id: Microsoft.AzureDataStudio
        source: winget
'@
            "$supported`n$retired" | Set-Content $path
        }
        It 'removes only the exact retired resource and preserves supported tools' {
            Set-LocalBoxPackageConfiguration $path
            $text = Get-Content $path -Raw
            $text | Should -Not -Match 'AzureDataStudio'
            $text.TrimEnd() | Should -Be $supported.TrimEnd()
            Set-LocalBoxPackageConfiguration $path
            (Get-Content $path -Raw).TrimEnd() | Should -Be $supported.TrimEnd()
        }
        It 'handles Windows CRLF configurations' {
            ((Get-Content $path -Raw).Replace("`n", "`r`n")) | Set-Content $path
            Set-LocalBoxPackageConfiguration $path
            Get-Content $path -Raw | Should -Not -Match 'AzureDataStudio'
        }
        It 'rejects unexpected changes to the retired package block without modifying it' {
            (Get-Content $path -Raw).Replace('Install Microsoft Azure Data Studio', 'Unknown changed block') | Set-Content $path
            $before = Get-Content $path -Raw
            { Set-LocalBoxPackageConfiguration $path } | Should -Throw '*Unrecognized retired*'
            Get-Content $path -Raw | Should -Be $before
        }
    }
    It 'protects repair and both native configuration calls before upstream task startup' {
        Set-LocalBoxWinGetGuard $path
        $text = Get-Content $path -Raw
        $text | Should -Match '\$ErrorActionPreference = ''Stop'''
        $text | Should -Match 'Initialize-LocalBoxWinGet'
        $text | Should -Not -Match 'Repair-WinGetPackageManager|& \$winget configure'
        [regex]::Matches($text, 'Invoke-LocalBoxWinGetConfiguration').Count | Should -Be 2
        $text.IndexOf('Invoke-LocalBoxWinGetConfiguration') | Should -BeLessThan $text.IndexOf('Start-ScheduledTask')
        $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors)
        $parseErrors.Count | Should -Be 0
    }
    It 'rejects upstream drift rather than running unprotected configuration' {
        (Get-Content $path -Raw).Replace('hyper-v.dsc.yml', 'different.yml') | Set-Content $path
        { Set-LocalBoxWinGetGuard $path } | Should -Throw '*Unsupported upstream WinGet*'
    }
}
