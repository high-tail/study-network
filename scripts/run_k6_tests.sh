#!/bin/bash

# K6 Load Testing Script
# Runs various load test scenarios against the network lab environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if K6 container is running
if ! docker ps | grep -q netlab-k6; then
    print_error "K6 container is not running. Please start it with: docker compose up -d k6"
    exit 1
fi

# Function to run a K6 test
run_test() {
    local test_name=$1
    local test_script=$2

    print_header "Running $test_name"

    # Run the test with Prometheus remote write enabled
    docker exec netlab-k6 k6 run \
        --out experimental-prometheus-rw \
        "/scripts/${test_script}" \
        2>&1

    if [ $? -eq 0 ]; then
        print_success "$test_name completed successfully"
    else
        print_error "$test_name failed"
        return 1
    fi

    echo ""
}

# Main menu
if [ $# -eq 0 ]; then
    echo "K6 Load Testing Menu"
    echo "===================="
    echo "1. Smoke Test (1 VU, 1 minute)"
    echo "2. Load Test (Ramp up to 20 VUs, 16 minutes)"
    echo "3. Stress Test (Ramp up to 100 VUs, 26 minutes)"
    echo "4. Spike Test (Sudden spike to 200 VUs, 5.5 minutes)"
    echo "5. Run All Tests"
    echo ""
    read -p "Select test to run (1-5): " choice

    case $choice in
        1)
            run_test "Smoke Test" "smoke-test.js"
            ;;
        2)
            run_test "Load Test" "load-test.js"
            ;;
        3)
            run_test "Stress Test" "stress-test.js"
            ;;
        4)
            run_test "Spike Test" "spike-test.js"
            ;;
        5)
            print_info "Running all tests sequentially..."
            run_test "Smoke Test" "smoke-test.js"
            sleep 5
            run_test "Load Test" "load-test.js"
            sleep 5
            run_test "Stress Test" "stress-test.js"
            sleep 5
            run_test "Spike Test" "spike-test.js"
            print_success "All tests completed!"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
else
    # Run specific test from command line
    case $1 in
        smoke)
            run_test "Smoke Test" "smoke-test.js"
            ;;
        load)
            run_test "Load Test" "load-test.js"
            ;;
        stress)
            run_test "Stress Test" "stress-test.js"
            ;;
        spike)
            run_test "Spike Test" "spike-test.js"
            ;;
        all)
            print_info "Running all tests sequentially..."
            run_test "Smoke Test" "smoke-test.js"
            sleep 5
            run_test "Load Test" "load-test.js"
            sleep 5
            run_test "Stress Test" "stress-test.js"
            sleep 5
            run_test "Spike Test" "spike-test.js"
            print_success "All tests completed!"
            ;;
        *)
            echo "Usage: $0 [smoke|load|stress|spike|all]"
            exit 1
            ;;
    esac
fi

print_info "View results in Grafana: http://localhost:3000/d/k6-performance"
print_info "View Prometheus metrics: http://localhost:9090"
