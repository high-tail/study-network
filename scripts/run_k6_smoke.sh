#!/bin/bash
# Run K6 smoke test to verify system functionality
# Usage: ./scripts/run_k6_smoke.sh

set -e

echo "=================================================="
echo "K6 Smoke Test - Network Lab Environment"
echo "=================================================="
echo ""
echo "This test runs minimal load to verify the system works correctly."
echo "Duration: 1 minute"
echo "Virtual Users: 1"
echo ""

# Run smoke test
docker compose exec k6 k6 run \
  --out experimental-prometheus-rw \
  /scripts/smoke-test.js

echo ""
echo "Smoke test completed!"
echo "View metrics in Grafana: http://localhost:3000"
echo "Dashboard: K6 Performance Testing"
