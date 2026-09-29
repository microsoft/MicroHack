BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/../..").Path
    $source = "$root/walkthrough/challenge-04"
    $workloadScript = Join-Path $TestDrive 'Deploy-VisualAttestationV2.ps1'
    Copy-Item "$source/Deploy-VisualAttestationV2.ps1" $workloadScript
    $sample = Join-Path $TestDrive 'resources/visual-attestation-demo-v2'
    New-Item -ItemType Directory -Path $sample -Force | Out-Null
    Copy-Item "$source/resources/visual-attestation-demo-v2/deployment-template-*.json" $sample
    $nameSuffix = [guid]::NewGuid().ToString('N')
    $config = @{
        registryName = 'testregistry'
        resourceGroup = 'lab-test'
        location = 'northeurope'
        loginServer = 'testregistry.azurecr.io'
        fullImage = 'testregistry.azurecr.io/cc-attest:1.0'
        nameSuffix = $nameSuffix
    }
    $config | ConvertTo-Json | Set-Content (Join-Path $TestDrive 'acr-config.json')
    function az {}
    function docker {}
}

AfterAll {
    Get-ChildItem ([IO.Path]::GetTempPath()) -Directory -Filter "microhack-ch04-$nameSuffix-*" |
        Remove-Item -Recurse -Force
}

Describe 'Visual attestation headless and desktop workflow' {
    BeforeEach {
        Remove-Item (Join-Path $TestDrive 'side-by-side-compare.html') -ErrorAction SilentlyContinue
        Mock az {
            $global:LASTEXITCODE = 0
            switch ($args[0]) {
                'version' { return '{}' }
                'account' { return '{"name":"Mock subscription","id":"test-subscription"}' }
                'extension' { return '{}' }
                'acr' {
                    if ($args[1] -eq 'credential') { return 'mock-credential' }
                    if ($args[1] -eq 'login') { return }
                }
                'confcom' { return }
                'deployment' { return 'single.example.invalid' }
                'container' {
                    if ($args[1] -eq 'logs') { return 'Mock container logs' }
                    if ($args[1] -eq 'show') {
                        $query = $args[[array]::IndexOf($args, '--query') + 1]
                        $name = $args[[array]::IndexOf($args, '-n') + 1]
                        $sku = if ($name -like 'cc-attest-conf-*') { 'Confidential' } else { 'Standard' }
                        if ($query -eq 'sku') { return $sku }
                        return "$($sku.ToLowerInvariant()).example.invalid"
                    }
                }
            }
            throw "Unexpected mocked Azure CLI call: $args"
        }
        Mock docker { $global:LASTEXITCODE = 0 }
        Mock Invoke-WebRequest { @{ StatusCode = 200 } }
        Mock Start-Process {}
    }

    It 'generates the complete comparison HTML without launching a browser in headless mode' {
        $output = & $workloadScript -Compare -SkipBrowser -Location 'northeurope' 6>&1 | Out-String
        $html = Get-Content (Join-Path $TestDrive 'side-by-side-compare.html') -Raw
        $html | Should -Match '<iframe src="http://confidential.example.invalid"'
        $html | Should -Match '<iframe src="http://standard.example.invalid"'
        $output | Should -Match 'select Download'
        $output | Should -Match 'No local web server or Codespaces port forwarding'
        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke az -Times 2 -Exactly -ParameterFilter { $args[0] -eq 'deployment' }
        Should -Invoke az -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'confcom' }
    }

    It 'preserves default desktop comparison launch with the generated file' {
        & $workloadScript -Compare -Location 'northeurope'
        Test-Path (Join-Path $TestDrive 'side-by-side-compare.html') | Should -BeTrue
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq (Join-Path $TestDrive 'side-by-side-compare.html')
        }
    }

    It 'preserves single deployment behavior with SkipBrowser=<Headless> and NoAcc=<Standard>' -TestCases @(
        @{ Headless = $true; Standard = $true }
        @{ Headless = $false; Standard = $true }
        @{ Headless = $true; Standard = $false }
        @{ Headless = $false; Standard = $false }
    ) {
        param($Headless, $Standard)
        $output = & $workloadScript -Deploy -NoAcc:$Standard -SkipBrowser:$Headless -Location 'northeurope' 6>&1 | Out-String
        if ($Headless) {
            $output | Should -Match 'Open http://single.example.invalid in your own browser'
            Should -Invoke Start-Process -Times 0 -Exactly
        }
        else {
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'http://single.example.invalid'
            }
        }
        Test-Path (Join-Path $TestDrive 'side-by-side-compare.html') | Should -BeFalse
    }

    It 'reports a platform-neutral Docker Engine error before deploying' {
        Mock docker { $global:LASTEXITCODE = 1 }
        { & $workloadScript -Compare -SkipBrowser } | Should -Throw '*Docker Engine is not reachable*Codespaces devcontainer or local host*'
        Should -Invoke az -Times 0 -Exactly -ParameterFilter { $args[0] -in @('deployment', 'confcom') }
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'has valid PowerShell syntax' {
        $parseErrors = $null
        [Management.Automation.Language.Parser]::ParseFile($workloadScript, [ref]$null, [ref]$parseErrors) | Out-Null
        $parseErrors.Count | Should -Be 0
    }
}
