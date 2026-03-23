#!/bin/bash
# Test DNS resolution (forward and reverse) from containers on the Internal network
# Note: The DNS server (10.0.2.10) is only reachable from the Internal network (10.0.2.0/24).
# Containers on DMZ and Public networks resolve names via Docker's internal resolver,
# which does not forward .netlab.local queries — so DNS tests run from the Internal network.

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DNS_SERVER=10.0.2.10

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  DNS Resolution Tests${NC}"
echo -e "${BLUE}======================================${NC}\n"
echo "  DNS server: $DNS_SERVER"
echo "  Testing from: netlab-dns (127.0.0.1) and netlab-k6 ($DNS_SERVER)"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Forward lookup test
test_forward() {
    local test_name="$1"
    local container="$2"
    local server="$3"
    local hostname="$4"
    local expected_ip="$5"

    echo -e "${YELLOW}Testing: $test_name${NC}"
    echo "  $container: nslookup $hostname $server → $expected_ip"

    if docker exec "$container" nslookup "$hostname" "$server" 2>&1 | grep -q "$expected_ip"; then
        echo -e "  ${GREEN}✓ PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗ FAIL${NC} - Expected $expected_ip in result\n"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Reverse lookup test
test_reverse() {
    local test_name="$1"
    local container="$2"
    local server="$3"
    local ip="$4"
    local expected_name="$5"

    echo -e "${YELLOW}Testing: $test_name${NC}"
    echo "  $container: nslookup $ip $server → $expected_name"

    if docker exec "$container" nslookup "$ip" "$server" 2>&1 | grep -q "$expected_name"; then
        echo -e "  ${GREEN}✓ PASS${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗ FAIL${NC} - Expected $expected_name in result\n"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================
# Forward lookups from DNS container (127.0.0.1)
# Comprehensive test of all dnsmasq entries
# ============================================
echo -e "${BLUE}--- Forward Lookups (netlab-dns, 127.0.0.1) ---${NC}\n"

test_forward "router.netlab.local" netlab-dns 127.0.0.1 router.netlab.local 10.0.1.254
test_forward "web1.netlab.local" netlab-dns 127.0.0.1 web1.netlab.local 10.0.1.10
test_forward "web2.netlab.local" netlab-dns 127.0.0.1 web2.netlab.local 10.0.1.11
test_forward "web3.netlab.local" netlab-dns 127.0.0.1 web3.netlab.local 10.0.1.12
test_forward "haproxy.netlab.local" netlab-dns 127.0.0.1 haproxy.netlab.local 10.0.3.10
test_forward "lb.netlab.local (CNAME)" netlab-dns 127.0.0.1 lb.netlab.local 10.0.3.10
test_forward "dns.netlab.local" netlab-dns 127.0.0.1 dns.netlab.local 10.0.2.10
test_forward "dhcp.netlab.local" netlab-dns 127.0.0.1 dhcp.netlab.local 10.0.2.11
test_forward "prometheus.netlab.local → 10.0.2.19 (fixed)" netlab-dns 127.0.0.1 prometheus.netlab.local 10.0.2.19
test_forward "grafana.netlab.local" netlab-dns 127.0.0.1 grafana.netlab.local 10.0.2.21
test_forward "k6.netlab.local" netlab-dns 127.0.0.1 k6.netlab.local 10.0.2.30
test_forward "prometheus-dmz.netlab.local" netlab-dns 127.0.0.1 prometheus-dmz.netlab.local 10.0.1.19
test_forward "prometheus-public.netlab.local" netlab-dns 127.0.0.1 prometheus-public.netlab.local 10.0.3.19

# ============================================
# Forward lookups from K6 container (Internal network, 10.0.2.0/24)
# Verifies DNS is reachable from another Internal container
# ============================================
echo -e "${BLUE}--- Forward Lookups (netlab-k6, Internal network) ---${NC}\n"

test_forward "web1.netlab.local from k6" netlab-k6 $DNS_SERVER web1.netlab.local 10.0.1.10
test_forward "web3.netlab.local from k6" netlab-k6 $DNS_SERVER web3.netlab.local 10.0.1.12
test_forward "haproxy.netlab.local from k6" netlab-k6 $DNS_SERVER haproxy.netlab.local 10.0.3.10
test_forward "prometheus.netlab.local from k6 → 10.0.2.19" netlab-k6 $DNS_SERVER prometheus.netlab.local 10.0.2.19

# ============================================
# Reverse lookups (PTR records)
# ============================================
echo -e "${BLUE}--- Reverse Lookups (PTR Records) ---${NC}\n"

test_reverse "PTR: 10.0.1.10 → web1" netlab-dns 127.0.0.1 10.0.1.10 web1.netlab.local
test_reverse "PTR: 10.0.1.11 → web2" netlab-dns 127.0.0.1 10.0.1.11 web2.netlab.local
test_reverse "PTR: 10.0.1.12 → web3" netlab-dns 127.0.0.1 10.0.1.12 web3.netlab.local
test_reverse "PTR: 10.0.2.10 → dns" netlab-dns 127.0.0.1 10.0.2.10 dns.netlab.local
test_reverse "PTR: 10.0.2.19 → prometheus (corrected)" netlab-dns 127.0.0.1 10.0.2.19 prometheus.netlab.local
test_reverse "PTR: 10.0.2.21 → grafana" netlab-dns 127.0.0.1 10.0.2.21 grafana.netlab.local
test_reverse "PTR: 10.0.2.30 → k6" netlab-dns 127.0.0.1 10.0.2.30 k6.netlab.local

# ============================================
# Verify removed phantom entries return NXDOMAIN
# ============================================
echo -e "${BLUE}--- Removed Phantom Entries (should not resolve) ---${NC}\n"

echo -e "${YELLOW}Testing: node-exporter.netlab.local should not resolve${NC}"
if docker exec netlab-dns nslookup node-exporter.netlab.local 127.0.0.1 2>&1 | grep -q "NXDOMAIN\|can't find\|not found"; then
    echo -e "  ${GREEN}✓ PASS${NC} - Correctly returns NXDOMAIN\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗ FAIL${NC} - Should not resolve (phantom entry)\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo -e "${YELLOW}Testing: cadvisor.netlab.local should not resolve${NC}"
if docker exec netlab-dns nslookup cadvisor.netlab.local 127.0.0.1 2>&1 | grep -q "NXDOMAIN\|can't find\|not found"; then
    echo -e "  ${GREEN}✓ PASS${NC} - Correctly returns NXDOMAIN\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗ FAIL${NC} - Should not resolve (phantom entry)\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================
# Summary
# ============================================
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "  Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "  Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "${BLUE}======================================${NC}\n"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All DNS tests passed!${NC}\n"
    exit 0
else
    echo -e "${RED}Some DNS tests failed!${NC}\n"
    exit 1
fi
