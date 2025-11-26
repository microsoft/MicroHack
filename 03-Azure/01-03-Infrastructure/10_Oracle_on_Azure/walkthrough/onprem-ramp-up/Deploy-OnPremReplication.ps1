#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys Oracle GoldenGate replication from on-premises (AKS) to ODAA ADB

.DESCRIPTION
    This script automates the deployment of Oracle GoldenGate microhack environment.
    It handles all the manual steps from the original walkthrough:
    - Connects to AKS cluster
    - Configures helm repositories
    - Uses the existing gghack.yaml template (no modifications)
    - Overrides user-specific values via Helm --set parameters
    - Creates Kubernetes secrets
    - Deploys the GoldenGate helm chart
    - Waits for deployment completion

.PARAMETER UserName
    Your assigned username (e.g., user01, user02)

.PARAMETER ADBPassword
    Password for the ODAA ADB instance (used for all database users)

.PARAMETER ADBConnectionString
    TNS connection string for your ODAA ADB instance
    Example: (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=xxx.adb.eu-paris-1.oraclecloud.com))(connect_data=(service_name=xxx_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=no)))

.PARAMETER AKSResourceGroup
    Name of the AKS resource group (default: auto-detected from username)

.PARAMETER AKSClusterName
    Name of the AKS cluster (default: auto-detected from username)

.PARAMETER Subscription
    Azure subscription name for AKS (default: auto-detected)

.PARAMETER SkipAKSConnection
    Skip AKS connection (use if already connected)

.PARAMETER SkipHelmSetup
    Skip helm repository setup (use if already configured)

.PARAMETER Uninstall
    Uninstall existing deployment before installing

.PARAMETER TemplateFile
    Path to the gghack.yaml template file (default: ../../resources/template/gghack.yaml)
    The template is used as base values; user-specific values are overridden via Helm --set

.EXAMPLE
    .\Deploy-OnPremReplication.ps1 -UserName "user01" -ADBPassword "Welcome1234#" -ADBConnectionString "(description= ...)"

.EXAMPLE
    .\Deploy-OnPremReplication.ps1 -UserName "user01" -ADBPassword "Welcome1234#" -ADBConnectionString "(description= ...)" -SkipAKSConnection

.NOTES
    Author: ODAA MicroHack Team
    This script simplifies Challenge 4: OnPrem ramp up
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Your assigned username (e.g., user01)")]
    [string]$UserName,
    
    [Parameter(Mandatory = $true, HelpMessage = "Password for ODAA ADB instance")]
    [string]$ADBPassword,
    
    [Parameter(Mandatory = $true, HelpMessage = "TNS connection string for ODAA ADB")]
    [string]$ADBConnectionString,
    
    [Parameter(Mandatory = $false)]
    [string]$AKSResourceGroup = "",
    
    [Parameter(Mandatory = $false)]
    [string]$AKSClusterName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$Subscription = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAKSConnection,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipHelmSetup,
    
    [Parameter(Mandatory = $false)]
    [switch]$Uninstall,
    
    [Parameter(Mandatory = $false, HelpMessage = "Path to the gghack.yaml template file")]
    [string]$TemplateFile = ""
)

# ============================================================================
# Configuration
# ============================================================================
$ErrorActionPreference = "Stop"
$Namespace = "microhacks"
$HelmReleaseName = "ogghack"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Step {
    param([string]$Message, [string]$Icon = "🔄")
    Write-Host "`n$Icon $Message" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor White
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Test-Prerequisites {
    Write-Step "Checking Prerequisites" "🔍"
    
    $required = @("az", "kubectl", "helm")
    $missing = @()
    
    foreach ($cmd in $required) {
        if (Test-Command $cmd) {
            Write-Success "$cmd is installed"
        }
        else {
            Write-Error "$cmd is NOT installed"
            $missing += $cmd
        }
    }
    
    if ($missing.Count -gt 0) {
        throw "Missing prerequisites: $($missing -join ', '). Please install them first."
    }
}

function Connect-ToAKS {
    param(
        [string]$ResourceGroup,
        [string]$ClusterName,
        [string]$SubscriptionName
    )
    
    Write-Step "Connecting to AKS Cluster" "⚓"
    
    # Set subscription if provided
    if ($SubscriptionName) {
        Write-Info "Setting subscription to: $SubscriptionName"
        az account set --subscription $SubscriptionName
    }
    
    # Get AKS credentials
    Write-Info "Getting AKS credentials for cluster: $ClusterName"
    az aks get-credentials -g $ResourceGroup -n $ClusterName --overwrite-existing
    
    # Verify connection
    $namespaces = kubectl get namespaces --no-headers 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to connect to AKS cluster"
    }
    
    Write-Success "Connected to AKS cluster: $ClusterName"
}

function Initialize-HelmRepository {
    Write-Step "Setting up Helm Repository" "📦"
    
    Write-Info "Adding oggfree helm repository..."
    helm repo add oggfree https://ilfur.github.io/VirtualAnalyticRooms 2>&1 | Out-Null
    
    Write-Info "Updating helm repositories..."
    helm repo update
    
    Write-Success "Helm repository configured"
}

function Get-IngressExternalIP {
    Write-Step "Getting Ingress Controller External IP" "🌐"
    
    $maxAttempts = 12
    $attempt = 1
    $externalIP = ""
    
    while ($attempt -le $maxAttempts) {
        Write-Info "Attempt $attempt/$maxAttempts - Checking for external IP..."
        
        $externalIP = (kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip}{end}' 2>&1) -replace '\s', ''
        
        if ($externalIP -and $externalIP -match '^\d+\.\d+\.\d+\.\d+$') {
            Write-Success "External IP found: $externalIP"
            return $externalIP
        }
        
        Write-Warning "External IP not yet assigned, waiting 10 seconds..."
        Start-Sleep -Seconds 10
        $attempt++
    }
    
    throw "Failed to get external IP after $maxAttempts attempts. Please check your ingress controller."
}

function Test-TemplateFile {
    param(
        [string]$TemplateFile
    )
    
    Write-Step "Validating Template File" "📄"
    
    if (-not (Test-Path $TemplateFile)) {
        throw "Template file not found: $TemplateFile"
    }
    
    Write-Success "Template file found: $TemplateFile"
    Write-Info "Template will be used as base values (no modifications)"
}

function New-KubernetesSecrets {
    param(
        [string]$Namespace,
        [string]$Password
    )
    
    Write-Step "Creating Kubernetes Secrets" "🔐"
    
    # Create namespace if it doesn't exist
    Write-Info "Creating namespace: $Namespace"
    kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - 2>&1 | Out-Null
    
    # Delete existing secrets if they exist (to update them)
    kubectl delete secret ogg-admin-secret -n $Namespace 2>&1 | Out-Null
    kubectl delete secret db-admin-secret -n $Namespace 2>&1 | Out-Null
    
    # Create OGG admin secret
    Write-Info "Creating ogg-admin-secret..."
    kubectl create secret generic ogg-admin-secret -n $Namespace `
        --from-literal=oggusername=ggadmin `
        --from-literal=oggpassword=$Password
    
    # Create database admin secret
    Write-Info "Creating db-admin-secret..."
    kubectl create secret generic db-admin-secret -n $Namespace `
        --from-literal=srcAdminPwd=$Password `
        --from-literal=trgAdminPwd=$Password `
        --from-literal=srcGGUserName=ggadmin `
        --from-literal=trgGGUserName=ggadmin `
        --from-literal=srcGGPwd=$Password `
        --from-literal=trgGGPwd=$Password
    
    Write-Success "Kubernetes secrets created"
}

function Uninstall-GoldenGate {
    param(
        [string]$ReleaseName,
        [string]$Namespace
    )
    
    Write-Step "Uninstalling Existing Deployment" "🗑️"
    
    $existing = helm list -n $Namespace --filter $ReleaseName -q 2>&1
    if ($existing -eq $ReleaseName) {
        Write-Info "Uninstalling helm release: $ReleaseName"
        helm uninstall $ReleaseName -n $Namespace
        
        Write-Info "Waiting for pods to terminate..."
        Start-Sleep -Seconds 10
        
        # Wait for pods to be deleted
        $maxWait = 60
        $waited = 0
        while ($waited -lt $maxWait) {
            $pods = kubectl get pods -n $Namespace --no-headers 2>&1
            if (-not $pods -or $pods -match "No resources found") {
                break
            }
            Start-Sleep -Seconds 5
            $waited += 5
        }
        
        Write-Success "Existing deployment uninstalled"
    }
    else {
        Write-Info "No existing deployment found"
    }
}

function Install-GoldenGate {
    param(
        [string]$ReleaseName,
        [string]$Namespace,
        [string]$ValuesFile,
        [string]$UserName,
        [string]$ExternalIP,
        [string]$ConnectionString
    )
    
    Write-Step "Installing GoldenGate via Helm" "🚀"
    
    Write-Info "Using template file: $ValuesFile"
    Write-Info "Overriding values via --set parameters:"
    Write-Info "  - microhack.user = $UserName"
    Write-Info "  - services.external.vhostName = gghack.$ExternalIP.nip.io"
    Write-Info "  - databases.trgConn = <connection-string>"
    
    # Build the vhostName value
    $vhostName = "gghack.$ExternalIP.nip.io"
    
    # Use --set-string to handle special characters in connection string
    Write-Info "Installing helm chart: oggfree/goldengate-microhack-sample"
    helm install $ReleaseName oggfree/goldengate-microhack-sample `
        --values $ValuesFile `
        --set-string microhack.user=$UserName `
        --set-string databases.trgConn=$ConnectionString `
        --set-string services.external.vhostName=$vhostName `
        -n $Namespace
    
    Write-Success "Helm installation initiated (template unchanged)"
}

function Wait-ForDeployment {
    param(
        [string]$Namespace
    )
    
    Write-Step "Waiting for Deployment to Complete" "⏳"
    
    Write-Info "This may take 5-10 minutes. You can also watch progress with:"
    Write-Host "   kubectl get pods -n $Namespace --watch" -ForegroundColor Yellow
    Write-Host ""
    
    $maxWait = 600  # 10 minutes
    $waited = 0
    $checkInterval = 15
    
    while ($waited -lt $maxWait) {
        $pods = kubectl get pods -n $Namespace --no-headers 2>&1
        
        if ($pods -and $pods -notmatch "No resources found") {
            $podLines = $pods -split "`n" | Where-Object { $_ -match '\S' }
            
            $allReady = $true
            $completed = 0
            $running = 0
            $pending = 0
            
            foreach ($line in $podLines) {
                if ($line -match 'Completed') {
                    $completed++
                }
                elseif ($line -match 'Running' -and $line -match '1/1') {
                    $running++
                }
                else {
                    $allReady = $false
                    $pending++
                }
            }
            
            Write-Host "`r[$(Get-Date -Format 'HH:mm:ss')] Running: $running | Completed: $completed | Pending: $pending    " -NoNewline
            
            # Check if db-prepare-job is completed
            $prepJob = $podLines | Where-Object { $_ -match 'db-prepare-job' -and $_ -match 'Completed' }
            if ($prepJob -and $running -ge 3) {
                Write-Host ""
                Write-Success "Deployment completed successfully!"
                return $true
            }
        }
        
        Start-Sleep -Seconds $checkInterval
        $waited += $checkInterval
    }
    
    Write-Host ""
    Write-Warning "Deployment is still in progress. Please check manually with: kubectl get pods -n $Namespace"
    return $false
}

function Show-DeploymentSummary {
    param(
        [string]$ExternalIP,
        [string]$Namespace,
        [string]$ConnectionString
    )
    
    Write-Step "Deployment Summary" "📊"
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    DEPLOYMENT COMPLETE                           ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "🌐 Access URLs:" -ForegroundColor Cyan
    Write-Host "   GoldenGate UI:     https://gghack.$ExternalIP.nip.io" -ForegroundColor White
    Write-Host "   SQLPlus Web:       https://gghack.$ExternalIP.nip.io/sqlplus/vnc.html" -ForegroundColor White
    Write-Host "   Jupyter Notebook:  https://gghack.$ExternalIP.nip.io/jupyter/" -ForegroundColor White
    Write-Host "   GG Big Data:       https://daagghack.$ExternalIP.nip.io" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🔑 Credentials:" -ForegroundColor Cyan
    Write-Host "   GoldenGate Admin:  ggadmin / <your-password>" -ForegroundColor White
    Write-Host "   Jupyter Password:  Welcome1234" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📋 Useful Commands:" -ForegroundColor Cyan
    Write-Host "   Check pods:        kubectl get pods -n $Namespace" -ForegroundColor White
    Write-Host "   Check logs:        kubectl logs -n $Namespace <pod-name>" -ForegroundColor White
    Write-Host "   Connect to client: kubectl exec -it -n $Namespace <instantclient-pod> -- /bin/bash" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📖 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Wait for all pods to be Running/Completed" -ForegroundColor White
    Write-Host "   2. Access GoldenGate UI to verify replication setup" -ForegroundColor White
    Write-Host "   3. Connect to instantclient pod to verify data migration" -ForegroundColor White
    Write-Host "   4. See 'onprem-ramp-up-simplified.md' for verification steps" -ForegroundColor White
    Write-Host ""
}

# ============================================================================
# Main Execution
# ============================================================================

function Main {
    $startTime = Get-Date
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       🔄 Challenge 4: OnPrem Ramp Up - Automated Deployment      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Auto-detect AKS settings from username if not provided
    if (-not $AKSResourceGroup) {
        $AKSResourceGroup = "aks-$UserName"
        Write-Info "Auto-detected AKS Resource Group: $AKSResourceGroup"
    }
    if (-not $AKSClusterName) {
        $AKSClusterName = "aks-$UserName"
        Write-Info "Auto-detected AKS Cluster Name: $AKSClusterName"
    }
    
    # Check prerequisites
    Test-Prerequisites
    
    # Connect to AKS
    if (-not $SkipAKSConnection) {
        Connect-ToAKS -ResourceGroup $AKSResourceGroup -ClusterName $AKSClusterName -SubscriptionName $Subscription
    }
    else {
        Write-Info "Skipping AKS connection (using existing context)"
    }
    
    # Setup Helm
    if (-not $SkipHelmSetup) {
        Initialize-HelmRepository
    }
    else {
        Write-Info "Skipping Helm setup"
    }
    
    # Get external IP
    $externalIP = Get-IngressExternalIP
    
    # Uninstall if requested
    if ($Uninstall) {
        Uninstall-GoldenGate -ReleaseName $HelmReleaseName -Namespace $Namespace
    }
    
    # Resolve template file path
    if (-not $TemplateFile) {
        $TemplateFile = Join-Path $ScriptDir "..\..\resources\template\gghack.yaml"
    }
    $TemplateFile = [System.IO.Path]::GetFullPath($TemplateFile)
    
    # Validate template file exists
    Test-TemplateFile -TemplateFile $TemplateFile
    
    # Create secrets
    New-KubernetesSecrets -Namespace $Namespace -Password $ADBPassword
    
    # Install GoldenGate using template + --set overrides (no file modification)
    Install-GoldenGate -ReleaseName $HelmReleaseName -Namespace $Namespace -ValuesFile $TemplateFile `
        -UserName $UserName -ExternalIP $externalIP -ConnectionString $ADBConnectionString
    
    # Wait for deployment
    $deploymentComplete = Wait-ForDeployment -Namespace $Namespace
    
    # Show summary
    Show-DeploymentSummary -ExternalIP $externalIP -Namespace $Namespace -ConnectionString $ADBConnectionString
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Write-Host "Total execution time: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
}

# Run main function
try {
    Main
}
catch {
    Write-Error "Deployment failed: $_"
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    exit 1
}
