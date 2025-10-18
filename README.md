# Network Lab Environment - OSI Layers 3-7

A complete, locally runnable networking lab environment built with Docker that demonstrates OSI layers 3 through 7, including routing, DNS, DHCP, HTTP, load balancing, and monitoring.

## Overview

This lab provides a fully functional multi-tier network environment for learning and testing networking concepts. All services run locally using Docker and Docker Compose with no external dependencies after the initial build.

### Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                      PUBLIC NETWORK (10.0.3.0/24)                    │
│                                                                      │
│  ┌──────────┐  ┌────────────┐  ┌──────────┐  ┌──────────────────┐    │
│  │  Router  │  │  HAProxy   │  │ Grafana  │  │ Prometheus-Public│    │
│  │ (.254)   │  │  (.10)     │  │  (.21)   │  │     (.19)        │    │
│  │(Layer 3) │  │ (Layer 4/7)│  │(Monitor) │  │  (Metrics)       │    │
│  └────┬─────┘  └──────┬─────┘  └────┬─────┘  └──────────────────┘    │
└───────┼───────────────┼─────────────┼────────────────────────────────┘
        │               │             │
        │               │             │
┌───────┼───────────────┼─────────────┼────────────────────────────────┐
│       │      DMZ NETWORK (10.0.1.0/24)            │                  │
│       │               │             │             │                  │
│  ┌────┴─────┐    ┌────┴────┐   ┌────┴────┐   ┌────┴────┐  ┌───────┐  │
│  │  Router  │    │ HAProxy │   │  Web1   │   │  Web2   │  │Prom-  │  │
│  │ (.254)   │    │  (.20)  │   │  (.10)  │   │  (.11)  │  │ DMZ   │  │
│  │          │    │(Backend)│   │(Layer 7)│   │(Layer 7)│  │(.19)  │  │
│  └────┬─────┘    └─────────┘   └─────────┘   └─────────┘  └───────┘  │
└───────┼──────────────────────────────────────────────────────────────┘
        │
        │
┌───────┼──────────────────────────────────────────────────────────────┐
│       │         INTERNAL NETWORK (10.0.2.0/24)                       │
│       │                                                              │
│  ┌────┴─────┐  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Router  │  │   DNS   │  │  DHCP   │  │ Grafana  │  │Prom-Int. │  │
│  │ (.254)   │  │  (.10)  │  │  (.11)  │  │  (.21)   │  │  (.19)   │  │
│  │          │  │ Server  │  │ Server  │  │(Multi-NW)│  │(Metrics) │  │
│  └──────────┘  └─────────┘  └─────────┘  └──────────┘  └──────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

Legend:
  Router: Connected to all 3 networks, provides inter-network routing
  HAProxy: Dual-homed (Public front-end, DMZ back-end)
  Grafana: Triple-homed (queries Prometheus in all networks)
  Prometheus: 3 instances, one per network for isolated monitoring
```

## Features

### 🚀 DevOps Best Practices (New!)

This lab now implements production-ready DevOps practices:

- ✅ **Health Checks**: Every service has health monitoring
- ✅ **Resource Limits**: CPU and memory constraints prevent resource exhaustion
- ✅ **Auto-Restart**: Services automatically recover from failures (`restart: unless-stopped`)
- ✅ **Smart Dependencies**: Services start in correct order based on health conditions
- ✅ **Static Configuration**: Prometheus monitors network segments with explicit target definitions
- ✅ **Environment Variables**: Easy configuration via `.env` file
- ✅ **Log Rotation**: JSON logs with automatic rotation (max 30MB per container)
- ✅ **Labels & Metadata**: Organized metadata for filtering and organization

**Quick Config:**

### Network Components by OSI Layer

- **Layer 3 (Network)**: FRRouting for inter-network routing
- **Layer 4 (Transport)**: HAProxy for TCP/HTTP load balancing
- **Layer 7 (Application)**:
  - Nginx web servers (web1, web2)
  - DNS server (Dnsmasq)
  - DHCP server (ISC DHCP)
  - HTTP load balancing with HAProxy

### Monitoring Stack

- **Prometheus** (3 instances): Network-segmented metrics collection
  - **Prometheus-Internal** (10.0.2.19:9090): Monitors DNS, DHCP, Router
  - **Prometheus-DMZ** (10.0.1.19:9091): Monitors Web1, Web2, HAProxy backend, Router
  - **Prometheus-Public** (10.0.3.19:9092): Monitors HAProxy frontend, Router
  - Static target configuration (no service discovery)
  - 15-second scrape interval
  - Network isolation: each instance only monitors its network segment

- **Grafana** (10.0.2.21 / 10.0.1.21 / 10.0.3.21): Multi-network monitoring
  - Connected to all three networks
  - Queries all three Prometheus instances
  - Unified dashboard showing metrics across all networks
  - Pre-configured datasources for each Prometheus

- **Node Exporter**: Per-container system metrics
  - Embedded in every container (runs on port 9100)
  - Metrics: CPU, memory, disk I/O, network traffic
  - Started via wrapper script with main service

### Network Topology

Three isolated networks connected through a router:

1. **DMZ Network (10.0.1.0/24)**: Web servers and public-facing services
2. **Internal Network (10.0.2.0/24)**: DNS, DHCP, and monitoring services
3. **Public Network (10.0.3.0/24)**: External access point with load balancer

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

# Test CNAME resolution
docker exec netlab-haproxy nslookup www.netlab.local 10.0.2.10

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

### Testing Direct Web Server Access

Access web servers directly (bypassing load balancer):

```bash
# Access from HAProxy container to web1
docker exec netlab-haproxy curl http://10.0.1.10/

# Access from HAProxy container to web2
docker exec netlab-haproxy curl http://10.0.1.11/

# Check health endpoints
docker exec netlab-haproxy curl http://10.0.1.10/health
docker exec netlab-haproxy curl http://10.0.1.11/health
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

# Query Prometheus-DMZ (Web1, Web2, HAProxy backend metrics)
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

## Container Details

### Service Information

| Service | Container Name | IP Address(es) | Network(s) | Purpose |
|---------|---------------|----------------|------------|---------|
| Router | netlab-router | 10.0.1.254, 10.0.2.254, 10.0.3.254 | All | Layer 3 routing (FRRouting) |
| DNS | netlab-dns | 10.0.2.10 | Internal | Name resolution (Dnsmasq) |
| DHCP | netlab-dhcp | 10.0.2.11 | Internal | Dynamic IP assignment (ISC DHCP) |
| Web1 | netlab-web1 | 10.0.1.10 | DMZ | HTTP server (Nginx) |
| Web2 | netlab-web2 | 10.0.1.11 | DMZ | HTTP server (Nginx) |
| HAProxy | netlab-haproxy | 10.0.3.10 (public), 10.0.1.20 (dmz) | Public, DMZ | Load balancer (HAProxy) |
| Prometheus-Internal | netlab-prometheus-internal | 10.0.2.19 | Internal | Metrics collection (Internal network) |
| Prometheus-DMZ | netlab-prometheus-dmz | 10.0.1.19 | DMZ | Metrics collection (DMZ network) |
| Prometheus-Public | netlab-prometheus-public | 10.0.3.19 | Public | Metrics collection (Public network) |
| Grafana | netlab-grafana | 10.0.2.21, 10.0.1.21, 10.0.3.21 | All | Monitoring dashboard (multi-network) |

**Note**: All containers run node-exporter on port 9100 internally for per-container metrics.

### Port Mappings

| Service | Host Port | Container Port | Purpose |
|---------|-----------|----------------|---------|
| HAProxy | 8080 | 80 | HTTP load balancer |
| HAProxy | 8443 | 443 | HTTPS (not configured) |
| HAProxy Stats | 8404 | 8404 | Statistics page |
| Grafana | 3000 | 3000 | Dashboard UI |
| Prometheus-Internal | 9090 | 9090 | Internal network metrics UI |
| Prometheus-DMZ | 9091 | 9090 | DMZ network metrics UI |
| Prometheus-Public | 9092 | 9090 | Public network metrics UI |

**Note**: Port 9100 (node-exporter) is accessible internally within containers but not exposed to the host.

## Learning Guide

### Understanding OSI Layers

This lab demonstrates the following OSI layers:

#### Layer 3 - Network Layer
- **Component**: FRRouting router
- **What it does**: Routes packets between different network segments (DMZ, Internal, Public)
- **Test it**: `docker exec netlab-router vtysh -c "show ip route"`

#### Layer 4 - Transport Layer
- **Component**: HAProxy (TCP mode)
- **What it does**: Load balances TCP connections, manages sessions
- **Test it**: View HAProxy stats at http://localhost:8404/stats

#### Layer 5 - Session Layer
- **Component**: HAProxy session management
- **What it does**: Maintains persistent connections, cookie-based session affinity
- **Test it**: Notice SERVERID cookies in HAProxy config

#### Layer 6 - Presentation Layer
- **Component**: HTTPS/SSL termination (configured but no certs)
- **What it does**: Encryption, data format conversion
- **Test it**: HAProxy listens on port 443 for HTTPS

#### Layer 7 - Application Layer
- **Components**: HTTP servers, DNS, DHCP
- **What it does**: Application-specific protocols (HTTP, DNS, DHCP)
- **Test it**: `curl http://localhost:8080`

### Experimentation Ideas

#### 1. Test Routing Behavior

Simulate network segmentation:

```bash
# Add a static route
docker exec netlab-router vtysh -c "configure terminal" -c "ip route 192.168.0.0/24 10.0.1.1"

# View routing table
docker exec netlab-router vtysh -c "show ip route"
```

#### 2. Simulate Server Failure

Test HAProxy failover:

```bash
# Stop web1
docker stop netlab-web1

# Make requests - they should all go to web2
for i in {1..5}; do curl -s http://localhost:8080/ | grep SERVER; done

# Restart web1
docker start netlab-web1
```

#### 3. Analyze DNS Queries

Monitor DNS traffic:

```bash
# Watch DNS logs in real-time
docker logs -f netlab-dns

# In another terminal, make DNS queries
docker exec netlab-haproxy nslookup web1.netlab.local 10.0.2.10
```

#### 4. Test Load Balancing Algorithms

Modify HAProxy configuration to test different algorithms:

```bash
# Edit haproxy/haproxy.cfg
# Change 'balance roundrobin' to 'balance leastconn' or 'balance source'

# Rebuild and restart
docker compose up -d --build haproxy
```

#### 5. Monitor Network Performance

Use Grafana to visualize performance:

1. Open http://localhost:3000
2. Create custom queries in Prometheus
3. Watch container CPU and memory usage under load
4. Generate load: `for i in {1..100}; do curl http://localhost:8080/ & done`

### Advanced Exercises

1. **Add a new web server**:
   - Create web3 directory
   - Add to docker-compose.yml
   - Update HAProxy backend pool
   - Update DNS records

2. **Implement HTTPS**:
   - Generate self-signed certificates
   - Configure HAProxy SSL termination
   - Test with `curl -k https://localhost:8443`

3. **Create custom Grafana dashboards**:
   - Add panels for HAProxy metrics
   - Monitor DNS query rates
   - Track request distribution

4. **Implement caching**:
   - Add Varnish or Nginx caching layer
   - Measure performance improvement

5. **Network traffic analysis**:
   - Use tcpdump to capture packets
   - Analyze with Wireshark
   - Identify different protocol layers

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
├── .env.example                # Environment variable template
├── README.md                   # This file
├── ARCHITECTURE.md             # Detailed architecture documentation
├── REFACTORING.md              # DevOps refactoring details
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
├── haproxy/
│   ├── Dockerfile             # HAProxy load balancer
│   ├── haproxy.cfg            # Load balancer config
│   └── start-with-exporter.sh # Wrapper to start HAProxy + node-exporter
├── monitor/
│   ├── prometheus/
│   │   ├── prometheus-internal.yml  # Internal network scrape config
│   │   ├── prometheus-dmz.yml       # DMZ network scrape config
│   │   └── prometheus-public.yml    # Public network scrape config
│   └── grafana/
│       ├── dashboards/
│       │   └── network-lab.json     # Multi-Prometheus dashboard
│       └── provisioning/
│           └── datasources/
│               └── prometheus.yml   # 3 Prometheus datasources
└── scripts/
    ├── test_all.sh            # Run all tests
    ├── test_connectivity.sh   # Layer 3 tests
    ├── test_dns.sh            # DNS tests
    └── test_http.sh           # HTTP/load balancing tests
```

## Multi-Prometheus Architecture

### Why Three Prometheus Instances?

This lab uses a **network-segmented monitoring approach** with three separate Prometheus instances:

1. **Educational Value**: Demonstrates real-world network segmentation and security boundaries
2. **Network Isolation**: Each Prometheus can only monitor services in its own network segment
3. **Realistic Deployment**: Mirrors production environments with DMZ/Internal/Public zones
4. **Security Best Practice**: Limits blast radius if one network segment is compromised

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Grafana (Multi-Network)                                    │
│  ├─ Queries: Prometheus-Internal (10.0.2.19:9090)           │
│  ├─ Queries: Prometheus-DMZ (10.0.1.19:9090)                │
│  └─ Queries: Prometheus-Public (10.0.3.19:9090)             │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Prom-Internal   │  │ Prom-DMZ        │  │ Prom-Public     │
├─────────────────┤  ├─────────────────┤  ├─────────────────┤
│ Targets:        │  │ Targets:        │  │ Targets:        │
│ • Router :9100  │  │ • Router :9100  │  │ • Router :9100  │
│ • DNS :9100     │  │ • Web1 :9100    │  │ • HAProxy :9100 │
│ • DHCP :9100    │  │ • Web2 :9100    │  │ • Self :9090    │
│ • Self :9090    │  │ • HAProxy :9100 │  │                 │
│                 │  │ • Self :9090    │  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### Configuration Files

Each Prometheus instance has its own configuration with **static targets**:

- [monitor/prometheus/prometheus-internal.yml](monitor/prometheus/prometheus-internal.yml)
- [monitor/prometheus/prometheus-dmz.yml](monitor/prometheus/prometheus-dmz.yml)
- [monitor/prometheus/prometheus-public.yml](monitor/prometheus/prometheus-public.yml)

### Grafana Integration

Grafana is connected to all three networks and aggregates data from all Prometheus instances:

- **Datasource UIDs**: `prometheus-internal`, `prometheus-dmz`, `prometheus-public`
- **Dashboard**: Queries all three datasources simultaneously
- **Panels**: Show metrics from all networks in unified views

## Additional Resources

### Understanding the Components

- **FRRouting**: Open-source routing software suite
- **Dnsmasq**: Lightweight DNS/DHCP server
- **HAProxy**: High-performance TCP/HTTP load balancer
- **Prometheus**: Time-series metrics database
- **Grafana**: Metrics visualization platform

### OSI Model Reference

| Layer | Number | Name | Protocols | Lab Component |
|-------|--------|------|-----------|---------------|
| Application | 7 | Application | HTTP, DNS, DHCP | Nginx, Dnsmasq |
| Presentation | 6 | Presentation | SSL/TLS | HAProxy SSL |
| Session | 5 | Session | NetBIOS, RPC | HAProxy sessions |
| Transport | 4 | Transport | TCP, UDP | HAProxy |
| Network | 3 | Network | IP, ICMP, Routing | FRRouting |
| Data Link | 2 | Data Link | Ethernet, ARP | Docker networks |
| Physical | 1 | Physical | Physical medium | Host network |

## License

This project is provided as-is for educational purposes.

## Contributing

Feel free to extend this lab environment with additional services or network configurations.

---

**Happy Learning!** 🚀
