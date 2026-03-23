#!/bin/bash
# Run K6 load test to simulate normal traffic patterns
# Usage: ./scripts/run_k6_load.sh

set -e

echo "=================================================="
echo "K6 Load Test - Network Lab Environment"
echo "=================================================="
echo ""
echo "This test simulates normal production load patterns."
echo "Duration: ~16 minutes"
echo "Stages:"
echo "  - Ramp up to 10 VUs (2 min)"
echo "  - Maintain 10 VUs (5 min)"
echo "  - Ramp up to 20 VUs (2 min)"
echo "  - Maintain 20 VUs (5 min)"
echo "  - Ramp down to 0 VUs (2 min)"
echo ""
echo "Press Ctrl+C to stop the test early"
echo ""

# Run load test
docker compose exec k6 k6 run \
  --out experimental-prometheus-rw \
  /scripts/load-test.js

echo ""
echo "Load test completed!"
echo "View metrics in Grafana: http://localhost:3000"
echo "Dashboard: K6 Performance Testing"
echo "View HAProxy stats: http://localhost:8404/stats (admin/admin)"
