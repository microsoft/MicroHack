[CmdletBinding()]
param(
    [string]$KernelName = $(if ($env:KERNEL_NAME) { $env:KERNEL_NAME } else { 'workshop' }),
    [int]$TimeoutSeconds = $(if ($env:TIMEOUT_SECONDS) { [int]$env:TIMEOUT_SECONDS } else { 1200 }),
    [bool]$AllowErrors = $(if ($null -ne $env:ALLOW_ERRORS) { [bool]::Parse($env:ALLOW_ERRORS) } else { $true }),
    [string]$PythonBin = $(if ($env:PYTHON_BIN) { $env:PYTHON_BIN } else { 'python' })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message"
}

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

$scriptDir = Split-Path -Parent $PSCommandPath
$workshopDir = Split-Path -Parent $scriptDir
$venvPython = Join-Path $workshopDir '.venv/bin/python'

if (Test-Path $venvPython) {
    $PythonBin = $venvPython
}

Assert-Command $PythonBin

$notebooks = Get-ChildItem -Path $workshopDir -Filter '*.ipynb' -File | Sort-Object Name
if ($notebooks.Count -eq 0) {
    throw "No notebooks found in $workshopDir"
}

Write-Step "Registering Jupyter kernel '$KernelName'"
$pythonVersion = (& $PythonBin -c "import sys; print('.'.join(map(str, sys.version_info[:3])))") | Select-Object -First 1
& $PythonBin -m ipykernel install --user --name $KernelName --display-name "workshop ($pythonVersion)" *> $null

$successCount = 0
$failureCount = 0

foreach ($notebook in $notebooks) {
    Write-Step "Executing $($notebook.Name)"

    & $PythonBin -m jupyter nbconvert `
        --to notebook `
        --execute `
        --inplace `
        --ExecutePreprocessor.kernel_name=$KernelName `
        --ExecutePreprocessor.timeout=$TimeoutSeconds `
        --ExecutePreprocessor.allow_errors=$AllowErrors `
        $notebook.FullName

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Completed: $($notebook.Name)"
        $successCount++
        continue
    }

    Write-Error "Failed: $($notebook.Name)"
    $failureCount++

    if (-not $AllowErrors) {
        break
    }
}

Write-Host "`nSummary: $successCount completed, $failureCount failed"

if ($failureCount -gt 0) {
    exit 1
}