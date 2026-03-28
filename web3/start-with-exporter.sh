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

# Start the main service in the background so this shell stays alive
# to receive signals and clean up node_exporter on container stop
"$@" &
MAIN_PID=$!

# Wait for main process to exit
wait $MAIN_PID
MAIN_EXIT=$?

# Cleanup node_exporter
kill $NODE_EXPORTER_PID 2>/dev/null
exit $MAIN_EXIT
