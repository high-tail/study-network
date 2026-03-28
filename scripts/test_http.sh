#!/bin/bash
# Test HTTP connectivity, health checks, and load balancing

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  HTTP Connectivity Tests${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# HTTP test function
test_http() {
    local test_name="$1"
    local container="$2"
    local url="$3"
    local expected_status="${4:-200}"

    echo -e "${YELLOW}Testing: $test_name${NC}"
    echo "  $container: GET $url → HTTP $expected_status"

    ACTUAL=$(docker exec "$container" curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    if [ "$ACTUAL" = "$expected_status" ]; then
        echo -e "  ${GREEN}✓ PASS${NC} - Got HTTP $ACTUAL\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗ FAIL${NC} - Expected $expected_status, got $ACTUAL\n"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================
# Direct web server health checks
# ============================================
echo -e "${BLUE}--- Direct Web Server Health Checks ---${NC}\n"

test_http "web1 health check" netlab-web1 http://localhost/health
test_http "web2 health check" netlab-web2 http://localhost/health
test_http "web3 HTTP→HTTPS redirect" netlab-web3 http://localhost/ 301

# web3 HTTPS tested below via haproxy container (self-signed cert requires -k)
echo -e "${YELLOW}Testing: web3 HTTPS health check (self-signed cert)${NC}"
echo "  netlab-haproxy: GET https://10.0.1.12/health → 200"
ACTUAL=$(docker exec netlab-haproxy curl -sk -o /dev/null -w "%{http_code}" https://10.0.1.12/health 2>/dev/null)
if [ "$ACTUAL" = "200" ]; then
    echo -e "  ${GREEN}✓ PASS${NC} - Got HTTP $ACTUAL\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗ FAIL${NC} - Expected 200, got $ACTUAL\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================
# HAProxy frontend
# ============================================
echo -e "${BLUE}--- HAProxy HTTP Frontend ---${NC}\n"

test_http "HAProxy HTTP frontend (host port)" netlab-haproxy http://10.0.3.10/health
test_http "HAProxy health endpoint via DMZ" netlab-web1 http://10.0.1.20/health

# ============================================
# HAProxy stats page
# ============================================
echo -e "${BLUE}--- HAProxy Stats Page ---${NC}\n"

echo -e "${YELLOW}Testing: HAProxy stats page accessible${NC}"
echo "  netlab-haproxy: GET http://10.0.1.20:8404/stats"
STATS=$(docker exec netlab-haproxy curl -s -o /dev/null -w "%{http_code}" \
    -u admin:admin http://10.0.1.20:8404/stats 2>/dev/null)
if [ "$STATS" = "200" ]; then
    echo -e "  ${GREEN}✓ PASS${NC} - Stats page accessible\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗ FAIL${NC} - Expected 200, got $STATS\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================
# Load balancing distribution
# ============================================
echo -e "${BLUE}--- HTTP Load Balancing (Round-Robin) ---${NC}\n"

echo -e "${YELLOW}Testing: Round-robin distribution across web1 and web2${NC}"
echo "  Sending 10 requests via HAProxy..."

WEB1_HITS=0
WEB2_HITS=0

for i in $(seq 1 10); do
    BODY=$(docker exec netlab-haproxy curl -s http://10.0.1.20/ 2>/dev/null)
    if echo "$BODY" | grep -qi "web1\|10\.0\.1\.10"; then
        WEB1_HITS=$((WEB1_HITS + 1))
    elif echo "$BODY" | grep -qi "web2\|10\.0\.1\.11"; then
        WEB2_HITS=$((WEB2_HITS + 1))
    fi
done

echo "  web1 hits: $WEB1_HITS / web2 hits: $WEB2_HITS"

if [ $WEB1_HITS -gt 0 ] && [ $WEB2_HITS -gt 0 ]; then
    echo -e "  ${GREEN}✓ PASS${NC} - Load distributed across both backends\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗ FAIL${NC} - Load not distributed (web1=$WEB1_HITS, web2=$WEB2_HITS)\n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================
# Individual server endpoints
# ============================================
echo -e "${BLUE}--- Individual Endpoint Tests ---${NC}\n"

test_http "web1 /info endpoint" netlab-web1 http://localhost/info
test_http "web2 /info endpoint" netlab-web2 http://localhost/info

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
    echo -e "${GREEN}All HTTP tests passed!${NC}\n"
    exit 0
else
    echo -e "${RED}Some HTTP tests failed!${NC}\n"
    exit 1
fi
