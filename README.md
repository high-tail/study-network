# Network Lab Environment - OSI Layers 3-7

A complete, locally runnable networking lab environment built with Docker that demonstrates OSI layers 3 through 7, including routing, DNS, DHCP, HTTP, load balancing, and monitoring.

## Overview

This lab provides a fully functional multi-tier network environment for learning and testing networking concepts. All services run locally using Docker and Docker Compose with no external dependencies after the initial build.

Three isolated Docker networks (DMZ, Internal, Public) connected via an FRRouting router, with HAProxy load balancing, DNS, DHCP, Prometheus monitoring, Grafana dashboards, and K6 load testing.

For architecture diagrams, OSI layer details, and learning exercises, see **[overview.md](overview.md)**.

## Prerequisites

- **Docker Engine** 20.10+ (with Compose V2)
- **Docker Compose** 2.0+
- **RAM**: 6-8GB recommended (minimum 4GB with resource limits)
- **Disk Space**: 10GB free
- **OS**: macOS, Linux, or WSL2 on Windows
- **Optional**: `jq` for JSON parsing in test scripts

## Quick Start

### 1. Build and Start the Environment

```bash
# Build all containers
docker compose build

# Start the network lab
docker compose up -d

# Verify all containers are running
docker compose ps
```

### 2. Wait for Services to Initialize

```bash
# Give services about 30 seconds to fully start
sleep 30
```

### 3. Access the Dashboards

- **Grafana Dashboard**: http://localhost:3000
  - Username: `admin`
  - Password: `admin`
  - Dashboard: "Network Lab - Multi-Prometheus Overview"
  - 3 datasources pre-configured (Internal, DMZ, Public)

- **HAProxy Statistics**: http://localhost:8404/stats
  - Username: `admin`
  - Password: `admin`

- **Load Balanced Web Servers**: http://localhost:8080

- **Prometheus Instances**:
  - Internal: http://localhost:9090 (monitors DNS, DHCP)
  - DMZ: http://localhost:9091 (monitors Web1, Web2)
  - Public: http://localhost:9092 (monitors HAProxy)

### 4. Run Test Scripts

```bash
# Run all tests
./scripts/test_all.sh

# Or run individual test suites
./scripts/test_connectivity.sh   # Layer 3 routing tests
./scripts/test_dns.sh             # DNS resolution tests
./scripts/test_http.sh            # HTTP load balancing tests
./scripts/test_https.sh           # HTTPS/TLS tests (requires certs)
```

### 5. Run K6 Performance Tests

```bash
# Quick smoke test (1 min)
./scripts/run_k6_smoke.sh

# Full load test (16 min)
./scripts/run_k6_load.sh

# Stress test with 100 VUs (~8.5 min)
./scripts/run_k6_stress.sh

# Spike test with 200 VUs (~5.5 min)
./scripts/run_k6_spike.sh

# Interactive menu for all test profiles
./scripts/run_k6_tests.sh
```

## Detailed Usage

### Testing Layer 3 Routing

Verify routing between different network segments:

```bash
# Ping from router to web1 (DMZ network)
docker exec netlab-router ping -c 3 10.0.1.10

# Ping from web1 to DNS server (across networks via router)
docker exec netlab-web1 ping -c 3 10.0.2.10

# View routing table on router
docker exec netlab-router ip route show
```

### Testing DNS Resolution

Test DNS name resolution:

```bash
# Resolve web server names
docker exec netlab-haproxy nslookup web1.netlab.local 10.0.2.10
docker exec netlab-haproxy nslookup web2.netlab.local 10.0.2.10

# Test CNAME resolution (www and api point to haproxy)
docker exec netlab-haproxy nslookup www.netlab.local 10.0.2.10
docker exec netlab-haproxy nslookup api.netlab.local 10.0.2.10

# View DNS logs
docker logs netlab-dns
```

### Testing Load Balancing

Test HAProxy distributing traffic between web servers:

```bash
# Make multiple requests to see load distribution
for i in {1..10}; do
  curl -s http://localhost:8080/ | grep "SERVER"
  sleep 0.5
done

# Check which backend servers are healthy
curl http://localhost:8404/stats

# View HAProxy logs
docker logs netlab-haproxy
```

### Testing HTTPS/TLS

Test SSL termination and HTTPS backends:

```bash
# HTTPS via HAProxy (SSL termination)
curl -k https://localhost:8443/

# Direct HTTPS to web3
docker exec netlab-haproxy curl -k https://10.0.1.12/

# View TLS details
docker exec netlab-haproxy curl -k https://10.0.1.12/tls-info

# Run HTTPS test suite
./scripts/test_https.sh
```

### Testing Direct Web Server Access

Access web servers directly (bypassing load balancer):

```bash
# Access from HAProxy container to web1
docker exec netlab-haproxy curl http://10.0.1.10/

# Access from HAProxy container to web2
docker exec netlab-haproxy curl http://10.0.1.11/

# Access web3 over HTTPS
docker exec netlab-haproxy curl -k https://10.0.1.12/

# Check health endpoints
docker exec netlab-haproxy curl http://10.0.1.10/health
docker exec netlab-haproxy curl http://10.0.1.11/health
docker exec netlab-haproxy curl -k https://10.0.1.12/health
```

### Monitoring and Observability

#### View Grafana Dashboards

1. Navigate to http://localhost:3000
2. Login with admin/admin
3. Navigate to Dashboards → "Network Lab - Multi-Prometheus Overview"
4. View metrics from all three networks:
   - Service health status (3 gauges, one per network)
   - CPU usage across all services
   - Memory consumption
   - Network traffic (RX/TX)
   - Disk I/O operations

#### Query Prometheus Directly

```bash
# Query Prometheus-Internal (DNS, DHCP, Router metrics)
open http://localhost:9090

# Query Prometheus-DMZ (Web1, Web2, Web3, HAProxy backend metrics)
open http://localhost:9091

# Query Prometheus-Public (HAProxy frontend metrics)
open http://localhost:9092

# Example: Check which targets are being monitored
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

#### Monitor Node-Exporter Metrics

```bash
# View node-exporter metrics from any container
docker exec netlab-web1 curl -s http://localhost:9100/metrics | grep node_cpu

# Check memory usage
docker exec netlab-dns curl -s http://localhost:9100/metrics | grep node_memory_MemTotal
```

### Network Analysis

Inspect network traffic and connectivity:

```bash
# View network interfaces on router
docker exec netlab-router ip addr show

# Capture traffic on router (DMZ interface)
docker exec netlab-router tcpdump -i eth0 -n

# Trace route from web1 to grafana
docker exec netlab-web1 traceroute 10.0.2.21

# View ARP table
docker exec netlab-router arp -a
```

### DHCP Testing

Check DHCP server status:

```bash
# View DHCP logs
docker logs netlab-dhcp

# Check DHCP lease file
docker exec netlab-dhcp cat /var/lib/dhcp/dhcpd.leases

# View DHCP configuration
docker exec netlab-dhcp cat /etc/dhcp/dhcpd.conf
```

For component IPs, port mappings, and OSI layer details, see **[overview.md](overview.md)**.

## Troubleshooting

### Containers won't start

```bash
# Check container logs
docker compose logs

# Check specific service
docker logs netlab-router

# Restart all services
docker compose restart
```

### DNS not resolving

```bash
# Check DNS server is running
docker exec netlab-dns ps aux | grep dnsmasq

# Test DNS directly
docker exec netlab-dns nslookup web1.netlab.local 127.0.0.1

# Check DNS configuration
docker exec netlab-dns cat /etc/dnsmasq.conf
```

### Routing not working

```bash
# Check IP forwarding is enabled
docker exec netlab-router sysctl net.ipv4.ip_forward

# Verify routing table
docker exec netlab-router ip route show

# Check FRR status
docker exec netlab-router vtysh -c "show ip route"
```

### HAProxy not load balancing

```bash
# Check backend servers are healthy
curl http://localhost:8404/stats

# View HAProxy logs
docker logs netlab-haproxy

# Test backend servers directly
docker exec netlab-haproxy curl http://10.0.1.10/health
docker exec netlab-haproxy curl http://10.0.1.11/health
```

### Grafana won't connect to Prometheus

```bash
# Check all Prometheus instances are running
curl http://localhost:9090/-/healthy  # Internal
curl http://localhost:9091/-/healthy  # DMZ (mapped to 9090 internally)
curl http://localhost:9092/-/healthy  # Public (mapped to 9090 internally)

# Test from Grafana container (uses internal IPs and port 9090)
docker exec netlab-grafana curl http://10.0.2.19:9090/-/healthy  # Internal
docker exec netlab-grafana curl http://10.0.1.19:9090/-/healthy  # DMZ
docker exec netlab-grafana curl http://10.0.3.19:9090/-/healthy  # Public

# Check datasource configuration (should show all 3 datasources)
docker exec netlab-grafana cat /etc/grafana/provisioning/datasources/prometheus.yml

# Verify datasources in Grafana API
docker exec netlab-grafana curl -s -u admin:admin http://localhost:3000/api/datasources | jq '.[] | {name, url, uid}'
```

## Cleanup

### Stop the lab

```bash
# Stop all containers
docker compose down

# Stop and remove volumes
docker compose down -v

# Remove all images (optional)
docker compose down --rmi all
```

### Reset everything

```bash
# Remove all containers, networks, and volumes
docker compose down -v --rmi all

# Clean up Docker system
docker system prune -a
```

## File Structure

```
network-lab/
├── docker-compose.yml          # Main orchestration file (with health checks, dependencies)
├── .env                        # Environment variables (IPs, ports, credentials, versions)
├── CLAUDE.md                   # AI assistant project instructions
├── README.md                   # This file
├── overview.md                 # Architecture diagrams, OSI layers, learning guide
├── router/
│   ├── Dockerfile             # FRRouting router image
│   ├── frr.conf               # Routing configuration
│   ├── daemons                # FRR daemon config
│   └── start-with-exporter.sh # Wrapper to start router + node-exporter
├── dns/
│   ├── Dockerfile             # Dnsmasq DNS server
│   ├── dnsmasq.conf           # DNS configuration
│   └── start-with-exporter.sh # Wrapper to start DNS + node-exporter
├── dhcp/
│   ├── Dockerfile             # ISC DHCP server
│   ├── dhcpd.conf             # DHCP configuration
│   └── start-with-exporter.sh # Wrapper to start DHCP + node-exporter
├── web1/
│   ├── Dockerfile             # Nginx web server 1
│   ├── index.html             # Web content
│   └── start-with-exporter.sh # Wrapper to start Nginx + node-exporter
├── web2/
│   ├── Dockerfile             # Nginx web server 2
│   ├── index.html             # Web content
│   └── start-with-exporter.sh # Wrapper to start Nginx + node-exporter
├── web3/
│   ├── Dockerfile             # Nginx web server 3 with HTTPS/TLS
│   ├── index.html             # Web content
│   └── start-with-exporter.sh # Wrapper to start Nginx + node-exporter
├── haproxy/
│   ├── Dockerfile             # HAProxy load balancer
│   ├── haproxy.cfg            # Load balancer config (HTTP + HTTPS frontends)
│   └── start-with-exporter.sh # Wrapper to start HAProxy + node-exporter
├── k6/
│   ├── Dockerfile             # K6 load testing container
│   ├── README.md              # K6 test documentation
│   └── scripts/
│       ├── smoke-test.js      # Quick 1-min verification
│       ├── load-test.js       # 16-min load test
│       ├── stress-test.js     # Stress test (100 VUs)
│       └── spike-test.js      # Spike test (200 VUs)
├── certs/                      # TLS certificates (gitignored, self-signed)
├── monitor/
│   ├── prometheus/
│   │   ├── prometheus-internal.yml  # Internal network scrape config
│   │   ├── prometheus-dmz.yml       # DMZ network scrape config
│   │   └── prometheus-public.yml    # Public network scrape config
│   └── grafana/
│       ├── dashboards/
│       │   ├── network-lab.json     # Multi-Prometheus dashboard
│       │   └── k6-netlab.json       # K6 performance dashboard
│       └── provisioning/
│           ├── dashboards/
│           │   └── dashboard.yml    # Dashboard provisioning config
│           └── datasources/
│               └── prometheus.yml   # 3 Prometheus datasources
└── scripts/
    ├── test_all.sh            # Run all tests
    ├── test_connectivity.sh   # Layer 3 tests
    ├── test_dns.sh            # DNS tests
    ├── test_http.sh           # HTTP/load balancing tests
    ├── test_https.sh          # HTTPS/TLS tests
    ├── generate-certs.sh      # Generate self-signed TLS certificates
    ├── run_k6_smoke.sh        # K6 smoke test runner
    ├── run_k6_load.sh         # K6 load test runner
    ├── run_k6_stress.sh       # K6 stress test runner
    ├── run_k6_spike.sh        # K6 spike test runner
    └── run_k6_tests.sh        # Interactive K6 test menu
```

## License

This project is provided as-is for educational purposes.

## Contributing

Feel free to extend this lab environment with additional services or network configurations.

---
