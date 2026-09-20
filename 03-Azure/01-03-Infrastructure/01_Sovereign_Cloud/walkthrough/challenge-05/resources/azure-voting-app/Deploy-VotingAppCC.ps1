# Hands-off script to build a small AKS cluster with an AMD SEV-SNP Confidential Computing node pool
# and deploy the public Microsoft "Azure Voting App" multi-container sample to it, exposed via a public
# LoadBalancer. Modeled on BuildRandomCVM.ps1 (random naming, tagging, smoketest, preflight).
#
# Simon Gallagher, ACC Product Group
# Use at your own risk, no warranties implied, test in a non-production environment first
#
# References:
#   - https://learn.microsoft.com/azure/aks/use-cvm                      (CVM node pools on AKS)
#   - https://learn.microsoft.com/azure/aks/confidential-computing-overview
#   - https://learn.microsoft.com/azure/aks/auto-upgrade-cluster         (auto-upgrade channel)
#   - https://learn.microsoft.com/azure/aks/auto-upgrade-node-image      (node OS auto-upgrade)
#   - https://github.com/Azure-Samples/azure-voting-app-redis            (the demo app)
#
# Usage:
#   ./Deploy-VotingAppCC.ps1 -subsID <SUBSCRIPTION ID> -basename <PREFIX> [-region <REGION>] `
#         [-description <TEXT>] [-smoketest] [-SkipSkuPreflight]
#
# Requirements:
#   - Azure PowerShell (Az) module + Azure CLI (az), both logged in to the same subscription
#   - kubectl on PATH (az aks install-cli will install it if missing)

param (
    [Parameter(Mandatory)]$subsID,
    [Parameter(Mandatory)]$basename,
    [Parameter(Mandatory=$false)]$description = "",
    [Parameter(Mandatory=$false)][switch]$smoketest,
    [Parameter(Mandatory=$false)]$region = "northeurope",
    [Parameter(Mandatory=$false)]$ccVmSize = "Standard_DC2as_v5",    # smallest AMD SEV-SNP CVM (2 vCPU / 8 GiB)
    [Parameter(Mandatory=$false)]$systemVmSize = "Standard_D2as_v6", # tiny non-CC system pool (AMD, allowed by typical Allowed-VM-SKUs policies)
    [Parameter(Mandatory=$false)][int]$ccNodeCount = 2,
    [Parameter(Mandatory=$false)][switch]$SkipSkuPreflight
)

if ($subsID -eq "" -or $basename -eq "") {
    write-host "You must enter a subscription ID and a basename"
    exit 1
}

$startTime = Get-Date
$scriptName = $MyInvocation.MyCommand.Name

# Get GitHub repository URL from git remote (used as a tag)
$gitRemoteUrl = ""
try { $gitRemoteUrl = (git remote get-url origin) -replace "\.git$","" } catch {}
if (-not $gitRemoteUrl) { $gitRemoteUrl = "[Originally from] https://github.com/Microsoft/confidential-computing" }

# ACR names cannot contain hyphens, AKS cluster names should be conservative as well.
if ($basename -match '[^a-z0-9]') {
    write-host "basename must contain only lowercase letters and digits (no hyphens, no uppercase). ACR does not allow hyphens." -ForegroundColor Red
    exit 1
}

# Random suffix in the same style as BuildRandomCVM.ps1
$basename = $basename + -join ((97..122) | Get-Random -Count 5 | % {[char]$_})
$resgrp        = $basename
$aksName       = $basename + "aks"
$acrName       = $basename + "acr"
$ccPoolName    = "ccpool"          # 12-char max, lowercase, AMD SEV-SNP node pool
$systemPool    = "syspool"

write-host "----------------------------------------------------------------------------------------------------------------"
write-host "Building AKS cluster '$aksName' with AMD SEV-SNP CC node pool in '$region' (subscription $subsID)"
write-host "  System pool : $systemPool   1x $systemVmSize"
write-host "  CC pool     : $ccPoolName   ${ccNodeCount}x $ccVmSize  (AMD SEV-SNP)"
write-host "  Resource Gp : $resgrp"
if ($smoketest) { write-host "SMOKETEST MODE: Resources will be auto-deleted after the front-end is verified" -ForegroundColor Yellow }
write-host "Script: $scriptName"
write-host "Repository URL: $gitRemoteUrl"
write-host "----------------------------------------------------------------------------------------------------------------"

# Set subscription context for both Az and az CLI
Set-AzContext -SubscriptionId $subsID | Out-Null
if (!$?) { write-host "Failed to Set-AzContext to $subsID" -ForegroundColor Red; exit 1 }
az account set --subscription $subsID | Out-Null
if (!$?) { write-host "Failed to az account set --subscription $subsID" -ForegroundColor Red; exit 1 }

$tmp = Get-AzContext
$ownername = $tmp.Account.Id

# ---------- Pre-flight: SKU + quota check for the CC pool -----------------------------------------
if ($SkipSkuPreflight) {
    write-host "Pre-flight check SKIPPED (-SkipSkuPreflight)." -ForegroundColor Yellow
} else {
    write-host "Pre-flight: confirming '$ccVmSize' is available in '$region' with sufficient AMD CVM vCPU quota..." -ForegroundColor Cyan

    # Hard-fail on Intel SGX SKUs - this script targets full-VM CC (SEV-SNP)
    if ($ccVmSize -match '^Standard_DC\d+s_v[23]$') {
        write-host "ERROR: '$ccVmSize' is an Intel SGX SKU; this script targets AMD SEV-SNP Confidential VM nodes." -ForegroundColor Red
        exit 1
    }
    if ($ccVmSize -notmatch '^Standard_(DC|EC)\d+a[a-z]*_v\d+$') {
        write-host "Warning: '$ccVmSize' does not look like an AMD SEV-SNP CVM SKU (expected DCa*/ECa*v5 family)." -ForegroundColor Yellow
    }

    $skuInfo = $null
    try {
        $skuInfo = Get-AzComputeResourceSku -Location $region -ErrorAction Stop |
            Where-Object { $_.ResourceType -eq 'virtualMachines' -and $_.Name -eq $ccVmSize } |
            Select-Object -First 1
    } catch {
        write-host "Warning: Get-AzComputeResourceSku failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    if ($null -eq $skuInfo) {
        write-host "ERROR: '$ccVmSize' is not offered in '$region'." -ForegroundColor Red
        write-host "Find available regions: Get-AzComputeResourceSku | ? { `$_.Name -eq '$ccVmSize' -and -not `$_.Restrictions } | Select Locations" -ForegroundColor Gray
        exit 1
    }

    $subRestriction = $skuInfo.Restrictions | Where-Object {
        $_.ReasonCode -eq 'NotAvailableForSubscription' -or
        ($_.RestrictionInfo -and $_.RestrictionInfo.Locations -contains $region)
    }
    if ($subRestriction) {
        $reason = ($skuInfo.Restrictions | ForEach-Object { $_.ReasonCode }) -join ', '
        write-host "ERROR: '$ccVmSize' is restricted for this subscription in '$region' (reason: $reason)." -ForegroundColor Red
        exit 1
    }

    $skuVCpus  = ($skuInfo.Capabilities | Where-Object Name -eq 'vCPUs' | Select-Object -First 1).Value -as [int]
    if (-not $skuVCpus) { $skuVCpus = 2 }
    $needed    = $skuVCpus * $ccNodeCount
    $skuFamily = $skuInfo.Family
    try {
        $usage = Get-AzVMUsage -Location $region -ErrorAction Stop |
            Where-Object { $_.Name.Value -eq $skuFamily } | Select-Object -First 1
        if ($usage) {
            $available = [int]$usage.Limit - [int]$usage.CurrentValue
            write-host ("Quota for {0} in {1}: {2}/{3} used, {4} vCPUs available, this pool needs {5}." -f `
                $skuFamily, $region, $usage.CurrentValue, $usage.Limit, $available, $needed) -ForegroundColor Cyan
            if ($available -lt $needed) {
                write-host "ERROR: Insufficient AMD CVM vCPU quota in '$skuFamily' / '$region' ($needed needed, $available available)." -ForegroundColor Red
                exit 1
            }
        }
    } catch {
        write-host "Warning: Get-AzVMUsage failed: $($_.Exception.Message). Continuing." -ForegroundColor Yellow
    }
    write-host "Pre-flight passed: '$ccVmSize' available with quota in '$region'." -ForegroundColor Green
}

# ---------- Resource group ------------------------------------------------------------------------
$rgTags = @{
    owner   = $ownername
    BuiltBy = $scriptName
    GitRepo = $gitRemoteUrl
    Workload = "azure-voting-app"
    CCType  = "AMD-SEV-SNP"
}
if ($description -ne "") { $rgTags.Add("description", $description) }
if ($smoketest)          { $rgTags.Add("smoketest", "true") }

New-AzResourceGroup -Name $resgrp -Location $region -Tag $rgTags -Force | Out-Null

# ---------- AKS cluster ---------------------------------------------------------------------------
# Auto-patching strategy (no preview features required, safe defaults that reflect the recommended
# Azure Policies "Kubernetes clusters should have auto-upgrade enabled" and node-image auto-upgrade):
#   --auto-upgrade-channel stable        cluster K8s version auto-upgrades to stable
#   --node-os-upgrade-channel NodeImage  node OS images auto-upgrade weekly
#   --enable-managed-identity            system-assigned MI for the cluster
#   --tier standard                      uptime SLA + financially-backed (cheap insurance)
# We deliberately keep local accounts enabled so 'az aks get-credentials' just works for the demo.
write-host "Creating AKS cluster '$aksName' (this takes ~5 minutes)..." -ForegroundColor Cyan
az aks create `
    --resource-group $resgrp `
    --name $aksName `
    --location $region `
    --node-count 1 `
    --nodepool-name $systemPool `
    --node-vm-size $systemVmSize `
    --os-sku Ubuntu `
    --enable-managed-identity `
    --generate-ssh-keys `
    --auto-upgrade-channel stable `
    --node-os-upgrade-channel NodeImage `
    --tier standard `
    --network-plugin azure `
    --tags owner=$ownername BuiltBy=$scriptName Workload=azure-voting-app `
    --only-show-errors
if ($LASTEXITCODE -ne 0) { write-host "az aks create failed" -ForegroundColor Red; exit 1 }

# ---------- AMD SEV-SNP Confidential Computing node pool ------------------------------------------
# AMD SEV-SNP CVM node pools require Ubuntu and a DCa*/ECa* v5 SKU. Secure Boot + vTPM are enabled
# implicitly by the platform when a CVM SKU is selected; no extra flags are needed.
write-host "Adding AMD SEV-SNP CC node pool '$ccPoolName' (${ccNodeCount}x $ccVmSize)..." -ForegroundColor Cyan
az aks nodepool add `
    --resource-group $resgrp `
    --cluster-name $aksName `
    --name $ccPoolName `
    --node-count $ccNodeCount `
    --node-vm-size $ccVmSize `
    --os-sku Ubuntu `
    --mode User `
    --labels workload=confidential sku=amd-sev-snp `
    --tags owner=$ownername CCType=AMD-SEV-SNP `
    --only-show-errors
if ($LASTEXITCODE -ne 0) { write-host "az aks nodepool add failed for CC pool" -ForegroundColor Red; exit 1 }

# ---------- kubectl access ------------------------------------------------------------------------
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    write-host "kubectl not found - installing via 'az aks install-cli'" -ForegroundColor Yellow
    az aks install-cli --only-show-errors | Out-Null
}
write-host "Fetching cluster credentials..." -ForegroundColor Cyan
az aks get-credentials --resource-group $resgrp --name $aksName --overwrite-existing --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) { write-host "az aks get-credentials failed" -ForegroundColor Red; exit 1 }

# Sanity: list nodes
kubectl get nodes -o wide
if ($LASTEXITCODE -ne 0) { write-host "kubectl get nodes failed - cluster not reachable" -ForegroundColor Red; exit 1 }

# ---------- Deploy public Azure Voting App (multi-container) --------------------------------------
# Source: https://github.com/Azure-Samples/azure-voting-app-redis - public images on mcr.microsoft.com
# We pin the front-end to the CC node pool via nodeSelector so the app actually runs inside SEV-SNP.
$votingManifest = @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azure-vote-back
  labels:
    app: azure-vote-back
spec:
  replicas: 1
  selector:
    matchLabels:
      app: azure-vote-back
  template:
    metadata:
      labels:
        app: azure-vote-back
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: azure-vote-back
        image: mcr.microsoft.com/oss/bitnami/redis:6.0.8
        env:
        - name: ALLOW_EMPTY_PASSWORD
          value: "yes"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        ports:
        - containerPort: 6379
          name: redis
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-back
spec:
  ports:
  - port: 6379
  selector:
    app: azure-vote-back
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azure-vote-front
  labels:
    app: azure-vote-front
spec:
  replicas: 2
  selector:
    matchLabels:
      app: azure-vote-front
  template:
    metadata:
      labels:
        app: azure-vote-front
    spec:
      nodeSelector:
        kubernetes.io/os: linux
        workload: confidential
      containers:
      - name: azure-vote-front
        # The previously-published mcr.microsoft.com/azuredocs/azure-vote-front:v1 image was
        # removed from MCR. We bootstrap the same Flask app at runtime from the public source
        # repo so the sample works first-time without requiring an attached ACR.
        image: docker.io/library/python:3.9-slim
        command: ["bash","-c"]
        args:
        - |
          set -e
          apt-get update -qq && apt-get install -y -qq --no-install-recommends git ca-certificates >/dev/null
          rm -rf /src
          git clone --depth 1 https://github.com/Azure-Samples/azure-voting-app-redis /src
          rm -rf /app && mkdir -p /app
          cp -r /src/azure-vote/azure-vote/. /app/
          cd /app
          pip install --no-cache-dir flask redis >/dev/null
          exec python -c "import sys; sys.path.insert(0,'.'); from main import app; app.run(host='0.0.0.0', port=80)"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        ports:
        - containerPort: 80
        env:
        - name: REDIS
          value: "azure-vote-back"
        startupProbe:
          httpGet: { path: /, port: 80 }
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 60
        readinessProbe:
          httpGet: { path: /, port: 80 }
          periodSeconds: 10
          failureThreshold: 6
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-front
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: azure-vote-front
'@

$manifestFile = Join-Path $env:TEMP "azure-vote-$basename.yaml"
$votingManifest | Out-File -FilePath $manifestFile -Encoding utf8 -Force
write-host "Applying voting-app manifest from $manifestFile..." -ForegroundColor Cyan
kubectl apply -f $manifestFile
if ($LASTEXITCODE -ne 0) { write-host "kubectl apply failed" -ForegroundColor Red; exit 1 }

# ---------- Wait for rollouts ---------------------------------------------------------------------
write-host "Waiting for deployments to become available..." -ForegroundColor Cyan
kubectl rollout status deployment/azure-vote-back  --timeout=5m
if ($LASTEXITCODE -ne 0) { write-host "azure-vote-back rollout failed" -ForegroundColor Red; kubectl describe deployment azure-vote-back; exit 1 }
kubectl rollout status deployment/azure-vote-front --timeout=10m
if ($LASTEXITCODE -ne 0) { write-host "azure-vote-front rollout failed" -ForegroundColor Red; kubectl describe deployment azure-vote-front; kubectl get pods -l app=azure-vote-front -o wide; exit 1 }

# ---------- Wait for LoadBalancer external IP -----------------------------------------------------
write-host "Waiting for LoadBalancer to allocate a public IP (up to 5 minutes)..." -ForegroundColor Cyan
$externalIP = $null
for ($i = 1; $i -le 30; $i++) {
    $externalIP = kubectl get service azure-vote-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($externalIP) { break }
    Start-Sleep -Seconds 10
    write-host "  ...still waiting for external IP (attempt $i/30)"
}
if (-not $externalIP) {
    write-host "Timed out waiting for external IP" -ForegroundColor Red
    kubectl describe service azure-vote-front
    exit 1
}
write-host "Voting app external IP: $externalIP" -ForegroundColor Green

# ---------- Smoke test the front-end --------------------------------------------------------------
write-host "Smoke testing http://$externalIP/ ..." -ForegroundColor Cyan
$ok = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://$externalIP/" -UseBasicParsing -TimeoutSec 10
        if ($resp.StatusCode -eq 200 -and $resp.Content -match 'Cats|Dogs|Azure Voting App') {
            $ok = $true; break
        }
    } catch { }
    Start-Sleep -Seconds 10
    write-host "  ...front-end not responding yet (attempt $i/30)"
}
if (-not $ok) {
    write-host "Front-end did not respond with expected content within 5 minutes" -ForegroundColor Red
    kubectl get pods -o wide
    kubectl logs -l app=azure-vote-front --tail=50
    exit 1
}

write-host "----------------------------------------------------------------------------------------------------------------"
write-host "SUCCESS: Azure Voting App is live at  http://$externalIP/" -ForegroundColor Green
write-host "Cluster        : $aksName"
write-host "Resource group : $resgrp"
write-host "CC node pool   : $ccPoolName  (${ccNodeCount}x $ccVmSize - AMD SEV-SNP)"
write-host "Auto-upgrade   : cluster=stable  node-os=NodeImage"
write-host "----------------------------------------------------------------------------------------------------------------"

# ---------- Deploy the runtime-attestation web UI -------------------------------------------------
# Wraps Azure/cvm-attestation-tools so a user can click "Attest" and see a fresh MAA-signed
# SEV-SNP attestation token with every claim explained. Bootstrapped at pod startup from a
# ConfigMap built from the local ./attestation/ folder (no ACR needed).
write-host "Deploying CC runtime-attestation web UI..." -ForegroundColor Cyan
$attestDir = Join-Path $PSScriptRoot 'attestation'
foreach ($f in @('app.py','config_snp.json','templates/index.html')) {
    if (-not (Test-Path (Join-Path $attestDir $f))) {
        write-host "Missing $f under $attestDir - skipping attestation deployment." -ForegroundColor Yellow
        $attestDir = $null
        break
    }
}

if ($attestDir) {
    # Build a single ConfigMap with three flat keys (app.py, config_snp.json, index.html).
    $cmYaml = kubectl create configmap cc-attest-app `
        --from-file=app.py=(Join-Path $attestDir 'app.py') `
        --from-file=config_snp.json=(Join-Path $attestDir 'config_snp.json') `
        --from-file=index.html=(Join-Path $attestDir 'templates/index.html') `
        --dry-run=client -o yaml
    if ($LASTEXITCODE -ne 0) { write-host "Failed to build attestation ConfigMap" -ForegroundColor Red; exit 1 }
    $cmFile = Join-Path $env:TEMP "cc-attest-cm-$basename.yaml"
    $cmYaml | Out-File -FilePath $cmFile -Encoding utf8 -Force
    kubectl apply -f $cmFile | Out-Null

    $attestManifest = @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cc-attest
  labels: { app: cc-attest }
spec:
  replicas: 1
  selector: { matchLabels: { app: cc-attest } }
  template:
    metadata:
      labels: { app: cc-attest }
    spec:
      nodeSelector:
        kubernetes.io/os: linux
        workload: confidential
      containers:
      - name: cc-attest
        image: docker.io/library/python:3.11-slim
        # Privileged + host TPM device passthrough so the upstream tool can read the
        # SEV-SNP HCL report from the node vTPM.
        securityContext:
          privileged: true
        env:
        - name: POD_NAME
          valueFrom: { fieldRef: { fieldPath: metadata.name } }
        - name: NODE_NAME
          valueFrom: { fieldRef: { fieldPath: spec.nodeName } }
        - name: CVM_TOOLS_DIR
          value: /opt/cvm-tools/cvm-attestation
        ports:
        - containerPort: 80
        command: ["bash","-c"]
        args:
        - |
          set -e
          export DEBIAN_FRONTEND=noninteractive
          apt-get update -qq
          apt-get install -y -qq --no-install-recommends git ca-certificates tpm2-tools >/dev/null
          rm -rf /opt/cvm-tools
          git clone --depth 1 https://github.com/Azure/cvm-attestation-tools.git /opt/cvm-tools
          cd /opt/cvm-tools/cvm-attestation
          pip install --no-cache-dir -r requirements.txt >/dev/null
          pip install --no-cache-dir flask >/dev/null
          mkdir -p /app/templates
          cp /etc/attest-app/app.py          /app/app.py
          cp /etc/attest-app/config_snp.json /app/config_snp.json
          cp /etc/attest-app/index.html      /app/templates/index.html
          exec python /app/app.py
        volumeMounts:
        - { name: tpmrm,      mountPath: /dev/tpmrm0 }
        - { name: tpm0,       mountPath: /dev/tpm0 }
        - { name: securityfs, mountPath: /sys/kernel/security, readOnly: true }
        - { name: app,        mountPath: /etc/attest-app }
        startupProbe:
          httpGet: { path: /healthz, port: 80 }
          initialDelaySeconds: 15
          periodSeconds: 10
          failureThreshold: 60
        readinessProbe:
          httpGet: { path: /healthz, port: 80 }
          periodSeconds: 10
          failureThreshold: 6
        resources:
          requests: { cpu: 100m, memory: 256Mi }
          limits:   { cpu: 1,    memory: 1Gi }
      volumes:
      - name: tpmrm
        hostPath: { path: /dev/tpmrm0, type: CharDevice }
      - name: tpm0
        hostPath: { path: /dev/tpm0,   type: CharDevice }
      - name: securityfs
        hostPath: { path: /sys/kernel/security, type: Directory }
      - name: app
        configMap:
          name: cc-attest-app
---
apiVersion: v1
kind: Service
metadata:
  name: cc-attest
spec:
  type: LoadBalancer
  selector: { app: cc-attest }
  ports:
  - port: 80
    targetPort: 80
'@

    $attestManifestFile = Join-Path $env:TEMP "cc-attest-$basename.yaml"
    $attestManifest | Out-File -FilePath $attestManifestFile -Encoding utf8 -Force
    kubectl apply -f $attestManifestFile
    if ($LASTEXITCODE -ne 0) { write-host "kubectl apply failed for attestation manifest" -ForegroundColor Red; exit 1 }

    # Restart deployment so any ConfigMap changes from re-runs are picked up.
    kubectl rollout restart deployment/cc-attest | Out-Null
    write-host "Waiting for cc-attest rollout (first run installs tpm2-tools + clones upstream)..." -ForegroundColor Cyan
    kubectl rollout status deployment/cc-attest --timeout=10m
    if ($LASTEXITCODE -ne 0) {
        write-host "cc-attest rollout failed" -ForegroundColor Red
        kubectl describe deployment cc-attest
        kubectl logs -l app=cc-attest --tail=80
    } else {
        # Wait for the attestation LoadBalancer.
        $attestIP = $null
        for ($i = 1; $i -le 30; $i++) {
            $attestIP = kubectl get service cc-attest -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
            if ($attestIP) { break }
            Start-Sleep -Seconds 10
            write-host "  ...still waiting for cc-attest external IP (attempt $i/30)"
        }
        if ($attestIP) {
            write-host "----------------------------------------------------------------------------------------------------------------"
            write-host "CC Attestation UI live at        http://$attestIP/" -ForegroundColor Green
            write-host "  Click 'Attest' to fetch a fresh MAA-signed SEV-SNP token with every claim explained."
            write-host "----------------------------------------------------------------------------------------------------------------"
        } else {
            write-host "cc-attest LoadBalancer did not get an external IP in time." -ForegroundColor Yellow
        }
    }
}

# ---------- Smoketest cleanup --------------------------------------------------------------------
if ($smoketest) {
    write-host "SMOKETEST MODE: Automatically removing all created resources..." -ForegroundColor Yellow
    write-host "Resource group: $resgrp"
    write-host "WARNING: RESOURCES ARE NOT RECOVERABLE." -ForegroundColor Red
    write-host "Press ANY KEY to cancel deletion, or wait 10 seconds to proceed..." -ForegroundColor Yellow

    $timeout = 10
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $cancelled = $false
    while ($timer.Elapsed.TotalSeconds -lt $timeout) {
        if ([Console]::KeyAvailable) { [Console]::ReadKey($true) | Out-Null; $cancelled = $true; break }
        Start-Sleep -Milliseconds 100
        $remaining = [math]::Ceiling($timeout - $timer.Elapsed.TotalSeconds)
        Write-Host "`rDeletion in $remaining seconds... (Press any key to cancel)" -NoNewline -ForegroundColor Yellow
    }
    $timer.Stop()
    if ($cancelled) {
        write-host "`nDeletion cancelled. To clean up later: Remove-AzResourceGroup -Name $resgrp -Force" -ForegroundColor Green
    } else {
        write-host "`nProceeding with resource deletion..."
        Remove-AzResourceGroup -Name $resgrp -Force -AsJob | Out-Null
        write-host "Resource group deletion initiated in background." -ForegroundColor Green
    }
} else {
    write-host ""
    write-host "Resources created in resource group: $resgrp"
    write-host "To clean up:  Remove-AzResourceGroup -Name $resgrp -Force"
}

$myTimeSpan = New-TimeSpan -Start $startTime -End (Get-Date)
Write-Output ("Execution time was {0} minutes and {1} seconds." -f $myTimeSpan.Minutes, $myTimeSpan.Seconds)
