# Deploy App1

```
$timestamp = (Get-Date).ToString("yyyyMMddTHHmmss")
Write-Output $timestamp

$deploymentName = "MH-Env-Deployment-$timestamp"
$location = "germanywestcentral"
$DeploymentPrefix = "mh-dth"
$templateFile = ".\deploy.bicep"
$parametersFile = ".\main.parameters.json"

New-AzSubscriptionDeployment `
    -Name "$deploymentName" `
    -Location "$location"  `
    -parDeploymentPrefix "$DeploymentPrefix" `
    -TemplateFile $templateFile `
    -TemplateParameterFile $parametersFile `
    -WarningAction Ignore

Write-Output $cmd
```
