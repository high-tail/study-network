#!/bin/bash
# Test Layer 3 connectivity and routing across all networks

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Layer 3 Connectivity Tests${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function: ping from a container to an IP
test_ping() {
    local test_name="$1"
    local container="$2"
    local target_ip="$3"

    echo -e "${YELLOW}Testing: $test_name${NC}"
    echo "  Container: $container → $target_ip"

    if docker exec "$container" ping -c 2 -W 2 "$target_ip" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ PASS${NC} - Ping successful\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗ FAIL${NC} - Ping failed\n"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================
# Intra-network connectivity
# ============================================
echo -e "${BLUE}--- DMZ Network (10.0.1.0/24) ---${NC}\n"

test_ping "web1 → Router DMZ interface" netlab-web1 10.0.1.254
test_ping "web2 → Router DMZ interface" netlab-web2 10.0.1.254
test_ping "web3 → Router DMZ interface" netlab-web3 10.0.1.254
test_ping "web1 → HAProxy DMZ interface" netlab-web1 10.0.1.20
test_ping "web1 → web2" netlab-web1 10.0.1.11

echo -e "${BLUE}--- Internal Network (10.0.2.0/24) ---${NC}\n"

test_ping "DNS → Router internal interface" netlab-dns 10.0.2.254
test_ping "DHCP → Router internal interface" netlab-dhcp 10.0.2.254
test_ping "DNS → DHCP" netlab-dns 10.0.2.11

echo -e "${BLUE}--- Public Network (10.0.3.0/24) ---${NC}\n"

test_ping "HAProxy → Router public interface" netlab-haproxy 10.0.3.254

# ============================================
# Cross-network routing (via FRRouting router)
# End hosts use Docker's gateway, not the FRRouting router, for unknown
# subnets — so cross-network routing is tested FROM the router which has
# all three network interfaces.
# ============================================
echo -e "${BLUE}--- Cross-Network Routing (via FRRouting router) ---${NC}\n"

test_ping "Router → Internal: router → DNS" netlab-router 10.0.2.10
test_ping "Router → Internal: router → DHCP" netlab-router 10.0.2.11
test_ping "Router → DMZ: router → web1" netlab-router 10.0.1.10
test_ping "Router → DMZ: router → web2" netlab-router 10.0.1.11
test_ping "Router → DMZ: router → web3" netlab-router 10.0.1.12
test_ping "Router → DMZ: router → HAProxy DMZ" netlab-router 10.0.1.20
test_ping "Router → Public: router → HAProxy public" netlab-router 10.0.3.10

# ============================================
# Router forwarding check
# ============================================
echo -e "${BLUE}--- Router IP Forwarding ---${NC}\n"
echo -e "${YELLOW}Testing: IP forwarding enabled on router${NC}"
FORWARD=$(docker exec netlab-router sysctl -n net.ipv4.ip_forward 2>/dev/null)
if [ "$FORWARD" = "1" ]; then
    echo -e "  ${GREEN}✓ PASS${NC} - net.ipv4.ip_forward = 1\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗ FAIL${NC} - net.ipv4.ip_forward = ${FORWARD:-unknown}\n"
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
    echo -e "${GREEN}All connectivity tests passed!${NC}\n"
    exit 0
else
    echo -e "${RED}Some connectivity tests failed!${NC}\n"
    exit 1
fi
