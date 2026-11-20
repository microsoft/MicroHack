param([switch]$SkipFileSystem)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$hack = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $hack))
$lab = Join-Path $hack 'labautomation'
. (Join-Path $lab 'automation-common.ps1')
. (Join-Path $lab 'bootstrap.ps1') -ConfigurationBase64 'e30='
$script:passed = 0
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++
}
function Assert-Throws([scriptblock]$Operation, [string]$Expected) {
    $threw = $false
    try { & $Operation | Out-Null }
    catch {
        $threw = $true
        if ($Expected -and $_.Exception.Message -notmatch $Expected) { throw "Unexpected failure: $($_.Exception.Message)" }
    }
    Assert-True $threw "Expected rejection: $Expected"
}
$scratch = $null
if (-not $SkipFileSystem) {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($tempRoot.TrimEnd('\') -eq $repo -or $tempRoot.StartsWith($repo.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OS temp must be outside the repository; refusing repository scratch writes.'
    }
    $scratch = Join-Path $tempRoot ('MicroHack-automation-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $scratch) { throw 'Unique test scratch path already exists; refusing adoption.' }
    New-Item -ItemType Directory -Path $scratch | Out-Null
}
try {
    foreach ($file in Get-ChildItem -LiteralPath $lab -Filter '*.ps1') {
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        Assert-True (@($errors).Count -eq 0) "$($file.Name) parses"
        if ($file.Name -in 'deploy-lab.ps1', 'shared-deploy-lab.ps1') {
            $expected = if ($file.Name -eq 'deploy-lab.ps1') { 'DeploymentType,SubscriptionId,ResourceGroupName,PreferredLocation,AllowedEntraUserIds' } else { 'SubscriptionId,PreferredLocation,AllowedEntraUserIds' }
            Assert-True (($ast.ParamBlock.Parameters.Name.VariablePath.UserPath -join ',') -ceq $expected) 'Exact hook signature'
            $idParam = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'AllowedEntraUserIds' }
            Assert-True ($idParam.StaticType -eq [string[]]) 'Identity array contract'
        }
    }
    $defaults = Get-Content -LiteralPath "$lab\lab-defaults.json" -Raw
    Assert-True (Test-Json -Json $defaults -SchemaFile "$repo\lab-defaults-schema.json") 'Platform defaults schema'
    $defaultsObject = $defaults | ConvertFrom-Json
    Assert-True (($defaultsObject.groups -join ',') -eq 'GHCPUsers,M365-E5-Users' -and $defaultsObject.Quality -eq 'Testing') 'Requested activation groups and Testing'
    Assert-Throws { Read-LabEventConfiguration "$lab\event-config.example.json" } ''
    Assert-Throws { Read-LabEventConfiguration 'relative.json' } 'absolute private'
    $sub = '11111111-1111-1111-1111-111111111111'
    $user = '22222222-2222-2222-2222-222222222222'
    $admin = '33333333-3333-3333-3333-333333333333'
    $ref = 'a' * 40
    $config = Get-Content -LiteralPath "$lab\event-config.example.json" -Raw | ConvertFrom-Json -AsHashtable
    $config.eventId = 'offline-fixture'
    $config.approved = $true
    $config.subscriptionIds = @($sub)
    $config.region = 'testregion'
    $config.capacityAdministrators = @($admin)
    $config.participants = @(@{objectId=$user; subscriptionId=$sub; resourceGroupName='rg-test'; sourceAddressPrefix='192.0.2.1/32'})
    $config.sizing = @{measuredParticipantsPerSubscription=2; measuredConcurrentNotebooks=1}
    $config.cost = @{perParticipantDailyUsd=1; sharedDailyUsd=1; budgetUsd=100; retentionHours=4; approvedBy='OFFLINE FIXTURE NOT EVENT APPROVAL'; priceDate='2026-01-01'}
    foreach ($key in @($config.evidence.Keys)) { $config.evidence[$key] = @{verified=$true; reference='OFFLINE FIXTURE ONLY'} }
    $config.vm = @{size='Standard_Test'; image=@{publisher='test';offer='test';sku='test';version='1.2.3'}; licenseType='None'; osDiskSizeGB=128; accessMode='PrivateRdp'}
    $config.bootstrap = @{uri="https://example.com/$ref/bootstrap.ps1"; sha256=('b'*64)}
    $config.source = @{uri="https://example.com/$ref/source.zip"; sha256=('c'*64);ref=$ref;root='archive\lab';banking='datasets\banking';insurance='datasets\insurance';briefs='briefs';manifest='datasets\manifest.json';dictionary='datasets\dictionary.md';generator='datasets\generate_data.py';generatorCli='datasets\generate-data.py'}
    $config.hosts = @{cliSkills='host\cli\skills';cliMcp='host\cli\mcp-config.json';vscodeSkills='host\vscode\skills';vscodeMcp='host\vscode\mcp.json'}
    foreach ($tool in $config.tools) { $tool.version='22.1.1';$tool.uri="https://example.com/$($tool.name).zip";$tool.sha256='d'*64;$tool.executable='bin\tool.exe' }
    if (-not $SkipFileSystem) {
    $configPath = Join-Path $scratch 'config.json'
    function Save-Fixture { $config | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $configPath }
    Save-Fixture
    $loaded = Read-LabEventConfiguration $configPath
    Assert-True ($loaded.eventId -eq 'offline-fixture') 'Valid synthetic configuration (not a tested cloud combination)'
    $config.approved=$false; Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } 'not approved'
    $config.approved=$true
    $config.evidence.automaticSqlEndpoint.verified=$false; Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } 'automaticSqlEndpoint'
    $config.evidence.automaticSqlEndpoint.verified=$true
    $config.capacityAdministrators=@($user); Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } 'capacity administrators'
    $config.capacityAdministrators=@($admin)
    $config.participants += $config.participants[0].Clone(); Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } 'identities must be unique'
    $config.participants=@($config.participants[0])
    $config.source.banking='walkthrough\banking'; Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } 'coach solutions'
    $config.source.banking='datasets\banking'
    $config.tools[1].version='18.20.0'; Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } 'Obsolete Node'
    $config.tools[1].version='22.1.1'
    $config.vm.image.version='latest'; Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } ''
    $config.vm.image.version='1.2.3'
    $config.participants[0].sourceAddressPrefix='0.0.0.0/0'; Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } 'RDP requires'
    $config.participants[0].sourceAddressPrefix='192.0.2.1/32'
    $config.source.uri='https://example.com/main.zip'; Save-Fixture
    Assert-Throws { Read-LabEventConfiguration $configPath } 'immutable source commit'
    }
    $sourceAllowlist = @(Get-LabSourceArchiveAllowlist $config)
    Assert-True ('archive\lab\datasets\dictionary.md' -in $sourceAllowlist) 'Production source allowlist explicitly includes dataset dictionary'
    foreach ($bad in 'http://example.com/a', 'https://example.com/a?token=x', 'https://user:pass@example.com/a') {
        Assert-Throws { Assert-LabPublicUri $bad } 'public HTTPS'
    }
    foreach ($bad in '..\banking', 'C:\banking', 'banking\..\solutions', 'walkthrough\answer.md') {
        Assert-Throws { Assert-LabRelativePath $bad } 'relative'
    }
    Assert-True ((Get-LabFingerprint @{b=2;a=@{d=4;c=3}}) -eq (Get-LabFingerprint @{a=@{c=3;d=4};b=2})) 'Canonical hash stable under key ordering'
    Assert-True ((Get-LabFingerprint @{a=1}) -ne (Get-LabFingerprint @{a=2})) 'Configuration drift changes fingerprint'
    Assert-True ((Get-LabRetryDelay '7') -eq 7) 'Retry-After seconds'
    Assert-True ((Get-LabRetryDelay ([DateTimeOffset]::UtcNow.AddSeconds(60).ToString('R'))) -gt 50) 'Retry-After HTTP date'
    Assert-Throws { Get-LabRetryDelay 'never' } 'Invalid ARM'
    Assert-Throws { ConvertTo-LabArmPath 'https://evil.example/subscriptions/a' } 'Untrusted'
    Assert-Throws { ConvertTo-LabArmPath '//evil.example/subscriptions/a' } 'Untrusted'
    Assert-True ((ConvertTo-LabArmPath "https://management.azure.com/subscriptions/$sub/providers/test?api-version=1") -like '/subscriptions/*') 'Trusted ARM URL normalized'

    # Local mocks only: no Az module, context, CLI login, network or deployment.
    $script:responses = [Collections.Queue]::new()
    function Invoke-AzRestMethod { param($Method,$Path,$ErrorAction) if(-not $script:responses.Count){throw 'Unexpected request'}; $script:responses.Dequeue() }
    function Start-Sleep { param($Seconds) $script:lastDelay=$Seconds }
    function Add-Response($Status,$Body,$Headers=@{}) { $script:responses.Enqueue([pscustomobject]@{StatusCode=$Status;Content=$Body;Headers=$Headers}) }
    Add-Response 202 '{}' @{'Azure-AsyncOperation'="https://management.azure.com/subscriptions/$sub/operations/a?api-version=1";'Retry-After'='2'}
    Add-Response 200 '{"status":"Succeeded"}'
    $result=Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1"
    Assert-True ($result.status -eq 'Succeeded' -and $script:lastDelay -eq 2) 'LRO polls and honors Retry-After'
    Add-Response 201 '{}' @{'Azure-AsyncOperation'="/subscriptions/$sub/operations/a?api-version=1"}
    Add-Response 200 '{"status":"Succeeded"}'
    $result=Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1"
    Assert-True ($result.status -eq 'Succeeded') '201 with async header is not premature success'
    Add-Response 429 '{}' @{'Retry-After'='3'}
    Add-Response 200 '{"properties":{"provisioningState":"Succeeded"}}'
    $result=Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1"
    Assert-True ($result.properties.provisioningState -eq 'Succeeded' -and $script:lastDelay -eq 3) 'Throttle recovery'
    Add-Response 200 '{"status":"Failed","error":{"message":"sensitive"}}'
    Assert-Throws { Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1" } 'failed or was cancelled'
    Add-Response 202 '{}' @{}
    Assert-Throws { Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1" } 'without a supported polling'
    Add-Response 202 '{}' @{'Location'='https://evil.example/a'}
    Assert-Throws { Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1" } 'Untrusted'
    Add-Response 202 '{}' @{'Location'='/subscriptions/44444444-4444-4444-4444-444444444444/operations/a?api-version=1'}
    Assert-Throws { Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1" } 'changed subscription'
    Add-Response 503 '{}' @{'Retry-After'='9000'}
    Assert-Throws { Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1" } 'deadline'
    Add-Response 200 '{"status":"Running"}' @{}
    Assert-Throws { Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1" -MaxRequests 1 } 'request limit'
    Assert-Throws { Invoke-LabAzureOperation { throw 'SECRET' } 'Synthetic operation' } '^Synthetic operation failed\.'
    $script:resources=@()
    $script:groupTags=@{}
    $script:claimed=$false
    function Get-AzResourceGroup { param($ErrorAction) [pscustomobject]@{ResourceGroupName='rg-test';Location='testregion';Tags=$script:groupTags} }
    function Get-AzResource { param($ResourceGroupName,$ErrorAction) $script:resources }
    function Set-AzResourceGroup { param($Name,$Tag,$ErrorAction) $script:groupTags=$Tag; $script:claimed=$true }
    $tags=@{LabEvent='offline-fixture';LabOwner='participant';LabConfig='abc';LabComponent='participant'}
    Assert-LabResourceGroup -Name 'rg-test' -Location 'testregion' -Tags $tags -ClaimEmpty
    Assert-True $script:claimed 'Empty platform participant group can be claimed'
    $script:claimed=$false
    Assert-LabResourceGroup -Name 'rg-test' -Location 'testregion' -Tags $tags -ClaimEmpty
    Assert-True (-not $script:claimed) 'Rerun does not reclaim group'
    $script:groupTags=@{LabOwner='foreign-partial-owner'}
    Assert-Throws { Assert-LabResourceGroup -Name 'rg-test' -Location 'testregion' -Tags $tags -ClaimEmpty } 'ownership/configuration collision'
    $script:groupTags=$tags
    $script:resources=@([pscustomobject]@{Tags=@{}})
    Assert-Throws { Assert-LabResourceGroup -Name 'rg-test' -Location 'testregion' -Tags $tags -ClaimEmpty } 'resource ownership'
    $script:resources=@()
    $drift=$tags.Clone();$drift.LabConfig='changed'
    Assert-Throws { Assert-LabResourceGroup -Name 'rg-test' -Location 'testregion' -Tags $drift -ClaimEmpty } 'ownership/configuration collision'
    $vmId="/subscriptions/$sub/resourceGroups/rg-test/providers/Microsoft.Compute/virtualMachines/vm-test"
    $diskId="/subscriptions/$sub/resourceGroups/rg-test/providers/Microsoft.Compute/disks/os-test"
    $script:resources=@(
        [pscustomobject]@{ResourceId=$vmId;ResourceType='Microsoft.Compute/virtualMachines';Tags=$tags},
        [pscustomobject]@{ResourceId=$diskId;ResourceType='Microsoft.Compute/disks';Tags=@{}}
    )
    $script:taggedDisk=$false
    function Update-AzTag { param($ResourceId,$Operation,$Tag,$ErrorAction) $script:taggedDisk=($ResourceId -eq $diskId -and $Operation -eq 'Merge') }
    Add-Response 200 ('{"managedBy":"' + $vmId + '"}')
    Assert-LabResourceGroup -Name 'rg-test' -Location 'testregion' -Tags $tags -ImplicitVmId $vmId
    Assert-True $script:taggedDisk 'Implicit OS disk tagged only after owning VM verified'
    Add-Response 200 '{"managedBy":"other-vm"}'
    Assert-Throws { Assert-LabResourceGroup -Name 'rg-test' -Location 'testregion' -Tags $tags -ImplicitVmId $vmId } 'not attached'

    if (-not $SkipFileSystem) {
    # Real ZIP extraction and final student copies share the production staging helpers.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $badZip=Join-Path $scratch 'unsafe.zip'
    $zip=[IO.Compression.ZipFile]::Open($badZip,[IO.Compression.ZipArchiveMode]::Create)
    $null=$zip.CreateEntry('..\escape.txt'); $zip.Dispose()
    Assert-Throws { Expand-VerifiedZip $badZip (Join-Path $scratch 'unsafe') } 'Unsafe ZIP'
    $studentZip=Join-Path $scratch 'source.zip'
    $zip=[IO.Compression.ZipFile]::Open($studentZip,[IO.Compression.ZipArchiveMode]::Create)
    $null=$zip.CreateEntry('archive/lab/datasets/banking/Table.csv')
    $null=$zip.CreateEntry('archive/lab/walkthrough/answer.md')
    $zip.Dispose()
    Expand-VerifiedZip $studentZip "$scratch\selected" -AllowedRelativePaths @('archive\lab\datasets\banking')
    Assert-True (Test-Path -LiteralPath "$scratch\selected\archive\lab\datasets\banking\Table.csv") 'Allowlisted source extracted'
    Assert-True (-not (Test-Path -LiteralPath "$scratch\selected\archive\lab\walkthrough")) 'Coach solution never extracted'
    $dictionaryZip = Join-Path $scratch 'dictionary-regression.zip'
    $zip = [IO.Compression.ZipFile]::Open($dictionaryZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $entries = @{
            'archive/lab/datasets/banking/Table.csv' = "Id`n1"
            'archive/lab/datasets/insurance/Table.csv' = "Id`n2"
            'archive/lab/datasets/manifest.json' = '{}'
            'archive/lab/datasets/dictionary.md' = '# Synthetic dictionary regression fixture'
            'archive/lab/datasets/generate_data.py' = '# Synthetic generator fixture'
            'archive/lab/datasets/generate-data.py' = '# Synthetic CLI fixture'
            'archive/lab/briefs/banking-business-brief.md' = '[Dictionary](../datasets/dictionary.md)'
            'archive/lab/briefs/insurance-business-brief.md' = '[Dictionary](../datasets/dictionary.md)'
            'archive/lab/walkthrough/answer.md' = 'Never extract this coach fixture'
        }
        foreach ($entry in $entries.GetEnumerator()) {
            $writer = [IO.StreamWriter]::new($zip.CreateEntry($entry.Key).Open())
            try { $writer.Write($entry.Value) } finally { $writer.Dispose() }
        }
    } finally { $zip.Dispose() }
    $extracted = Join-Path $scratch 'dictionary-extracted'
    Expand-VerifiedZip $dictionaryZip $extracted -AllowedRelativePaths (Get-LabSourceArchiveAllowlist $config)
    $extractedRoot = Get-SafeSourcePath $extracted $config.source.root
    Assert-True (Test-Path -LiteralPath "$extractedRoot\datasets\dictionary.md") 'Actual archive allowlist extracts dictionary'
    Assert-True (-not (Test-Path -LiteralPath "$extractedRoot\walkthrough")) 'Dictionary regression excludes coach source'
    $stagedStudent = Join-Path $scratch 'dictionary-student'
    Copy-LabStudentSource -SourceRoot $extractedRoot -StudentRoot $stagedStudent -Source $config.source
    Assert-True ((Get-Content -LiteralPath "$stagedStudent\datasets\dictionary.md" -Raw) -eq $entries['archive/lab/datasets/dictionary.md']) 'Production final copy preserves dictionary content'
    foreach ($scenario in 'banking', 'insurance') {
        $brief = Join-Path "$stagedStudent\briefs" "$scenario-business-brief.md"
        $link = [regex]::Match((Get-Content -LiteralPath $brief -Raw), '\]\(([^)]+dictionary\.md)\)').Groups[1].Value
        $target = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $brief) $link))
        Assert-True ($target -eq "$stagedStudent\datasets\dictionary.md" -and (Test-Path -LiteralPath $target)) "Staged $scenario brief dictionary link resolves to staged datasets path"
    }
    New-Item -ItemType Directory -Path "$scratch\student\datasets\banking","$scratch\student\datasets\insurance" -Force | Out-Null
    $manifest=@{scenarios=@{}}
    foreach($scenario in 'banking','insurance') {
        $csv="$scratch\student\datasets\$scenario\Table.csv"
        Set-Content -LiteralPath $csv -Value "Id`n1"
        $manifest.scenarios[$scenario]=@{tables=@{Table=@{file="$scenario/Table.csv";sha256=(Get-FileHash $csv -Algorithm SHA256).Hash;bytes=(Get-Item $csv).Length}}}
    }
    $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath "$scratch\student\datasets\manifest.json"
    Assert-CsvManifest "$scratch\student"
    $script:passed++
    Add-Content -LiteralPath "$scratch\student\datasets\banking\Table.csv" -Value '2'
    Assert-Throws { Assert-CsvManifest "$scratch\student" } 'checksum/size'
    }
    $coverage = if ($SkipFileSystem) { 'Filesystem regressions SKIPPED (read-only subset).' } else { 'Includes actual archive extraction and final student-copy regressions in unique OS temp.' }
    Write-Output "PASS: $script:passed offline automation assertions. $coverage No cloud checks performed."
} finally {
    if ($scratch -and (Test-Path -LiteralPath $scratch)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
