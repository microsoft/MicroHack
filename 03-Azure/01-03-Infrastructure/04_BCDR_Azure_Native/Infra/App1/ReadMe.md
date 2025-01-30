# Deploy App1

```
# e.g. deployment command
New-AzSubscriptionDeployment `
    -Name "MH-Demo-Env-Deployment" `
    -Location "germanywestcentral" `
    -TemplateFile ".\deploy.bicep" `
    -parDeploymentPrefix "mh" `
    -TemplateParameterFile ".\main.parameters.json" `
    -WarningAction Ignore
```
