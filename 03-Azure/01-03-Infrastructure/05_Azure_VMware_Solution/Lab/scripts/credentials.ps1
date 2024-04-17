# This script block grabs AVS credentials and outputs in the terminal
# Prerequisites: This script uses a *Managed Identity* of the Jumpbox VM that you will need to assign as *Contributor* to AVS Private Cloud 


[void] (az login --identity)
[void] (az config set extension.use_dynamic_install=yes_without_prompt)

$resourceGroup = az vmware private-cloud list --query [0].resourceGroup
$avsPrivateCloud = az vmware private-cloud list --query [0].name

$creds = az vmware private-cloud list-admin-credentials -c $avsPrivateCloud  -g $resourceGroup

$credsString = [system.String]::Join(" ", $creds)
$credsJson = ConvertFrom-Json $credsString

$endpoints = az vmware private-cloud show -n $avsPrivateCloud  -g $resourceGroup --query "endpoints"

$endpointsString = [system.String]::Join(" ", $endpoints)
$endpointsJson = ConvertFrom-Json $endpointsString

$nsxtURL = $endpointsJson.nsxtManager
$vcsaURL = $endpointsJson.vcsa

$vcsaIP = $vcsaURL.Substring(8)
$vcsaIP = $vcsaIP.Substring(0, $vcsaIP.Length - 1)

$nsxtIP = $nsxtURL.Substring(8)
$nsxtIP = $nsxtIP.Substring(0, $nsxtIP.Length - 1)

$configs = @{"AVSvCenter" = @{"IP" = $vcsaIP; "Username" = $credsJson.vcenterUsername; "Password" = $credsJson.vcenterPassword }; "AVSNSXT" = @{"IP" = $nsxtIP; "Username" = $credsJson.nsxtUsername; "Password" = $credsJson.nsxtPassword } }

$configs | ConvertTo-Json