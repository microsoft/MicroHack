param([switch]$SkipFileSystem)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$hack = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $hack))
$lab = Join-Path $hack 'labautomation'
. (Join-Path $lab 'automation-common.ps1')
. (Join-Path $lab 'bootstrap.ps1') -ConfigurationBase64 'e30='
$script:passed = 0
$script:httpResponses = [Collections.Generic.List[Net.Http.HttpResponseMessage]]::new()
function New-TestHttpHeaders($Values = @{}) {
    $message = [Net.Http.HttpResponseMessage]::new()
    $script:httpResponses.Add($message)
    foreach ($key in $Values.Keys) {
        if (-not $message.Headers.TryAddWithoutValidation($key, [string[]]@($Values[$key]))) { throw 'Invalid HTTP header fixture.' }
    }
    return ,$message.Headers
}
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
    $sub = '11111111-1111-1111-1111-111111111111'
    $user = '22222222-2222-2222-2222-222222222222'
    $admin = '33333333-3333-3333-3333-333333333333'
    $settings = Read-LabSettings
    Assert-True ($settings.Tools.Count -eq 7) 'Seven real checksum-pinned tool packages'
    $guest = Get-LabGuestConfiguration $settings
    Assert-True ($guest.source.files.Count -eq 25) 'Both scenarios and required support files supplied without a private config'
    $npmLock = $guest.npm.lock | ConvertFrom-Json -AsHashtable
    Assert-True ($npmLock.packages['node_modules/@microsoft/powerbi-report-authoring-cli'].version -eq '0.1.1') 'Report CLI lock supplied'
    foreach ($package in $npmLock.packages.Values) {
        if ($package.ContainsKey('resolved')) {
            Assert-True ($package.integrity -match '^sha512-' -and $package.resolved -match '^https://') 'Transitive package HTTPS/SHA512 lock'
        }
    }
    foreach ($bad in 'http://example.com/a', 'https://example.com/a?token=x', 'https://user:pass@example.com/a') {
        Assert-Throws { Assert-LabPublicUri $bad } 'public HTTPS'
    }
    Assert-True ((Get-LabFingerprint @{b=2;a=@{d=4;c=3}}) -eq (Get-LabFingerprint @{a=@{c=3;d=4};b=2})) 'Canonical hash stable under key ordering'
    Assert-True ((ConvertTo-LabCanonicalJson @{b=2;a=@{d=4;c=3}}) -ceq (ConvertTo-LabCanonicalJson @{a=@{c=3;d=4};b=2})) 'Guest wire JSON is deterministic across hashtable ordering'
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
    Add-Response 200 '[{"name":"1.0.0"},{"name":"1.0.1"}]' (New-TestHttpHeaders)
    $result=@(Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1")
    Assert-True ($result.Count -eq 2 -and $result[1].name -eq '1.0.1') 'ARM array responses are not mistaken for LRO objects'
    Add-Response 202 '{}' (New-TestHttpHeaders @{'azure-asyncoperation'="https://management.azure.com/subscriptions/$sub/operations/a?api-version=1";'retry-after'='2'})
    Add-Response 200 '{"status":"Succeeded"}' (New-TestHttpHeaders)
    $result=Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1"
    Assert-True ($result.status -eq 'Succeeded' -and $script:lastDelay -eq 2) 'Real HttpResponseHeaders LRO polling honors case-insensitive headers and Retry-After'
    Add-Response 201 '{}' @{'Azure-AsyncOperation'="/subscriptions/$sub/operations/a?api-version=1"}
    Add-Response 200 '{"status":"Succeeded"}'
    $result=Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1"
    Assert-True ($result.status -eq 'Succeeded') '201 with async header is not premature success'
    Add-Response 202 '{}' (New-TestHttpHeaders @{'location'="/subscriptions/$sub/operations/location?api-version=1";'retry-after'='4'})
    Add-Response 200 '{"status":"Succeeded"}' (New-TestHttpHeaders)
    $result=Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1"
    Assert-True ($result.status -eq 'Succeeded' -and $script:lastDelay -eq 4) 'Real HttpResponseHeaders Location fallback polls successfully'
    Add-Response 429 '{}' @{'Retry-After'='3'}
    Add-Response 200 '{"properties":{"provisioningState":"Succeeded"}}'
    $result=Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1"
    Assert-True ($result.properties.provisioningState -eq 'Succeeded' -and $script:lastDelay -eq 3) 'Throttle recovery'
    Add-Response 503 '{}' (New-TestHttpHeaders @{'Retry-After'='6'})
    Add-Response 200 '{}' (New-TestHttpHeaders)
    $null=Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1"
    Assert-True ($script:lastDelay -eq 6) 'Real HttpResponseHeaders transient failure honors Retry-After'
    Add-Response 202 '{}' (New-TestHttpHeaders @{'Location'=@("/subscriptions/$sub/operations/a?api-version=1","/subscriptions/$sub/operations/b?api-version=1")})
    Assert-Throws { Invoke-LabArmRequest -Path "/subscriptions/$sub/resources?api-version=1" } 'Invalid ARM Location header'
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
    New-Item -ItemType Directory -Path "$scratch\tree-source" | Out-Null
    Set-Content -LiteralPath "$scratch\tree-source\SKILL.md" -Value '# Synthetic retry fixture'
    Copy-StudentTree "$scratch\tree-source" "$scratch\tree-destination"
    Copy-StudentTree "$scratch\tree-source" "$scratch\tree-destination"
    Assert-True ((Test-Path -LiteralPath "$scratch\tree-destination\SKILL.md") -and
        -not (Test-Path -LiteralPath "$scratch\tree-destination\tree-source")) 'Skill staging retries merge content without nesting source directories'
    $studentZip=Join-Path $scratch 'source.zip'
    $zip=[IO.Compression.ZipFile]::Open($studentZip,[IO.Compression.ZipArchiveMode]::Create)
    $null=$zip.CreateEntry('archive/lab/datasets/banking/Table.csv')
    $null=$zip.CreateEntry('archive/lab/walkthrough/answer.md')
    $zip.Dispose()
    Expand-VerifiedZip $studentZip "$scratch\selected" -AllowedRelativePaths @('archive\lab\datasets\banking')
    Assert-True (Test-Path -LiteralPath "$scratch\selected\archive\lab\datasets\banking\Table.csv") 'Allowlisted source extracted'
    Assert-True (-not (Test-Path -LiteralPath "$scratch\selected\archive\lab\walkthrough")) 'Coach solution never extracted'
    # Exercise the production selective downloader with local bytes, not a network request.
    function Get-VerifiedAsset($Asset, [string]$Destination) {
        $prefix = "https://raw.githubusercontent.com/microsoft/MicroHack/$($settings.SourceRef)/03-Azure/01-02%20Data/04-Agentic_PBIReport_Development/"
        if (-not $Asset.uri.StartsWith($prefix)) { throw 'Unexpected source URI.' }
        $relative = [uri]::UnescapeDataString($Asset.uri.Substring($prefix.Length))
        $start = [Diagnostics.ProcessStartInfo]::new('git')
        $start.WorkingDirectory = $repo
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        foreach ($argument in @('cat-file','blob',"$($settings.SourceRef):03-Azure/01-02 Data/04-Agentic_PBIReport_Development/$relative")) {
            $start.ArgumentList.Add($argument)
        }
        $process = [Diagnostics.Process]::Start($start)
        $stream = [IO.File]::Create($Destination)
        try { $process.StandardOutput.BaseStream.CopyTo($stream) }
        finally { $stream.Dispose() }
        $process.WaitForExit()
        try {
            if ($process.ExitCode -ne 0 -or (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $Asset.sha256) {
                throw 'Committed source descriptor checksum mismatch.'
            }
        } finally { $process.Dispose() }
    }
    $stagedStudent = Join-Path $scratch 'dictionary-student'
    Copy-LabStudentFiles $guest.source $stagedStudent
    Assert-CsvManifest $stagedStudent
    $dictionary = @($guest.source.files | Where-Object target -EQ 'datasets/dictionary.md')[0]
    Assert-True ((Get-FileHash "$stagedStudent\datasets\dictionary.md").Hash -eq $dictionary.sha256) 'Production staging preserves committed dictionary bytes, independent of autocrlf'
    Assert-True (-not (Test-Path -LiteralPath "$stagedStudent\walkthrough")) 'Student staging excludes coach source'
    $badSource = @{ref=$settings.SourceRef;files=@(@{path='datasets/../walkthrough/answer.md';target='datasets/answer.md';sha256=('a'*64)})}
    Assert-Throws { Copy-LabStudentFiles $badSource "$scratch\bad-student" } 'Unsafe student'
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
    $coverage = if ($SkipFileSystem) { 'Filesystem regressions SKIPPED (read-only subset).' } else { 'Includes actual archive extraction and selective student staging with real CSV checksum verification in unique OS temp.' }
    Write-Output "PASS: $script:passed offline automation assertions. $coverage No cloud checks performed."
} finally {
    foreach ($message in $script:httpResponses) { $message.Dispose() }
    if ($scratch -and (Test-Path -LiteralPath $scratch)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
