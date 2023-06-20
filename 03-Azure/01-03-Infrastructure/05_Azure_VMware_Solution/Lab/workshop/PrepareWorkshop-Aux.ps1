
###################################################################################################################################################

# Delete old subscription deployments

$deployments = az deployment sub list -o tsv --query [].name

$resultsTable = @()

foreach ($deployment in $deployments) {

    $resultsTable += [PSCustomObject](@{Deployment = $deployment; status = "Will be deleted" })
    
    az deployment sub delete --name $deployment --no-wait
}

#$resultsTable | Format-Table -AutoSize 
$resultsTable | Export-Csv -Path "results.csv" -NoTypeInformation -Force

###################################################################################################################################################

# Check AVS Labs Deployments Status

$Prefix = "GPSUS-XYZ"
$numberOfLabs = 10
$resultsTable = @()

for ($i = 1; $i -le $numberOfLabs; $i++) {
    $name = "$Prefix$i"

    $avsStatus = az vmware private-cloud show -n $name-PrivateCloud  -g $name-SDDC --query "provisioningState"

    $resultsTable += [PSCustomObject](@{ SDDC = '$name-PrivateCloud'; status = $avsStatus })
}

$resultsTable | Format-Table -AutoSize

###################################################################################################################################################

# Check AVS Nested Labs Deployments Status

$Prefix = "GPSUS-XYZ-"
$numberOfLabs = 4
$resultsTable = @()

for ($i = 1; $i -le $numberOfLabs; $i++) {
    
    $name = "$Prefix$i-jumpbox"

    $runCommandResults = az vm run-command invoke --command-id RunPowerShellScript --name $name -g $name --scripts "Get-Content -Path C:\temp\bootstrap-nestedlabs.log -Tail 25" --query "value[*].message"
    $runCommandResultsString = [system.String]::Join(" ", $runCommandResults)
    #$runCommandResultsJson = ConvertFrom-Json $runCommandResultsString
    
    $resultsTable += [PSCustomObject](@{ VM = $name; status = $runCommandResultsString })
}

#$resultsTable | Format-Table -AutoSize
$resultsTable | Export-Csv -Path "results.csv" -NoTypeInformation -Force

###################################################################################################################################################

#Delete Empty Resource Groups

$groups = az group list -o tsv --query [].name

$resultsTable = @()

foreach ($group in $groups) {

    if (az resource list --resource-group $group -o tsv) {
        Write-Host "$group is not empty" -ForegroundColor Green
        $resultsTable += [PSCustomObject](@{resourceGroup = $group; status = "Not Empty" })
    }
    else {
        Write-Host "$group will be deleted" -ForegroundColor Cyan
        $resultsTable += [PSCustomObject](@{resourceGroup = $group; status = "Empty; will be deleted" })
        az group delete --resource-group $group --no-wait --yes
    }
}

#$resultsTable | Format-Table -AutoSize 
$resultsTable | Export-Csv -Path "results.csv" -NoTypeInformation -Force

###################################################################################################################################################

#Delete Empty Resource Groups by Tags

#"[?tags.Team == 'Engineering']"
#11/16/2022
#((Get-Date).AddDays(-13) -Format 'MM/dd/yyyy')

$groups = az group list -o tsv --query "[?tags.DeleteDate == '11/13/2022'].name"

$resultsTable = @()

foreach ($group in $groups) {

    $resultsTable += [PSCustomObject](@{resourceGroup = $group; status = "Will be deleted" })
    az group delete --resource-group $group --no-wait --yes
}

#$resultsTable | Format-Table -AutoSize 
$resultsTable | Export-Csv -Path "results.csv" -NoTypeInformation -Force

###################################################################################################################################################

# Delete Running Deployments 

$deployments = az deployment sub list --filter "provisioningState eq 'Running'" -o tsv --query [].name

foreach ($deployment in $deployments) {

    $resultsTable += [PSCustomObject](@{Deployment = $deployment; status = "Will be canceled" })
    
    az deployment sub cancel --name $deployment

}

$resultsTable | Format-Table -AutoSize 

###################################################################################################################################################
