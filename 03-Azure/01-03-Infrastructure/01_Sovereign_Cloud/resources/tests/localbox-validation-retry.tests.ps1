BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    . "$root/labautomation/localbox-automation.ps1"
    . "$root/labautomation/localbox-validation-retry.ps1"
    function Update-MhhToken {}
    function az {}
    $testSubscription = '10000000-0000-0000-0000-000000000001'
    $testGroup = 'rg-localbox-test'
    $originalId = '20000000-0000-0000-0000-000000000001'
    $newId = '20000000-0000-0000-0000-000000000002'
    $downloadError = @{
        code = 'UpdateDeploymentSettingsDataFailed'
        message = 'Validation status is {Status=Error, Steps={Name=Download content for deployment, Description=Download required content before starting validation., Status=Error, Exception=Timeout of 7200 seconds reached for interface DownloadContent}}'
    }
}

Describe 'Validation failure classification' {
    It 'recognizes the reported content-download timeout, including nested ARM errors' {
        Test-LocalBoxValidationDownloadTimeout $downloadError | Should -BeTrue
        Test-LocalBoxValidationDownloadTimeout @{ code = 'DeploymentFailed'; details = @($downloadError) } | Should -BeTrue
    }
    It 'rejects unknown, empty and mixed validation errors' {
        foreach ($errorDetail in @(
            $null,
            @{ code = 'AuthorizationFailed'; message = $downloadError.message },
            @{ code = $downloadError.code; message = 'Network validation failed' },
            @{ code = $downloadError.code; message = 'Name=Download content for deployment, Exception=Access denied' },
            @{ details = @($downloadError, @{ code = 'InvalidConfiguration'; message = 'Invalid network' }) }
        )) {
            Test-LocalBoxValidationDownloadTimeout $errorDetail | Should -BeFalse
        }
    }
}

Describe 'Bounded Console validation recovery' {
    BeforeEach {
        $recoveryTest = @{ Submitted = 0; Reads = 0; Recovered = $false; Existing = $null; Body = $null; FailedState = 'Failed' }
        Mock Update-MhhToken {}
        Mock Wait-LocalBoxAutomation {
            for ($iteration = 0; $iteration -lt 6; $iteration++) {
                $probeResult = & $Probe
                if ($probeResult.Ready) { return $probeResult }
            }
            throw 'Test polling budget exhausted.'
        }
        Mock Invoke-LocalBoxAutomationAz {
            if ($Arguments[0] -eq 'deployment' -and $Arguments[1] -eq 'operation') {
                @{ properties = @{ provisioningState = 'Failed'
                    targetResource = @{ resourceType = 'Microsoft.AzureStackHCI/clusters/deploymentSettings' }
                    statusMessage = @{ error = $downloadError } } }
            }
            elseif ($Arguments[0] -eq 'deployment') {
                if ($recoveryTest.Recovered) {
                    @{ name = 'localcluster-validate'; properties = @{ provisioningState = 'Succeeded'; correlationId = $newId } }
                    @{ name = 'localcluster-deploy'; properties = @{ provisioningState = 'Succeeded' } }
                }
                else {
                    @{ name = 'localcluster-validate'; properties = @{ provisioningState = $recoveryTest.FailedState; correlationId = $originalId } }
                }
            }
            elseif ($Arguments[0] -eq 'resource' -and $Arguments[1] -eq 'list') {
                foreach ($type in @('Microsoft.AzureStackHCI/clusters', 'Microsoft.ResourceConnector/appliances', 'Microsoft.ExtendedLocation/customLocations')) {
                    @{ type = $type; id = "/$type/test" }
                }
            }
            elseif ($Arguments[0] -eq 'resource') {
                @{ properties = @{ provisioningState = 'Succeeded'; connectivityStatus = 'Connected'; status = 'Running'
                    clusterExtensionIds = @('/test/hybridaksextension') } }
            }
            else { throw 'Unexpected Azure CLI call.' }
        }
        Mock Invoke-LocalBoxAutomationRequest {
            if ($Method -eq 'PUT') {
                $recoveryTest.Submitted++
                $recoveryTest.Body = $Body
                $recoveryTest.Existing = @{ properties = @{ provisioningState = 'Succeeded'; parameters = $Body.properties.parameters } }
                return
            }
            if ($Path -notlike '*runCommands*') { return @{ location = 'spaincentral' } }
            if (-not $recoveryTest.Existing) { return }
            $recoveryTest.Reads++
            $execution = if ($recoveryTest.Reads -lt 2) { 'Running' } else { 'Succeeded' }
            $recoveryTest.Existing.properties.instanceView = @{
                executionState = $execution; exitCode = 0; startTime = [datetime]::UtcNow.ToString('o')
            }
            if ($execution -eq 'Succeeded') { $recoveryTest.Recovered = $true }
            $recoveryTest.Existing
        }
        $retryParameters = @(
            @{ name = 'SubscriptionId'; value = $testSubscription }
            @{ name = 'ResourceGroupName'; value = $testGroup }
            @{ name = 'OriginalValidationCorrelationId'; value = $originalId }
            @{ name = 'StartedAfter'; value = [datetime]::UtcNow.AddMinutes(-1).ToString('o') }
            @{ name = 'RecoveryVersion'; value = '1' }
        )
    }
    It 'submits exactly one asynchronous retry inside the existing timeout and still checks nested readiness' {
        Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup -TimeoutSeconds 600
        $recoveryTest.Submitted | Should -Be 1
        $recoveryTest.Body.properties.asyncExecution | Should -BeTrue
        $recoveryTest.Body.properties.timeoutInSeconds | Should -BeLessOrEqual 600
        $recoveryTest.Body.properties.timeoutInSeconds | Should -BeGreaterThan 120
        $recoveryTest.Body.properties.source.script | Should -Be (Get-Content "$root/labautomation/localbox-validation-retry.ps1" -Raw)
        Should -Invoke Invoke-LocalBoxAutomationAz -Times 5 -Exactly -ParameterFilter { $Arguments[0] -eq 'resource' }
        Should -Invoke Wait-LocalBoxAutomation -Times 1 -Exactly -ParameterFilter { $TimeoutSeconds -eq 600 }
    }
    It 'resumes an existing recovery without replacing it or spending another retry' {
        $recoveryTest.Existing = @{ properties = @{ provisioningState = 'Succeeded'; parameters = $retryParameters } }
        Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup -TimeoutSeconds 600
        $recoveryTest.Submitted | Should -Be 0
    }
    It 'never retries a canceled validation' {
        $recoveryTest.FailedState = 'Canceled'
        { Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup } | Should -Throw '*canceled*'
        $recoveryTest.Submitted | Should -Be 0
    }
    It 'does not schedule recovery without enough time for its backoff' {
        { Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup -TimeoutSeconds 120 } | Should -Throw '*Insufficient*'
        $recoveryTest.Submitted | Should -Be 0
    }
    It 'rejects unrelated failed operations' {
        Mock Invoke-LocalBoxAutomationAz {
            @{ properties = @{ provisioningState = 'Failed'; targetResource = @{ resourceType = 'Microsoft.KeyVault/vaults' }; statusMessage = @{ error = $downloadError } } }
        } -ParameterFilter { $Arguments[1] -eq 'operation' }
        { Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup } | Should -Throw '*outside the recognized*'
        $recoveryTest.Submitted | Should -Be 0
    }
    It 'surfaces operation-read errors without submitting recovery' {
        Mock Invoke-LocalBoxAutomationAz { throw 'AuthorizationFailed' } -ParameterFilter { $Arguments[1] -eq 'operation' }
        { Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup } | Should -Throw '*AuthorizationFailed*'
        $recoveryTest.Submitted | Should -Be 0
    }
    It 'rejects an unrecognized validation failure even when its operation type matches' {
        Mock Invoke-LocalBoxAutomationAz {
            @{ properties = @{ provisioningState = 'Failed'
                targetResource = @{ resourceType = 'Microsoft.AzureStackHCI/clusters/deploymentSettings' }
                statusMessage = @{ error = @{ code = 'UpdateDeploymentSettingsDataFailed'; message = 'Invalid configuration' } } } }
        } -ParameterFilter { $Arguments[1] -eq 'operation' }
        { Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup } | Should -Throw '*non-retryable*'
        $recoveryTest.Submitted | Should -Be 0
    }
    It 'does not replace a failed recovery when the Console is restarted' {
        Mock Invoke-LocalBoxAutomationRequest {
            @{ properties = @{ provisioningState = 'Succeeded'; parameters = $retryParameters
                instanceView = @{ executionState = 'Failed'; exitCode = 1; startTime = [datetime]::UtcNow.ToString('o') } } }
        }
        { Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup } | Should -Throw '*Automatic validation retry failed*'
        $recoveryTest.Submitted | Should -Be 0
    }
    It 'rejects a second failed validation after successful recovery execution rather than looping' {
        $recoveryTest.Existing = @{ properties = @{ provisioningState = 'Succeeded'; parameters = $retryParameters } }
        Mock Invoke-LocalBoxAutomationAz {
            @{ name = 'localcluster-validate'; properties = @{ provisioningState = 'Failed'; correlationId = $newId } }
        } -ParameterFilter { $Arguments[0] -eq 'deployment' -and $Arguments[1] -eq 'group' }
        { Wait-LocalBoxNestedDeployment -SubscriptionId $testSubscription -ResourceGroupName $testGroup } | Should -Throw '*No further automatic*'
        $recoveryTest.Submitted | Should -Be 0
    }
    It 'ignores stale execution success and rejects foreign recovery metadata' {
        $command = @{ properties = @{ provisioningState = 'Succeeded'; parameters = $retryParameters
            instanceView = @{ executionState = 'Succeeded'; exitCode = 0; startTime = [datetime]::UtcNow.AddHours(-1).ToString('o') } } }
        (Get-LocalBoxValidationRetryState $command $testSubscription $testGroup).Ready | Should -BeFalse
        { Get-LocalBoxValidationRetryState $command $testSubscription 'another-group' } | Should -Throw '*Unrecognized*'
    }
    It 'rejects nonzero and missing recovery exit codes even when execution says Succeeded' {
        foreach ($code in @(1, $null)) {
            $command = @{ properties = @{ provisioningState = 'Succeeded'; parameters = $retryParameters
                instanceView = @{ executionState = 'Succeeded'; exitCode = $code; startTime = [datetime]::UtcNow.ToString('o') } } }
            { Get-LocalBoxValidationRetryState $command $testSubscription $testGroup } | Should -Throw '*did not exit successfully*'
        }
    }
}

Describe 'Validation recovery on LocalBox-Client' {
    BeforeEach {
        $guestRetryTest = @{ Creates = [Collections.Generic.List[object]]::new(); OriginalState = 'Failed'; OriginalId = $originalId
            ValidationState = 'Succeeded'; DeploymentExists = $false; FailValidation = $false; Profile = $null }
        $templateDir = Join-Path $TestDrive 'localbox'
        New-Item -ItemType Directory -Path $templateDir -Force | Out-Null
        $fixtureParameters = @{
            clusterName = @{ value = 'localboxcluster' }; keyVaultName = @{ value = 'localbox-kv-test' }
            diagnosticStorageAccountName = @{ value = 'localboxdiagtest' }
            arcNodeResourceIds = @{ value = @("/subscriptions/$testSubscription/resourceGroups/$testGroup/providers/Microsoft.HybridCompute/machines/node1") }
        }
        @{ parameters = $fixtureParameters } | ConvertTo-Json -Depth 10 | Set-Content "$templateDir/azlocal.parameters.json"
        @{ parameters = @{ deploymentMode = @{ allowedValues = @('Validate', 'Deploy') } } } |
            ConvertTo-Json -Depth 10 | Set-Content "$templateDir/azlocal.json"
        Mock Start-Sleep {}
        Mock Invoke-LocalBoxValidationRetryAz {
            $guestRetryTest.Profile = $env:AZURE_CONFIG_DIR
            switch ($Arguments[2]) {
                'show' {
                    if ($guestRetryTest.Creates.Count) {
                        @{ properties = @{ provisioningState = 'Succeeded'; correlationId = $newId } }
                    }
                    else {
                        @{ properties = @{ provisioningState = $guestRetryTest.OriginalState; correlationId = $guestRetryTest.OriginalId; parameters = $fixtureParameters } }
                    }
                }
                'list' {
                    if ($guestRetryTest.DeploymentExists) { @{ name = 'localcluster-deploy' } }
                }
                'create' {
                    $guestRetryTest.Creates.Add(@($Arguments))
                    if ($Arguments -contains 'deploymentMode=Validate') {
                        if ($guestRetryTest.FailValidation) { throw 'Validation failed again' }
                        @{ properties = @{ provisioningState = $guestRetryTest.ValidationState; correlationId = $newId } }
                    }
                }
                default {
                    if ($Arguments[0] -ne 'login') { throw 'Unexpected guest CLI call.' }
                }
            }
        }
        $guestArguments = @{ SubscriptionId = $testSubscription; ResourceGroupName = $testGroup
            OriginalValidationCorrelationId = $originalId; TemplateDirectory = $templateDir }
    }
    It 'waits, validates exactly once, then submits deploy without changing local credentials or files' {
        $before = (Get-FileHash "$templateDir/azlocal.parameters.json").Hash
        $previousProfile = $env:AZURE_CONFIG_DIR
        Invoke-LocalBoxValidationRetry @guestArguments
        Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 120 }
        $guestRetryTest.Creates.Count | Should -Be 2
        $guestRetryTest.Creates[0] | Should -Contain 'deploymentMode=Validate'
        $guestRetryTest.Creates[0] | Should -Not -Contain '--no-wait'
        $guestRetryTest.Creates[1] | Should -Contain 'deploymentMode=Deploy'
        $guestRetryTest.Creates[1] | Should -Contain '--no-wait'
        (Get-FileHash "$templateDir/azlocal.parameters.json").Hash | Should -Be $before
        $env:AZURE_CONFIG_DIR | Should -Be $previousProfile
        Test-Path $guestRetryTest.Profile | Should -BeFalse
    }
    It 'never deploys if retry fails or returns a nonsuccess status' {
        $guestRetryTest.FailValidation = $true
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*Validation failed again*'
        $guestRetryTest.Creates.Count | Should -Be 1
        Test-Path $guestRetryTest.Profile | Should -BeFalse
        $guestRetryTest.Creates.Clear()
        $guestRetryTest.FailValidation = $false
        $guestRetryTest.ValidationState = 'Failed'
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*did not return a new successful validation*'
        $guestRetryTest.Creates.Count | Should -Be 1
    }
    It 'rejects changed correlation, changed state, and an existing deployment' {
        $guestRetryTest.OriginalId = $newId
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*Validation changed*'
        $guestRetryTest.OriginalId = $originalId
        $guestRetryTest.OriginalState = 'Running'
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*Validation changed*'
        $guestRetryTest.OriginalState = 'Failed'
        $guestRetryTest.DeploymentExists = $true
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*already exists*'
        $guestRetryTest.Creates.Count | Should -Be 0
    }
    It 'rejects parameters from a different generated environment' {
        $fixtureParameters.clusterName.value = 'different-cluster'
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*does not match*'
        $guestRetryTest.Creates.Count | Should -Be 0
    }
    It 'does not deploy when another operation changes validation after the retry' {
        Mock Invoke-LocalBoxValidationRetryAz {
            @{ properties = @{ provisioningState = 'Running'; correlationId = $originalId } }
        } -ParameterFilter { $Arguments[2] -eq 'show' -and $guestRetryTest.Creates.Count -gt 0 }
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*Validation changed before cluster deployment*'
        $guestRetryTest.Creates.Count | Should -Be 1
    }
    It 'does not submit a duplicate cluster deployment after successful validation' {
        Mock Invoke-LocalBoxValidationRetryAz { @{ name = 'localcluster-deploy' } } -ParameterFilter {
            $Arguments[2] -eq 'list' -and $guestRetryTest.Creates.Count -gt 0
        }
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*appeared during validation*'
        $guestRetryTest.Creates.Count | Should -Be 1
    }
    It 'fails explicitly on missing local deployment files' {
        Remove-Item "$templateDir/azlocal.parameters.json"
        { Invoke-LocalBoxValidationRetry @guestArguments } | Should -Throw '*file is missing*'
        Should -Invoke Invoke-LocalBoxValidationRetryAz -Times 0
    }
}

Describe 'Recovery CLI failure handling' {
    It 'withholds credential-bearing native output on failure' {
        Mock az { $global:LASTEXITCODE = 1; 'sensitive-fixture-value' }
        $failure = { Invoke-LocalBoxValidationRetryAz @('deployment', 'group', 'create') } | Should -Throw '*CLI*failed*' -PassThru
        $failure.Exception.Message | Should -Not -Match 'sensitive-fixture-value'
    }
}
