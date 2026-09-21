<#
.SYNOPSIS
  Deploys the upstream Azure Voting App sample to confidential AKS nodes.

.DESCRIPTION
  Adapts the upstream Azure Voting App confidential-computing sample to the
  provided MicroHack AKS cluster shared with Challenge 7. Only Challenge 5
  workloads in its owned namespace are deployed or removed.

.EXAMPLE
  ./Deploy-VotingAppCC.ps1 -Deploy
  ./Deploy-VotingAppCC.ps1 -Cleanup
#>
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
#   ./Deploy-VotingAppCC.ps1 -Deploy -ClusterName <Console cluster name>
#   ./Deploy-VotingAppCC.ps1 -Cleanup
#
# Requirements:
#   - Azure CLI signed in to the subscription containing the provided AKS cluster
#   - kubectl installed on PATH

[CmdletBinding(DefaultParameterSetName='Help')]
param (
  [Parameter(ParameterSetName='Deploy')][switch]$Deploy,
  [Parameter(ParameterSetName='Cleanup')][switch]$Cleanup,
  [string]$ResourceGroup = $env:RESOURCE_GROUP,
  [string]$ClusterName = $env:AKS_CLUSTER,
  [string]$ConfidentialNodePool = 'cvmnodepool'
)

if ($PSCmdlet.ParameterSetName -eq 'Help') {
  Get-Help $PSCommandPath -Detailed
  return
}

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

foreach ($requiredValue in @{
  RESOURCE_GROUP = $ResourceGroup
  AKS_CLUSTER = $ClusterName
  }.GetEnumerator()) {
  if ([string]::IsNullOrWhiteSpace($requiredValue.Value)) {
    throw "$($requiredValue.Key) is not set. Define the MicroHack environment variables before running this script."
  }
}

$subsID = (az account show --query id --output tsv 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $subsID) { throw 'Azure CLI is not signed in. Run az login.' }
$sampleDirectory = Join-Path $PSScriptRoot 'resources/azure-voting-app'
$startTime = Get-Date
$resgrp = $ResourceGroup
$aksName = $ClusterName
$ccPoolName = $ConfidentialNodePool
$namespace = 'challenge-05'
$contextName = "challenge-05-$subsID-$aksName"
$basename = [guid]::NewGuid().ToString('N')
$kubeconfigPath = Join-Path ([IO.Path]::GetTempPath()) "challenge-05-$basename.kubeconfig"
$manifestFile = $null
$cmFile = $null
$attestManifestFile = $null
$kubectlScope = @('--kubeconfig', $kubeconfigPath, '--context', $contextName, '--namespace', $namespace)
$clusterJson = az aks show --subscription $subsID --resource-group $resgrp --name $aksName --output json --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the provided AKS cluster. Verify the Console cluster name and subscription.' }
$cluster = ($clusterJson -join "`n") | ConvertFrom-Json
if ($cluster.provisioningState -ne 'Succeeded') { throw 'The provided AKS cluster is not ready. Ask the facilitator to finish provisioning.' }
if ($Deploy) {
  $poolJson = az aks nodepool show --subscription $subsID --resource-group $resgrp --cluster-name $aksName --name $ccPoolName --output json --only-show-errors
  if ($LASTEXITCODE -ne 0) { throw 'The provided confidential pool is missing. This script does not create node pools.' }
  $pool = ($poolJson -join "`n") | ConvertFrom-Json
  if ($pool.provisioningState -ne 'Succeeded' -or $pool.count -ne 2 -or $pool.osSKU -ne 'Ubuntu' -or
    $pool.vmSize -notmatch '^Standard_DC2as_v[56]$' -or $pool.mode -ne 'User' -or
    $pool.nodeLabels.workload -ne 'confidential') {
    throw 'Expected two ready Ubuntu Standard_DC2as_v5/v6 user nodes labelled workload=confidential. Ask the facilitator to align the shared pool; no infrastructure was changed.'
  }
  $ccVmSize = $pool.vmSize
  $ccNodeCount = $pool.count
}
Write-Host "Using provided AKS cluster '$aksName' in '$($cluster.location)' (subscription $subsID), namespace $namespace."
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
  throw 'kubectl is required. Install it before running Challenge 5.'
}
try {
az aks get-credentials --subscription $subsID --resource-group $resgrp --name $aksName --file $kubeconfigPath --context $contextName --overwrite-existing --only-show-errors | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'az aks get-credentials failed.' }
$namespaceJson = kubectl @kubectlScope get namespace $namespace --ignore-not-found -o json
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the Challenge 5 namespace.' }
$existingNamespace = if ($namespaceJson) { ($namespaceJson -join "`n") | ConvertFrom-Json }
if ($existingNamespace -and $existingNamespace.metadata.labels.'microhack-challenge' -ne '05') {
  throw 'The challenge-05 namespace exists without the expected ownership label. No changes were made.'
}
if ($Cleanup) {
  if ($existingNamespace) {
    kubectl @kubectlScope delete deployment/azure-vote-back deployment/azure-vote-front deployment/cc-attest service/azure-vote-back service/azure-vote-front service/cc-attest configmap/cc-attest-app --ignore-not-found --timeout=5m
    if ($LASTEXITCODE -ne 0) { throw 'Challenge 5 application cleanup failed.' }
  }
  Write-Host 'Challenge 5 applications removed. Shared AKS, node pools, namespace and Challenge 7 resources were retained.'
  return
}
if ($existingNamespace -and ($existingNamespace.metadata.labels.'istio.io/rev' -or
    $existingNamespace.metadata.labels.'istio-injection' -eq 'enabled')) {
  throw 'Challenge 5 requires its namespace without Istio sidecar injection. Ask the facilitator to review the namespace labels.'
}
if (-not $existingNamespace) {
  @{ apiVersion = 'v1'; kind = 'Namespace'; metadata = @{ name = $namespace; labels = @{ 'microhack-challenge' = '05'; 'istio-injection' = 'disabled' } } } |
    ConvertTo-Json -Depth 5 | kubectl @kubectlScope apply -f -
  if ($LASTEXITCODE -ne 0) { throw 'Cannot create the Challenge 5 namespace.' }
}
kubectl @kubectlScope get nodes -o wide
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

$manifestFile = Join-Path ([IO.Path]::GetTempPath()) "azure-vote-$basename.yaml"
$votingManifest | Out-File -FilePath $manifestFile -Encoding utf8 -Force
write-host "Applying voting-app manifest from $manifestFile..." -ForegroundColor Cyan
kubectl @kubectlScope apply -f $manifestFile
if ($LASTEXITCODE -ne 0) { write-host "kubectl apply failed" -ForegroundColor Red; exit 1 }

# ---------- Wait for rollouts ---------------------------------------------------------------------
write-host "Waiting for deployments to become available..." -ForegroundColor Cyan
kubectl @kubectlScope rollout status deployment/azure-vote-back  --timeout=5m
if ($LASTEXITCODE -ne 0) { write-host "azure-vote-back rollout failed" -ForegroundColor Red; kubectl @kubectlScope describe deployment azure-vote-back; exit 1 }
kubectl @kubectlScope rollout status deployment/azure-vote-front --timeout=10m
if ($LASTEXITCODE -ne 0) { write-host "azure-vote-front rollout failed" -ForegroundColor Red; kubectl @kubectlScope describe deployment azure-vote-front; kubectl @kubectlScope get pods -l app=azure-vote-front -o wide; exit 1 }

# ---------- Wait for LoadBalancer external IP -----------------------------------------------------
write-host "Waiting for LoadBalancer to allocate a public IP (up to 5 minutes)..." -ForegroundColor Cyan
$externalIP = $null
for ($i = 1; $i -le 30; $i++) {
    $externalIP = kubectl @kubectlScope get service azure-vote-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($externalIP) { break }
    Start-Sleep -Seconds 10
    write-host "  ...still waiting for external IP (attempt $i/30)"
}
if (-not $externalIP) {
    write-host "Timed out waiting for external IP" -ForegroundColor Red
    kubectl @kubectlScope describe service azure-vote-front
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
    kubectl @kubectlScope get pods -o wide
    kubectl @kubectlScope logs -l app=azure-vote-front --tail=50
    exit 1
}

write-host "----------------------------------------------------------------------------------------------------------------"
write-host "SUCCESS: Azure Voting App is live at  http://$externalIP/" -ForegroundColor Green
write-host "Cluster        : $aksName"
write-host "Resource group : $resgrp"
write-host "CC node pool   : $ccPoolName  (${ccNodeCount}x $ccVmSize - AMD SEV-SNP)"
write-host "Namespace      : $namespace"
write-host "----------------------------------------------------------------------------------------------------------------"

# ---------- Deploy the runtime-attestation web UI -------------------------------------------------
# Wraps Azure/cvm-attestation-tools so a user can click "Attest" and see a fresh MAA-signed
# SEV-SNP attestation token with every claim explained. Bootstrapped at pod startup from a
# ConfigMap built from the local ./attestation/ folder (no ACR needed).
write-host "Deploying CC runtime-attestation web UI..." -ForegroundColor Cyan
$attestDir = Join-Path $sampleDirectory 'attestation'
foreach ($f in @('app.py','config_snp.json','templates/index.html')) {
    if (-not (Test-Path (Join-Path $attestDir $f))) {
        throw "Missing attestation asset $f under $attestDir. Use a complete repository checkout."
    }
}

if ($attestDir) {
    # Build a single ConfigMap with three flat keys (app.py, config_snp.json, index.html).
  $attestAppPath = Join-Path $attestDir 'app.py'
  $attestConfigPath = Join-Path $attestDir 'config_snp.json'
  $attestTemplatePath = Join-Path $attestDir 'templates/index.html'
    $cmYaml = kubectl @kubectlScope create configmap cc-attest-app `
    "--from-file=app.py=$attestAppPath" `
    "--from-file=config_snp.json=$attestConfigPath" `
    "--from-file=index.html=$attestTemplatePath" `
        --dry-run=client -o yaml
    if ($LASTEXITCODE -ne 0) { write-host "Failed to build attestation ConfigMap" -ForegroundColor Red; exit 1 }
    $cmFile = Join-Path ([IO.Path]::GetTempPath()) "cc-attest-cm-$basename.yaml"
    $cmYaml | Out-File -FilePath $cmFile -Encoding utf8 -Force
    kubectl @kubectlScope apply -f $cmFile | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot apply the attestation ConfigMap.' }

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

    $attestManifestFile = Join-Path ([IO.Path]::GetTempPath()) "cc-attest-$basename.yaml"
    $attestManifest | Out-File -FilePath $attestManifestFile -Encoding utf8 -Force
    kubectl @kubectlScope apply -f $attestManifestFile
    if ($LASTEXITCODE -ne 0) { write-host "kubectl apply failed for attestation manifest" -ForegroundColor Red; exit 1 }

    # Restart deployment so any ConfigMap changes from re-runs are picked up.
    kubectl @kubectlScope rollout restart deployment/cc-attest | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot restart the attestation deployment.' }
    write-host "Waiting for cc-attest rollout (first run installs tpm2-tools + clones upstream)..." -ForegroundColor Cyan
    kubectl @kubectlScope rollout status deployment/cc-attest --timeout=10m
    if ($LASTEXITCODE -ne 0) {
        write-host "cc-attest rollout failed" -ForegroundColor Red
        kubectl @kubectlScope describe deployment cc-attest
        kubectl @kubectlScope logs -l app=cc-attest --tail=80
        throw 'Attestation rollout failed.'
    } else {
        # Wait for the attestation LoadBalancer.
        $attestIP = $null
        for ($i = 1; $i -le 30; $i++) {
            $attestIP = kubectl @kubectlScope get service cc-attest -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
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
            throw 'Attestation LoadBalancer did not get an external IP in time.'
        }
    }
}

# ---------- MicroHack cleanup guidance ------------------------------------------------------------
write-host ""
write-host "Resources created in resource group: $resgrp"
write-host "To clean up:  ./Deploy-VotingAppCC.ps1 -Cleanup"

$myTimeSpan = New-TimeSpan -Start $startTime -End (Get-Date)
Write-Output ("Execution time was {0} minutes and {1} seconds." -f $myTimeSpan.Minutes, $myTimeSpan.Seconds)
}
finally {
  foreach ($temporaryFile in @($kubeconfigPath, $manifestFile, $cmFile, $attestManifestFile)) {
    if ($temporaryFile -and (Test-Path -LiteralPath $temporaryFile)) {
      Remove-Item -LiteralPath $temporaryFile -Force
    }
  }
}
