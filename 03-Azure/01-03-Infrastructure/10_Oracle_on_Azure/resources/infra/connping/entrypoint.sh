#!/bin/bash

# Entrypoint script for Connping Network Testing Container
set -e

# Detect actual Oracle client version and update environment
ORACLE_VERSION=$(ls /usr/lib/oracle/ 2>/dev/null | head -1)
if [ -n "$ORACLE_VERSION" ]; then
    export ORACLE_HOME=/usr/lib/oracle/${ORACLE_VERSION}/client64
    export LD_LIBRARY_PATH=/usr/lib/oracle/${ORACLE_VERSION}/client64/lib:${LD_LIBRARY_PATH}
    export PATH=/opt/rwloadsim:/usr/lib/oracle/${ORACLE_VERSION}/client64/bin:${PATH}
fi

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Show banner
show_banner() {
    cat << 'EOF'
   ____                       _             
  / ___|___  _ __  _ __  _ __ (_)_ __   __ _ 
 | |   / _ \| '_ \| '_ \| '_ \| | '_ \ / _` |
 | |__| (_) | | | | | | | |_) | | | | | (_| |
  \____\___/|_| |_|_| |_| .__/|_|_| |_|\__, |
                        |_|            |___/ 
  ____                 _                      _    
 |  _ \  __ ___      _| | ___   __ _ ___(_)_ __ ___ 
 | |_) |/ _` \ \ /\ / / |/ _ \ / _` / __| | '_ ` _ \
 |  _ <| (_| |\ V  V /| | (_) | (_| \__ \ | | | | | |
 |_| \_\\__,_| \_/\_/ |_|\___/ \__,_|___/_|_| |_| |_|
                                                      
EOF
    echo
    print_success "Oracle ADB Connping Testing Container (rwloadsim)"
    echo "Version: 1.0"
    echo "Available tools: connping, ociping, sqlplus, dig, ping, traceroute, nc, curl, wget"
    echo
}

# Show help information
show_help() {
    cat << EOF
Oracle ADB Connping Testing Container

DESCRIPTION:
  This container includes the rwloadsim tool suite (connping/ociping) created by 
  Oracle's Real World Performance team for testing Oracle ADB connection latency.
  
  The primary metric to watch is 'ociping' which measures the connection latency.

USAGE:
  # Run connping with one-way TLS connection (recommended)
  docker run --rm odaamh.azurecr.io/connping:v1.0 \\
    connping -l 'admin/password@"(description=...)"' --period=300

  # Run connping with wallet authentication
  docker run --rm -v /path/to/wallet:/opt/oracle/wallet \\
    odaamh.azurecr.io/connping:v1.0 \\
    connping -l admin/password@service_name --period=300

  # Network diagnostics
  docker run --rm odaamh.azurecr.io/connping:v1.0 \\
    ping -c 4 adb.eu-frankfurt-1.oraclecloud.com

  # Interactive shell
  docker run --rm -it odaamh.azurecr.io/connping:v1.0 bash

AVAILABLE COMMANDS:
  connping          - Connection and latency testing tool (rwloadsim)
  ociping           - Part of rwloadsim suite
  sqlplus           - Oracle SQL*Plus client (23c)
  dig, nslookup     - DNS lookup utilities
  ping              - ICMP ping utility
  traceroute        - Network route tracing
  nc (netcat)       - TCP/UDP connectivity testing
  curl, wget        - HTTP/HTTPS clients

ENVIRONMENT VARIABLES:
  TNS_ADMIN         - Oracle wallet location (default: /opt/oracle/wallet)
  ORACLE_HOME       - Oracle client home (default: /usr/lib/oracle/23/client64)
  LD_LIBRARY_PATH   - Oracle library path

VOLUME MOUNTS:
  /opt/oracle/wallet - Mount your Oracle wallet here (optional for one-way TLS)

EXAMPLES:
  # Basic latency test with one-way TLS (300 seconds duration)
  connping -l 'admin/pass@"(description= (retry_count=20)(retry_delay=3)\\
    (address=(protocol=tcps)(port=1521)(host=adb.eu-frankfurt-1.oraclecloud.com))\\
    (connect_data=(service_name=db_tp.adb.oraclecloud.com))\\
    (security=(ssl_server_dn_match=yes)))"' --period=300

  # Test with wallet
  connping -l admin/password@mydb_high --period=300

  # Network connectivity test
  ping -c 10 adb.eu-frankfurt-1.oraclecloud.com

  # DNS resolution test
  dig adb.eu-frankfurt-1.oraclecloud.com

  # Interactive troubleshooting
  docker run --rm -it -v \$(pwd)/wallet:/opt/oracle/wallet \\
    odaamh.azurecr.io/connping:v1.0 bash

IMPORTANT NOTES:
  - Watch for the 'ociping' metric in the output - this is the key latency measurement
  - The --period parameter specifies the test duration in seconds
  - One-way TLS connections do not require a wallet
  - For wallet-based connections, ensure TNS_ADMIN points to the wallet directory

REFERENCE:
  rwloadsim GitHub: https://github.com/oracle/rwloadsim
  Version: 3.2.1

EOF
}

# Main execution
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_banner
    show_help
    exit 0
fi

# Check if wallet directory is mounted and has files
if [[ -d "/opt/oracle/wallet" ]]; then
    wallet_files=$(ls -A /opt/oracle/wallet 2>/dev/null | wc -l)
    if [[ $wallet_files -gt 0 ]]; then
        print_success "Oracle wallet detected in /opt/oracle/wallet"
    else
        print_info "Oracle wallet directory is empty. For wallet-based connections, mount your wallet to /opt/oracle/wallet"
    fi
else
    print_info "For wallet-based connections, mount your wallet to /opt/oracle/wallet"
fi

# Verify connping is available
if ! command -v connping &> /dev/null; then
    print_warning "connping command not found in PATH. Checking /opt/rwloadsim/bin..."
    export PATH="/opt/rwloadsim/bin:$PATH"
fi

# Execute the provided command
exec "$@"
