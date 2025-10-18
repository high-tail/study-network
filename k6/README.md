# K6 Load Testing for Network Lab

This directory contains K6 load testing configuration and scripts for performance testing the network lab environment.

## Overview

K6 is a modern load testing tool that allows you to test the performance and reliability of your systems. In this lab, K6 generates HTTP traffic to test:

- HAProxy load balancing efficiency
- Web server performance under load
- Network throughput and latency
- System recovery from traffic spikes
- Overall infrastructure resilience

## Architecture

```
K6 (10.0.2.30) → HAProxy (10.0.3.10) → Web1/Web2 (10.0.1.10-11)
              ↓
      Prometheus (10.0.2.19) → Grafana (10.0.2.21)
```

- **K6 Container**: Runs in the Internal network, sends traffic to HAProxy
- **Metrics Flow**: K6 → Prometheus (via remote write) → Grafana dashboards
- **Target**: HAProxy load balancer (`haproxy.netlab.local:8080`)

## Test Scenarios

### 1. Smoke Test (`smoke-test.js`)
**Purpose**: Verify system functionality with minimal load

- **Duration**: 1 minute
- **Virtual Users**: 1
- **Thresholds**:
  - 95% of requests < 500ms
  - Error rate < 1%
- **Use Case**: Quick sanity check after deployment or configuration changes

**Run:**
```bash
./scripts/run_k6_smoke.sh
# OR
docker compose exec k6 k6 run --out experimental-prometheus-rw /scripts/smoke-test.js
```

### 2. Load Test (`load-test.js`)
**Purpose**: Simulate normal production traffic patterns

- **Duration**: ~16 minutes
- **Stages**:
  - Ramp up to 10 VUs (2 min)
  - Maintain 10 VUs (5 min)
  - Ramp up to 20 VUs (2 min)
  - Maintain 20 VUs (5 min)
  - Ramp down to 0 VUs (2 min)
- **Thresholds**:
  - 95% of requests < 1000ms
  - Error rate < 5%
  - Success rate > 95%
- **Custom Metrics**:
  - Load balancing distribution (web1_hits, web2_hits)
  - Response time trends
  - Success/failure rates

**Run:**
```bash
./scripts/run_k6_load.sh
# OR
docker compose exec k6 k6 run --out experimental-prometheus-rw /scripts/load-test.js
```

### 3. Stress Test (`stress-test.js`)
**Purpose**: Find system breaking point and identify bottlenecks

- **Duration**: ~26 minutes
- **Stages**:
  - Ramp up to 20 VUs (2 min)
  - Maintain 20 VUs (5 min)
  - Ramp up to 50 VUs (2 min)
  - Maintain 50 VUs (5 min)
  - Ramp up to 100 VUs (2 min)
  - Maintain 100 VUs (5 min) ← **STRESS LEVEL**
  - Ramp down to 0 VUs (5 min) ← **RECOVERY**
- **Thresholds**:
  - 95% of requests < 2000ms (relaxed for stress)
  - Error rate < 10% (some failures expected)
- **Monitor**: CPU, memory, network usage with `docker stats`

**Run:**
```bash
./scripts/run_k6_stress.sh
# OR
docker compose exec k6 k6 run --out experimental-prometheus-rw /scripts/stress-test.js
```

### 4. Spike Test (`spike-test.js`)
**Purpose**: Test system resilience and recovery from sudden traffic bursts

- **Duration**: ~5.5 minutes
- **Stages**:
  - Normal: 10 VUs (30 sec)
  - **SPIKE**: Ramp to 200 VUs (1 min)
  - **SPIKE**: Maintain 200 VUs (30 sec)
  - Recovery: Drop to 10 VUs (1 min)
  - Recovery: Maintain 10 VUs (2 min)
  - Ramp down to 0 VUs (30 sec)
- **Thresholds**:
  - 95% of requests < 3000ms
  - Error rate < 20% (spike conditions)
- **Focus**: System recovery speed and stability

**Run:**
```bash
./scripts/run_k6_spike.sh
# OR
docker compose exec k6 k6 run --out experimental-prometheus-rw /scripts/spike-test.js
```

## Custom Test Execution

You can run K6 with custom parameters:

```bash
# Run with custom VUs and duration
docker compose exec k6 k6 run --vus 50 --duration 30s /scripts/load-test.js

# Run without Prometheus export (console output only)
docker compose exec k6 k6 run /scripts/smoke-test.js

# Run with custom environment variables
docker compose exec -e BASE_URL=http://10.0.3.10 k6 k6 run /scripts/load-test.js

# Run and save results to file
docker compose exec k6 k6 run --out json=/results/test-results.json /scripts/load-test.js
```

## Metrics and Monitoring

### K6 Metrics Exported to Prometheus

K6 automatically exports these metrics via remote write:

- `k6_http_reqs_total`: Total HTTP requests
- `k6_http_req_failed_total`: Failed HTTP requests
- `k6_http_req_duration`: Request duration histogram
- `k6_vus`: Current number of active virtual users
- `k6_vus_max`: Maximum number of allocated VUs
- `k6_data_received_total`: Total bytes received
- `k6_data_sent_total`: Total bytes sent
- `k6_iterations_total`: Total iterations completed

### Grafana Dashboard

Access the K6 Performance Testing dashboard:

1. Open Grafana: http://localhost:3000
2. Login: `admin` / `admin`
3. Navigate to **Dashboards** → **K6 Performance Testing**

**Dashboard Panels:**
- Request Rate (requests/sec)
- Error Rate (gauge)
- Active Virtual Users (gauge)
- Response Time Percentiles (P50, P95, P99)
- Virtual Users Over Time
- HTTP Status Codes Distribution
- Data Transfer Rate

### Real-Time Monitoring During Tests

While tests are running, monitor:

1. **K6 Console Output**: Real-time test progress
   ```bash
   docker compose logs -f k6
   ```

2. **Grafana Dashboard**: Visual metrics in real-time
   - http://localhost:3000

3. **HAProxy Stats**: Backend server health and distribution
   - http://localhost:8404/stats (admin/admin)

4. **Prometheus Queries**: Direct metric queries
   - http://localhost:9090/graph
   - Example query: `rate(k6_http_reqs_total[1m])`

5. **Container Resources**: CPU, memory, network usage
   ```bash
   docker stats netlab-web1 netlab-web2 netlab-haproxy netlab-k6
   ```

## Configuration

### Environment Variables

K6 is pre-configured with:

- `K6_PROMETHEUS_RW_SERVER_URL`: Prometheus remote write endpoint
- `K6_PROMETHEUS_RW_TREND_AS_NATIVE_HISTOGRAM`: Enable histogram support

### Network Configuration

K6 runs in the Internal network (`10.0.2.0/24`) with:
- IP Address: `10.0.2.30`
- DNS: Uses internal DNS server (`10.0.2.10`)
- Target: HAProxy via hostname resolution (`haproxy.netlab.local`)

## Troubleshooting

### K6 Can't Resolve Hostnames

```bash
# Verify DNS is working
docker compose exec k6 nslookup haproxy.netlab.local

# Expected output should show: 10.0.3.10
```

### Prometheus Not Receiving Metrics

```bash
# Check Prometheus remote write is enabled
docker compose exec prometheus-internal wget -O- http://localhost:9090/api/v1/status/config | grep enable-remote-write-receiver

# Verify K6 environment variable
docker compose exec k6 env | grep K6_PROMETHEUS

# Check Prometheus logs
docker compose logs prometheus-internal | grep remote
```

### High Error Rates

```bash
# Check HAProxy backend health
curl http://localhost:8404/stats

# Verify both web servers are running
docker compose ps web1 web2

# Check web server logs
docker compose logs web1 web2

# Test connectivity from K6 container
docker compose exec k6 curl -v http://haproxy.netlab.local:8080
```

### Tests Running Slowly

Check resource limits:
```bash
# View container resources
docker stats

# Check if containers are hitting CPU/memory limits
docker compose ps

# Increase resources if needed (edit docker-compose.yml)
```

## Best Practices

1. **Start Small**: Always run smoke test first before load tests
2. **Monitor During Tests**: Keep Grafana and HAProxy stats open during test execution
3. **Baseline First**: Run load test first to establish baseline performance
4. **Progressive Testing**: smoke → load → stress → spike
5. **Clean Between Tests**: Allow system to stabilize between test runs
6. **Resource Monitoring**: Watch `docker stats` during stress/spike tests
7. **Save Results**: Export important test results for comparison
8. **Document Findings**: Note any bottlenecks or issues discovered

## Example Test Workflow

```bash
# 1. Start the environment
docker compose up -d

# 2. Verify all services are healthy
docker compose ps

# 3. Run smoke test (quick verification)
./scripts/run_k6_smoke.sh

# 4. Run load test (normal traffic)
./scripts/run_k6_load.sh

# 5. Analyze results in Grafana
open http://localhost:3000

# 6. Optional: Run stress test (find limits)
./scripts/run_k6_stress.sh

# 7. Optional: Run spike test (resilience)
./scripts/run_k6_spike.sh
```

## Custom Test Development

Create your own test scripts in `/scripts/`:

```javascript
// my-custom-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,
  duration: '30s',
};

export default function () {
  const res = http.get('http://haproxy.netlab.local:8080');
  check(res, {
    'status is 200': (r) => r.status === 200,
  });
  sleep(1);
}
```

Run your custom test:
```bash
docker compose exec k6 k6 run --out experimental-prometheus-rw /scripts/my-custom-test.js
```

## Resources

- [K6 Documentation](https://k6.io/docs/)
- [K6 Test Types](https://k6.io/docs/test-types/introduction/)
- [K6 Metrics](https://k6.io/docs/using-k6/metrics/)
- [K6 Prometheus Output](https://k6.io/docs/results-output/real-time/prometheus-remote-write/)
