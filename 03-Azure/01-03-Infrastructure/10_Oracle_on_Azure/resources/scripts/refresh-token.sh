#!/bin/bash
# Token Refresh Service for Oracle Entra ID Authentication
# Runs as a sidecar container to automatically refresh OAuth tokens

set -e

# Configuration from environment variables
TENANT_ID="${AZURE_TENANT_ID:-f71980b2-590a-4de9-90d5-6fbc867da951}"
CLIENT_ID="${AZURE_CLIENT_ID:-7d22ece1-dd60-4279-a911-4b7b95934f2e}"
SCOPE="https://cptazure.org/${CLIENT_ID}/.default"
TOKEN_FILE="${TOKEN_FILE:-/tmp/wallet/token.txt}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-2700}"  # 45 minutes (2700 seconds)
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

# Function to decode JWT and get expiry time
get_token_expiry() {
    local token=$1
    
    # Extract payload (second part of JWT)
    payload=$(echo "$token" | cut -d'.' -f2)
    
    # Add padding if needed
    padding_length=$((4 - ${#payload} % 4))
    if [ $padding_length -ne 4 ]; then
        payload="${payload}$(printf '=%.0s' $(seq 1 $padding_length))"
    fi
    
    # Decode and extract exp claim
    exp=$(echo "$payload" | base64 -d 2>/dev/null | grep -o '"exp":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$exp" ]; then
        echo "$exp"
    else
        echo "0"
    fi
}

# Function to refresh token
refresh_token() {
    log_info "Attempting to refresh token..."
    
    # Try to get token using Managed Identity first
    local token=""
    local use_method="unknown"
    
    # Method 1: Try Managed Identity via IMDS endpoint
    if command -v curl &> /dev/null; then
        log_info "Trying Managed Identity (IMDS endpoint)..."
        response=$(curl -sf -H "Metadata: true" \
            "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=${SCOPE}" \
            2>/dev/null || echo "")
        
        if [ -n "$response" ]; then
            token=$(echo "$response" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
            if [ -n "$token" ]; then
                use_method="Managed Identity (IMDS)"
            fi
        fi
    fi
    
    # Method 2: Try Azure CLI with Managed Identity
    if [ -z "$token" ] && command -v az &> /dev/null; then
        log_info "Trying Azure CLI with Managed Identity..."
        token=$(az account get-access-token \
            --tenant "$TENANT_ID" \
            --scope "$SCOPE" \
            --query accessToken \
            --output tsv 2>/dev/null || echo "")
        
        if [ -n "$token" ]; then
            use_method="Azure CLI (Managed Identity)"
        fi
    fi
    
    # Method 3: Try Azure CLI with user authentication (fallback)
    if [ -z "$token" ] && command -v az &> /dev/null; then
        log_warn "Managed Identity failed, trying Azure CLI user authentication..."
        token=$(az account get-access-token \
            --scope "$SCOPE" \
            --query accessToken \
            --output tsv 2>/dev/null || echo "")
        
        if [ -n "$token" ]; then
            use_method="Azure CLI (User Auth)"
        fi
    fi
    
    # Check if we got a token
    if [ -z "$token" ] || [ "$token" == "null" ]; then
        log_error "Failed to obtain token from any method"
        return 1
    fi
    
    # Write token to file (single line, no newline)
    echo -n "$token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
    
    # Get token expiry
    exp=$(get_token_expiry "$token")
    if [ "$exp" -gt 0 ]; then
        expiry_date=$(date -d "@$exp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$exp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
        time_until_expiry=$(( exp - $(date +%s) ))
        minutes_until_expiry=$(( time_until_expiry / 60 ))
        
        log_info "✅ Token refreshed successfully using ${use_method}"
        log_info "Token expires at: ${expiry_date} (in ${minutes_until_expiry} minutes)"
    else
        log_info "✅ Token refreshed successfully using ${use_method}"
        log_warn "Could not decode token expiry time"
    fi
    
    return 0
}

# Function to verify token file
verify_token_file() {
    if [ ! -f "$TOKEN_FILE" ]; then
        log_error "Token file does not exist: $TOKEN_FILE"
        return 1
    fi
    
    local file_size=$(wc -c < "$TOKEN_FILE")
    local line_count=$(wc -l < "$TOKEN_FILE")
    
    if [ "$file_size" -lt 100 ]; then
        log_error "Token file is too small (${file_size} bytes)"
        return 1
    fi
    
    if [ "$line_count" -gt 0 ]; then
        log_warn "Token file has line breaks (${line_count} lines) - this may cause issues"
    fi
    
    log_info "Token file verification passed (${file_size} bytes, ${line_count} lines)"
    return 0
}

# Main loop
main() {
    log_info "=========================================="
    log_info "Token Refresh Service Starting"
    log_info "=========================================="
    log_info "Tenant ID: ${TENANT_ID}"
    log_info "Client ID: ${CLIENT_ID}"
    log_info "Scope: ${SCOPE}"
    log_info "Token File: ${TOKEN_FILE}"
    log_info "Refresh Interval: ${REFRESH_INTERVAL} seconds ($(($REFRESH_INTERVAL / 60)) minutes)"
    log_info "=========================================="
    
    # Initial token refresh
    log_info "Performing initial token refresh..."
    if ! refresh_token; then
        log_error "Initial token refresh failed. Retrying in 60 seconds..."
        sleep 60
    fi
    
    # Verify token file
    verify_token_file
    
    # Main refresh loop
    local retry_count=0
    local max_retries=3
    
    while true; do
        log_info "Next token refresh in $(($REFRESH_INTERVAL / 60)) minutes"
        log_info "Sleeping for ${REFRESH_INTERVAL} seconds..."
        sleep "$REFRESH_INTERVAL"
        
        # Attempt to refresh token
        if refresh_token; then
            retry_count=0
            verify_token_file
        else
            retry_count=$((retry_count + 1))
            log_error "Token refresh failed (attempt ${retry_count}/${max_retries})"
            
            if [ $retry_count -ge $max_retries ]; then
                log_error "Max retries reached. Waiting full interval before next attempt."
                retry_count=0
            else
                # Exponential backoff for retries
                retry_delay=$((60 * retry_count))
                log_warn "Retrying in ${retry_delay} seconds..."
                sleep "$retry_delay"
            fi
        fi
    done
}

# Handle signals for graceful shutdown
cleanup() {
    log_info "Received termination signal. Shutting down gracefully..."
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start the service
main
