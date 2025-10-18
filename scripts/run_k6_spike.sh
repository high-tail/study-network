#!/bin/bash
# Run K6 spike test to test system recovery from sudden traffic bursts
# Usage: ./scripts/run_k6_spike.sh

set -e

echo "=================================================="
echo "K6 Spike Test - Network Lab Environment"
echo "=================================================="
echo ""
echo "This test simulates sudden traffic spikes to test system resilience."
echo ""
echo "Duration: ~5.5 minutes"
echo "Stages:"
echo "  - Normal load: 10 VUs (30 sec)"
echo "  - SPIKE: Ramp to 200 VUs (1 min)"
echo "  - SPIKE: Maintain 200 VUs (30 sec)"
echo "  - Recovery: Drop to 10 VUs (1 min)"
echo "  - Recovery: Maintain 10 VUs (2 min)"
echo "  - Ramp down to 0 VUs (30 sec)"
echo ""
echo "Watch Grafana dashboards during the spike!"
echo "Press Ctrl+C to stop the test early"
echo ""

# Run spike test
docker compose exec k6 k6 run \
  --out experimental-prometheus-rw \
  /scripts/spike-test.js

echo ""
echo "Spike test completed!"
echo "View metrics in Grafana: http://localhost:3000"
echo "Dashboard: K6 Performance Testing"
echo ""
echo "Analysis:"
echo "  - Check response time during spike"
echo "  - Verify system recovered after spike"
echo "  - Review error rates during peak load"
