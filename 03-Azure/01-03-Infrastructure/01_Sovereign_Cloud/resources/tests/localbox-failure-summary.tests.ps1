BeforeAll {
    . "$PSScriptRoot/../../labautomation/localbox-automation.ps1"
    $scopeArguments = @{
        RunId = '682105d5-dfa6-4cba-a646-74ee20fe7121'; PackageHash = 'fixture-package'
        GroupId = '10000000-0000-0000-0000-000000000001'
        SubscriptionId = '20000000-0000-0000-0000-000000000001'; ResourceGroupName = 'rg-localbox-test'
    }
}

Describe 'Actionable failure summaries' {
    BeforeEach {
        $directory = Join-Path $TestDrive 'reports'
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $status = @{
            RunId = $scopeArguments.RunId; PackageHash = $scopeArguments.PackageHash
            AksAdminGroupObjectId = $scopeArguments.GroupId; SubscriptionId = $scopeArguments.SubscriptionId
            ResourceGroupName = $scopeArguments.ResourceGroupName; State = 'Failed'; Phase = 'Pester'
            Error = 'Sovereign Cloud Full health tests failed.'
        }
        $status | ConvertTo-Json | Set-Content "$directory/status.json"
        $passing = '<test-case name="healthy" executed="True" result="Success" />'
        "<test-results><test-suite><results>$($passing * 12)</results></test-suite></test-results>" | Set-Content "$directory/upstream.xml"
        $failure = '<test-case name="has an in-cluster MetalLB address pool and L2 advertisement" executed="True" result="Failure"><failure><message><![CDATA[kubectl failed: Error from server (NotFound): ipaddresspools.metallb.io "aks-pool" not found]]></message><stack-trace>private-stack-not-for-console</stack-trace></failure></test-case>'
        "<test-results><test-suite><results>$($passing * 13)$failure</results></test-suite></test-results>" | Set-Content "$directory/health.xml"
        Mock Write-Host {}
        Mock Write-Warning {}
    }
    It 'reports the exact failing phase, both suite counts, failed test and underlying Kubernetes error' {
        Write-LocalBoxAutomationFailureReport -Directory $directory @scopeArguments
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Last guest phase: Pester; reported state: Failed*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Upstream tests: 12 passed, 0 failed*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Sovereign tests: 13 passed, 1 failed*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*FAILED TEST*MetalLB address pool*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Reason:*aks-pool*not found*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Suggested check:*Azure-managed MetalLB*' }
        Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -match 'private-stack-not-for-console|Infrastructure health: PASSED' }
    }
    It 'rejects a mismatched <Field> before displaying test counts' -TestCases @(
        @{ Field = 'RunId' }, @{ Field = 'PackageHash' }, @{ Field = 'AksAdminGroupObjectId' },
        @{ Field = 'SubscriptionId' }, @{ Field = 'ResourceGroupName' }
    ) {
        param($Field)
        $status[$Field] = 'different'
        $status | ConvertTo-Json | Set-Content "$directory/status.json"
        Write-LocalBoxAutomationFailureReport -Directory $directory @scopeArguments
        Should -Invoke Write-Host -Times 0
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*unavailable or unverified*' }
    }
    It 'keeps phase and upstream evidence when Sovereign tests never produced a report' {
        Remove-Item "$directory/health.xml"
        Write-LocalBoxAutomationFailureReport -Directory $directory @scopeArguments
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Upstream tests: 12 passed*' }
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*Sovereign*NOT VERIFIED*' }
        Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like '*Sovereign tests:*' }
    }
    It 'displays no report-derived evidence for <Kind> status' -TestCases @(
        @{ Kind = 'missing' }, @{ Kind = 'malformed' }
    ) {
        param($Kind)
        if ($Kind -eq 'missing') { Remove-Item "$directory/status.json" }
        else { '{broken' | Set-Content "$directory/status.json" }
        Write-LocalBoxAutomationFailureReport -Directory $directory @scopeArguments
        Should -Invoke Write-Host -Times 0
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*unavailable or unverified*' }
    }
    It 'rejects malformed, empty, wrong-root and entity-bearing XML' {
        foreach ($xml in @(
            '<broken', '<test-results />', '<not-pester />',
            '<test-results><test-case name="bad" result="Unknown" /></test-results>',
            '<!DOCTYPE test-results [<!ENTITY bad SYSTEM "file:///etc/passwd">]><test-results>&bad;</test-results>'
        )) {
            $xml | Set-Content "$directory/health.xml"
            { Get-LocalBoxAutomationFailureSuite "$directory/health.xml" } | Should -Throw
        }
    }
    It 'does not count an unexecuted success as passed' {
        '<test-results><test-case name="bad" executed="False" result="Success" /></test-results>' | Set-Content "$directory/health.xml"
        { Get-LocalBoxAutomationFailureSuite "$directory/health.xml" } | Should -Throw '*unexecuted*'
    }
    It 'counts ignored and inconclusive cases without treating them as successful' {
        '<test-results><test-case name="ignored" result="Ignored" executed="False" /><test-case name="inconclusive" result="Inconclusive" executed="True" /></test-results>' |
            Set-Content "$directory/health.xml"
        $report = Get-LocalBoxAutomationFailureSuite "$directory/health.xml"
        $report.Counts.Passed | Should -Be 0
        $report.Counts.Skipped | Should -Be 1
        $report.Counts.NotRun | Should -Be 1
    }
    It 'bounds failed-test details without losing the total failure count' {
        "<test-results>$($failure * 12)</test-results>" | Set-Content "$directory/health.xml"
        Write-LocalBoxAutomationFailureReport -Directory $directory @scopeArguments
        Should -Invoke Write-Host -Times 10 -Exactly -ParameterFilter { $Object -like '*FAILED TEST (*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Sovereign tests: 0 passed, 12 failed*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*2 additional failed tests*' }
    }
    It 'retains a correlated execution error when all report downloads are denied' {
        Mock Invoke-LocalBoxAutomationAz { throw 'Permission denied' }
        Write-LocalBoxAutomationFailureDiagnostics -Directory $directory -StorageAccountName fixture -Container fixture `
            -InstanceView @{ executionState = 'Failed'; exitCode = 1; error = 'Health runner failed.' } @scopeArguments
        Should -Invoke Invoke-LocalBoxAutomationAz -Times 3 -Exactly -ParameterFilter {
            $Arguments -contains '--no-progress' -and $Arguments -contains '--auth-mode' -and $NoOutput
        }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*execution: Failed; exit code: 1*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like '*Execution error: Health runner failed*' }
        Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like '*tests:*' }
        Test-Path "$directory/status.json" | Should -BeFalse
    }
}

Describe 'Console diagnostic redaction' {
    It 'redacts common credentials and URL credentials before truncating' {
        $text = @'
password="private spaced password" --admin-password 'private cli password'
{"access_token":"private-token"} AccountKey=private-key; Bearer private-bearer
https://user:private-userinfo@example.test/path?sig=private-signature&other=value
eyJheader.eyJpayload.privatesignature
-----BEGIN PRIVATE KEY-----
private-key-material
-----END PRIVATE KEY-----
'@
        $rendered = ConvertTo-LocalBoxDiagnosticText $text 4000
        $rendered | Should -Not -Match 'private-|private spaced|private cli|privatesignature'
        $rendered | Should -Match 'REDACTED'
    }
    It 'strips terminal control characters and bounds long errors' {
        $text = "$([char]27)[31mError$([char]27)[0m`n" + ('x' * 1000)
        $rendered = ConvertTo-LocalBoxDiagnosticText $text 80
        $rendered | Should -Not -Match '[\x00-\x1f]'
        $rendered | Should -Match '^Error '
        $rendered | Should -Match '\[truncated; see private report\]$'
        $rendered.Length | Should -Be 80
    }
}
