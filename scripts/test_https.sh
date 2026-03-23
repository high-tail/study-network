#!/bin/bash
# Test HTTPS/TLS connectivity and certificate validation
# This script tests TLS termination at HAProxy and end-to-end TLS to web3

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  HTTPS/TLS Connectivity Tests${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_https() {
    local test_name="$1"
    local target="$2"
    local expected_status="${3:-200}"
    local extra_args="${4:-}"

    echo -e "${YELLOW}Testing: $test_name${NC}"
    echo "  Target: $target"

    if docker exec netlab-haproxy curl -s -o /dev/null -w "%{http_code}" $extra_args "$target" | grep -q "$expected_status"; then
        echo -e "  ${GREEN}✓ PASS${NC} - Got HTTP $expected_status\n"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ FAIL${NC} - Expected HTTP $expected_status\n"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test TLS certificate info
test_tls_cert() {
    local test_name="$1"
    local target="$2"

    echo -e "${YELLOW}Testing: $test_name${NC}"
    echo "  Target: $target"

    # Test TLS handshake - look for successful connection (SSL-Session or Verify return code)
    TLS_OUTPUT=$(docker exec netlab-haproxy openssl s_client -connect "$target" -servername "${target%:*}" </dev/null 2>&1)

    if echo "$TLS_OUTPUT" | grep -q "SSL-Session:\|Verify return code"; then
        echo -e "  ${GREEN}✓ PASS${NC} - TLS handshake successful\n"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ FAIL${NC} - TLS handshake failed\n"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo -e "${BLUE}[1/7] Test HTTPS via HAProxy (SSL Termination)${NC}\n"
test_https "HAProxy HTTPS Frontend" "https://10.0.3.10/health" "200" "-k"

echo -e "${BLUE}[2/7] Test Direct HTTPS to web3${NC}\n"
test_https "Direct web3 HTTPS" "https://10.0.1.12/health" "200" "-k"

echo -e "${BLUE}[3/7] Test web3 HTTP to HTTPS Redirect${NC}\n"
test_https "web3 HTTP Redirect" "http://10.0.1.12/" "301" "-I"

echo -e "${BLUE}[4/7] Test DNS Resolution for web3${NC}\n"
echo -e "${YELLOW}Testing: DNS Resolution for web3.netlab.local${NC}"
# DNS server (10.0.2.10) is on the Internal network - test from DNS container using loopback
if docker exec netlab-dns nslookup web3.netlab.local 127.0.0.1 2>&1 | grep -q "10.0.1.12"; then
    echo -e "  ${GREEN}✓ PASS${NC} - web3.netlab.local resolves to 10.0.1.12\n"
    ((TESTS_PASSED++))
else
    echo -e "  ${RED}✗ FAIL${NC} - DNS resolution failed\n"
    ((TESTS_FAILED++))
fi

echo -e "${BLUE}[5/7] Test TLS Certificate for HAProxy${NC}\n"
test_tls_cert "HAProxy TLS Certificate" "10.0.3.10:443"

echo -e "${BLUE}[6/7] Test TLS Certificate for web3${NC}\n"
test_tls_cert "web3 TLS Certificate" "10.0.1.12:443"

echo -e "${BLUE}[7/7] Test HTTPS Load Balancing${NC}\n"
echo -e "${YELLOW}Testing: HTTPS Load Balancing across backends${NC}"
echo "  Sending 10 HTTPS requests through HAProxy..."

# Test load balancing by checking X-Backend-Server header
BACKENDS_HIT=()
for i in {1..10}; do
    BACKEND=$(docker exec netlab-haproxy curl -sk -I https://10.0.3.10/ | grep -i "X-Backend-Server" | awk '{print $2}' | tr -d '\r\n')
    if [ ! -z "$BACKEND" ]; then
        BACKENDS_HIT+=("$BACKEND")
    fi
done

# Count unique backends
UNIQUE_BACKENDS=$(printf '%s\n' "${BACKENDS_HIT[@]}" | sort -u | wc -l)

if [ "$UNIQUE_BACKENDS" -ge 2 ]; then
    echo -e "  ${GREEN}✓ PASS${NC} - Requests distributed across $UNIQUE_BACKENDS backends"
    echo "  Backends hit: $(printf '%s\n' "${BACKENDS_HIT[@]}" | sort | uniq -c)"
    ((TESTS_PASSED++))
else
    echo -e "  ${RED}✗ FAIL${NC} - Only $UNIQUE_BACKENDS backend(s) received requests"
    ((TESTS_FAILED++))
fi

echo ""

# ============================================
# Summary
# ============================================
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "  Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "  Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Additional TLS Information
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  TLS Configuration Details${NC}"
echo -e "${BLUE}======================================${NC}\n"

echo -e "${YELLOW}HAProxy TLS Certificate Info:${NC}"
docker exec netlab-haproxy openssl s_client -connect 10.0.3.10:443 -servername haproxy.netlab.local </dev/null 2>/dev/null | \
    openssl x509 -noout -subject -issuer -dates 2>/dev/null || echo "  Unable to retrieve certificate"

echo ""
echo -e "${YELLOW}web3 TLS Certificate Info:${NC}"
docker exec netlab-haproxy openssl s_client -connect 10.0.1.12:443 -servername web3.netlab.local </dev/null 2>/dev/null | \
    openssl x509 -noout -subject -issuer -dates 2>/dev/null || echo "  Unable to retrieve certificate"

echo ""
echo -e "${YELLOW}TLS Protocol and Cipher (HAProxy):${NC}"
docker exec netlab-haproxy curl -vsk https://10.0.3.10/ 2>&1 | grep -E "SSL connection|Server certificate|subject|issuer" | head -10 || echo "  Unable to retrieve TLS details"

echo ""

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}\n"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}\n"
    exit 1
fi
