<#
.SYNOPSIS
    Two-phase deployment script for Oracle on Azure MicroHack infrastructure.

.DESCRIPTION
    This script deploys the infrastructure in two phases to avoid Azure AD 
    eventual consistency issues:
    
    Phase 1: Create Entra ID users and group memberships (identity folder)
    Phase 2: Deploy AKS clusters and ODAA resources (main folder)
    
    By separating user creation from infrastructure deployment, we allow
    Azure AD time to propagate the user objects before they're used in
    RBAC role assignments.

.PARAMETER Phase
    Which phase to run: 'identity', 'infrastructure', or 'all' (default).
    - identity: Only create users in Entra ID
    - infrastructure: Only deploy AKS/ODAA (requires identity phase first)
    - all: Run both phases sequentially

.PARAMETER Destroy
    If specified, destroys resources instead of creating them.

.PARAMETER Plan
    If specified, only runs terraform plan without applying.

.PARAMETER AutoApprove
    If specified, skips confirmation prompts (uses -auto-approve).

.PARAMETER PropagationWait
    Additional wait time (seconds) between phases. Default: 60.
    The identity module already waits 90 seconds internally.

.EXAMPLE
    # Full deployment (both phases)
    .\deploy-two-phase.ps1

.EXAMPLE
    # Only create users
    .\deploy-two-phase.ps1 -Phase identity

.EXAMPLE
    # Only deploy infrastructure (users must exist)
    .\deploy-two-phase.ps1 -Phase infrastructure

.EXAMPLE
    # Destroy everything (infrastructure first, then identity)
    .\deploy-two-phase.ps1 -Destroy

.NOTES
    Author: Generated for Oracle on Azure MicroHack
    Requires: Terraform 1.0+, Azure CLI logged in
#>

[CmdletBinding()]
param(
    [ValidateSet('identity', 'infrastructure', 'all')]
    [string]$Phase = 'all',
    
    [switch]$Destroy,
    
    [switch]$Plan,
    
    [switch]$AutoApprove,
    
    [int]$PropagationWait = 60
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot
$TerraformRoot = Split-Path $ScriptRoot -Parent
$IdentityFolder = Join-Path $TerraformRoot 'identity'
$InfrastructureFolder = $TerraformRoot

function Write-Phase {
    param([string]$Message, [string]$Color = 'Cyan')
    Write-Host "`n$('=' * 80)" -ForegroundColor $Color
    Write-Host $Message -ForegroundColor $Color
    Write-Host "$('=' * 80)`n" -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-Host ">>> $Message" -ForegroundColor Yellow
}

function Invoke-Terraform {
    param(
        [string]$WorkingDirectory,
        [string]$Command,
        [string[]]$Arguments
    )
    
    Push-Location $WorkingDirectory
    try {
        $allArgs = @($Command) + $Arguments
        Write-Host "terraform $($allArgs -join ' ')" -ForegroundColor Gray
        & terraform @allArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform $Command failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

function Deploy-Identity {
    Write-Phase "PHASE 1: ENTRA ID IDENTITY MANAGEMENT"
    
    if (!(Test-Path $IdentityFolder)) {
        throw "Identity folder not found: $IdentityFolder"
    }
    
    Write-Step "Initializing Terraform in identity folder..."
    Invoke-Terraform -WorkingDirectory $IdentityFolder -Command 'init'
    
    if ($Plan) {
        Write-Step "Planning identity changes..."
        Invoke-Terraform -WorkingDirectory $IdentityFolder -Command 'plan'
        return
    }
    
    $applyArgs = @()
    if ($AutoApprove) { $applyArgs += '-auto-approve' }
    
    Write-Step "Applying identity configuration..."
    Invoke-Terraform -WorkingDirectory $IdentityFolder -Command 'apply' -Arguments $applyArgs
    
    Write-Host "`nIdentity deployment complete!" -ForegroundColor Green
    Write-Host "User credentials saved to: $IdentityFolder\user_credentials.json"
    Write-Host "Identity outputs saved to: $IdentityFolder\identity_outputs.json"
}

function Destroy-Identity {
    Write-Phase "DESTROYING: ENTRA ID IDENTITY RESOURCES" -Color Red
    
    if (!(Test-Path $IdentityFolder)) {
        Write-Warning "Identity folder not found, skipping: $IdentityFolder"
        return
    }
    
    $destroyArgs = @()
    if ($AutoApprove) { $destroyArgs += '-auto-approve' }
    
    Write-Step "Destroying identity resources..."
    Invoke-Terraform -WorkingDirectory $IdentityFolder -Command 'destroy' -Arguments $destroyArgs
}

function Deploy-Infrastructure {
    Write-Phase "PHASE 2: AKS AND ODAA INFRASTRUCTURE"
    
    # Check that identity outputs exist
    $identityOutputs = Join-Path $IdentityFolder 'identity_outputs.json'
    if (!(Test-Path $identityOutputs)) {
        throw @"
Identity outputs not found at: $identityOutputs

Please run the identity phase first:
    .\deploy-two-phase.ps1 -Phase identity

Or run both phases:
    .\deploy-two-phase.ps1 -Phase all
"@
    }
    
    Write-Step "Initializing Terraform in infrastructure folder..."
    Invoke-Terraform -WorkingDirectory $InfrastructureFolder -Command 'init'
    
    if ($Plan) {
        Write-Step "Planning infrastructure changes..."
        Invoke-Terraform -WorkingDirectory $InfrastructureFolder -Command 'plan' -Arguments @('-var=use_external_identity=true')
        return
    }
    
    $applyArgs = @('-var=use_external_identity=true')
    if ($AutoApprove) { $applyArgs += '-auto-approve' }
    
    Write-Step "Applying infrastructure configuration..."
    Invoke-Terraform -WorkingDirectory $InfrastructureFolder -Command 'apply' -Arguments $applyArgs
    
    Write-Host "`nInfrastructure deployment complete!" -ForegroundColor Green
}

function Destroy-Infrastructure {
    Write-Phase "DESTROYING: AKS AND ODAA INFRASTRUCTURE" -Color Red
    
    $destroyArgs = @('-var=use_external_identity=true')
    if ($AutoApprove) { $destroyArgs += '-auto-approve' }
    
    Write-Step "Destroying infrastructure resources..."
    Invoke-Terraform -WorkingDirectory $InfrastructureFolder -Command 'destroy' -Arguments $destroyArgs
}

# Main execution
try {
    if ($Destroy) {
        # Destroy in reverse order: infrastructure first, then identity
        if ($Phase -eq 'all' -or $Phase -eq 'infrastructure') {
            Destroy-Infrastructure
        }
        if ($Phase -eq 'all' -or $Phase -eq 'identity') {
            Destroy-Identity
        }
        Write-Phase "DESTROY COMPLETE" -Color Green
    }
    else {
        # Deploy in order: identity first, then infrastructure
        if ($Phase -eq 'all' -or $Phase -eq 'identity') {
            Deploy-Identity
        }
        
        if ($Phase -eq 'all') {
            Write-Phase "WAITING FOR AZURE AD PROPAGATION"
            Write-Host "Waiting $PropagationWait additional seconds for Azure AD to propagate..."
            Write-Host "(The identity module already waited 90 seconds internally)"
            
            for ($i = $PropagationWait; $i -gt 0; $i -= 10) {
                Write-Host "  $i seconds remaining..." -ForegroundColor Gray
                Start-Sleep -Seconds ([Math]::Min(10, $i))
            }
            Write-Host "Propagation wait complete.`n" -ForegroundColor Green
        }
        
        if ($Phase -eq 'all' -or $Phase -eq 'infrastructure') {
            Deploy-Infrastructure
        }
        
        Write-Phase "DEPLOYMENT COMPLETE" -Color Green
        
        if ($Phase -eq 'all') {
            Write-Host @"

Summary:
--------
- Users created and added to group: mh-odaa-user-grp
- User credentials: identity\user_credentials.json
- AKS clusters deployed with RBAC roles assigned
- VNet peering established between AKS and ODAA networks

Next steps:
-----------
1. Distribute user credentials to participants
2. Deploy ingress controllers: .\scripts\deploy-ingress-controllers.ps1
3. Optionally create Oracle databases: terraform apply -var="create_oracle_database=true" -var="use_external_identity=true"

"@
        }
    }
}
catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
