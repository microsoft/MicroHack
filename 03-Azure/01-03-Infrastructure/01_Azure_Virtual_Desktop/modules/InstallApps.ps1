Try {
       
    # Download VSCode Sources
    Write-Host "Downloading VS Code sources..."
    Invoke-WebRequest -Uri 'https://aka.ms/vscode-win32-x64-system-stable' -OutFile 'c:\windows\temp\VSCode_x64.exe'
    # Wait 10s
    Start-Sleep -Seconds 10
    # Install VSCode silently
    Write-Host "Installing VS Code now..."
    Start-Process -FilePath 'c:\windows\temp\VSCode_x64.exe' -Args '/verysilent /suppressmsgboxes /mergetasks=!runcode' -Wait -PassThru
    Write-Host "Successfully installed VS Code..."

    # Download Notepad++ Sources
    Write-Host "Downloading Notepad++ sources..."
    Invoke-WebRequest -Uri 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.5.6/npp.8.5.6.Installer.x64.exe' -OutFile 'c:\windows\temp\npp.8.5.6.Installer.x64.exe'
    # Wait 10s
    Start-Sleep -Seconds 10
    # Install VSCode silently
    Write-Host "Installing Notepad++ now..."
    Start-Process -FilePath 'c:\windows\temp\npp.8.5.6.Installer.x64.exe' -Args '/S' -Wait -PassThru
    Write-Host "Successfully installed Notepad++..."
       
    } catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}