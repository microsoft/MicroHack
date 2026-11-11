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

    # Storage Explorer is optional: a failure must not fail the whole script.
    try {
        $storageExplorerInstaller = Join-Path $installDirectory 'StorageExplorer-windows-x64.exe'

        Write-Host 'Downloading Azure Storage Explorer.'

        Invoke-WebRequest `
            -Uri 'https://go.microsoft.com/fwlink/?LinkId=708343&clcid=0x409' `
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
    }
    catch {
        Write-Warning "Azure Storage Explorer could not be installed and is skipped: $($_.Exception.Message)"
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