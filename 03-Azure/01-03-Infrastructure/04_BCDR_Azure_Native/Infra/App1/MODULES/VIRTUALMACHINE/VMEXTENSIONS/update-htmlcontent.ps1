$metadataUrl = "http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01"
$headers = @{ "Metadata" = "true" }
$response = Invoke-RestMethod -Headers $headers -Uri $metadataUrl


$serverName=$response.name
$location=$response.location

$IndexFile=get-content -path c:\inetpub\wwwroot\index.html
$UpdatedFile = $IndexFile -replace "ServerName",$serverName -replace "Location",$location
$UpdatedFile
Set-content -path c:\inetpub\wwwroot\index.html -Value $UpdatedFile
