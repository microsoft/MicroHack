BeforeAll {
    $resourceRoot = (Resolve-Path "$PSScriptRoot/..").Path
    . "$resourceRoot/../labautomation/localbox-automation.ps1"
    . "$resourceRoot/invoke-localbox-automation.ps1"
    function Update-MhhToken {}
    function az {}
    function Invoke-AzRestMethod { param($Path, $Method, $Payload) }
    function Get-AzAccessToken { param($ResourceUrl) }
    function Get-AzRoleAssignment { param($ObjectId, $RoleDefinitionName, $Scope) }
    function New-AzRoleAssignment { param($ObjectId, $RoleDefinitionName, $Scope) }
    $subscription = '10000000-0000-0000-0000-000000000001'
    $group = '20000000-0000-0000-0000-000000000001'
    $identity = '30000000-0000-0000-0000-000000000001'
    $scope = "/subscriptions/$subscription/resourceGroups/rg-localbox-shared"
    $vmId = "$scope/providers/Microsoft.Compute/virtualMachines/LocalBox-Client"
    $storageId = "$scope/providers/Microsoft.Storage/storageAccounts/localbox123"
    $suite = @{ Passed = 1; Failed = 0; Skipped = 0; NotRun = 0 }
    $xml = '<test-results name="Pester"><test-suite><results><test-case name="ready" executed="True" result="Success" /></results></test-suite></test-results>'
}

Describe 'Token-aware LocalBox polling' {
    BeforeEach { Mock Update-MhhToken {}; Mock Start-Sleep {} }
    It 'refreshes credentials on every poll, including completion' {
        $counter = @{ Value = 0 }
        Wait-LocalBoxAutomation -Phase test -TimeoutSeconds 60 -Probe {
            $counter.Value++
            @{ Ready = $counter.Value -eq 3; Detail = 'waiting' }
        } | Out-Null
        Should -Invoke Update-MhhToken -Times 3 -Exactly
        Should -Invoke Start-Sleep -Times 2 -Exactly
    }
    It 'fails instead of returning success on timeout' {
        { Wait-LocalBoxAutomation -Phase test -TimeoutSeconds 0 -Probe { @{ Ready = $false } } } | Should -Throw '*Timed out*'
    }
    It 'does not continue with failed token refresh' {
        Mock Update-MhhToken { throw 'Token refresh failed' }
        { Wait-LocalBoxAutomation -Phase test -TimeoutSeconds 60 -Probe { throw 'Should not run' } } | Should -Throw '*Token refresh failed*'
        Should -Invoke Start-Sleep -Times 0
    }
    It 'propagates CLI errors and malformed JSON' {
        Mock az { $global:LASTEXITCODE = 1; 'AuthorizationFailed' }
        { Invoke-LocalBoxAutomationAz @('resource', 'list') } | Should -Throw '*AuthorizationFailed*'
        Mock az { $global:LASTEXITCODE = 0; 'not JSON' }
        { Invoke-LocalBoxAutomationAz @('resource', 'list') } | Should -Throw
    }
    It 'treats only an allowed 404 as absence' {
        Mock Invoke-AzRestMethod { @{ StatusCode = 404; Content = '' } }
        Invoke-LocalBoxAutomationRequest -Path '/test' -AllowNotFound | Should -BeNullOrEmpty
        { Invoke-LocalBoxAutomationRequest -Path '/test' } | Should -Throw '*404*'
        Mock Invoke-AzRestMethod { @{ StatusCode = 403; Content = 'Denied' } }
        { Invoke-LocalBoxAutomationRequest -Path '/test' -AllowNotFound } | Should -Throw '*403*'
    }
}

Describe 'Nested deployment gate' {
    BeforeEach {
        Mock Update-MhhToken {}
        Mock Start-Sleep {}
        Mock Invoke-LocalBoxAutomationAz {
            switch ($Arguments[0]) {
                'deployment' { @{ name = 'localcluster-deploy'; properties = @{ provisioningState = 'Succeeded' } } }
                'resource' {
                    if ($Arguments[1] -eq 'list') {
                        foreach ($type in @('Microsoft.AzureStackHCI/clusters', 'Microsoft.ResourceConnector/appliances', 'Microsoft.ExtendedLocation/customLocations')) {
                            @{ type = $type; id = "/$type/test" }
                        }
                    }
                    else {
                        @{ properties = @{ provisioningState = 'Succeeded'; connectivityStatus = 'Connected'; status = 'Running'
                            clusterExtensionIds = @('/test/hybridaksextension') } }
                    }
                }
            }
        }
    }
    It 'requires cluster deployment, connectivity, bridge, custom location and extension' {
        Wait-LocalBoxNestedDeployment -SubscriptionId $subscription -ResourceGroupName rg-localbox-shared -TimeoutSeconds 1
        Should -Invoke Invoke-LocalBoxAutomationAz -Times 6 -Exactly
    }
    It 'rejects a failed nested deployment rather than continuing preparation' {
        Mock Invoke-LocalBoxAutomationAz { @{ name = 'localcluster-deploy'; properties = @{ provisioningState = 'Failed' } } } -ParameterFilter { $Arguments[0] -eq 'deployment' }
        { Wait-LocalBoxNestedDeployment -SubscriptionId $subscription -ResourceGroupName rg-localbox-shared -TimeoutSeconds 0 } | Should -Throw '*Nested deployment*failed*'
    }
    It 'does not equate ARM success with cluster connectivity' {
        Mock Invoke-LocalBoxAutomationAz { @{ properties = @{ provisioningState = 'Succeeded'; connectivityStatus = 'Disconnected' } } } -ParameterFilter {
            $Arguments[1] -eq 'show' -and $Arguments[3] -match 'AzureStackHCI'
        }
        { Wait-LocalBoxNestedDeployment -SubscriptionId $subscription -ResourceGroupName rg-localbox-shared -TimeoutSeconds 0 } | Should -Throw '*connectivity*'
    }
    It 'stops on failed hybrid extension' {
        Mock Invoke-LocalBoxAutomationAz { @{ properties = @{ provisioningState = 'Failed' } } } -ParameterFilter {
            $Arguments[1] -eq 'show' -and $Arguments[3] -match 'hybridaksextension'
        }
        { Wait-LocalBoxNestedDeployment -SubscriptionId $subscription -ResourceGroupName rg-localbox-shared -TimeoutSeconds 0 } | Should -Throw '*hybridaksextension*failed*'
    }
}

Describe 'Imported-content package and PS7 bootstrap' {
    BeforeEach { Mock Invoke-WebRequest { throw 'Unexpected download for a complete local checkout.' } }
    It 'packages local content without fetching a moving GitHub branch' {
        $one = New-Item -ItemType Directory -Path "$TestDrive/one"
        $two = New-Item -ItemType Directory -Path "$TestDrive/two"
        $first = New-LocalBoxAutomationPackage $resourceRoot $one.FullName
        $second = New-LocalBoxAutomationPackage $resourceRoot $two.FullName
        $first.Hash | Should -Be $second.Hash
        $first.Hash | Should -Match '^[a-f0-9]{64}$'
        Expand-Archive "$TestDrive/one/package.zip" "$TestDrive/extracted"
        Test-Path "$TestDrive/extracted/tests/localbox.health.tests.ps1" | Should -BeTrue
        (Get-FileHash "$TestDrive/extracted/prepare-localbox.ps1").Hash | Should -Be (Get-FileHash "$resourceRoot/prepare-localbox.ps1").Hash
        $command = New-LocalBoxGuestCommand -Configuration @{ RunId = [guid]::NewGuid().ToString(); AksAdminGroupObjectId = $group } -Archive $first.Archive
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseInput($command, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
        $command | Should -Match 'PowerShell\\7\\pwsh.exe'
        $command | Should -Match 'exit \$LASTEXITCODE'
        $command | Should -Not -Match 'raw.githubusercontent|__CONFIG__|__ARCHIVE__'
        [Text.Encoding]::UTF8.GetByteCount($command) | Should -BeLessThan 262144
    }
    It 'changes the package identity when a source file changes' {
        Copy-Item -Path "$resourceRoot/prepare-localbox.ps1", "$resourceRoot/invoke-localbox-automation.ps1", "$resourceRoot/test-sovereign-cloud.ps1" -Destination $TestDrive
        New-Item -ItemType Directory "$TestDrive/tests" | Out-Null
        Copy-Item "$resourceRoot/tests/*.health.tests.ps1" "$TestDrive/tests"
        New-Item -ItemType Directory "$TestDrive/before", "$TestDrive/after" | Out-Null
        $before = New-LocalBoxAutomationPackage $TestDrive "$TestDrive/before"
        Add-Content "$TestDrive/prepare-localbox.ps1" '# changed content'
        $after = New-LocalBoxAutomationPackage $TestDrive "$TestDrive/after"
        $before.Hash | Should -Not -Be $after.Hash
    }
}

Describe 'Console mount without guest resources' {
    BeforeEach {
        $originalGuestRoot = $resourceRoot
        $mount = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory "$mount/labautomation" | Out-Null
        foreach ($file in @('localbox-automation.ps1', 'localbox-automation-source.json')) {
            Copy-Item "$resourceRoot/../labautomation/$file" "$mount/labautomation"
        }
        $sourceManifestPath = "$mount/labautomation/localbox-automation-source.json"
        $pin = Get-Content $sourceManifestPath -Raw | ConvertFrom-Json -AsHashtable
        Mock Invoke-WebRequest {
            $prefix = "https://raw.githubusercontent.com/$($pin.repository)/$($pin.commit)/03-Azure/01-03-Infrastructure/01_Sovereign_Cloud/resources/"
            $url = $Uri.AbsoluteUri
            $url.StartsWith($prefix) | Should -BeTrue
            Copy-Item -LiteralPath (Join-Path $originalGuestRoot $url.Substring($prefix.Length)) -Destination $OutFile
        }
    }
    It 'keeps the pin synchronized with the guest sources in this checkout' {
        $pin.commit | Should -Match '^[a-f0-9]{40}$'
        $pin.files.Count | Should -Be 5
        foreach ($file in $pin.files.Keys) {
            (Get-FileHash -LiteralPath (Join-Path $resourceRoot $file) -Algorithm SHA256).Hash |
                Should -Be $pin.files[$file]
        }
    }
    It 'packages the actual labautomation-only layout using default paths' {
        . "$mount/labautomation/localbox-automation.ps1"
        $package = New-LocalBoxAutomationPackage
        $local = New-LocalBoxAutomationPackage -ResourceRoot $resourceRoot
        $package.Hash | Should -Be $local.Hash
        Test-Path "$mount/resources" | Should -BeFalse
        Should -Invoke Invoke-WebRequest -Times 5 -Exactly
    }
    It 'uses the whole pinned set rather than mixing partial local files with downloads' {
        New-Item -ItemType Directory "$mount/resources" | Out-Null
        Set-Content "$mount/resources/prepare-localbox.ps1" 'incomplete checkout - must not be used'
        $package = New-LocalBoxAutomationPackage -ResourceRoot "$mount/resources" -SourceManifestPath $sourceManifestPath
        $local = New-LocalBoxAutomationPackage -ResourceRoot $resourceRoot
        $package.Hash | Should -Be $local.Hash
        Should -Invoke Invoke-WebRequest -Times 5 -Exactly
    }
    It 'rejects mutable refs or incomplete checksums before downloading' -TestCases @(
        @{ Invalid = 'branch' }; @{ Invalid = 'checksum' }; @{ Invalid = 'extra-file' }
    ) {
        param($Invalid)
        switch ($Invalid) {
            'branch' { $pin.commit = 'main' }
            'checksum' { $pin.files['prepare-localbox.ps1'] = 'bad' }
            'extra-file' { $pin.files['unwanted.ps1'] = '0' * 64 }
        }
        $pin | ConvertTo-Json -Depth 5 | Set-Content $sourceManifestPath
        { New-LocalBoxAutomationPackage -ResourceRoot "$mount/resources" -SourceManifestPath $sourceManifestPath } | Should -Throw
        Should -Invoke Invoke-WebRequest -Times 0
    }
    It 'rejects downloaded content that does not match the pinned SHA256' {
        Mock Invoke-WebRequest { Set-Content -LiteralPath $OutFile 'incorrect content' }
        { New-LocalBoxAutomationPackage -ResourceRoot "$mount/resources" -SourceManifestPath $sourceManifestPath } |
            Should -Throw '*SHA256 mismatch*'
    }
    It 'propagates download failures without a success-shaped package' {
        Mock Invoke-WebRequest { throw 'Source download failed: HTTP 404' }
        { New-LocalBoxAutomationPackage -ResourceRoot "$mount/resources" -SourceManifestPath $sourceManifestPath } |
            Should -Throw '*HTTP 404*'
    }
}

Describe 'Guest readiness result contract' {
    BeforeEach {
        $result = @{
            RunId = 'run'; PackageHash = 'hash'; SubscriptionId = $subscription; ResourceGroupName = 'rg-localbox-shared'
            AksAdminGroupObjectId = $group; State = 'Succeeded'; Upstream = $suite.Clone(); Sovereign = $suite.Clone()
            UpdateAssessment = @{ Status = 'Succeeded'; Timestamp = '2026-11-02T00:00:00Z' }
        }
    }
    It 'accepts the exact run and both successful test suites' {
        Assert-LocalBoxAutomationResult $result run hash $group $subscription rg-localbox-shared
    }
    It 'rejects incorrect <Field>' -TestCases @(
        @{ Field = 'RunId' }; @{ Field = 'PackageHash' }; @{ Field = 'SubscriptionId' }; @{ Field = 'ResourceGroupName' }
        @{ Field = 'AksAdminGroupObjectId' }; @{ Field = 'State' }
    ) {
        param($Field)
        $result[$Field] = 'wrong'
        { Assert-LocalBoxAutomationResult $result run hash $group $subscription rg-localbox-shared } | Should -Throw '*stale*'
    }
    It 'rejects failed, skipped, absent or empty suites' -TestCases @(
        @{ Field = 'Passed'; Value = 0 }; @{ Field = 'Failed'; Value = 1 }; @{ Field = 'Skipped'; Value = 1 }
        @{ Field = 'NotRun'; Value = 1 }; @{ Field = 'Failed'; Value = $null }
    ) {
        param($Field, $Value)
        $result.Sovereign[$Field] = $Value
        { Assert-LocalBoxAutomationResult $result run hash $group $subscription rg-localbox-shared } | Should -Throw '*tests*'
    }
    It 'requires a successful update assessment with a timestamp' {
        $result.UpdateAssessment.Timestamp = $null
        { Assert-LocalBoxAutomationResult $result run hash $group $subscription rg-localbox-shared } | Should -Throw '*assessment*'
    }
    It 'validates XML test cases rather than trusting a success-shaped summary' {
        Set-Content "$TestDrive/good.xml" $xml
        Assert-LocalBoxAutomationXml "$TestDrive/good.xml" $suite
        Set-Content "$TestDrive/bad.xml" ($xml.Replace('Success', 'Failure'))
        { Assert-LocalBoxAutomationXml "$TestDrive/bad.xml" $suite } | Should -Throw '*XML*'
        Set-Content "$TestDrive/empty.xml" '<test-results />'
        { Assert-LocalBoxAutomationXml "$TestDrive/empty.xml" $suite } | Should -Throw '*XML*'
    }
    It 'rejects skipped upstream tests and returns real Pester counts' {
        $pester = @{ TotalCount = 1; PassedCount = 1; FailedCount = 0; SkippedCount = 0; NotRunCount = 0 }
        (Assert-LocalBoxAutomationTests $pester).Passed | Should -Be 1
        $pester.SkippedCount = 1
        { Assert-LocalBoxAutomationTests $pester } | Should -Throw '*skipped*'
    }
}

Describe 'Hosted LocalBox automation lifecycle' {
    BeforeEach {
        $tracking = @{ Body = $null; Polls = 0; Existing = $null; ExitCode = 0; ExecutionState = 'Succeeded' }
        Mock Update-MhhToken {}
        Mock Start-Sleep {}
        Mock Wait-LocalBoxNestedDeployment {}
        Mock New-LocalBoxAutomationPackage { @{ Hash = 'package'; Archive = 'UEs=' } }
        Mock New-LocalBoxGuestCommand { 'guest code' }
        Mock Get-AzAccessToken {
            @{ Token = ('head.' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("{`"oid`":`"$identity`"}")).TrimEnd('=') + '.signature') }
        }
        Mock Get-AzRoleAssignment { @{ RoleDefinitionName = 'Storage Blob Data Contributor' } }
        Mock New-AzRoleAssignment {}
        Mock Invoke-LocalBoxAutomationRequest {
            if ($Path -like '*runCommands*') {
                if ($Method -eq 'PUT') { $tracking.Body = $Body; return @{} }
                if (-not $tracking.Body) { return $tracking.Existing }
                $tracking.Polls++
                return @{ properties = @{
                    provisioningState = 'Succeeded'; parameters = $tracking.Body.properties.parameters
                    instanceView = @{ executionState = $tracking.ExecutionState; exitCode = $tracking.ExitCode; startTime = [datetime]::UtcNow.ToString('o') }
                } }
            }
            if ($Path -like '*containers*') { return @{} }
            @{ location = 'spaincentral'; identity = @{ principalId = $identity } }
        }
        Mock Invoke-LocalBoxAutomationAz {
            if ($Arguments[0..2] -join ' ' -eq 'storage account list') {
                return @{ name = 'localbox123'; id = $storageId; primaryEndpoints = @{ blob = 'https://localbox123.blob.core.windows.net/' } }
            }
            if ($Arguments[0..2] -join ' ' -eq 'storage blob download') {
                $file = $Arguments[[array]::IndexOf($Arguments, '--file') + 1]
                if ($file.EndsWith('.xml')) { Set-Content $file $xml }
                else {
                    $id = ($tracking.Body.properties.parameters | Where-Object name -eq RunId).value
                    @{
                        RunId = $id; PackageHash = 'package'; AksAdminGroupObjectId = $group; SubscriptionId = $subscription
                        ResourceGroupName = 'rg-localbox-shared'; State = 'Succeeded'; Upstream = $suite; Sovereign = $suite
                        UpdateAssessment = @{ Status = 'Succeeded'; Timestamp = [datetime]::UtcNow.ToString('o') }
                    } | ConvertTo-Json -Depth 8 | Set-Content $file
                }
                return @{}
            }
            throw "Unexpected CLI request: $Arguments"
        }
    }
    It 'submits an asynchronous bounded guest command and verifies both XML suites' {
        $result = Invoke-LocalBoxHostedAutomation $subscription rg-localbox-shared $group
        $tracking.Body.properties.asyncExecution | Should -BeTrue
        $tracking.Body.properties.timeoutInSeconds | Should -Be 43200
        ($tracking.Body.properties.parameters | Where-Object name -eq GroupId).value | Should -Be $group
        $result.ResultsUri | Should -Match 'https://localbox123.blob.core.windows.net/microhack-automation/'
        Should -Invoke Wait-LocalBoxNestedDeployment -Times 1
        Should -Invoke New-AzRoleAssignment -Times 0
        Should -Invoke Invoke-LocalBoxAutomationAz -Times 4 -ParameterFilter { $Arguments[2] -eq 'download' }
    }
    It 'uses the already validated preflight package without downloading it again' {
        Invoke-LocalBoxHostedAutomation $subscription rg-localbox-shared $group -Package @{ Hash = 'package'; Archive = 'UEs=' } | Out-Null
        Should -Invoke New-LocalBoxAutomationPackage -Times 0
        Should -Invoke New-LocalBoxGuestCommand -Times 1 -ParameterFilter { $Archive -eq 'UEs=' }
    }
    It 'fails on nonzero, absent or failed guest execution results' -TestCases @(
        @{ Code = 1; State = 'Succeeded' }; @{ Code = $null; State = 'Succeeded' }; @{ Code = 0; State = 'Failed' }
    ) {
        param($Code, $State)
        $tracking.ExitCode = $Code
        $tracking.ExecutionState = $State
        { Invoke-LocalBoxHostedAutomation $subscription rg-localbox-shared $group } | Should -Throw '*LocalBox guest*'
        Should -Invoke Invoke-LocalBoxAutomationAz -Times 0 -ParameterFilter { $Arguments[2] -eq 'download' }
    }
    It 'does not overwrite an active command from another revision or group' {
        $tracking.Existing = @{ properties = @{ instanceView = @{ executionState = 'Running' }; parameters = @(@{ name = 'PackageHash'; value = 'old' }) } }
        { Invoke-LocalBoxHostedAutomation $subscription rg-localbox-shared $group } | Should -Throw '*different content or group*'
        Should -Invoke Invoke-LocalBoxAutomationRequest -Times 0 -ParameterFilter { $Method -eq 'PUT' }
    }
    It 'resumes an existing matching execution without restarting guest work' {
        $id = [guid]::NewGuid().ToString()
        $tracking.Existing = @{ properties = @{ provisioningState = 'Succeeded'; instanceView = @{ executionState = 'Running' }
            parameters = @(
                @{ name = 'RunId'; value = $id }; @{ name = 'PackageHash'; value = 'package' }
                @{ name = 'GroupId'; value = $group }; @{ name = 'StartedAfter'; value = '2026-01-01T00:00:00Z' }
            )
        } }
        Mock Invoke-LocalBoxAutomationRequest {
            if (-not $tracking.Body) {
                $tracking.Body = $tracking.Existing
                return $tracking.Existing
            }
            @{ properties = @{
                provisioningState = 'Succeeded'; parameters = $tracking.Body.properties.parameters
                instanceView = @{ executionState = 'Succeeded'; exitCode = 0; startTime = [datetime]::UtcNow.ToString('o') }
            } }
        } -ParameterFilter { $Path -like '*runCommands*' -and $Method -ne 'PUT' }
        (Invoke-LocalBoxHostedAutomation $subscription rg-localbox-shared $group).RunId | Should -Be $id
        Should -Invoke Wait-LocalBoxNestedDeployment -Times 0
        Should -Invoke Invoke-LocalBoxAutomationRequest -Times 0 -ParameterFilter { $Method -eq 'PUT' -and $Path -like '*runCommands*' }
    }
    It 'ignores a previous execution instance view while a new command starts' {
        Mock Invoke-LocalBoxAutomationRequest {
            $tracking.Polls++
            $start = if ($tracking.Polls -eq 1) { '2020-01-01T00:00:00Z' } else { [datetime]::UtcNow.ToString('o') }
            @{ properties = @{
                provisioningState = 'Succeeded'; parameters = $tracking.Body.properties.parameters
                instanceView = @{ executionState = 'Succeeded'; exitCode = 0; startTime = $start }
            } }
        } -ParameterFilter { $Path -like '*runCommands*' -and $Method -ne 'PUT' -and $null -ne $tracking.Body }
        Invoke-LocalBoxHostedAutomation $subscription rg-localbox-shared $group | Out-Null
        $tracking.Polls | Should -Be 2
        Should -Invoke Start-Sleep -Times 1
    }
}

Describe 'Unattended kubectl provisioning' {
    BeforeAll {
        function Invoke-LocalBoxAz { param($Arguments, $TimeoutSeconds, [switch]$NoOutput) }
        function Get-LocalBoxResource { param($Id) }
    }
    BeforeEach {
        $clientDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $clientRun = Join-Path $clientDirectory 'run'
        $clientPath = Join-Path $clientDirectory 'tools/kubectl-1.31.5/kubectl.exe'
        $originalPath = $env:PATH
        Mock Get-LocalBoxResource { @{ properties = @{ kubernetesVersion = '1.31.5' } } }
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'kubectl' }
        Mock Get-LocalBoxKubectlClientVersion { [version]'1.31.5' }
        Mock Invoke-LocalBoxAz {}
    }
    AfterEach { $env:PATH = $originalPath }
    It 'installs a matching client privately when SYSTEM cannot resolve kubectl' {
        Initialize-LocalBoxAutomationKubectl '/aks/instance' $clientRun | Should -Be $clientPath
        Should -Invoke Get-LocalBoxResource -Times 1 -Exactly -ParameterFilter { $Id -eq '/aks/instance' }
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly -ParameterFilter {
            $Arguments[0..1] -join ' ' -eq 'aks install-cli' -and
            $Arguments[$Arguments.IndexOf('--client-version') + 1] -eq '1.31.5' -and
            $Arguments[$Arguments.IndexOf('--install-location') + 1] -eq $clientPath -and
            $Arguments[$Arguments.IndexOf('--kubelogin-install-location') + 1] -eq (Join-Path (Split-Path $clientPath) 'kubelogin.exe') -and
            $TimeoutSeconds -eq 900 -and $NoOutput
        }
        Should -Invoke Get-LocalBoxKubectlClientVersion -Times 1 -Exactly -ParameterFilter { $Path -eq $clientPath }
        $env:PATH.Split([IO.Path]::PathSeparator)[0] | Should -Be (Split-Path $clientPath)
    }
    It 'reuses an existing same-minor client without upgrading or installing anything' {
        Mock Get-Command { @{ Path = '/existing/kubectl.exe' } } -ParameterFilter { $Name -eq 'kubectl' }
        Mock Get-LocalBoxKubectlClientVersion { [version]'1.31.4' }
        Initialize-LocalBoxAutomationKubectl '/aks/instance' $clientRun | Should -Be '/existing/kubectl.exe'
        Should -Invoke Invoke-LocalBoxAz -Times 0
        $env:PATH | Should -Be $originalPath
    }
    It 'does not overwrite an existing client from a different minor release' {
        Mock Get-Command { @{ Path = '/existing/kubectl.exe' } } -ParameterFilter { $Name -eq 'kubectl' }
        Mock Get-LocalBoxKubectlClientVersion { [version]'1.35.0' } -ParameterFilter { $Path -eq '/existing/kubectl.exe' }
        Initialize-LocalBoxAutomationKubectl '/aks/instance' $clientRun | Should -Be $clientPath
        Should -Invoke Invoke-LocalBoxAz -Times 1 -Exactly
    }
    It 'revalidates and reuses a private client on retry' {
        New-Item -ItemType Directory -Path (Split-Path $clientPath) -Force | Out-Null
        Set-Content $clientPath 'fixture'
        Initialize-LocalBoxAutomationKubectl '/aks/instance' $clientRun | Should -Be $clientPath
        Should -Invoke Invoke-LocalBoxAz -Times 0
        Should -Invoke Get-LocalBoxKubectlClientVersion -Times 1 -Exactly -ParameterFilter { $Path -eq $clientPath }
    }
    It 'never falls back to latest when the cluster version is missing or invalid' -TestCases @(
        @{ Version = $null }; @{ Version = 'latest' }; @{ Version = '../other' }
    ) {
        param($Version)
        Mock Get-LocalBoxResource { @{ properties = @{ kubernetesVersion = $Version } } }
        { Initialize-LocalBoxAutomationKubectl '/aks/instance' $clientRun } | Should -Throw '*valid Kubernetes version*'
        Should -Invoke Invoke-LocalBoxAz -Times 0
    }
    It 'propagates installation errors without adding a broken directory to PATH' {
        Mock Invoke-LocalBoxAz { throw 'Download failed' }
        { Initialize-LocalBoxAutomationKubectl '/aks/instance' $clientRun } | Should -Throw '*Download failed*'
        $env:PATH | Should -Be $originalPath
    }
    It 'rejects an incorrect installed version before running health tests' {
        Mock Get-LocalBoxKubectlClientVersion { [version]'1.35.0' }
        { Initialize-LocalBoxAutomationKubectl '/aks/instance' $clientRun } | Should -Throw '*does not match requested version*'
        $env:PATH | Should -Be $originalPath
    }
}

Describe 'kubectl client version validation' {
    BeforeAll {
        function Test-KubectlProcess {
            $global:LASTEXITCODE = $script:kubectlExit
            $script:kubectlOutput
        }
    }
    BeforeEach { $script:kubectlExit = 0; $script:kubectlOutput = '{"clientVersion":{"gitVersion":"v1.31.5"}}' }
    It 'reads the actual client version' {
        Get-LocalBoxKubectlClientVersion Test-KubectlProcess | Should -Be ([version]'1.31.5')
    }
    It 'rejects a failing executable' {
        $script:kubectlExit = 1
        { Get-LocalBoxKubectlClientVersion Test-KubectlProcess } | Should -Throw '*client version check failed*'
    }
    It 'rejects malformed or missing version output' -TestCases @(
        @{ Output = 'not JSON' }; @{ Output = '{}' }; @{ Output = '{"clientVersion":{"gitVersion":"latest"}}' }
    ) {
        param($Output)
        $script:kubectlOutput = $Output
        { Get-LocalBoxKubectlClientVersion Test-KubectlProcess } | Should -Throw
    }
}

Describe 'Guest default preparation and health orchestration' {
    BeforeAll {
        function Invoke-LocalBoxAz { param($Arguments, $TimeoutSeconds, [switch]$NoOutput) }
        function Wait-SovereignCheck { param($TimeoutSeconds, $Check) }
        function Get-LocalBoxReferenceVmReadiness { param($MachineId) }
        function Invoke-TestPreparation { param($SubscriptionId, $ResourceGroupName, $AksAdminGroupObjectId) }
        $guestFixture = Join-Path $TestDrive 'guest'
        New-Item -ItemType Directory $guestFixture | Out-Null
        @'
[CmdletBinding(SupportsShouldProcess)]
param($SubscriptionId, $ResourceGroupName, $AksAdminGroupObjectId, $ManifestPath)
Invoke-TestPreparation -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -AksAdminGroupObjectId $AksAdminGroupObjectId
'@ | Set-Content "$guestFixture/prepare-localbox.ps1"
    }
    BeforeEach {
        $guestDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory $guestDirectory | Out-Null
        $guestConfig = @{
            RunId = [guid]::NewGuid().ToString(); PackageHash = 'content'
            SubscriptionId = $subscription; ResourceGroupName = 'rg-localbox-shared'; AksAdminGroupObjectId = $group
            StorageAccountName = 'localbox123'; Container = 'microhack-automation'
        }
        $oldSubscription = $env:subscriptionId
        $oldResourceGroup = $env:resourceGroup
        $oldProfile = $env:AZURE_CONFIG_DIR
        $env:subscriptionId = $subscription
        $env:resourceGroup = 'rg-localbox-shared'
        $env:AZURE_CONFIG_DIR = 'caller-profile'
        Mock Start-Transcript {}
        Mock Stop-Transcript {}
        Mock Initialize-LocalBoxAutomationEnvironment {}
        Mock Initialize-LocalBoxAutomationKubectl { 'private/kubectl.exe' }
        Mock Invoke-TestPreparation {}
        Mock Send-LocalBoxAutomationFiles {}
        Mock Write-LocalBoxAutomationStatus {}
        Mock Wait-SovereignCheck { & $Check }
        Mock Get-LocalBoxReferenceVmReadiness { @{ PowerState = 'Running'; ArcStatus = 'Connected'; MdeProvisioningState = 'Succeeded' } }
        Mock Invoke-LocalBoxAz {
            if ($Arguments[0..1] -join ' ' -eq 'extension list') { return @{ name = 'connectedmachine' } }
            if ($Arguments[0..1] -join ' ' -eq 'connectedmachine assess-patches') {
                return @{ status = 'Succeeded'; lastModifiedDateTime = '2026-11-02T01:00:00Z'; assessmentActivityId = 'assessment' }
            }
        }
        $manifestFile = Join-Path $guestDirectory 'manifest.json'
        @{ AksPreparationSkipped = $false; AksAdminGroupObjectId = $group; AksInstanceId = '/aks/instance'; ReferenceVm = @{ MachineId = 'reference' } } |
            ConvertTo-Json -Depth 6 | Set-Content $manifestFile
        Mock Test-Path { $true } -ParameterFilter { $LiteralPath -like 'C:\LocalBox\Tests\*' }
        Mock Get-Module { @{ Version = [version]'5.7.1' } } -ParameterFilter { $Name -eq 'Pester' }
        Mock Import-Module {} -ParameterFilter { $Name -eq 'Pester' }
        Mock Invoke-Pester { @{ TotalCount = 1; PassedCount = 1; FailedCount = 0; SkippedCount = 0; NotRunCount = 0 } }
        Mock Invoke-LocalBoxAutomationHealthProcess {
            @{ FullReadiness = $true; Passed = 1; Failed = 0; Skipped = 0; NotRun = 0 } | ConvertTo-Json | Set-Content "$guestDirectory/health.json"
        }
    }
    AfterEach {
        $env:subscriptionId = $oldSubscription
        $env:resourceGroup = $oldResourceGroup
        $env:AZURE_CONFIG_DIR = $oldProfile
    }
    It 'prepares defaults with the exact event group and gates on assessment and both test suites' {
        Invoke-LocalBoxGuestAutomation $guestConfig $guestDirectory $guestFixture 'input.json' -ManifestPath $manifestFile
        Should -Invoke Invoke-TestPreparation -Times 1 -Exactly -ParameterFilter {
            $AksAdminGroupObjectId -eq $group -and $SubscriptionId -eq $subscription
        }
        Should -Invoke Invoke-LocalBoxAz -Times 1 -ParameterFilter { $Arguments[0..1] -join ' ' -eq 'connectedmachine assess-patches' }
        Should -Invoke Invoke-LocalBoxAutomationHealthProcess -Times 1
        Should -Invoke Initialize-LocalBoxAutomationKubectl -Times 1 -Exactly -ParameterFilter {
            $InstanceId -eq '/aks/instance' -and $Directory -eq $guestDirectory
        }
        Should -Invoke Send-LocalBoxAutomationFiles -Times 1
        $status = Get-Content "$guestDirectory/status.json" -Raw | ConvertFrom-Json
        $status.State | Should -Be 'Succeeded'
        $status.UpdateAssessment.Status | Should -Be 'Succeeded'
        $status.DefenderCloudReporting | Should -Be 'NotVerified'
        $env:AZURE_CONFIG_DIR | Should -Be 'caller-profile'
    }
    It 'captures prerequisite failures locally even before Azure authentication' {
        Mock Initialize-LocalBoxAutomationEnvironment { throw 'Get-VM unavailable' }
        { Invoke-LocalBoxGuestAutomation $guestConfig $guestDirectory $guestFixture 'input.json' -ManifestPath $manifestFile } | Should -Throw '*Get-VM unavailable*'
        $status = Get-Content "$guestDirectory/status.json" -Raw | ConvertFrom-Json
        $status.State | Should -Be 'Failed'
        $status.Phase | Should -Be 'Prerequisites'
        $status.Error | Should -Be 'Get-VM unavailable'
        Should -Invoke Start-Transcript -Times 1
        Should -Invoke Stop-Transcript -Times 1
        Should -Invoke Send-LocalBoxAutomationFiles -Times 0
        Should -Invoke Invoke-TestPreparation -Times 0
    }
    It 'reports kubectl provisioning failures and restores the caller PATH' {
        $callerPath = $env:PATH
        Mock Initialize-LocalBoxAutomationKubectl { $env:PATH = 'broken'; throw 'kubectl install failed' }
        { Invoke-LocalBoxGuestAutomation $guestConfig $guestDirectory $guestFixture 'input.json' -ManifestPath $manifestFile } | Should -Throw '*kubectl install failed*'
        $env:PATH | Should -Be $callerPath
        $status = Get-Content "$guestDirectory/status.json" -Raw | ConvertFrom-Json
        $status.State | Should -Be 'Failed'
        $status.Phase | Should -Be 'KubernetesClient'
        Should -Invoke Send-LocalBoxAutomationFiles -Times 1
        Should -Invoke Invoke-LocalBoxAutomationHealthProcess -Times 0
    }
    It 'preserves the original error if diagnostic upload also fails' {
        Mock Invoke-TestPreparation { throw 'Preparation failed' }
        Mock Send-LocalBoxAutomationFiles { throw 'Blob upload failed' }
        { Invoke-LocalBoxGuestAutomation $guestConfig $guestDirectory $guestFixture 'input.json' -ManifestPath $manifestFile } | Should -Throw '*Preparation failed*Blob upload failed*'
    }
    It 'records and uploads preparation failure without running tests or deleting the lab' {
        Mock Invoke-TestPreparation { throw 'Storage validation failed' }
        { Invoke-LocalBoxGuestAutomation $guestConfig $guestDirectory $guestFixture 'input.json' -ManifestPath $manifestFile } | Should -Throw '*Storage validation failed*'
        $status = Get-Content "$guestDirectory/status.json" -Raw | ConvertFrom-Json
        $status.State | Should -Be 'Failed'
        $status.Phase | Should -Be 'Preparation'
        Should -Invoke Send-LocalBoxAutomationFiles -Times 1
        Should -Invoke Invoke-LocalBoxAutomationHealthProcess -Times 0
        $env:AZURE_CONFIG_DIR | Should -Be 'caller-profile'
    }
    It 'fails on unsuccessful update assessment instead of claiming readiness' {
        Mock Invoke-LocalBoxAz { @{ status = 'Failed' } } -ParameterFilter { $Arguments[0..1] -join ' ' -eq 'connectedmachine assess-patches' }
        { Invoke-LocalBoxGuestAutomation $guestConfig $guestDirectory $guestFixture 'input.json' -ManifestPath $manifestFile } | Should -Throw '*assessment*'
        Should -Invoke Invoke-LocalBoxAutomationHealthProcess -Times 0
    }
    It 'propagates Full health process failure and cleans up the private kubeconfig' {
        Set-Content "$guestDirectory/aks.kubeconfig" 'private test fixture'
        Mock Invoke-LocalBoxAutomationHealthProcess { throw 'Full health failed' }
        { Invoke-LocalBoxGuestAutomation $guestConfig $guestDirectory $guestFixture 'input.json' -ManifestPath $manifestFile } | Should -Throw '*Full health failed*'
        Test-Path "$guestDirectory/aks.kubeconfig" | Should -BeFalse
        (Get-Content "$guestDirectory/status.json" -Raw | ConvertFrom-Json).State | Should -Be 'Failed'
    }
    It 'fails explicitly if diagnostic upload is unavailable' {
        Mock Send-LocalBoxAutomationFiles { throw 'Blob upload failed' }
        { Invoke-LocalBoxGuestAutomation $guestConfig $guestDirectory $guestFixture 'input.json' -ManifestPath $manifestFile } | Should -Throw '*Blob upload failed*'
        $env:AZURE_CONFIG_DIR | Should -Be 'caller-profile'
    }
}
