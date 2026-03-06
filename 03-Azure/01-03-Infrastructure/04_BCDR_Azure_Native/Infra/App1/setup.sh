#!/bin/bash

# =============================================================================
# Azure BCDR MicroHack - Automated Setup Script
# =============================================================================
# This script automates the complete setup of the BCDR MicroHack environment:
# - Prerequisites validation
# - Parameter configuration
# - Infrastructure deployment
# - Post-deployment verification
# =============================================================================

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Default values
DEFAULT_SOURCE_LOCATION="germanywestcentral"
DEFAULT_TARGET_LOCATION="swedencentral"
DEPLOYMENT_PREFIX=""
VM_ADMIN_PASSWORD=""
SOURCE_LOCATION=""
TARGET_LOCATION=""
SKIP_VALIDATION=false
USE_BICEP=true
AUTO_APPROVE=false

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_banner() {
    echo -e "${CYAN}"
    echo "============================================================"
    echo "     Azure BCDR MicroHack - Automated Setup"
    echo "============================================================"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}${BOLD}==> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Automated setup script for the Azure BCDR MicroHack environment.

OPTIONS:
    -p, --prefix PREFIX         Deployment prefix (e.g., mh01, mh02)
    -w, --password PASSWORD     VM admin password
    -s, --source-location LOC   Source region (default: germanywestcentral)
    -t, --target-location LOC   Target region (default: swedencentral)
    --skip-validation           Skip prerequisites validation
    --use-arm                   Use ARM template instead of Bicep
    -y, --yes                   Auto-approve deployment (no confirmation)
    -h, --help                  Show this help message

EXAMPLES:
    # Interactive mode (prompts for all values)
    ./setup.sh

    # Non-interactive with all parameters
    ./setup.sh -p mh01 -w 'MySecureP@ssw0rd!' -y

    # Use ARM template instead of Bicep
    ./setup.sh -p mh01 -w 'MySecureP@ssw0rd!' --use-arm

EOF
}

# Password validation function
validate_password() {
    local password="$1"
    local errors=()

    # Check length (12-123 characters)
    if [ ${#password} -lt 12 ] || [ ${#password} -gt 123 ]; then
        errors+=("Password must be between 12 and 123 characters")
    fi

    # Check complexity (at least 3 of: uppercase, lowercase, digit, special)
    local complexity=0
    [[ "$password" =~ [A-Z] ]] && ((complexity++))
    [[ "$password" =~ [a-z] ]] && ((complexity++))
    [[ "$password" =~ [0-9] ]] && ((complexity++))
    [[ "$password" =~ [^a-zA-Z0-9] ]] && ((complexity++))

    if [ $complexity -lt 3 ]; then
        errors+=("Password must contain at least 3 of: uppercase, lowercase, digit, special character")
    fi

    if [ ${#errors[@]} -gt 0 ]; then
        for err in "${errors[@]}"; do
            print_error "$err"
        done
        return 1
    fi
    return 0
}

# Validate deployment prefix
validate_prefix() {
    local prefix="$1"

    # Check if prefix starts with alphanumeric and contains only allowed characters
    if [[ ! "$prefix" =~ ^[a-z][a-z0-9]{1,5}$ ]]; then
        print_error "Prefix must be 2-6 lowercase alphanumeric characters, starting with a letter"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Prerequisites Validation (embedded from validate-prerequisites.sh)
# -----------------------------------------------------------------------------

run_prerequisites_check() {
    print_step "Validating Prerequisites"

    local errors=0
    local warnings=0

    # Required resource providers
    local REQUIRED_PROVIDERS=(
        "Microsoft.Compute"
        "Microsoft.Network"
        "Microsoft.Storage"
        "Microsoft.RecoveryServices"
        "Microsoft.DataProtection"
        "Microsoft.Automation"
        "Microsoft.OperationalInsights"
        "Microsoft.KeyVault"
        "Microsoft.SqlVirtualMachine"
        "Microsoft.Resources"
    )

    # Check Azure CLI
    echo -e "\n${BLUE}[1/4]${NC} Checking Azure CLI..."
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        print_info "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        return 1
    fi
    local az_version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
    print_success "Azure CLI installed (version: $az_version)"

    # Check authentication
    echo -e "\n${BLUE}[2/4]${NC} Checking Azure authentication..."
    if ! az account show &> /dev/null; then
        print_error "Not authenticated to Azure"
        print_info "Run 'az login' to authenticate"
        return 1
    fi

    local account_name=$(az account show --query "user.name" -o tsv 2>/dev/null)
    local subscription_name=$(az account show --query "name" -o tsv 2>/dev/null)
    local subscription_id=$(az account show --query "id" -o tsv 2>/dev/null)
    print_success "Authenticated as: $account_name"
    print_info "Subscription: $subscription_name"
    print_info "Subscription ID: $subscription_id"

    # Store subscription ID for later use
    SUBSCRIPTION_ID="$subscription_id"

    # Check RBAC permissions
    echo -e "\n${BLUE}[3/4]${NC} Checking RBAC permissions..."
    local has_permission=false

    # Try to validate permissions by checking role assignments
    local role_assignments=$(az role assignment list --assignee "$(az account show --query 'user.name' -o tsv)" \
        --scope "/subscriptions/$subscription_id" --query "[].roleDefinitionName" -o tsv 2>/dev/null || true)

    if echo "$role_assignments" | grep -qE "^(Owner|Contributor)$"; then
        print_success "Has sufficient permissions"
        has_permission=true
    else
        # Try capability check by validating we can list resource groups
        if az group list --query "[0]" &> /dev/null; then
            print_warning "Unable to verify role assignment, but basic access confirmed"
            has_permission=true
        else
            print_error "Insufficient permissions - Owner or Contributor role required"
            ((errors++))
        fi
    fi

    # Check resource providers
    echo -e "\n${BLUE}[4/4]${NC} Checking resource providers..."
    local unregistered=()

    for provider in "${REQUIRED_PROVIDERS[@]}"; do
        local state=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")

        if [ "$state" = "Registered" ]; then
            print_success "$provider"
        else
            print_warning "$provider not registered (attempting registration...)"
            if az provider register --namespace "$provider" &> /dev/null; then
                print_success "$provider registration initiated"
            else
                print_error "Failed to register $provider"
                ((errors++))
            fi
        fi
    done

    # Summary
    echo ""
    if [ $errors -eq 0 ]; then
        print_success "All prerequisites validated successfully"
        return 0
    else
        print_error "Prerequisites check failed with $errors error(s)"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Parameter Collection
# -----------------------------------------------------------------------------

collect_parameters() {
    print_step "Configuring Deployment Parameters"

    # Deployment prefix
    if [ -z "$DEPLOYMENT_PREFIX" ]; then
        echo ""
        print_info "Enter a unique deployment prefix (2-6 lowercase alphanumeric chars)"
        print_info "Example: mh01, mh02, etc."
        while true; do
            read -p "Deployment prefix: " DEPLOYMENT_PREFIX
            if validate_prefix "$DEPLOYMENT_PREFIX"; then
                break
            fi
        done
    else
        if ! validate_prefix "$DEPLOYMENT_PREFIX"; then
            return 1
        fi
    fi

    # VM Admin Password
    if [ -z "$VM_ADMIN_PASSWORD" ]; then
        echo ""
        print_info "Enter VM admin password (12-123 chars, 3 of: upper/lower/digit/special)"
        while true; do
            read -s -p "VM Admin Password: " VM_ADMIN_PASSWORD
            echo ""
            if validate_password "$VM_ADMIN_PASSWORD"; then
                read -s -p "Confirm Password: " password_confirm
                echo ""
                if [ "$VM_ADMIN_PASSWORD" = "$password_confirm" ]; then
                    break
                else
                    print_error "Passwords do not match"
                fi
            fi
        done
    else
        if ! validate_password "$VM_ADMIN_PASSWORD"; then
            return 1
        fi
    fi

    # Source location
    if [ -z "$SOURCE_LOCATION" ]; then
        SOURCE_LOCATION="$DEFAULT_SOURCE_LOCATION"
    fi

    # Target location
    if [ -z "$TARGET_LOCATION" ]; then
        TARGET_LOCATION="$DEFAULT_TARGET_LOCATION"
    fi

    # Summary
    echo ""
    print_info "Deployment Configuration:"
    echo "  - Prefix:          $DEPLOYMENT_PREFIX"
    echo "  - Source Region:   $SOURCE_LOCATION"
    echo "  - Target Region:   $TARGET_LOCATION"
    echo "  - Template Type:   $([ "$USE_BICEP" = true ] && echo "Bicep" || echo "ARM")"

    return 0
}

# -----------------------------------------------------------------------------
# Infrastructure Deployment
# -----------------------------------------------------------------------------

deploy_infrastructure() {
    print_step "Deploying Infrastructure"

    local deployment_name="${DEPLOYMENT_PREFIX}-bcdr-deployment-$(date +%Y%m%d%H%M%S)"

    # Confirmation
    if [ "$AUTO_APPROVE" != true ]; then
        echo ""
        print_warning "This will deploy the following resources:"
        echo "  - Resource Groups in $SOURCE_LOCATION and $TARGET_LOCATION"
        echo "  - Virtual Networks with peering"
        echo "  - 4 Virtual Machines (2 web, 1 SQL, 1 Linux)"
        echo "  - Azure Bastion"
        echo "  - Recovery Services Vaults"
        echo "  - Storage Account (GRS)"
        echo "  - Load Balancers and Traffic Manager"
        echo "  - Key Vault, Log Analytics, and more"
        echo ""
        read -p "Do you want to proceed? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Deployment cancelled"
            exit 0
        fi
    fi

    echo ""
    print_info "Starting deployment: $deployment_name"
    print_info "This may take 20-30 minutes..."
    echo ""

    # Create temporary parameters file with actual values
    local temp_params=$(mktemp)
    cat > "$temp_params" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "parDeploymentPrefix": { "value": "$DEPLOYMENT_PREFIX" },
    "sourceLocation": { "value": "$SOURCE_LOCATION" },
    "targetLocation": { "value": "$TARGET_LOCATION" },
    "vmAdminPassword": { "value": "$VM_ADMIN_PASSWORD" },
    "hubVnetConfig": {
      "value": {
        "addressSpace": { "addressPrefixes": ["10.0.0.0/16"] },
        "subnets": [
          { "name": "default", "addressPrefix": "10.0.0.0/24" },
          { "name": "AzureBastionSubnet", "addressPrefix": "10.0.1.0/24" }
        ]
      }
    },
    "sourceVnetConfig": {
      "value": {
        "addressSpace": { "addressPrefixes": ["10.1.0.0/16"] },
        "subnets": [{ "name": "default", "addressPrefix": "10.1.0.0/24" }]
      }
    },
    "targetVnetConfig": {
      "value": {
        "addressSpace": { "addressPrefixes": ["10.2.0.0/16"] },
        "subnets": [{ "name": "default", "addressPrefix": "10.2.0.0/24" }]
      }
    },
    "testVnetConfig": {
      "value": {
        "addressSpace": { "addressPrefixes": ["10.3.0.0/16"] },
        "subnets": [{ "name": "default", "addressPrefix": "10.3.0.0/24" }]
      }
    },
    "vmConfigs": {
      "value": [
        {
          "purpose": "web", "deploy": true, "nameSuffix": "web1",
          "vmSize": "Standard_D2as_v6", "osDiskSize": 127, "dataDiskSize": 0,
          "osType": "Windows", "imagePublisher": "MicrosoftWindowsServer",
          "imageOffer": "WindowsServer", "imageSku": "2019-datacenter-gensecond",
          "imageVersion": "latest", "publicIp": false
        },
        {
          "purpose": "web", "deploy": true, "nameSuffix": "web2",
          "vmSize": "Standard_D2as_v6", "osDiskSize": 127, "dataDiskSize": 0,
          "osType": "Windows", "imagePublisher": "MicrosoftWindowsServer",
          "imageOffer": "WindowsServer", "imageSku": "2019-datacenter-gensecond",
          "imageVersion": "latest", "publicIp": false
        },
        {
          "purpose": "sql", "deploy": true, "nameSuffix": "sql",
          "vmSize": "Standard_D4as_v6", "osDiskSize": 127, "dataDiskSize": 1024,
          "osType": "Windows", "imagePublisher": "MicrosoftSQLServer",
          "imageOffer": "SQL2019-WS2019", "imageSku": "standard-gen2",
          "imageVersion": "latest", "publicIp": false
        },
        {
          "purpose": "linux", "deploy": true, "nameSuffix": "linux",
          "vmSize": "Standard_D2as_v6", "osDiskSize": 127, "dataDiskSize": 1024,
          "osType": "Linux", "imagePublisher": "Canonical",
          "imageOffer": "UbuntuServer", "imageSku": "18_04-lts-gen2",
          "imageVersion": "latest", "publicIp": false
        }
      ]
    }
  }
}
EOF

    # Run deployment
    local deploy_result
    if [ "$USE_BICEP" = true ]; then
        print_info "Deploying with Bicep template..."
        deploy_result=$(az deployment sub create \
            --name "$deployment_name" \
            --location "$SOURCE_LOCATION" \
            --template-file "$SCRIPT_DIR/deploy.bicep" \
            --parameters "@$temp_params" \
            --output json 2>&1) || {
            rm -f "$temp_params"
            print_error "Deployment failed"
            echo "$deploy_result"
            return 1
        }
    else
        print_info "Deploying with ARM template..."
        deploy_result=$(az deployment sub create \
            --name "$deployment_name" \
            --location "$SOURCE_LOCATION" \
            --template-file "$SCRIPT_DIR/deploy.json" \
            --parameters "@$temp_params" \
            --output json 2>&1) || {
            rm -f "$temp_params"
            print_error "Deployment failed"
            echo "$deploy_result"
            return 1
        }
    fi

    rm -f "$temp_params"

    # Extract outputs
    local traffic_manager_fqdn=$(echo "$deploy_result" | jq -r '.properties.outputs.fqdn.value // empty')
    local vm_username=$(echo "$deploy_result" | jq -r '.properties.outputs.vmUserName.value // empty')

    print_success "Deployment completed successfully!"

    # Store for verification
    TRAFFIC_MANAGER_FQDN="$traffic_manager_fqdn"
    VM_USERNAME="$vm_username"

    return 0
}

# -----------------------------------------------------------------------------
# Post-Deployment Verification
# -----------------------------------------------------------------------------

verify_deployment() {
    print_step "Verifying Deployment"

    local source_rg="${DEPLOYMENT_PREFIX}-source-${SOURCE_LOCATION}-rg"
    local target_rg="${DEPLOYMENT_PREFIX}-target-${TARGET_LOCATION}-rg"
    local errors=0

    echo ""

    # Check resource groups
    print_info "Checking resource groups..."
    if az group show --name "$source_rg" &> /dev/null; then
        print_success "Source resource group: $source_rg"
    else
        print_error "Source resource group not found: $source_rg"
        ((errors++))
    fi

    if az group show --name "$target_rg" &> /dev/null; then
        print_success "Target resource group: $target_rg"
    else
        print_error "Target resource group not found: $target_rg"
        ((errors++))
    fi

    # Check VMs
    print_info "Checking virtual machines..."
    local vms=$(az vm list --resource-group "$source_rg" --query "[].name" -o tsv 2>/dev/null || true)
    local vm_count=$(echo "$vms" | wc -w)
    if [ "$vm_count" -ge 4 ]; then
        print_success "Virtual machines deployed: $vm_count"
        for vm in $vms; do
            local vm_status=$(az vm get-instance-view --resource-group "$source_rg" --name "$vm" \
                --query "instanceView.statuses[?code=='PowerState/running'].displayStatus" -o tsv 2>/dev/null || echo "unknown")
            if [ "$vm_status" = "VM running" ]; then
                print_success "  - $vm (running)"
            else
                print_warning "  - $vm (status: $vm_status)"
            fi
        done
    else
        print_error "Expected 4 VMs, found: $vm_count"
        ((errors++))
    fi

    # Check Recovery Services Vaults
    print_info "Checking Recovery Services Vaults..."
    local source_vault=$(az backup vault list --resource-group "$source_rg" --query "[0].name" -o tsv 2>/dev/null || true)
    local target_vault=$(az backup vault list --resource-group "$target_rg" --query "[0].name" -o tsv 2>/dev/null || true)

    if [ -n "$source_vault" ]; then
        print_success "Source Recovery Vault: $source_vault"
    else
        print_warning "Source Recovery Vault not found (may still be provisioning)"
    fi

    if [ -n "$target_vault" ]; then
        print_success "Target Recovery Vault: $target_vault"
    else
        print_warning "Target Recovery Vault not found (may still be provisioning)"
    fi

    # Check Storage Account
    print_info "Checking Storage Account..."
    local storage_account=$(az storage account list --resource-group "$source_rg" \
        --query "[0].{name:name, replication:sku.name}" -o json 2>/dev/null || echo "{}")
    local storage_name=$(echo "$storage_account" | jq -r '.name // empty')
    local storage_replication=$(echo "$storage_account" | jq -r '.replication // empty')

    if [ -n "$storage_name" ]; then
        if [[ "$storage_replication" =~ GRS|GZRS ]]; then
            print_success "Storage Account: $storage_name (Geo-Redundant: $storage_replication)"
        else
            print_warning "Storage Account: $storage_name (Replication: $storage_replication - not geo-redundant)"
        fi
    else
        print_error "Storage Account not found"
        ((errors++))
    fi

    # Check Azure Bastion
    print_info "Checking Azure Bastion..."
    local bastion=$(az network bastion list --resource-group "$source_rg" --query "[0].name" -o tsv 2>/dev/null || true)
    if [ -n "$bastion" ]; then
        print_success "Azure Bastion: $bastion"
    else
        print_warning "Azure Bastion not found (may still be provisioning)"
    fi

    # Summary
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}                    Deployment Summary${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo "Resource Groups:"
    echo "  - Source: $source_rg"
    echo "  - Target: $target_rg"
    echo ""

    if [ -n "$TRAFFIC_MANAGER_FQDN" ]; then
        echo "Web Application URL:"
        echo "  - http://$TRAFFIC_MANAGER_FQDN"
        echo ""
    fi

    echo "VM Credentials:"
    echo "  - Username: ${VM_USERNAME:-azadmin}"
    echo "  - Password: (as configured)"
    echo ""

    echo "Next Steps:"
    echo "  1. Wait ~5 minutes for VMs to complete IIS/SQL setup"
    echo "  2. Access the web app via Traffic Manager URL"
    echo "  3. Continue to Challenge 3: Regional Protection (Backup)"
    echo ""

    if [ $errors -eq 0 ]; then
        print_success "Deployment verification completed successfully!"
        return 0
    else
        print_warning "Deployment completed with $errors issue(s)"
        print_info "Some resources may still be provisioning. Re-run verification in a few minutes."
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Cleanup Function
# -----------------------------------------------------------------------------

cleanup_deployment() {
    print_step "Cleaning Up Deployment"

    local source_rg="${DEPLOYMENT_PREFIX}-source-${SOURCE_LOCATION}-rg"
    local target_rg="${DEPLOYMENT_PREFIX}-target-${TARGET_LOCATION}-rg"

    echo ""
    print_warning "This will DELETE all resources in:"
    echo "  - $source_rg"
    echo "  - $target_rg"
    echo ""
    read -p "Are you sure? (type 'yes' to confirm): " confirm

    if [ "$confirm" = "yes" ]; then
        print_info "Deleting resource groups (this may take several minutes)..."

        az group delete --name "$source_rg" --yes --no-wait 2>/dev/null || true
        az group delete --name "$target_rg" --yes --no-wait 2>/dev/null || true

        print_success "Deletion initiated. Resource groups will be removed in the background."
    else
        print_info "Cleanup cancelled"
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    print_banner

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--prefix)
                DEPLOYMENT_PREFIX="$2"
                shift 2
                ;;
            -w|--password)
                VM_ADMIN_PASSWORD="$2"
                shift 2
                ;;
            -s|--source-location)
                SOURCE_LOCATION="$2"
                shift 2
                ;;
            -t|--target-location)
                TARGET_LOCATION="$2"
                shift 2
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --use-arm)
                USE_BICEP=false
                shift
                ;;
            -y|--yes)
                AUTO_APPROVE=true
                shift
                ;;
            --cleanup)
                # Special mode for cleanup
                if [ -z "$DEPLOYMENT_PREFIX" ]; then
                    read -p "Enter deployment prefix to cleanup: " DEPLOYMENT_PREFIX
                fi
                SOURCE_LOCATION="${SOURCE_LOCATION:-$DEFAULT_SOURCE_LOCATION}"
                TARGET_LOCATION="${TARGET_LOCATION:-$DEFAULT_TARGET_LOCATION}"
                cleanup_deployment
                exit 0
                ;;
            --verify-only)
                # Special mode for verification only
                if [ -z "$DEPLOYMENT_PREFIX" ]; then
                    read -p "Enter deployment prefix to verify: " DEPLOYMENT_PREFIX
                fi
                SOURCE_LOCATION="${SOURCE_LOCATION:-$DEFAULT_SOURCE_LOCATION}"
                TARGET_LOCATION="${TARGET_LOCATION:-$DEFAULT_TARGET_LOCATION}"
                verify_deployment
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Step 1: Prerequisites validation
    if [ "$SKIP_VALIDATION" != true ]; then
        if ! run_prerequisites_check; then
            print_error "Prerequisites check failed. Use --skip-validation to skip."
            exit 1
        fi
    else
        print_warning "Skipping prerequisites validation"
    fi

    # Step 2: Collect/validate parameters
    if ! collect_parameters; then
        print_error "Parameter validation failed"
        exit 1
    fi

    # Step 3: Deploy infrastructure
    if ! deploy_infrastructure; then
        print_error "Infrastructure deployment failed"
        exit 1
    fi

    # Step 4: Verify deployment
    verify_deployment

    echo ""
    print_success "Setup completed! You're ready to start the MicroHack challenges."
}

# Run main
main "$@"
