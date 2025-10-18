# Network Lab Architecture

## Network Topology Diagram

```
                    ┌─────────────────────────────────────────────────────────┐
                    │         HOST MACHINE (macOS/Linux/WSL2)                 │
                    │                                                         │
                    │  Ports Exposed:                                         │
                    │  - 3000  → Grafana Dashboard                            │
                    │  - 8080  → HAProxy (Load Balanced Web)                  │
                    │  - 8404  → HAProxy Stats                                │
                    │  - 9090  → Prometheus (Internal Network)                │
                    │  - 9091  → Prometheus (DMZ Network)                     │
                    │  - 9092  → Prometheus (Public Network)                  │
                    └─────────────────────────────────────────────────────────┘
                                      │
                              ┌───────┴────────┐
                              │  DOCKER ENGINE │
                              └────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        │                             │                             │
┌───────▼────────┐          ┌─────────▼────────┐          ┌────────▼────────┐
│ PUBLIC NETWORK │          │   DMZ NETWORK    │          │ INTERNAL NETWORK│
│  10.0.3.0/24   │          │  10.0.1.0/24     │          │  10.0.2.0/24    │
│                │          │                  │          │                 │
│ ┌────────────┐ │          │ ┌──────────────┐ │          │ ┌─────────────┐ │
│ │  Router    │◄┼──────────┼─┤   Router     │◄┼──────────┼─┤   Router    │ │
│ │ 10.0.3.254 │ │          │ │  10.0.1.254  │ │          │ │  10.0.2.254 │ │
│ │ (Layer 3)  │ │          │ │  (Layer 3)   │ │          │ │  (Layer 3)  │ │
│ │ [Healthy]  │ │          │ │  [Healthy]   │ │          │ │  [Healthy]  │ │
│ └─────┬──────┘ │          │ └───────┬──────┘ │          │ └──────┬──────┘ │
│       │        │          │         │        │          │        │        │
│ ┌─────▼──────┐ │          │ ┌───────▼──────┐ │          │ ┌──────▼──────┐ │
│ │  HAProxy   │ │          │ │   HAProxy    │ │          │ │    DNS      │ │
│ │ 10.0.3.10  │ │          │ │  10.0.1.20   │ │          │ │  10.0.2.10  │ │
│ │  (L4/L7)   │◄┼──────────┼─┤  Backend     │ │          │ │  (Layer 7)  │ │
│ │  Frontend  │ │          │ │  Connection  │ │          │ │  [Healthy]  │ │
│ │ [Healthy]  │ │          │ │  [Healthy]   │ │          │ └─────────────┘ │
│ └────────────┘ │          │ └───────┬──────┘ │          │                 │
│       │        │          │         │        │          │ ┌─────────────┐ │
│       │        │          │    ┌────▼─────┐  │          │ │    DHCP     │ │
│ ┌─────▼──────┐ │          │    │   Web1   │  │          │ │  10.0.2.11  │ │
│ │Prometheus-P│ │          │    │10.0.1.10 │  │          │ │  (Layer 7)  │ │
│ │ 10.0.3.19  │ │          │    │ (Layer 7)│  │          │ │  [Healthy]  │ │
│ │ [Healthy]  │ │          │    │ [Healthy]│  │          │ └─────────────┘ │
│ │:9100 ◄─────┼─┼─Scrapes Router/HAProxy     │          │                 │
│ └────────────┘ │          │    └──────────┘  │          │ ┌─────────────┐ │
│       │        │          │                  │          │ │Prometheus-I │ │
│       │        │          │    ┌──────────┐  │          │ │  10.0.2.19  │ │
│       │        │          │    │   Web2   │  │          │ │  [Healthy]  │ │
│ ┌─────▼──────┐ │          │    │10.0.1.11 │  │          │ │:9100 ◄──────┼─┼─Scrapes DNS/DHCP/Router
│ │  Grafana   │ │          │    │ (Layer 7)│  │          │ └──────┬──────┘ │
│ │ 10.0.3.21  │ │          │    │ [Healthy]│  │          │        │        │
│ │ (All Nets) │◄┼──────────┼────────┐         │          │ ┌──────▼──────┐ │
│ │ [Healthy]  │ │          │        │         │          │ │  Grafana    │ │
│ └────────────┘ │          │ ┌──────▼───────┐ │          │ │  10.0.2.21  │ │
│                │          │ │Prometheus-DMZ│ │          │ │ (All Nets)  │ │
└────────────────┘          │ │  10.0.1.19   │ │          │ │  [Healthy]  │ │
                            │ │  [Healthy]   │ │          │ └─────────────┘ │
                            │ │:9100 ◄───────┼─┼─Scrapes Web1/Web2/HAProxy/Router
                            │ └──────────────┘ │          │                 │
                            └──────────────────┘          └─────────────────┘

Legend:
  [Healthy] = Health check passing
  :9100 ◄─ = Static scrape targets (node-exporter)

Note: All containers run node-exporter on port 9100 for per-container system metrics
```

## Traffic Flow Examples

### 1. External HTTP Request → Load Balanced Web Server

```
Browser (localhost:8080)
    │
    ▼
HAProxy:80 (10.0.3.10) - PUBLIC NETWORK
    │
    │ (Round Robin Load Balancing)
    │
    ├──────────────┬──────────────┐
    │              │              │
    ▼              ▼              ▼
HAProxy Backend (10.0.1.20) - DMZ NETWORK
    │              │
    │              │
    ▼              ▼
Web1 (10.0.1.10)  Web2 (10.0.1.11) - DMZ NETWORK
```

### 2. DNS Query Resolution

```
Container (any network)
    │
    ▼
DNS Query to 10.0.2.10
    │
    ▼
Dnsmasq DNS Server (10.0.2.10) - INTERNAL NETWORK
    │
    ├─── Local records (.netlab.local)
    │    └─── Returns IP from dnsmasq.conf
    │
    └─── External domains
         └─── Forwards to 8.8.8.8 (Google DNS)
```

### 3. Cross-Network Routing (Web1 → DNS)

```
Web1 (10.0.1.10) - DMZ NETWORK
    │
    │ Destination: 10.0.2.10
    │ Gateway: 10.0.1.254
    │
    ▼
Router (10.0.1.254) - DMZ Interface
    │
    │ Routing decision
    │ Route: 10.0.2.0/24 → 10.0.2.254
    │
    ▼
Router (10.0.2.254) - INTERNAL Interface
    │
    ▼
DNS Server (10.0.2.10) - INTERNAL NETWORK
```

### 4. Monitoring Data Collection with Static Configuration

```
Static Configuration Files
    │
    │ prometheus-internal.yml, prometheus-dmz.yml, prometheus-public.yml
    │
    ├──────────────────┬──────────────────┬──────────────────┐
    │                  │                  │                  │
    ▼                  ▼                  ▼                  ▼
Prometheus-Internal  Prometheus-DMZ   Prometheus-Public   All Containers
(10.0.2.19)         (10.0.1.19)      (10.0.3.19)        (node-exporter:9100)
    │                  │                  │                  │
    │ Scrapes :9100    │ Scrapes :9100    │ Scrapes :9100    │
    │                  │                  │                  │
    │ Static targets:  │ Static targets:  │ Static targets:  │
    │ - DNS (.10)      │ - Web1 (.10)     │ - HAProxy (.10)  │
    │ - DHCP (.11)     │ - Web2 (.11)     │ - Router (.254)  │
    │ - Router (.254)  │ - HAProxy (.20)  │ - Self           │
    │ - Self           │ - Router (.254)  │                  │
    │                  │ - Self           │                  │
    │                  │                  │                  │
    └──────────────────┴──────────────────┴──────────────────┘
                              │
                              │ Labels configured in YAML:
                              │ - service: web1
                              │ - network: dmz
                              │ - osi_layer: layer7
                              │
                              ▼
                    Time-Series Databases (3x)
                              │
                              │ Grafana queries all 3
                              │
                              ▼
                    Grafana (10.0.2.21 / 10.0.1.21 / 10.0.3.21)
                              │
                              │ Aggregates metrics from all networks
                              │
                              ▼
                    Browser (localhost:3000)
```

**Static Configuration Benefits:**
- ✅ Simple and predictable (no dynamic discovery complexity)
- 🎯 Explicit target definition (clear visibility of what's monitored)
- 🔍 Network-aware (each Prometheus monitors only its network segment)
- 🏷️  Custom labels per target (service, network, OSI layer)
- 📊 Production-ready pattern (proven reliability)

## OSI Layer Mapping

### Layer 7 - Application Layer
**Components:**
- **Nginx Web Servers** (web1, web2): HTTP/1.1 server
- **Dnsmasq**: DNS protocol (port 53)
- **ISC DHCP**: DHCP protocol (ports 67/68)
- **HAProxy**: HTTP protocol parsing and routing

**Example:** HTTP request parsing, DNS name resolution, DHCP address assignment

### Layer 6 - Presentation Layer
**Components:**
- **HAProxy SSL/TLS Termination** (configured but no certificates)

**Example:** Encryption/decryption, data format conversion (though not fully implemented in this lab)

### Layer 5 - Session Layer
**Components:**
- **HAProxy Session Management**
  - Cookie-based persistence (SERVERID cookie)
  - Connection pooling
  - Session affinity

**Example:** Maintaining persistent connections between client and specific backend server

### Layer 4 - Transport Layer
**Components:**
- **HAProxy TCP Load Balancing**
  - TCP connection handling
  - Port mapping (80, 443)
  - Health checks

**Example:** TCP connection establishment, port-based routing

### Layer 3 - Network Layer
**Components:**
- **FRRouting Router**
  - IP packet routing between subnets
  - Routing table management
  - Inter-network gateway

**Example:** Routing packets from 10.0.1.0/24 to 10.0.2.0/24

### Layer 2 - Data Link Layer
**Components:**
- **Docker Bridge Networks**
  - Ethernet frames
  - MAC address assignment
  - ARP resolution within each network

**Example:** Ethernet frame switching within each Docker network

### Layer 1 - Physical Layer
**Components:**
- **Virtual Network Interfaces** (veth pairs)
- **Host Network Stack**

**Example:** Virtual Ethernet interfaces created by Docker

## Data Flow Sequence

### Complete HTTP Request Example

```
Step 1: User Request
  └─ Browser: http://localhost:8080
     └─ Host forwards to container port 80

Step 2: Layer 7 Processing
  └─ HAProxy Frontend (10.0.3.10:80)
     └─ Parses HTTP request
     └─ Checks headers, path, method
     └─ Selects backend based on round-robin

Step 3: Layer 4 Processing
  └─ HAProxy opens TCP connection to backend
     └─ Connection to Web1 (10.0.1.10:80) or Web2 (10.0.1.11:80)

Step 4: Layer 3 Routing
  └─ HAProxy (10.0.1.20) → Web1 (10.0.1.10)
     └─ Same network, no routing needed
  OR
  └─ For cross-network, packets routed through 10.0.1.254

Step 5: Web Server Processing
  └─ Nginx receives HTTP request
     └─ Processes request
     └─ Serves index.html
     └─ Adds X-Served-By header

Step 6: Response Path
  └─ Web1/Web2 → HAProxy Backend → HAProxy Frontend → Client
     └─ HAProxy adds X-Backend-Server header
     └─ Response returned to browser
```

## Network Isolation and Security

### Network Segmentation

1. **Public Network (10.0.3.0/24)**
   - External-facing services only
   - HAProxy frontend, Grafana UI
   - Exposed to host machine

2. **DMZ Network (10.0.1.0/24)**
   - Semi-trusted zone
   - Web servers isolated from internal services
   - Can only reach internal via router

3. **Internal Network (10.0.2.0/24)**
   - Protected services
   - DNS, DHCP, monitoring backend
   - Not directly accessible from outside

### Routing Controls

The router acts as a controlled gateway:
- All cross-network traffic must pass through router (10.0.x.254 on each network)
- Can implement firewall rules (not configured in this lab)
- Can monitor inter-network traffic
- Provides single point for network policy enforcement
- Note: Docker network gateways are 10.0.x.1, but router uses 10.0.x.254 for routing

## Service Dependencies

```
┌─────────────┐
│   Router    │ ◄─── Must start first (all networks depend on it)
└──────┬──────┘
       │
       ├────┐
       │    │
┌──────▼────▼─────┐
│   DNS Server    │ ◄─── Other services use for name resolution
└──────┬──────────┘
       │
       ├──────────────┐
       │              │
┌──────▼──────┐  ┌───▼────────┐
│   Web1      │  │   Web2     │
│   Web2      │  │ HAProxy    │
└──────┬──────┘  └───┬────────┘
       │             │
       │   ┌─────────┘
       │   │
┌──────▼───▼──────┐
│   HAProxy       │ ◄─── Depends on web servers being up
└─────────────────┘

┌─────────────────┐
│  Prometheus     │ ◄─── Can start independently
└──────┬──────────┘
       │
┌──────▼──────────┐
│   Grafana       │ ◄─── Depends on Prometheus
└─────────────────┘
```

## Scaling Considerations

### Adding More Web Servers

1. Create new container in DMZ network (10.0.1.x)
2. Add to HAProxy backend pool
3. Add DNS record
4. Add Prometheus scrape target

### Adding More Networks

1. Define new network in docker-compose.yml
2. Attach router to new network
3. Add static routes in frr.conf
4. Attach services to new network

### Performance Tuning

- **HAProxy**: Adjust maxconn, timeout values
- **Prometheus**: Modify scrape_interval
- **Web Servers**: Configure worker processes
- **Docker**: Allocate more CPU/memory resources

## Monitoring Architecture

### Per-Container Metrics with Node Exporter

This lab uses a distributed monitoring approach where each container runs its own node-exporter instance:

**Implementation Details:**
- Each container includes `prometheus-node-exporter` package
- All containers use a `start-with-exporter.sh` wrapper script
- Node-exporter runs on port 9100 within each container
- Provides system-level metrics (CPU, memory, disk, network) per container

**Benefits over cAdvisor:**
- Per-container resource visibility
- Direct insight into container internals
- Simpler deployment (no separate monitoring container)
- Consistent metrics across all services

**Metrics Collection:**
- Three Prometheus instances scrape node-exporter via static configuration
- 15-second scrape interval per target
- Network-specific targets (each Prometheus monitors only its network segment)
- Explicit labels in config: service name, OSI layer, network placement

**Available Metrics:**
```
node_cpu_seconds_total          # CPU usage
node_memory_MemAvailable_bytes  # Available memory
node_network_receive_bytes_total # Network RX
node_network_transmit_bytes_total # Network TX
node_disk_read_bytes_total      # Disk reads
node_disk_written_bytes_total   # Disk writes
node_filesystem_avail_bytes     # Available disk space
```

See [monitor/prometheus/prometheus-*.yml](monitor/prometheus/) for complete scrape configuration.

## DevOps Features

### Health Checks

All services have Docker-monitored health checks:

| Service | Check Type | Command | Interval |
|---------|-----------|---------|----------|
| Router | Process | `pgrep -f zebra` | 30s |
| DNS | Process | `pgrep -f dnsmasq` | 30s |
| DHCP | Process | `pgrep -f dhcpd` | 30s |
| Web1/Web2 | HTTP | `curl -f http://localhost/health` | 10s |
| HAProxy | Process | `pgrep -f haproxy` | 10s |
| Prometheus | HTTP | `wget http://localhost:9090/-/healthy` | 30s |
| Grafana | HTTP | `wget http://localhost:3000/api/health` | 30s |

**Health Check States:**
- ✅ `healthy` - Service ready and responding
- ⏳ `starting` - Within start_period window
- ❌ `unhealthy` - Failed retries threshold

**Benefits:**
- Dependencies wait for upstream services to be healthy
- Auto-restart on persistent failures
- Visible in `docker compose ps`
- Prevents race conditions on startup

### Resource Limits

Every service has defined CPU and memory limits:

| Service Category | CPU Limit | Memory Limit | Justification |
|-----------------|-----------|--------------|---------------|
| Router, DNS, DHCP | 0.25 cores | 128MB | Lightweight network services |
| Web1, Web2, HAProxy | 0.5 cores | 256MB | HTTP request handling |
| Prometheus (3x) | 1 core each | 1GB each | Time-series data + queries |
| Grafana | 1 core | 512MB | Dashboard rendering |

**Total Resources:**
- Max CPUs: ~6 cores
- Max Memory: ~4GB
- Prevents: Resource exhaustion, noisy neighbor issues
- Enables: Predictable performance, fair resource sharing

### Dependency Graph

Services start in health-based order:

```
router [healthy]
    ├── dns [healthy]
    │   ├── web1 [healthy]
    │   ├── web2 [healthy]
    │   ├── dhcp [healthy]
    │   └── prometheus-internal [healthy]
    │       └── grafana [healthy]
    ├── haproxy [depends on web1, web2]
    │   └── prometheus-public [healthy]
    │       └── grafana [healthy]
    └── prometheus-dmz [depends on web1, web2]
        └── grafana [healthy]
```

**Restart Policy:** All services use `restart: unless-stopped`
- Auto-restart on crash
- Survive Docker daemon restarts
- Stay down only when explicitly stopped

### Labels and Metadata

All resources (services, networks, volumes) have structured labels:

```yaml
labels:
  com.netlab.service: "web1"
  com.netlab.layer: "layer7"
  com.netlab.network: "dmz"
  com.netlab.description: "Nginx web server 1"
```

**Use Cases:**
```bash
# Find all layer 7 services
docker ps --filter "label=com.netlab.layer=layer7"

# Find all DMZ services
docker ps --filter "label=com.netlab.network=dmz"

# View service metadata
docker inspect netlab-web1 | jq '.[0].Config.Labels'
```

### Logging Configuration

All services use JSON logging with rotation:

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

**Benefits:**
- Max 30MB per container (10MB × 3 files)
- Structured JSON format
- Compatible with log aggregation (ELK, Loki)
- Prevents disk exhaustion

## Testing Points

Each layer can be tested independently:

- **Layer 3**: `ping`, `traceroute`, `ip route show`
- **Layer 4**: `netstat`, `ss`, HAProxy stats
- **Layer 7**: `curl`, `dig`, `nslookup`, browser access
- **Monitoring**: Prometheus UI (localhost:9090), Grafana dashboards (localhost:3000)

See [README.md](README.md) for detailed testing instructions.
