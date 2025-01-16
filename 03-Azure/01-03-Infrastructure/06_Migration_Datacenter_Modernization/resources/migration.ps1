# Setting Variables
$Unifiedinstallerpath = "https://aka.ms/unifiedinstaller"
$mysqlserverpath = "https://aka.ms/mysqlserverdownload"
$outputpath = "C:\temp"


# Create output directory
New-Item -ItemType Directory -Path $outputpath
New-Item -ItemType Directory -Path "$outputpath\ASRSetup"
# Download files from repository
Invoke-WebRequest -Uri $Unifiedinstallerpath -OutFile "$outputpath\unifiedinstaller.exe"
Invoke-WebRequest -Uri $mysqlserverpath -OutFile "$outputpath\ASRSetup\mysql-installer-community-5.7.20.0.msi"




