#!/bin/bash
# Run K6 stress test to find system breaking point
# Usage: ./scripts/run_k6_stress.sh

set -e

echo "=================================================="
echo "K6 Stress Test - Network Lab Environment"
echo "=================================================="
echo ""
echo "WARNING: This test pushes the system beyond normal load."
echo "It helps identify the breaking point and bottlenecks."
echo ""
echo "Duration: ~26 minutes"
echo "Stages:"
echo "  - Ramp up to 20 VUs (2 min)"
echo "  - Maintain 20 VUs (5 min)"
echo "  - Ramp up to 50 VUs (2 min)"
echo "  - Maintain 50 VUs (5 min)"
echo "  - Ramp up to 100 VUs (2 min)"
echo "  - Maintain 100 VUs (5 min) <- STRESS LEVEL"
echo "  - Ramp down to 0 VUs (5 min) <- RECOVERY"
echo ""
echo "Monitor system resources with: docker stats"
echo "Press Ctrl+C to stop the test early"
echo ""

read -p "Are you sure you want to run the stress test? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Stress test cancelled."
    exit 0
fi

# Run stress test
docker compose exec k6 k6 run \
  --out experimental-prometheus-rw \
  /scripts/stress-test.js

echo ""
echo "Stress test completed!"
echo "View metrics in Grafana: http://localhost:3000"
echo "Dashboard: K6 Performance Testing"
echo "Check for any errors in container logs: docker compose logs"
