#!/bin/bash

# Azure BCDR Workshop - Prerequisites Validation Script
# This script validates Azure CLI installation, authentication, permissions, and resource provider registration
# required for deploying the BCDR workshop infrastructure.

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters for validation results
ERRORS=0
WARNINGS=0
SUCCESS=0

# Required resource providers for the BCDR workshop
REQUIRED_PROVIDERS=(
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

# Required permissions (RBAC roles)
REQUIRED_ROLES=("Owner")

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Azure BCDR Workshop Prerequisites Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print success message
print_success() {
    echo -e "${GREEN}✓${NC} $1"
    ((SUCCESS++))
}

# Function to print error message
print_error() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Function to print info message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check 1: Azure CLI Installation
echo -e "\n${BLUE}[1/5]${NC} Checking Azure CLI installation..."
if command -v az &> /dev/null; then
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
    print_success "Azure CLI is installed (version: $AZ_VERSION)"
else
    print_error "Azure CLI is not installed"
    print_info "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    # Skip remaining checks if Azure CLI is not available
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Validation Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Successful checks: $SUCCESS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo -e "${RED}Errors: $ERRORS${NC}"
    echo -e "\n${RED}✗ Cannot proceed without Azure CLI installed.${NC}"
    return 0 2>/dev/null || true
fi

# Check 2: Azure CLI Login Status
echo -e "\n${BLUE}[2/5]${NC} Checking Azure authentication..."
if az account show &> /dev/null; then
    ACCOUNT_NAME=$(az account show --query "user.name" -o tsv 2>/dev/null || echo "unknown")
    print_success "Authenticated to Azure"
    print_info "User: $ACCOUNT_NAME"
    
    # Get all subscriptions
    echo -e "\n${BLUE}Fetching available subscriptions...${NC}"
    SUBSCRIPTIONS=$(az account list --query "[].{Name:name, Id:id, State:state}" -o tsv 2>/dev/null)
    
    if [ -z "$SUBSCRIPTIONS" ]; then
        print_error "No subscriptions found"
        echo -e "\n${BLUE}========================================${NC}"
        echo -e "${BLUE}Validation Summary${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}Successful checks: $SUCCESS${NC}"
        echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
        echo -e "${RED}Errors: $ERRORS${NC}"
        echo -e "\n${RED}✗ Cannot proceed without an active subscription.${NC}"
        return 0 2>/dev/null || true
    fi
    
    # Count subscriptions
    SUB_COUNT=$(echo "$SUBSCRIPTIONS" | wc -l)
    
    if [ "$SUB_COUNT" -eq 1 ]; then
        # Only one subscription, use it automatically
        SUBSCRIPTION_NAME=$(echo "$SUBSCRIPTIONS" | awk '{print $1}')
        SUBSCRIPTION_ID=$(echo "$SUBSCRIPTIONS" | awk '{print $2}')
        print_info "Using subscription: $SUBSCRIPTION_NAME"
    else
        # Multiple subscriptions, let user choose
        echo -e "\n${YELLOW}Multiple subscriptions found:${NC}"
        echo "$SUBSCRIPTIONS" | nl -w2 -s'. '
        echo ""
        
        # Prompt for selection
        while true; do
            read -p "Select subscription number (1-$SUB_COUNT): " selection
            
            if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$SUB_COUNT" ]; then
                SELECTED_LINE=$(echo "$SUBSCRIPTIONS" | sed -n "${selection}p")
                SUBSCRIPTION_NAME=$(echo "$SELECTED_LINE" | awk '{print $1}')
                SUBSCRIPTION_ID=$(echo "$SELECTED_LINE" | awk '{print $2}')
                
                # Set the selected subscription as active
                az account set --subscription "$SUBSCRIPTION_ID" &> /dev/null
                print_success "Selected subscription: $SUBSCRIPTION_NAME"
                break
            else
                echo -e "${RED}Invalid selection. Please enter a number between 1 and $SUB_COUNT${NC}"
            fi
        done
    fi
    
    TENANT_ID=$(az account show --query "tenantId" -o tsv 2>/dev/null || echo "unknown")
    print_info "Subscription ID: $SUBSCRIPTION_ID"
    print_info "Tenant ID: $TENANT_ID"
else
    print_error "Not authenticated to Azure"
    print_info "Run 'az login' to authenticate"
    # Skip remaining checks if not authenticated
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Validation Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Successful checks: $SUCCESS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo -e "${RED}Errors: $ERRORS${NC}"
    echo -e "\n${RED}✗ Cannot proceed without Azure authentication.${NC}"
    return 0 2>/dev/null || true
fi

# Check 3: RBAC Permissions
echo -e "\n${BLUE}[3/5]${NC} Checking RBAC permissions (including inherited roles)..."
print_info "Retrieving role assignments (this may take a moment)..."

# Query role assignments without scope filter to include inherited roles from management groups
ROLE_ASSIGNMENTS=$(az role assignment list --all --query "[?scope=='/subscriptions/$SUBSCRIPTION_ID' || contains(scope, '/providers/Microsoft.Management/managementGroups/')].roleDefinitionName" -o tsv 2>/dev/null || true)

if [ -z "$ROLE_ASSIGNMENTS" ]; then
    # Try alternative method: check what user can do on the subscription
    CAN_READ=$(az role assignment list --subscription "$SUBSCRIPTION_ID" --query "[0]" -o tsv 2>/dev/null || true)
    if [ -n "$CAN_READ" ]; then
        # User has some access, likely has inherited permissions
        print_warning "Unable to enumerate all role assignments (inherited roles may not be visible)"
        print_info "Verifying deployment permissions through capability check..."
        
        # Try to validate if user can create resource groups (requires Contributor or Owner)
        TEST_RG_NAME="test-permissions-check-$$"
        if az group create --name "$TEST_RG_NAME" --location "westeurope" --tags "temporary=true" &> /dev/null; then
            az group delete --name "$TEST_RG_NAME" --yes --no-wait &> /dev/null || true
            print_success "Has sufficient permissions (verified through capability check)"
            HAS_REQUIRED_ROLE=true
        else
            print_error "Insufficient permissions to create resource groups"
            print_info "Owner role at subscription level (or inherited from management group) is required"
            ((ERRORS++))
            HAS_REQUIRED_ROLE=false
        fi
    else
        print_error "Unable to verify role assignments"
        ((ERRORS++))
        HAS_REQUIRED_ROLE=false
    fi
else
    HAS_REQUIRED_ROLE=false
    if [ -n "$ROLE_ASSIGNMENTS" ]; then
        while IFS= read -r role; do
            for required_role in "${REQUIRED_ROLES[@]}"; do
                if [ "$role" = "$required_role" ]; then
                    print_success "Has required role: $role"
                    HAS_REQUIRED_ROLE=true
                    break 2
                fi
            done
        done <<< "$ROLE_ASSIGNMENTS"
    fi
    
    if [ "$HAS_REQUIRED_ROLE" = false ]; then
        print_error "Missing required RBAC role at subscription level"
        print_info "Required roles: ${REQUIRED_ROLES[*]}"
        print_info "Your roles: $ROLE_ASSIGNMENTS"
        print_info "Contact your Azure administrator to assign the appropriate role"
        ((ERRORS++))
    fi
fi

# Check 4: Resource Provider Registration
echo -e "\n${BLUE}[4/5]${NC} Checking resource provider registration..."
UNREGISTERED_PROVIDERS=()

for provider in "${REQUIRED_PROVIDERS[@]}"; do
    PROVIDER_STATE=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
    
    if [ "$PROVIDER_STATE" = "Registered" ]; then
        print_success "$provider is registered"
    elif [ "$PROVIDER_STATE" = "Registering" ]; then
        print_warning "$provider is currently registering (may take a few minutes)"
        UNREGISTERED_PROVIDERS+=("$provider")
    else
        print_error "$provider is not registered (Status: $PROVIDER_STATE)"
        UNREGISTERED_PROVIDERS+=("$provider")
    fi
done

# Check 5: Resource Provider Registration Capability
echo -e "\n${BLUE}[5/5]${NC} Checking ability to register resource providers..."
if [ ${#UNREGISTERED_PROVIDERS[@]} -gt 0 ]; then
    print_warning "The following providers need to be registered: ${UNREGISTERED_PROVIDERS[*]}"
    print_info "Attempting to register providers (requires appropriate permissions)..."
    
    REGISTRATION_FAILED=false
    for provider in "${UNREGISTERED_PROVIDERS[@]}"; do
        echo -n "Registering $provider... "
        if az provider register --namespace "$provider" &> /dev/null; then
            print_success "Successfully registered $provider"
            ((ERRORS--))
        else
            print_error "Failed to register $provider (insufficient permissions or other error)"
            REGISTRATION_FAILED=true
        fi
    done
    
    if [ "$REGISTRATION_FAILED" = true ]; then
        print_info "Contact your Azure administrator to register the required providers"
        print_info "Or run: az provider register --namespace <provider-name> --wait"
    fi
else
    print_success "All required resource providers are registered"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Successful checks: $SUCCESS${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Errors: $ERRORS${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All prerequisites are met! You can proceed with the deployment.${NC}"
    echo -e "\n${BLUE}To deploy the infrastructure, run:${NC}"
    echo -e "  az deployment sub create --location <location> --template-file deploy.json --parameters @main.parameters.json"
elif [ $ERRORS -eq 0 ] && [ $WARNINGS -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ Prerequisites check completed with warnings.${NC}"
    echo -e "${YELLOW}Review the warnings above. You may proceed with caution.${NC}"
else
    echo -e "\n${RED}✗ Prerequisites check failed. Please resolve the errors above before proceeding.${NC}"
fi
