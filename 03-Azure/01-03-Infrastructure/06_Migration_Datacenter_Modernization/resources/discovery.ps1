# Setting Variables
$downloadpath = "https://go.microsoft.com/fwlink/?linkid=2191847"
$outputpath = "C:\temp"


# Create output directory
New-Item -ItemType Directory -Path $outputpath

# Download files from repository
Invoke-WebRequest -Uri $downloadpath -OutFile "$outputpath\AzureMigrateInstaller.zip"

# Unzip the files
Expand-Archive -Path "$outputpath\AzureMigrateInstaller.zip" -DestinationPath "$outputpath\AzureMigrateInstaller"



