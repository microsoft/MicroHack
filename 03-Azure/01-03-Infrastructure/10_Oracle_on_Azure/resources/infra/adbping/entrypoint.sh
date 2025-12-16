#!/bin/bash

# Entrypoint script for ADB Network Testing Container
set -e

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
  ____  ____  ____    _   _      _                      _    
 / _  ||  _ \|  _ \  | \ | | ___| |_ __      _____  _ __| | __
| |_| || | | | |_) | |  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ /
|  _  || |_| |  _ <  | |\  |  __/ |_ \ V  V / (_) | |  |   < 
|_| |_||____/|_| \_\ |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\
 _____         _   _             
|_   _|__  ___| |_(_)_ __   __ _ 
  | |/ _ \/ __| __| | '_ \ / _` |
  | |  __/\__ \ |_| | | | | (_| |
  |_|\___||___/\__|_|_| |_|\__, |
                          |___/ 
EOF
    echo
    print_success "Oracle ADB Network Testing Container"
    echo "Version: 1.0"
    echo "Available tools: adbping, dig, ping, traceroute, nc, curl, wget"
    echo
}

# Show help information
show_help() {
    cat << EOF
Oracle ADB Network Testing Container

USAGE:
  # Run adbping tool directly
  docker run --rm -v /path/to/wallet:/opt/oracle/wallet adb-nettest \\
    adbping -u admin -p password -s service_name -w /opt/oracle/wallet

  # Run network tests
  docker run --rm adb-nettest network-test dns adb.us-ashburn-1.oraclecloud.com
  docker run --rm adb-nettest network-test ping adb.us-ashburn-1.oraclecloud.com
  docker run --rm adb-nettest network-test all adb.us-ashburn-1.oraclecloud.com

  # Interactive shell
  docker run --rm -it adb-nettest bash

AVAILABLE COMMANDS:
  adbping           - Oracle ADB ping and latency benchmarking tool
  network-test      - Comprehensive network testing script
  dig               - DNS lookup utility
  nslookup          - DNS lookup utility
  ping              - ICMP ping utility
  traceroute        - Network route tracing
  nc (netcat)       - TCP/UDP connectivity testing
  curl              - HTTP/HTTPS client
  wget              - HTTP/HTTPS downloader
  telnet            - Telnet client
  nmap              - Network discovery and port scanning
  tcpdump           - Network packet analyzer

ENVIRONMENT VARIABLES:
  TNS_ADMIN         - Oracle wallet location (default: /opt/oracle/wallet)
  ORACLE_HOME       - Oracle client home (default: /usr/lib/oracle/21/client64)
  JAVA_HOME         - Java home (default: /usr/lib/jvm/java-11-openjdk)

VOLUME MOUNTS:
  /opt/oracle/wallet - Mount your Oracle wallet here
  /opt/adbping/sql   - Mount custom SQL files here

EXAMPLES:
  # Test with wallet authentication
  docker run --rm -v \$(pwd)/wallet:/opt/oracle/wallet adb-nettest \\
    adbping -u admin -p MyPassword123 -s mydb_high -w /opt/oracle/wallet

  # Test with one-way TLS
  docker run --rm adb-nettest \\
    adbping -u admin -p MyPassword123 --onewaytls \\
    --tlsurl '(description=...your_tls_connection_string...)'

  # Comprehensive network testing
  docker run --rm adb-nettest network-test all adb.us-ashburn-1.oraclecloud.com

  # Interactive troubleshooting
  docker run --rm -it -v \$(pwd)/wallet:/opt/oracle/wallet adb-nettest bash

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
    wallet_files=$(ls -la /opt/oracle/wallet 2>/dev/null | wc -l)
    if [[ $wallet_files -gt 3 ]]; then  # More than just . and ..
        print_success "Oracle wallet detected in /opt/oracle/wallet"
    else
        print_warning "Oracle wallet directory is empty. Mount your wallet to /opt/oracle/wallet for adbping tests"
    fi
else
    print_warning "Oracle wallet directory not found. Mount your wallet to /opt/oracle/wallet for adbping tests"
fi

# Execute the provided command
exec "$@"