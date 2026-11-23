<#
.SYNOPSIS
Prepares a laptop or VM for the Offline Industrial Copilot MicroHack. Run it before the day, while you are online.
.DESCRIPTION
Creates the work folder, a Python virtual environment with the packages, copies the starter helper, downloads
the models used in the challenges, and checks the result. Safe to run again: it skips what is already there.
Through a corporate package proxy the package install can take about 10 minutes, the models 7 GB of downloads.
.EXAMPLE
powershell -ExecutionPolicy Bypass -File resources\starter\setup.ps1
.EXAMPLE
powershell -ExecutionPolicy Bypass -File resources\starter\setup.ps1 -SkipModels
#>
param(
    # Do not download the models (for example when your coach copies a model cache to the device).
    [switch]$SkipModels
)
$ErrorActionPreference = 'Stop'
$lab = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$work = Join-Path $lab 'work'
$models = @('phi-4-mini', 'qwen2.5-1.5b', 'qwen3-1.7b', 'qwen3-embedding-0.6b')
$start = Get-Date
function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

Step 'Checking Foundry Local and Python'
if (-not (Get-Command foundry -ErrorAction SilentlyContinue)) {
    throw "The 'foundry' command was not found. Install it with: winget install Microsoft.FoundryLocal (then open a new terminal)."
}
Write-Host "Foundry Local $(foundry --version)"
$python = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $python) { throw 'Python was not found. Install Python 3.11 or newer.' }
& $python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 'Python 3.11 or newer is needed, found ' + sys.version.split()[0])"

Step "Creating $work and the virtual environment"
New-Item -ItemType Directory -Force $work | Out-Null
$venvPython = Join-Path $work '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) { & $python -m venv (Join-Path $work '.venv') }
Copy-Item (Join-Path $lab 'resources\starter\fl.py') $work -Force

Step 'Installing the Python packages (the longest step behind a proxy)'
& $venvPython -m pip install --quiet --disable-pip-version-check -r (Join-Path $lab 'resources\starter\requirements.txt') foundry-local-sdk
if ($LASTEXITCODE -ne 0) { throw 'pip install failed. Behind a proxy, set PIP_INDEX_URL (and HTTPS_PROXY) and run this script again.' }

if (-not $SkipModels) {
    Step "Downloading the models: $($models -join ', ')"
    foreach ($m in $models) { foundry model download $m; if ($LASTEXITCODE -ne 0) { throw "Download of $m failed." } }
}

Step 'Checking the result'
& $venvPython -c "import openai, numpy, onnxruntime, foundry_local_sdk; print('Python packages: ok')"
$cached = (foundry model list --cached -o json | ConvertFrom-Json).models.alias
foreach ($m in $models) { Write-Host ("{0,-22} {1}" -f $m, $(if ($cached -contains $m) { 'downloaded' } else { 'MISSING' })) }
Push-Location $work
try { & $venvPython -c "import fl; m = fl.load('phi-4-mini'); r = fl.client().chat.completions.create(model=m, max_tokens=5, messages=[{'role': 'user', 'content': 'Say OK.'}]); print('Local model answers: ok (' + m + ')')" }
finally { Pop-Location }

Write-Host "`nReady in $([math]::Round(((Get-Date) - $start).TotalMinutes, 1)) minutes. Activate the environment with: $work\.venv\Scripts\Activate.ps1" -ForegroundColor Green
