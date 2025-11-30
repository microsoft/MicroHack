# ===============================================================================
# Entra ID User Management - Separate Terraform Configuration
# ===============================================================================
# This configuration manages Entra ID users and group memberships separately
# from the main infrastructure deployment. This separation:
# - Avoids Azure AD eventual consistency race conditions
# - Allows users to fully propagate before infrastructure deployment
# - Enables faster iterations on infrastructure changes
# ===============================================================================

locals {
  default_prefix = "user"

  user_indices = range(var.user_count)

  deployment_users = {
    for idx in local.user_indices :
    tostring(idx) => {
      identifier = lower(format("%s%02d", local.default_prefix, idx))
    }
  }

  shared_deployment_group = {
    name        = "mh-odaa-user-grp"
    description = "Security group with rights to deploy applications to the Oracle AKS cluster"
  }

  common_tags = {
    Project   = var.microhack_event_name
    ManagedBy = "Terraform"
    Component = "Identity"
  }
}

# ===============================================================================
# Entra ID Users and Group Membership
# ===============================================================================

module "entra_id_users" {
  source = "../modules/entra-id"

  providers = {
    azuread = azuread
  }

  aks_deployment_group_name        = local.shared_deployment_group.name
  aks_deployment_group_description = local.shared_deployment_group.description
  tenant_id                        = var.tenant_id
  user_principal_domain            = var.entra_user_principal_domain
  users                            = local.deployment_users
  azuread_propagation_wait_seconds = var.azuread_propagation_wait_seconds
  user_reset_trigger               = var.user_reset_trigger

  tags = merge(local.common_tags, {
    AKSDeploymentGroup = local.shared_deployment_group.name
  })
}

# ===============================================================================
# Consolidated User Credentials Export
# ===============================================================================
# Single JSON file containing:
# - Group information (object_id, display_name)
# - User information (object_id, user_principal_name, display_name, password)
#
# This file is consumed by:
# - Main infrastructure Terraform (reads object IDs for RBAC)
# - Event organizers (distribute credentials to participants)
#
# Output location: terraform/user_credentials.json (parent folder, not identity/)
# ===============================================================================

locals {
  # Output to parent folder (terraform root) for easy access
  # path.root is identity/, so we go up one level
  user_credentials_output_path = "${path.root}/../user_credentials.json"
}

resource "local_file" "user_credentials" {
  filename = local.user_credentials_output_path
  content = jsonencode({
    generated_at         = timestamp()
    user_reset_trigger   = var.user_reset_trigger
    microhack_event_name = var.microhack_event_name
    user_count           = var.user_count

    group = {
      object_id    = module.entra_id_users.group_object_id
      display_name = local.shared_deployment_group.name
    }

    users = {
      for idx in local.user_indices :
      format("%s%02d", local.default_prefix, idx) => {
        object_id           = module.entra_id_users.user_object_ids[tostring(idx)]
        user_principal_name = module.entra_id_users.user_principal_names[tostring(idx)]
        display_name        = module.entra_id_users.user_credentials[tostring(idx)].display_name
        password            = module.entra_id_users.user_credentials[tostring(idx)].initial_password
      }
    }
  })

  # Format the JSON file after creation for better readability
  provisioner "local-exec" {
    command     = "Get-Content '${local.user_credentials_output_path}' | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Set-Content '${local.user_credentials_output_path}' -Encoding UTF8"
    interpreter = ["pwsh", "-Command"]
  }
}

# ===============================================================================
# MFA Reset for Workshop Users
# ===============================================================================
# This null_resource triggers MFA reset when mfa_reset_trigger changes.
# It removes all MFA authentication methods (except password) from users,
# allowing new workshop attendees to register their own MFA on first login.
#
# Required: UserAuthenticationMethod.ReadWrite.All permission on service principal
# Alternative: Run scripts/reset-user-mfa.ps1 manually as Authentication Administrator
# ===============================================================================

resource "null_resource" "mfa_reset" {
  count = var.user_reset_trigger != "disabled" ? 1 : 0

  triggers = {
    user_reset_trigger = var.user_reset_trigger
    user_count         = var.user_count
  }

  # Depends on users being created first
  depends_on = [module.entra_id_users]

  provisioner "local-exec" {
    command     = <<-EOT
      $ErrorActionPreference = "Continue"
      $users = @(${join(",", [for idx in local.user_indices : format("'%s%02d@%s'", local.default_prefix, idx, var.entra_user_principal_domain)])})
      
      Write-Host "========================================" -ForegroundColor Cyan
      Write-Host "MFA Reset - Trigger: ${var.user_reset_trigger}" -ForegroundColor Cyan
      Write-Host "========================================" -ForegroundColor Cyan
      Write-Host "Users to process: $($users.Count)" -ForegroundColor Yellow
      
      $successCount = 0
      $errorCount = 0
      $noMfaCount = 0
      
      foreach ($upn in $users) {
        Write-Host "`nProcessing: $upn" -ForegroundColor Cyan
        
        try {
          # Get all authentication methods
          $methodsJson = az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/$upn/authentication/methods" 2>&1
          
          if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARN: Cannot access auth methods (permission issue) - $methodsJson" -ForegroundColor Yellow
            $errorCount++
            continue
          }
          
          $methods = $methodsJson | ConvertFrom-Json
          $mfaMethods = $methods.value | Where-Object { $_.'@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod' }
          
          if ($mfaMethods.Count -eq 0) {
            Write-Host "  No MFA methods registered" -ForegroundColor Gray
            $noMfaCount++
            continue
          }
          
          foreach ($method in $mfaMethods) {
            $methodType = $method.'@odata.type' -replace '#microsoft.graph.', ''
            $methodId = $method.id
            
            $deleteUri = switch ($methodType) {
              "phoneAuthenticationMethod" { "https://graph.microsoft.com/v1.0/users/$upn/authentication/phoneMethods/$methodId" }
              "microsoftAuthenticatorAuthenticationMethod" { "https://graph.microsoft.com/v1.0/users/$upn/authentication/microsoftAuthenticatorMethods/$methodId" }
              "softwareOathAuthenticationMethod" { "https://graph.microsoft.com/v1.0/users/$upn/authentication/softwareOathMethods/$methodId" }
              "fido2AuthenticationMethod" { "https://graph.microsoft.com/v1.0/users/$upn/authentication/fido2Methods/$methodId" }
              "emailAuthenticationMethod" { "https://graph.microsoft.com/v1.0/users/$upn/authentication/emailMethods/$methodId" }
              default { $null }
            }
            
            if ($deleteUri) {
              az rest --method DELETE --uri $deleteUri 2>&1 | Out-Null
              if ($LASTEXITCODE -eq 0) {
                Write-Host "  Removed: $methodType" -ForegroundColor Green
              }
            }
          }
          $successCount++
        } catch {
          Write-Host "  ERROR: $_" -ForegroundColor Red
          $errorCount++
        }
      }
      
      Write-Host "`n========================================" -ForegroundColor Cyan
      Write-Host "MFA Reset Complete" -ForegroundColor Cyan
      Write-Host "Processed: $successCount | No MFA: $noMfaCount | Errors: $errorCount" -ForegroundColor Yellow
      
      if ($errorCount -gt 0) {
        Write-Host "`nNote: Permission errors are expected if service principal lacks" -ForegroundColor Yellow
        Write-Host "UserAuthenticationMethod.ReadWrite.All. Run reset-user-mfa.ps1 manually." -ForegroundColor Yellow
      }
    EOT
    interpreter = ["pwsh", "-Command"]
  }
}
