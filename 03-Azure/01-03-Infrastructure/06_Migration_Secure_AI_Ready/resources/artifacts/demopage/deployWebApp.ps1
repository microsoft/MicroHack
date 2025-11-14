# Setting Variables
$pathToRepo = "https://raw.githubusercontent.com/microsoft/MicroHack/main/03-Azure/01-03-Infrastructure/06_Migration_Secure_AI_Ready/resources/artifacts/demopage"
$pathToIndex = "C:\inetpub\wwwroot\index.html"
$replaceText = "<HOSTNAME>"
$hostname = $env:computername

# Remove Default contents of wwwroot
Remove-Item -Path "C:\inetpub\wwwroot\*.*"

# Download files from repository
Invoke-WebRequest -Uri "$pathToRepo/index.html" -OutFile C:\inetpub\wwwroot\index.html
Invoke-WebRequest -Uri "$pathToRepo/GitHub_Logo.png" -OutFile C:\inetpub\wwwroot\GitHub_Logo.png
Invoke-WebRequest -Uri "$pathToRepo/MSLogo.png" -OutFile C:\inetpub\wwwroot\MSLogo.png
Invoke-WebRequest -Uri "$pathToRepo/MSicon.png" -OutFile C:\inetpub\wwwroot\MSicon.png
Invoke-WebRequest -Uri "$pathToRepo/github-mark.png" -OutFile C:\inetpub\wwwroot\github-mark.png
Invoke-WebRequest -Uri "$pathToRepo/stylesheet.css" -OutFile C:\inetpub\wwwroot\stylesheet.css

# Replace Hostname placeholder with actual Hostname
(Get-Content -path $pathToIndex -Raw).replace($replaceText, $hostname) | Set-Content -Path $pathToIndex
