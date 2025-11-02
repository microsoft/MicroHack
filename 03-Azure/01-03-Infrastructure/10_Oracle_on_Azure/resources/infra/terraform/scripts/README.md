# Scripts Directory

This directory contains utility scripts for managing the Oracle on Azure Microhack infrastructure.

## Available Scripts

### preflight-check.ps1

**Purpose**: Comprehensive pre-deployment validation script that checks all prerequisites before running Terraform.

**Usage**:

```powershell
# Basic usage (validates all prerequisites)
.\preflight-check.ps1

# Skip VM quota checks (faster validation)
.\preflight-check.ps1 -SkipQuotaCheck

# Use custom configuration file
.\preflight-check.ps1 -ConfigFile "..\custom.tfvars"
```

**What it checks**:

* Required tools installation (Terraform, Azure CLI, kubectl, helm)
* Azure authentication status
* Access to all configured subscriptions
* Management group existence and permissions
* Oracle Cloud service principal configuration
* Resource provider registrations
* Oracle SDN feature flags
* VM quota availability across subscriptions
* users.json file structure and completeness
* Terraform initialization and configuration validity

**Exit codes**:

* `0` - All checks passed or passed with warnings
* `1` - One or more critical checks failed

**Output**: Color-coded results with actionable remediation steps for any failures.

---

### cleanup-entra-groups.ps1

**Purpose**: Cleanup script for removing Entra ID groups created by the deployment.

**Usage**:

```powershell
.\cleanup-entra-groups.ps1
```

**Note**: Use this script when Terraform destroy leaves behind Entra ID resources.

---

### register-oracle-sdn.ps1

**Purpose**: Bulk registration of Oracle SDN features across multiple subscriptions.

**Usage**:

```powershell
# Edit the script to add your subscription IDs
.\register-oracle-sdn.ps1
```

**What it does**:

* Registers `Microsoft.Baremetal/EnableRotterdamSdnApplianceForOracle` feature
* Registers `Microsoft.Network/EnableRotterdamSdnApplianceForOracle` feature
* Refreshes provider registrations after feature approval

**Note**: Feature registration can take 10-15 minutes to complete.

---

### monitor-odaa-deployment.ps1

**Purpose**: Monitor and analyze Oracle Database@Azure Autonomous Database deployment timeline with detailed phase breakdowns.

**Usage**:

```powershell
# Basic usage - generates detailed report
.\monitor-odaa-deployment.ps1 `
  -ResourceGroupName "odaa-shared" `
  -DatabaseName "user00" `
  -CompartmentId "ocid1.compartment.oc1..aaaaaa..."

# Generate JSON output for automation
.\monitor-odaa-deployment.ps1 `
  -ResourceGroupName "odaa-shared" `
  -DatabaseName "user00" `
  -CompartmentId "ocid1.compartment.oc1..aaaaaa..." `
  -OutputFormat Json

# Export timeline to file
.\monitor-odaa-deployment.ps1 `
  -ResourceGroupName "odaa-shared" `
  -DatabaseName "user00" `
  -CompartmentId "ocid1.compartment.oc1..aaaaaa..." `
  -ExportPath ".\deployment-timeline.txt"

# Analyze specific time range
.\monitor-odaa-deployment.ps1 `
  -ResourceGroupName "odaa-shared" `
  -DatabaseName "user00" `
  -CompartmentId "ocid1.compartment.oc1..aaaaaa..." `
  -StartTime "2025-11-02T08:00:00Z" `
  -EndTime "2025-11-02T10:00:00Z"

# Table format for quick view
.\monitor-odaa-deployment.ps1 `
  -ResourceGroupName "odaa-shared" `
  -DatabaseName "user00" `
  -CompartmentId "ocid1.compartment.oc1..aaaaaa..." `
  -OutputFormat Table
```

**Parameters**:

* `ResourceGroupName` - Azure resource group containing the database (required)
* `DatabaseName` - Name of the Autonomous Database to monitor (required)
* `CompartmentId` - OCI compartment OCID (required)
* `SubscriptionId` - Azure subscription ID (optional, uses current if not specified)
* `StartTime` - Start time in ISO 8601 format (optional, defaults to 24 hours ago)
* `EndTime` - End time in ISO 8601 format (optional, defaults to now)
* `OutputFormat` - Output format: Report, Table, or Json (default: Report)
* `ExportPath` - Path to export results to a file (optional)

**What it provides**:

* Total deployment duration calculation
* Phase-by-phase breakdown with timing
  * VCN infrastructure provisioning
  * Network resources (IPs, gateways)
  * Database and security provisioning
  * DNS configuration
* Azure Activity Log timeline
* OCI resource creation timeline grouped by type
* Commands used to generate the report (for reproducibility)

**Output formats**:

* **Report** (default): Detailed text report with deployment analysis
* **Table**: Tabular output for quick scanning
* **Json**: Structured JSON for integration with other tools

**Example output**:

```text
================================================================================
ODAA AUTONOMOUS DATABASE DEPLOYMENT TIMELINE REPORT
================================================================================

Database Information:
  Name:              user00
  Resource Group:    odaa-shared
  Subscription ID:   4aecf0e8-2fe2-4187-bc93-0356bd2676f5
  OCI Compartment:   ocid1.compartment.oc1..aaaaaa...

Deployment Summary:
  Start Time:        2025-11-02 08:52:57 UTC
  End Time:          2025-11-02 09:08:41 UTC
  Total Duration:    15m 44s

================================================================================
DEPLOYMENT PHASES ANALYSIS
================================================================================

Phase 1: VCN Infrastructure (7 resources)
  Start:    08:53:45
  End:      08:53:47
  Duration: 2 seconds

Phase 2: Network Resources (12 resources)
  Start:    08:53:59
  End:      08:55:30
  Duration: 91 seconds

Phase 3: Database Provisioning (2 resources)
  Start:    08:57:04
  End:      08:59:20
  Duration: 136 seconds

Phase 4: DNS Configuration (8 resources)
  Start:    08:53:46
  End:      09:00:55
  Duration: 429 seconds
```

**Requirements**:

* Azure CLI (az) authenticated
* OCI CLI (oci) configured
* PowerShell 7+

---

## Quick Start Workflow

```powershell
# 1. Run pre-flight checks
cd scripts
.\preflight-check.ps1

# 2. If Oracle SDN features need registration
.\register-oracle-sdn.ps1
# Wait 10-15 minutes for feature registration

# 3. Re-run pre-flight checks to confirm
.\preflight-check.ps1

# 4. Proceed with Terraform deployment
cd ..
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## Troubleshooting

### "Execution of scripts is disabled on this system"

PowerShell execution policy prevents script execution.

**Solution**:

```powershell
# Temporarily allow scripts for current session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Or sign the script (recommended for production)
```

### "az: command not found"

Azure CLI is not installed or not in PATH.

**Solution**:

```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Restart your terminal
```

### Pre-flight check shows warnings

Warnings indicate potential issues that may not block deployment but should be reviewed.

**Common warnings**:

* Resource providers in "Registering" state (wait for completion)
* Insufficient VM quota (request increase or reduce user_count)
* Missing optional tools (kubectl, helm) - only required for post-deployment verification

---

## Contributing

When adding new scripts:

1. Follow PowerShell best practices
2. Include proper parameter documentation
3. Add error handling and validation
4. Update this README with usage instructions
5. Use color-coded output for user feedback:
   * Green: Success
   * Yellow: Warning
   * Red: Error
   * Cyan: Information

## Support

For issues with scripts, refer to:

* Main README.md in the parent directory
* Terraform documentation for configuration issues
* Azure CLI documentation for authentication issues
