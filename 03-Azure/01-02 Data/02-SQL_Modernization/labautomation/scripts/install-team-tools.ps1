$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$logPath = 'C:\Windows\Temp\install-team-tools.log'

Start-Transcript -Path $logPath -Append

try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12

    $installDirectory = 'C:\Install'

    New-Item `
        -Path $installDirectory `
        -ItemType Directory `
        -Force |
        Out-Null

    Write-Host 'Downloading SQL Server Management Studio 22.'

    $ssmsInstaller =
        Join-Path $installDirectory 'vs_SSMS.exe'

    Invoke-WebRequest `
        -Uri 'https://aka.ms/ssms/22/release/vs_SSMS.exe' `
        -OutFile $ssmsInstaller `
        -UseBasicParsing

    Write-Host 'Installing SQL Server Management Studio 22.'

    $ssmsProcess = Start-Process `
        -FilePath $ssmsInstaller `
        -ArgumentList '--add Microsoft.SqlServer.Workload.SSMS.AI --add Microsoft.SqlServer.Workload.SSMS.HybridAndMigration --includeRecommended --quiet --wait --norestart' `
        -Wait `
        -PassThru

    if ($ssmsProcess.ExitCode -notin 0, 3010) {
        throw "SSMS installation failed with exit code $($ssmsProcess.ExitCode)."
    }

    Write-Host 'Resolving latest Azure Storage Explorer release.'

    $release = Invoke-RestMethod `
        -Uri 'https://api.github.com/repos/microsoft/AzureStorageExplorer/releases/latest' `
        -UseBasicParsing

    $asset = $release.assets |
        Where-Object {
            $_.name -eq 'StorageExplorer-windows-x64.exe'
        } |
        Select-Object -First 1

    if (-not $asset) {
        throw 'The Azure Storage Explorer x64 installer could not be found.'
    }

    $storageExplorerInstaller =
        Join-Path $installDirectory 'StorageExplorer-windows-x64.exe'

    Write-Host 'Downloading Azure Storage Explorer.'

    Invoke-WebRequest `
        -Uri $asset.browser_download_url `
        -OutFile $storageExplorerInstaller `
        -UseBasicParsing

    Write-Host 'Installing Azure Storage Explorer.'

    $storageExplorerProcess = Start-Process `
        -FilePath $storageExplorerInstaller `
        -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS' `
        -Wait `
        -PassThru

    if ($storageExplorerProcess.ExitCode -notin 0, 3010) {
        throw "Storage Explorer installation failed with exit code $($storageExplorerProcess.ExitCode)."
    }

    New-Item `
        -Path 'HKLM:\SOFTWARE\SQLMicroHack' `
        -Force |
        Out-Null

    New-ItemProperty `
        -Path 'HKLM:\SOFTWARE\SQLMicroHack' `
        -Name 'TeamToolsInstalled' `
        -Value (Get-Date).ToString('o') `
        -PropertyType String `
        -Force |
        Out-Null

    Write-Host 'Team VM tool installation completed.'
}
finally {
    Stop-Transcript
}