#Requires -Version 5.1
<#
.SYNOPSIS
    Verify Oracle GoldenGate replication is working correctly

.DESCRIPTION
    This script helps verify that the GoldenGate deployment is working by:
    - Checking pod status
    - Testing database connectivity
    - Creating test data and verifying replication

.PARAMETER ADBConnectionString
    TNS connection string for your ODAA ADB instance

.PARAMETER ADBPassword
    Password for the ODAA ADB admin user

.PARAMETER Namespace
    Kubernetes namespace (default: microhacks)

.EXAMPLE
    .\Verify-Replication.ps1 -ADBConnectionString "(description= ...)" -ADBPassword "Welcome1234#"

.NOTES
    Run this after Deploy-OnPremReplication.ps1 has completed successfully
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ADBConnectionString,
    
    [Parameter(Mandatory = $true)]
    [string]$ADBPassword,
    
    [Parameter(Mandatory = $false)]
    [string]$Namespace = "microhacks"
)

function Write-Step {
    param([string]$Message, [string]$Icon = "🔍")
    Write-Host "`n$Icon $Message" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor DarkGray
}

function Write-Success { param([string]$Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "❌ $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "ℹ️  $Message" -ForegroundColor White }

# ============================================================================
# Check Pod Status
# ============================================================================

Write-Step "Checking Pod Status" "📦"

$pods = kubectl get pods -n $Namespace --no-headers 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get pods. Are you connected to the AKS cluster?"
    exit 1
}

$podLines = $pods -split "`n" | Where-Object { $_ -match '\S' }

$runningCount = 0
$completedCount = 0
$errorCount = 0

foreach ($line in $podLines) {
    $parts = $line -split '\s+'
    $podName = $parts[0]
    $status = $parts[2]
    
    if ($status -eq "Running") {
        Write-Success "$podName - Running"
        $runningCount++
    }
    elseif ($status -eq "Completed") {
        Write-Success "$podName - Completed"
        $completedCount++
    }
    else {
        Write-Warning "$podName - $status"
        $errorCount++
    }
}

Write-Host ""
Write-Info "Summary: $runningCount Running, $completedCount Completed, $errorCount Other"

if ($runningCount -lt 3) {
    Write-Warning "Not all pods are running yet. Please wait and try again."
    Write-Host ""
    Write-Host "Watch pod status with:" -ForegroundColor Yellow
    Write-Host "   kubectl get pods -n $Namespace --watch" -ForegroundColor White
    exit 0
}

# ============================================================================
# Get Instant Client Pod
# ============================================================================

Write-Step "Preparing Verification Commands" "🔧"

$instantClientPod = $podLines | Where-Object { $_ -match 'instantclient' } | ForEach-Object { ($_ -split '\s+')[0] }

if (-not $instantClientPod) {
    Write-Error "Instant client pod not found"
    exit 1
}

Write-Success "Found instant client pod: $instantClientPod"

# ============================================================================
# Generate Verification Commands
# ============================================================================

Write-Step "Verification Steps" "📋"

Write-Host @"

To verify replication is working, follow these steps:

"@ -ForegroundColor White

Write-Host "1️⃣  Connect to the Instant Client Pod:" -ForegroundColor Cyan
Write-Host @"
   kubectl exec -it -n $Namespace $instantClientPod -- /bin/bash

"@ -ForegroundColor Yellow

Write-Host "2️⃣  Inside the pod, connect to ODAA ADB and check SH2 schema:" -ForegroundColor Cyan
Write-Host @"
   sqlplus admin@'$ADBConnectionString'
   # Enter password: $ADBPassword
   
   -- Run these SQL commands:
   SELECT USERNAME FROM ALL_USERS WHERE USERNAME LIKE 'SH%';
   SELECT COUNT(*) FROM all_tables WHERE owner = 'SH2';
   exit

"@ -ForegroundColor Yellow

Write-Host "3️⃣  Connect to on-prem database and create test data:" -ForegroundColor Cyan
Write-Host @"
   sql
   
   -- Create a test table:
   CREATE TABLE SH.TEST_REPLICATION AS SELECT * FROM SH.COUNTRIES;
   SELECT COUNT(*) FROM SH.TEST_REPLICATION;
   exit

"@ -ForegroundColor Yellow

Write-Host "4️⃣  Verify replication to ODAA ADB:" -ForegroundColor Cyan
Write-Host @"
   sqlplus admin@'$ADBConnectionString'
   # Enter password: $ADBPassword
   
   -- Check if test table replicated:
   SELECT COUNT(*) FROM SH2.TEST_REPLICATION;
   exit

"@ -ForegroundColor Yellow

Write-Host "5️⃣  Exit the pod:" -ForegroundColor Cyan
Write-Host @"
   exit

"@ -ForegroundColor Yellow

# ============================================================================
# Web Interface URLs
# ============================================================================

Write-Step "Web Interfaces" "🌐"

$externalIP = (kubectl get service -n ingress-nginx -o jsonpath='{range .items[*]}{.status.loadBalancer.ingress[*].ip}{end}') -replace '\s', ''

if ($externalIP) {
    Write-Host @"

Access these URLs in your browser:

   GoldenGate UI:     https://gghack.$externalIP.nip.io
   SQLPlus Web:       https://gghack.$externalIP.nip.io/sqlplus/vnc.html
   Jupyter Notebook:  https://gghack.$externalIP.nip.io/jupyter/
   GG Big Data:       https://daagghack.$externalIP.nip.io

"@ -ForegroundColor White
}

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Verification script completed. Follow steps above." -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
