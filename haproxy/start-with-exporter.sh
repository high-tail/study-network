#!/bin/sh
# Generic startup script to run node-exporter alongside the main service
# Usage: start-with-exporter.sh <main_command> [args...]

# Start node_exporter in the background on port 9100
/usr/bin/node_exporter \
  --web.listen-address=":9100" \
  --collector.disable-defaults \
  --collector.cpu \
  --collector.meminfo \
  --collector.diskstats \
  --collector.netdev \
  --collector.filesystem \
  --collector.loadavg \
  --collector.stat &

# Store the PID
NODE_EXPORTER_PID=$!

# Function to handle shutdown
shutdown() {
  echo "Shutting down node_exporter (PID: $NODE_EXPORTER_PID)"
  kill $NODE_EXPORTER_PID 2>/dev/null
  wait $NODE_EXPORTER_PID 2>/dev/null
  exit 0
}

# Trap SIGTERM and SIGINT
trap shutdown SIGTERM SIGINT

# Start the main service in the foreground
exec "$@"
