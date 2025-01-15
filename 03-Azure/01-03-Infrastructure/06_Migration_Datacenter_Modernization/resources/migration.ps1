# Setting Variables
$downloadpath = "https://aka.ms/unifiedinstaller"
$outputpath = "C:\temp"


# Create output directory
New-Item -ItemType Directory -Path $outputpath

# Download files from repository
Invoke-WebRequest -Uri $downloadpath -OutFile "$outputpath\AzureMigrateInstaller.zip"





