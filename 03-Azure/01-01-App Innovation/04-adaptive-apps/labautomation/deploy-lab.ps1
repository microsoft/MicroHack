<#
.SYNOPSIS
Provision one dedicated Microsoft-hosted Adaptive Apps lab through challenge 05.
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('subscription', 'resourcegroup', 'resourcegroup-with-subscriptionowner')]
    [string]$DeploymentType,
    [Parameter(Mandatory)][string]$SubscriptionId,
    [string]$ResourceGroupName = '',
    [string[]]$PreferredLocation = @(),
    [string[]]$AllowedEntraUserIds = @()
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'console-helpers.ps1')
if (-not $IsLinux) { throw 'Adaptive Apps Console automation requires a Linux runner (Bash and native Bastion tunneling).' }
if ($DeploymentType -ne 'resourcegroup' -or -not $ResourceGroupName) {
    throw 'This hook requires a Console-provisioned resourcegroup scope.'
}
if ($AllowedEntraUserIds.Count -eq 0) { throw 'Console must supply participant object IDs for node resource group Reader access.' }
$sourceManifest = Read-AdaptiveSourceManifest -Path (Join-Path $PSScriptRoot 'bootstrap-source.json')
if (-not $env:AZURE_CONFIG_DIR -or -not [IO.Path]::IsPathRooted($env:AZURE_CONFIG_DIR)) {
    throw 'Console must supply an absolute, isolated AZURE_CONFIG_DIR before HOME can be isolated.'
}
$saved = @{}
$isolatedHome = Join-Path ([IO.Path]::GetTempPath()) "adaptive-console-$([guid]::NewGuid().ToString('N'))"
$workingRoot = Join-Path $isolatedHome 'work'
try {
    $scratch = Join-Path $isolatedHome 'scratch'
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    & chmod 700 $isolatedHome $scratch
    if ($LASTEXITCODE -ne 0) { throw 'Unable to secure isolated Console HOME.' }
    New-Item -ItemType Directory -Path $workingRoot | Out-Null
    Receive-AdaptiveBootstrap -Manifest $sourceManifest -Destination $workingRoot

    Update-MhhToken | Out-Null
    Write-Host 'Validating participant Azure contexts and shared region metadata...'
    Assert-AdaptiveContext -SubscriptionId $SubscriptionId
    $group = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
    $region = $group.Location.ToLowerInvariant()
    $metadata = (Get-AzTag -ResourceId "/subscriptions/$SubscriptionId" -ErrorAction Stop).Properties.TagsProperty
    if (-not $metadata -or $region -notin ($metadata['microhack-adaptive-regions'] -split ',')) {
        throw "RG location '$region' was not validated by shared-deploy-lab.ps1. Run the shared hook for this region; do not relocate resources independently of their RG."
    }
    Update-AzTag -ResourceId $group.ResourceId -Operation Merge -Tag @{
        adaptiveAppsReady = 'false'
        SecurityControl = 'Ignore'
        CostControl = 'Ignore'
    } -ErrorAction Stop | Out-Null

    Write-Host 'Preparing private infrastructure deployment parameters...'
    $parameterFile = Join-Path $scratch 'main.parameters.json'
    @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            location = @{ value = $region }
            adminPassword = @{ value = (New-MhhStablePassword -Purpose 'adaptive-apps-k3s-admin' -Length 24) }
        }
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $parameterFile -Encoding utf8
    & chmod 600 $parameterFile
    if ($LASTEXITCODE -ne 0) { throw 'Unable to secure infrastructure parameter file.' }
    Write-Host 'Submitting incremental Adaptive Apps infrastructure deployment...'
    try {
        $deployment = New-AzResourceGroupDeployment -Name 'adaptive-apps-console' `
            -ResourceGroupName $ResourceGroupName -TemplateFile (Join-Path $PSScriptRoot 'main.bicep') `
            -TemplateParameterFile $parameterFile -Mode Incremental -ErrorAction Stop
    } finally {
        Remove-Item -LiteralPath $parameterFile -Force
    }
    if ($deployment.ProvisioningState -ne 'Succeeded') {
        throw "Infrastructure deployment failed: $($deployment.ProvisioningState). Resources are retained for diagnosis; no destructive fallback is attempted."
    }
    $acrName = $deployment.Outputs.acrName.Value
    $nodeGroup = $deployment.Outputs.nodeResourceGroup.Value
    if (-not $acrName -or -not $nodeGroup) { throw 'Infrastructure deployment omitted ACR or AKS node resource group outputs.' }
    Update-MhhToken | Out-Null
    $nodeScope = "/subscriptions/$SubscriptionId/resourceGroups/$nodeGroup"
    $readerId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    foreach ($objectId in ($AllowedEntraUserIds | Select-Object -Unique)) {
        # --assignee-object-id and --assignee-principal-type avoid all Microsoft Graph lookups.
        $assignments = @(Invoke-AdaptiveAz -Arguments @('role', 'assignment', 'list', '--scope', $nodeScope, '--all', '--fill-principal-name', 'false'))
        $exists = $assignments | Where-Object {
            $_.principalId -eq $objectId -and $_.roleDefinitionId -like "*/$readerId" -and $_.scope -ieq $nodeScope
        }
        if (-not $exists) {
            Invoke-AdaptiveAz -Arguments @('role', 'assignment', 'create', '--assignee-object-id', $objectId,
                '--assignee-principal-type', 'User', '--role', $readerId, '--scope', $nodeScope) | Out-Null
        }
    }
    Update-MhhToken | Out-Null
    $guest = Invoke-AdaptiveAz -Arguments @('vm', 'run-command', 'invoke', '--resource-group', $ResourceGroupName,
        '--name', 'vm-adaptive-apps-k3s', '--command-id', 'RunShellScript',
        '--scripts', "@$(Join-Path $PSScriptRoot 'install-k3s.sh')")
    if (($guest.value.message -join "`n") -notmatch '(?m)^ADAPTIVE_K3S_READY\r?$') {
        throw 'K3s Run Command did not return its readiness marker. Inspect VM Run Command and NAT outbound; credentials were not emitted.'
    }
    Update-AzTag -ResourceId $group.ResourceId -Operation Merge -Tag @{
        adaptiveAppsAcr = $acrName
    } -ErrorAction Stop | Out-Null

    $environment = @{
        AZURE_SUBSCRIPTION = $SubscriptionId
        RESOURCE_GROUP = $ResourceGroupName
        REGION = $region
        AZURE_LOCATION = $region
        ACR_NAME = $acrName
        AKS_CLUSTER = 'aks-adaptive-apps'
        AKS_CLUSTER_NAME = 'aks-adaptive-apps'
        AKS_CONTEXT = 'aks-adaptive-apps'
        K3S_VM_NAME = 'vm-adaptive-apps-k3s'
        K3S_CONTEXT = 'k3s-azure-vm'
        RADIUS_GROUP = 'rg-trading'
        BASTION_NAME = 'bas-adaptive-apps'
        KUBECONFIG = $null
        RAD_WORKSPACE = $null
        HOME = $isolatedHome
        PATH = "$(Join-Path $isolatedHome '.local/bin'):$env:PATH"
        TMPDIR = $scratch
        K3S_KUBECONFIG = Join-Path $isolatedHome '.kube/adaptive-apps-k3s.yaml'
        K3S_TUNNEL_STATE_DIR = Join-Path $isolatedHome '.kube/adaptive-apps-bastion'
    }
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        $environment.K3S_LOCAL_PORT = "$($listener.LocalEndpoint.Port)"
    } finally {
        $listener.Stop()
    }
    foreach ($key in $environment.Keys) {
        $saved[$key] = [Environment]::GetEnvironmentVariable($key)
        [Environment]::SetEnvironmentVariable($key, $environment[$key])
    }
    Push-Location $workingRoot
    try {
        Invoke-AdaptiveBash -Script 'resources/install-console-tools.sh'
        foreach ($phase in @('aks-radius', 'k3s-radius', 'aks-types', 'k3s-types', 'recipes', 'verify')) {
            Write-Host "Bootstrapping Adaptive Apps: $phase"
            Invoke-AdaptiveBash -Script 'resources/bootstrap-console.sh' -Arguments @($phase)
        }
    } finally {
        Pop-Location
    }
} finally {
    foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key, $saved[$key]) }
    if (Test-Path -LiteralPath $isolatedHome) { Remove-Item -LiteralPath $isolatedHome -Recurse -Force }
}
Update-MhhToken | Out-Null
Update-AzTag -ResourceId $group.ResourceId -Operation Merge -Tag @{ adaptiveAppsReady = 'true' } -ErrorAction Stop | Out-Null
@{ HackboxCredential = @{ name = 'Adaptive Apps Region'; value = $region; note = 'All resources and recipes use the supplied resource group location.' } }
@{ HackboxCredential = @{ name = 'Adaptive Apps Registry'; value = "$acrName.azurecr.io"; note = 'Anonymous recipe pull is enabled; do not publish sensitive artifacts.' } }
@{ HackboxCredential = @{ name = 'Adaptive Apps AKS'; value = 'aks-adaptive-apps'; note = "Node RG: $nodeGroup (Reader granted for recipe egress discovery)." } }
@{ HackboxCredential = @{ name = 'Adaptive Apps K3s'; value = 'vm-adaptive-apps-k3s'; note = 'Private VM via bas-adaptive-apps. Connect uses Run Command, not SSH/password.' } }
@{ HackboxCredential = @{
    name = 'Adaptive Apps Connect'
    value = "AZURE_SUBSCRIPTION='$SubscriptionId' RESOURCE_GROUP='$ResourceGroupName' bash resources/connect-console.sh"
    note = 'Run from the complete Adaptive Apps checkout after signing into your own participant Azure CLI account. Ready through challenge 05; start challenge 06.'
} }
