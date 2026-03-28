#!/bin/bash
# Run all test suites and report overall results

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Network Lab - Full Test Suite${NC}"
echo -e "${BLUE}======================================${NC}\n"

SUITES_PASSED=0
SUITES_FAILED=0
FAILED_SUITES=()

run_suite() {
    local suite_name="$1"
    local script="$2"

    echo -e "${BLUE}>>> Running: $suite_name${NC}\n"

    if bash "$script"; then
        echo -e "${GREEN}>>> SUITE PASSED: $suite_name${NC}\n"
        SUITES_PASSED=$((SUITES_PASSED + 1))
    else
        echo -e "${RED}>>> SUITE FAILED: $suite_name${NC}\n"
        SUITES_FAILED=$((SUITES_FAILED + 1))
        FAILED_SUITES+=("$suite_name")
    fi

    echo -e "${BLUE}--------------------------------------${NC}\n"
}

run_suite "Layer 3 Connectivity" "$SCRIPT_DIR/test_connectivity.sh"
run_suite "DNS Resolution" "$SCRIPT_DIR/test_dns.sh"
run_suite "HTTP Load Balancing" "$SCRIPT_DIR/test_http.sh"
run_suite "HTTPS / TLS" "$SCRIPT_DIR/test_https.sh"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Overall Results${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "  Suites Passed: ${GREEN}$SUITES_PASSED${NC}"
echo -e "  Suites Failed: ${RED}$SUITES_FAILED${NC}"

if [ ${#FAILED_SUITES[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${RED}Failed suites:${NC}"
    for suite in "${FAILED_SUITES[@]}"; do
        echo -e "    - $suite"
    done
fi

echo -e "${BLUE}======================================${NC}\n"

if [ $SUITES_FAILED -eq 0 ]; then
    echo -e "${GREEN}All test suites passed!${NC}\n"
    exit 0
else
    echo -e "${RED}$SUITES_FAILED test suite(s) failed!${NC}\n"
    exit 1
fi
