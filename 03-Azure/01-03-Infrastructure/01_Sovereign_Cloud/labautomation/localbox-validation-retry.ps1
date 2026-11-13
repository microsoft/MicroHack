param(
    [string]$SubscriptionId,
    [string]$ResourceGroupName,
    [string]$OriginalValidationCorrelationId,
    [string]$StartedAfter,
    [string]$RecoveryVersion
)

function Update-LocalBoxValidationRetryPath {
    param(
        [string]$MachinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine'),
        [string]$UserPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    )
    $env:PATH = (@($env:PATH, $MachinePath, $UserPath) |
        Where-Object { $_ } | Select-Object -Unique) -join [IO.Path]::PathSeparator
}

function Invoke-LocalBoxValidationRetryAz {
    param([string[]]$Arguments, [switch]$NoOutput)
    $PSNativeCommandUseErrorActionPreference = $false
    $format = if ($NoOutput) { 'none' } else { 'json' }
    $output = @(& az @Arguments --only-show-errors --output $format 2>&1)
    $operation = ($Arguments | Select-Object -First 3) -join ' '
    if ($LASTEXITCODE -ne 0) {
        throw "Validation recovery Azure CLI '$operation' failed. Inspect localcluster-validate/localcluster-deploy operations. CLI output is withheld to protect deployment credentials."
    }
    $stderr = @($output | Where-Object { $_ -is [Management.Automation.ErrorRecord] })
    if ($stderr.Count) { Write-Warning "Azure CLI emitted diagnostics during '$operation'; raw output is withheld to protect deployment credentials." }
    if ($NoOutput) { return }
    $stdout = ($output | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] }) -join "`n"
    try { $stdout | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Validation recovery Azure CLI '$operation' returned invalid JSON; raw output is withheld." }
}

function Invoke-LocalBoxValidationRetry {
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][guid]$OriginalValidationCorrelationId,
        [string]$TemplateDirectory = 'C:\LocalBox',
        [int]$RetryDelaySeconds = 120
    )
    $ErrorActionPreference = 'Stop'
    if ($OriginalValidationCorrelationId -eq [guid]::Empty) { throw 'A nonempty original validation correlation ID is required.' }
    $template = Join-Path $TemplateDirectory 'azlocal.json'
    $parameters = Join-Path $TemplateDirectory 'azlocal.parameters.json'
    foreach ($path in @($template, $parameters)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required existing LocalBox deployment file is missing: $path" }
    }
    Update-LocalBoxValidationRetryPath
    Get-Command az -ErrorAction Stop | Out-Null
    Write-Host "[LocalBox] Automatic validation retry 1/1: waiting $RetryDelaySeconds seconds before rechecking the failed deployment."
    Start-Sleep -Seconds $RetryDelaySeconds
    $previousProfile = $env:AZURE_CONFIG_DIR
    $profile = Join-Path ([IO.Path]::GetTempPath()) "localbox-validation-$([guid]::NewGuid())"
    $failure = $null
    try {
        New-Item -ItemType Directory -Path $profile -ErrorAction Stop | Out-Null
        $env:AZURE_CONFIG_DIR = $profile
        Invoke-LocalBoxValidationRetryAz @('login', '--identity', '--allow-no-subscriptions') -NoOutput
        $scope = @('--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName)
        $original = Invoke-LocalBoxValidationRetryAz (@('deployment', 'group', 'show') + $scope + @('--name', 'localcluster-validate'))
        if ($original.properties.provisioningState -ne 'Failed' -or
            $original.properties.correlationId -ne $OriginalValidationCorrelationId.ToString()) {
            throw 'Validation changed after recovery was requested. No retry was submitted; inspect possible manual intervention.'
        }
        $deployments = @(Invoke-LocalBoxValidationRetryAz (@('deployment', 'group', 'list') + $scope))
        if (@($deployments | Where-Object name -eq 'localcluster-deploy').Count) {
            throw 'A cluster deployment already exists. Recovery will not replace or overlap it.'
        }
        try {
            $localParameters = (Get-Content -LiteralPath $parameters -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).parameters
            $localTemplate = Get-Content -LiteralPath $template -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
        catch { throw 'Unable to read the existing LocalBox template/parameters; contents are withheld to protect credentials.' }
        foreach ($field in @('clusterName', 'keyVaultName', 'diagnosticStorageAccountName', 'arcNodeResourceIds')) {
            $expected = $original.properties.parameters.$field.value
            $actual = $localParameters.$field.value
            if ($null -eq $expected -or $null -eq $actual -or
                (ConvertTo-Json -InputObject $actual -Compress) -ne (ConvertTo-Json -InputObject $expected -Compress)) {
                throw "LocalBox parameter '$field' does not match the failed validation. No retry was submitted."
            }
        }
        foreach ($mode in @('Validate', 'Deploy')) {
            if ($mode -notin $localTemplate.parameters.deploymentMode.allowedValues) { throw 'The LocalBox template does not support the expected Validate/Deploy contract.' }
        }
        $arguments = @('deployment', 'group', 'create') + $scope + @('--template-file', $template, '--parameters', "@$parameters")
        Write-Host '[LocalBox] Retrying Azure Local validation using the existing local deployment files.'
        $validation = Invoke-LocalBoxValidationRetryAz ($arguments + @('deploymentMode=Validate', '--name', 'localcluster-validate'))
        if ($validation.properties.provisioningState -ne 'Succeeded' -or
            -not $validation.properties.correlationId -or $validation.properties.correlationId -eq $OriginalValidationCorrelationId.ToString()) {
            throw 'The automatic validation retry did not return a new successful validation. Cluster deployment was not submitted.'
        }
        $current = Invoke-LocalBoxValidationRetryAz (@('deployment', 'group', 'show') + $scope + @('--name', 'localcluster-validate'))
        if ($current.properties.provisioningState -ne 'Succeeded' -or $current.properties.correlationId -ne $validation.properties.correlationId) {
            throw 'Validation changed before cluster deployment could be submitted. Inspect possible manual intervention.'
        }
        $deployments = @(Invoke-LocalBoxValidationRetryAz (@('deployment', 'group', 'list') + $scope))
        if (@($deployments | Where-Object name -eq 'localcluster-deploy').Count) {
            throw 'A cluster deployment appeared during validation. Recovery will not replace or overlap it.'
        }
        Write-Host '[LocalBox] Validation retry succeeded. Submitting Azure Local deployment; nested readiness is still pending.'
        Invoke-LocalBoxValidationRetryAz ($arguments + @('deploymentMode=Deploy', '--name', 'localcluster-deploy', '--no-wait')) -NoOutput
    }
    catch {
        $failure = $_
        throw
    }
    finally {
        $env:AZURE_CONFIG_DIR = $previousProfile
        try {
            if (Test-Path -LiteralPath $profile) { Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction Stop }
        }
        catch {
            if ($failure) { throw "Validation recovery failed: $($failure.Exception.Message) Cleanup of its private CLI profile also failed." }
            throw 'Validation recovery could not remove its private CLI profile.'
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-LocalBoxValidationRetry -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName `
            -OriginalValidationCorrelationId $OriginalValidationCorrelationId
    }
    catch { Write-Error $_ -ErrorAction Continue; exit 1 }
}
