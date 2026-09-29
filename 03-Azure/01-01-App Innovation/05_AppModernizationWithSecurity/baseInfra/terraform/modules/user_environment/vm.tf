resource "random_password" "database" {
  for_each = local.stacks

  length           = 32
  special          = true
  override_special = "!#%+-_="
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "random_password" "performance_api_key" {
  for_each = local.stacks

  length  = 48
  special = false
}

resource "terraform_data" "provisioner" {
  input = local.provisioner_sha256
}

# osProfile.customData cannot be updated after a VM is created, so a changed facilitator
# identity has to replace the VM instead of producing a PUT that Azure rejects.
resource "terraform_data" "facilitator_principal" {
  input = sha256(join(":", [
    var.facilitator_principal_name,
    var.facilitator_principal_object_id
  ]))
}

resource "azapi_resource" "vm" {
  for_each = local.stacks

  type      = "Microsoft.Compute/virtualMachines@2024-11-01"
  name      = each.value.vm_name
  location  = var.location
  parent_id = azapi_resource.rg.id
  body = {
    properties = {
      hardwareProfile = { vmSize = var.vm_size }
      storageProfile = {
        osDisk = {
          createOption = "FromImage"
          deleteOption = "Delete"
          diskSizeGB   = var.os_disk_size_gb
          managedDisk  = { storageAccountType = "Premium_LRS" }
        }
        imageReference = {
          publisher = "MicrosoftWindowsServer"
          offer     = "WindowsServer"
          # Deliberately the plain Desktop Experience SKU rather than `-azure-edition`.
          # The Azure Edition images are Hotpatch-compatible, and Azure rejects them unless
          # patchMode is "AutomaticByPlatform" -- which is precisely the platform patch
          # orchestration the osProfile comment below explains this workshop cannot use.
          sku = "2025-datacenter-g2"
          # Not pinned to a patch version. Azure deprecates specific Windows Server image
          # versions within months, and a pinned version fails the deployment outright with
          # ImageVersionDeprecated once that happens -- which is exactly how the previously
          # pinned 26100.7456.251206 broke. The environment is rebuilt fresh for each
          # delivery, so tracking the current image is what keeps it deployable.
          version = "latest"
        }
      }
      osProfile = {
        computerName  = each.value.computer_name
        adminUsername = var.admin_username
        adminPassword = var.admin_password
        customData    = local.provisioner_custom_data[each.key]
        # Platform patch orchestration flips provisioningState to "Updating" during every
        # assessment and installation pass. While the VM is "Updating", az vm run-command
        # returns Conflict and the acceptance topology gate reports precondition-failed,
        # even though the VM is running and healthy. On a lab VM that lives for two days
        # that locks the attendee out of the only delivery channel for reasons unrelated to
        # their work, so patching is left to the (current) base image instead.
        windowsConfiguration = {
          enableAutomaticUpdates = false
          patchSettings          = { patchMode = "Manual" }
        }
      }
      diagnosticsProfile = {
        bootDiagnostics = { enabled = true }
      }
      networkProfile = {
        networkInterfaces = [
          {
            id         = azapi_resource.nic[each.key].id
            properties = { primary = true }
          }
        ]
      }
    }
    identity = {
      type = "SystemAssigned"
    }
  }

  lifecycle {
    precondition {
      # 87,380 base-64 characters is exactly 65,535 bytes, the documented maximum length of
      # the binary array Azure decodes osProfile.customData into.
      condition     = length(local.provisioner_custom_data[each.key]) <= 87380
      error_message = "The rendered VM custom data exceeds the 65,535-byte Azure osProfile.customData limit. Shrink baseInfra/scripts/provision-vm.ps1 or compress it inside the bundle."
    }

    replace_triggered_by = [
      terraform_data.provisioner,
      terraform_data.facilitator_principal,
      random_password.database[each.key],
      random_password.performance_api_key[each.key]
    ]
  }

  depends_on = [azapi_resource.nic]
}

resource "azapi_resource" "vm_setup" {
  for_each = local.stacks

  type      = "Microsoft.Compute/virtualMachines/extensions@2024-11-01"
  name      = "provision-${each.key}"
  location  = var.location
  parent_id = azapi_resource.vm[each.key].id
  body = {
    properties = {
      publisher               = "Microsoft.Compute"
      type                    = "CustomScriptExtension"
      typeHandlerVersion      = "1.10"
      autoUpgradeMinorVersion = false
      # Azure caps forceUpdateTag at 50 characters. The provisioner hash (64 hex) and the
      # source commit (40 hex) together are 105, so re-hash the pair instead of concatenating
      # it. Any change to either input still produces a different tag, which is the only
      # property the extension needs in order to re-run.
      forceUpdateTag = substr(sha256("${local.provisioner_sha256}-${var.source_commit}"), 0, 32)
      # The command carries only the gzipped bootstrapper, the stack name, the source commit
      # and the archive digest - all public. Every secret travels in osProfile.customData
      # instead. Keeping it in `settings` rather than `protectedSettings` is what makes a
      # failed bootstrap legible: protected commands are reported as `SecureCommand_0` with an
      # empty formattedMessage, so the extension looks identical whether it worked or threw.
      settings = {
        commandToExecute = local.provisioner_command_to_execute[each.key]
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.provisioner_command_to_execute[each.key]) <= 7800
      error_message = "The rendered Windows Custom Script Extension command exceeds the conservative 7,800-character launch limit."
    }
  }

  depends_on = [azapi_resource.vm]
}
