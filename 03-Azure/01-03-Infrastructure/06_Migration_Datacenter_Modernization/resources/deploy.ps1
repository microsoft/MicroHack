

# Replace Hostname placeholter with actual Hostname
(Get-Content -path $pathToIndex -Raw).replace($replaceText, $hostname) | Set-Content -Path $pathToIndex