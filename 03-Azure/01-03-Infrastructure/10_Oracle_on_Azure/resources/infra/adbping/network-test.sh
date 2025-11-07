#!/bin/bash

# Network Testing Script for Oracle ADB
# This script provides comprehensive network testing capabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
show_usage() {
    cat << EOF
Network Testing Script for Oracle ADB

Usage: $0 [OPTIONS] <test_type> [target]

Test Types:
  dns <hostname>        - DNS resolution test using dig
  ping <hostname>       - ICMP ping test
  trace <hostname>      - Traceroute test
  port <host> <port>    - TCP port connectivity test
  http <url>            - HTTP/HTTPS connectivity test
  oracle <host> <port>  - Oracle-specific connectivity test
  all <hostname>        - Run all network tests

Options:
  -h, --help           Show this help message
  -v, --verbose        Verbose output
  -c, --count <num>    Number of ping/test iterations (default: 4)
  -t, --timeout <sec>  Timeout in seconds (default: 10)

Examples:
  $0 dns adb.us-ashburn-1.oraclecloud.com
  $0 ping adb.us-ashburn-1.oraclecloud.com
  $0 port adb.us-ashburn-1.oraclecloud.com 1521
  $0 all adb.us-ashburn-1.oraclecloud.com
  $0 oracle adb.us-ashburn-1.oraclecloud.com 1521

EOF
}

# Default values
COUNT=4
TIMEOUT=10
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check if test type is provided
if [[ $# -lt 1 ]]; then
    print_error "Test type is required"
    show_usage
    exit 1
fi

TEST_TYPE="$1"
TARGET="$2"
PORT="$3"

# Function to test DNS resolution
test_dns() {
    local host="$1"
    print_info "Testing DNS resolution for: $host"
    
    if dig +short "$host" > /dev/null 2>&1; then
        print_success "DNS resolution successful"
        if $VERBOSE; then
            dig "$host"
        else
            dig +short "$host"
        fi
    else
        print_error "DNS resolution failed"
        return 1
    fi
}

# Function to test ping connectivity
test_ping() {
    local host="$1"
    print_info "Testing ICMP connectivity to: $host (count: $COUNT)"
    
    if ping -c "$COUNT" -W "$TIMEOUT" "$host"; then
        print_success "Ping test successful"
    else
        print_error "Ping test failed"
        return 1
    fi
}

# Function to test traceroute
test_traceroute() {
    local host="$1"
    print_info "Running traceroute to: $host"
    
    if command -v traceroute >/dev/null 2>&1; then
        traceroute -w "$TIMEOUT" "$host"
    else
        print_warning "traceroute command not available"
        return 1
    fi
}

# Function to test TCP port connectivity
test_port() {
    local host="$1"
    local port="$2"
    print_info "Testing TCP connectivity to: $host:$port"
    
    if timeout "$TIMEOUT" nc -z "$host" "$port" 2>/dev/null; then
        print_success "Port $port is open on $host"
    else
        print_error "Port $port is closed or filtered on $host"
        return 1
    fi
}

# Function to test HTTP/HTTPS connectivity
test_http() {
    local url="$1"
    print_info "Testing HTTP/HTTPS connectivity to: $url"
    
    if curl -I -m "$TIMEOUT" -s "$url" >/dev/null 2>&1; then
        print_success "HTTP/HTTPS connectivity successful"
        if $VERBOSE; then
            curl -I -m "$TIMEOUT" "$url"
        fi
    else
        print_error "HTTP/HTTPS connectivity failed"
        return 1
    fi
}

# Function to test Oracle-specific connectivity
test_oracle() {
    local host="$1"
    local port="${2:-1521}"
    
    print_info "Testing Oracle connectivity to: $host:$port"
    
    # Test basic TCP connectivity first
    if ! test_port "$host" "$port"; then
        return 1
    fi
    
    # Test TNS ping if available
    if command -v tnsping >/dev/null 2>&1; then
        print_info "Testing TNS connectivity"
        if tnsping "$host:$port" > /dev/null 2>&1; then
            print_success "TNS connectivity successful"
        else
            print_warning "TNS ping failed, but TCP connection is working"
        fi
    else
        print_info "tnsping not available, skipping TNS test"
    fi
}

# Function to run all tests
test_all() {
    local host="$1"
    local failed_tests=0
    
    print_info "Running comprehensive network tests for: $host"
    echo "================================================"
    
    # DNS test
    echo
    test_dns "$host" || ((failed_tests++))
    
    # Ping test
    echo
    test_ping "$host" || ((failed_tests++))
    
    # Traceroute test
    echo
    test_traceroute "$host" || ((failed_tests++))
    
    # Common Oracle ports
    local oracle_ports=(1521 1522 2484)
    for port in "${oracle_ports[@]}"; do
        echo
        test_port "$host" "$port" || true  # Don't count as failure
    done
    
    # Oracle-specific tests
    echo
    test_oracle "$host" || ((failed_tests++))
    
    # HTTPS test (common for Oracle Cloud)
    echo
    test_http "https://$host" || true  # Don't count as failure
    
    echo
    echo "================================================"
    if [ $failed_tests -eq 0 ]; then
        print_success "All critical tests passed!"
    else
        print_warning "$failed_tests critical tests failed"
    fi
    
    return $failed_tests
}

# Main execution logic
case "$TEST_TYPE" in
    dns)
        if [[ -z "$TARGET" ]]; then
            print_error "Hostname is required for DNS test"
            exit 1
        fi
        test_dns "$TARGET"
        ;;
    ping)
        if [[ -z "$TARGET" ]]; then
            print_error "Hostname is required for ping test"
            exit 1
        fi
        test_ping "$TARGET"
        ;;
    trace|traceroute)
        if [[ -z "$TARGET" ]]; then
            print_error "Hostname is required for traceroute test"
            exit 1
        fi
        test_traceroute "$TARGET"
        ;;
    port)
        if [[ -z "$TARGET" || -z "$PORT" ]]; then
            print_error "Hostname and port are required for port test"
            exit 1
        fi
        test_port "$TARGET" "$PORT"
        ;;
    http|https)
        if [[ -z "$TARGET" ]]; then
            print_error "URL is required for HTTP test"
            exit 1
        fi
        test_http "$TARGET"
        ;;
    oracle)
        if [[ -z "$TARGET" ]]; then
            print_error "Hostname is required for Oracle test"
            exit 1
        fi
        test_oracle "$TARGET" "$PORT"
        ;;
    all)
        if [[ -z "$TARGET" ]]; then
            print_error "Hostname is required for comprehensive test"
            exit 1
        fi
        test_all "$TARGET"
        ;;
    *)
        print_error "Unknown test type: $TEST_TYPE"
        show_usage
        exit 1
        ;;
esac