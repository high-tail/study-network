# Network Lab Architecture & Learning Guide

For setup, usage, and troubleshooting, see [README.md](README.md).

## System Architecture Diagram

```mermaid
graph TB
    subgraph "PUBLIC NETWORK (10.0.3.0/24)"
        direction TB
        RouterPublic["Router<br/>10.0.3.254<br/>(FRRouting)"]
        HAProxyPublic["HAProxy Frontend<br/>10.0.3.10<br/>(Load Balancer)"]
        PrometheusPublic["Prometheus-Public<br/>10.0.3.19<br/>(Metrics)"]
        GrafanaPublic["Grafana<br/>10.0.3.21<br/>(Dashboard)"]
    end

    subgraph "DMZ NETWORK (10.0.1.0/24)"
        direction TB
        RouterDMZ["Router<br/>10.0.1.254<br/>(FRRouting)"]
        Web1["Web1<br/>10.0.1.10<br/>(Nginx HTTP)"]
        Web2["Web2<br/>10.0.1.11<br/>(Nginx HTTP)"]
        Web3["Web3<br/>10.0.1.12<br/>(Nginx HTTPS)"]
        HAProxyDMZ["HAProxy Backend<br/>10.0.1.20"]
        PrometheusDMZ["Prometheus-DMZ<br/>10.0.1.19<br/>(Metrics)"]
        GrafanaDMZ["Grafana<br/>10.0.1.21"]
        K6DMZ["K6<br/>10.0.1.30<br/>(Load Testing)"]
    end

    subgraph "INTERNAL NETWORK (10.0.2.0/24)"
        direction TB
        RouterInternal["Router<br/>10.0.2.254<br/>(FRRouting)"]
        DNS["DNS Server<br/>10.0.2.10<br/>(Dnsmasq)"]
        DHCP["DHCP Server<br/>10.0.2.11<br/>(ISC DHCP)"]
        PrometheusInternal["Prometheus-Internal<br/>10.0.2.19<br/>(Metrics)"]
        GrafanaInternal["Grafana<br/>10.0.2.21"]
        K6["K6<br/>10.0.2.30<br/>(Load Testing)"]
    end

    subgraph "Host Ports"
        direction TB
        Host8080["Host:8080<br/>(HTTP)"]
        Host8443["Host:8443<br/>(HTTPS)"]
        Host8404["Host:8404<br/>(HAProxy Stats)"]
        Host3000["Host:3000<br/>(Grafana)"]
        Host9090["Host:9090<br/>(Prom-Internal)"]
        Host9091["Host:9091<br/>(Prom-DMZ)"]
        Host9092["Host:9092<br/>(Prom-Public)"]
    end

    %% Router connections (multi-homed)
    RouterPublic -.- RouterDMZ
    RouterDMZ -.- RouterInternal

    %% HAProxy connections (multi-homed)
    HAProxyPublic -.- HAProxyDMZ
    HAProxyDMZ --> Web1
    HAProxyDMZ --> Web2
    HAProxyDMZ --> Web3

    %% Grafana connections (multi-homed)
    GrafanaPublic -.- GrafanaDMZ
    GrafanaDMZ -.- GrafanaInternal

    %% Monitoring connections
    GrafanaInternal -.-> PrometheusInternal
    GrafanaDMZ -.-> PrometheusDMZ
    GrafanaPublic -.-> PrometheusPublic

    %% Prometheus scrape targets
    PrometheusInternal -.-> DNS
    PrometheusInternal -.-> DHCP
    PrometheusInternal -.-> RouterInternal
    
    PrometheusDMZ -.-> Web1
    PrometheusDMZ -.-> Web2
    PrometheusDMZ -.-> Web3
    PrometheusDMZ -.-> HAProxyDMZ
    PrometheusDMZ -.-> RouterDMZ
    
    PrometheusPublic -.-> HAProxyPublic
    PrometheusPublic -.-> RouterPublic

    %% Host port mappings
    Host8080 --> HAProxyPublic
    Host8443 --> HAProxyPublic
    Host8404 --> HAProxyPublic
    Host3000 --> GrafanaPublic
    Host9090 --> PrometheusInternal
    Host9091 --> PrometheusDMZ
    Host9092 --> PrometheusPublic

    %% DNS resolution
    Web1 -.->|DNS| DNS
    Web2 -.->|DNS| DNS
    Web3 -.->|DNS| DNS
    HAProxyDMZ -.->|DNS| DNS

    %% K6 load testing (dual-homed: Internal + DMZ)
    K6 -.- K6DMZ
    K6DMZ -.->|Load Test| HAProxyDMZ
```

## OSI Layer Breakdown

```mermaid
graph LR
    subgraph "Layer 7 - Application"
        A1["HTTP/HTTPS<br/>Nginx"]
        A2["DNS<br/>Dnsmasq"]
        A3["DHCP<br/>ISC DHCP"]
        A4["HTTP LB<br/>HAProxy"]
    end

    subgraph "Layer 6 - Presentation"
        P1["TLS/SSL<br/>HTTPS on Web3"]
    end

    subgraph "Layer 5 - Session"
        S1["Session Management<br/>HAProxy Cookies"]
    end

    subgraph "Layer 4 - Transport"
        T1["TCP Load Balancing<br/>HAProxy"]
        T2["TCP/UDP<br/>Ports 80,443,53,67"]
    end

    subgraph "Layer 3 - Network"
        N1["IP Routing<br/>FRRouting"]
        N2["ICMP<br/>Ping/Traceroute"]
    end

    A4 --> S1
    S1 --> T1
    T1 --> T2
    T2 --> N1
    N1 --> N2
    A1 --> P1
```

### Layer Details

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
- **Components**: HTTPS/SSL termination at HAProxy, TLS on Web3
- **What it does**: Encryption, data format conversion
- **Test it**: `curl -k https://localhost:8443` or `./scripts/test_https.sh`

#### Layer 7 - Application Layer
- **Components**: HTTP servers, DNS, DHCP
- **What it does**: Application-specific protocols (HTTP, DNS, DHCP)
- **Test it**: `curl http://localhost:8080`

### OSI Model Reference

| Layer | Number | Name | Protocols | Lab Component |
|-------|--------|------|-----------|---------------|
| Application | 7 | Application | HTTP, DNS, DHCP | Nginx, Dnsmasq |
| Presentation | 6 | Presentation | SSL/TLS | HAProxy SSL, Web3 TLS |
| Session | 5 | Session | NetBIOS, RPC | HAProxy sessions |
| Transport | 4 | Transport | TCP, UDP | HAProxy |
| Network | 3 | Network | IP, ICMP, Routing | FRRouting |
| Data Link | 2 | Data Link | Ethernet, ARP | Docker networks |
| Physical | 1 | Physical | Physical medium | Host network |

## Data Flow Diagram

```mermaid
sequenceDiagram
    participant User as External User
    participant HAProxyPub as HAProxy Public<br/>(10.0.3.10)
    participant HAProxyDMZ as HAProxy DMZ<br/>(10.0.1.20)
    participant Web1 as Web1 (10.0.1.10)
    participant Web2 as Web2 (10.0.1.11)
    participant Web3 as Web3 (10.0.1.12)

    User->>HAProxyPub: HTTP Request (host:8080)
    Note over HAProxyPub,HAProxyDMZ: Same container, dual-homed

    Note over HAProxyDMZ: Round-robin load balancing<br/>(uses static IPs in config)

    HAProxyDMZ->>Web1: HTTP to 10.0.1.10:80 (same subnet)
    Web1-->>HAProxyDMZ: HTTP Response
    HAProxyPub-->>User: HTTP Response

    alt Web1 Health Check Fails
        HAProxyDMZ->>Web2: Failover to 10.0.1.11:80
        Web2-->>HAProxyDMZ: HTTP Response
        HAProxyPub-->>User: HTTP Response
    end

    Note over User,Web3: HTTPS flow (host:8443)
    User->>HAProxyPub: HTTPS Request (host:8443)
    Note over HAProxyPub: SSL termination
    HAProxyDMZ->>Web3: HTTPS to 10.0.1.12:443
    Web3-->>HAProxyDMZ: HTTPS Response
    HAProxyPub-->>User: HTTPS Response
```

## Monitoring Architecture

```mermaid
graph TB
    subgraph "Data Sources"
        Web1["Web1<br/>node-exporter:9100"]
        Web2["Web2<br/>node-exporter:9100"]
        Web3["Web3<br/>node-exporter:9100"]
        HAProxy["HAProxy<br/>node-exporter:9100"]
        DNS["DNS<br/>node-exporter:9100"]
        DHCP["DHCP<br/>node-exporter:9100"]
        Router["Router<br/>node-exporter:9100"]
    end

    subgraph "Metrics Collection"
        PromInternal["Prometheus-Internal<br/>10.0.2.19:9090"]
        PromDMZ["Prometheus-DMZ<br/>10.0.1.19:9090"]
        PromPublic["Prometheus-Public<br/>10.0.3.19:9090"]
    end

    subgraph "Visualization"
        Grafana["Grafana<br/>localhost:3000"]
    end

    %% Scrape targets by network
    PromInternal <-.-> DNS
    PromInternal <-.-> DHCP
    PromInternal <-.-> Router
    
    PromDMZ <-.-> Web1
    PromDMZ <-.-> Web2
    PromDMZ <-.-> Web3
    PromDMZ <-.-> HAProxy
    PromDMZ <-.-> Router
    
    PromPublic <-.-> HAProxy
    PromPublic <-.-> Router

    %% Grafana queries all Prometheus
    Grafana <-.-> PromInternal
    Grafana <-.-> PromDMZ
    Grafana <-.-> PromPublic

    style PromInternal fill:#e1f5ff
    style PromDMZ fill:#e1f5ff
    style PromPublic fill:#e1f5ff
    style Grafana fill:#fff4e1
```

### Why Three Prometheus Instances?

This lab uses a **network-segmented monitoring approach** with three separate Prometheus instances:

1. **Educational Value**: Demonstrates real-world network segmentation and security boundaries
2. **Network Isolation**: Each Prometheus can only monitor services in its own network segment
3. **Realistic Deployment**: Mirrors production environments with DMZ/Internal/Public zones
4. **Security Best Practice**: Limits blast radius if one network segment is compromised

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

## Service Dependency Graph

```mermaid
graph TB
    direction TB

    subgraph "Base Layer"
        Router["Router<br/>(FRRouting)"]
    end

    subgraph "Infrastructure Layer"
        DNS["DNS<br/>(Dnsmasq)"]
        DHCP["DHCP<br/>(ISC DHCP)"]
    end

    subgraph "Application Layer"
        Web1["Web1<br/>(Nginx)"]
        Web2["Web2<br/>(Nginx)"]
        Web3["Web3<br/>(Nginx + TLS)"]
    end

    subgraph "Load Balancing Layer"
        HAProxy["HAProxy<br/>(Load Balancer)"]
    end

    subgraph "Monitoring Layer"
        PromInternal["Prometheus-Internal"]
        PromDMZ["Prometheus-DMZ"]
        PromPublic["Prometheus-Public"]
        Grafana["Grafana"]
        K6["K6"]
    end

    %% Dependencies
    DNS --> Router
    DHCP --> Router
    DHCP --> DNS
    Web1 --> Router
    Web1 --> DNS
    Web2 --> Router
    Web2 --> DNS
    Web3 --> Router
    Web3 --> DNS
    HAProxy --> Router
    HAProxy --> Web1
    HAProxy --> Web2
    HAProxy --> Web3
    PromInternal --> Router
    PromInternal --> DNS
    PromDMZ --> Router
    PromDMZ --> Web1
    PromDMZ --> Web2
    PromDMZ --> Web3
    PromPublic --> Router
    PromPublic --> HAProxy
    Grafana --> PromInternal
    Grafana --> PromDMZ
    Grafana --> PromPublic
    K6 --> HAProxy
    K6 --> PromInternal

    style Router fill:#ffdfd3
    style DNS fill:#d4f1f4
    style DHCP fill:#d4f1f4
    style Web1 fill:#e8f5e9
    style Web2 fill:#e8f5e9
    style Web3 fill:#e8f5e9
    style HAProxy fill:#fff3e0
    style Grafana fill:#fce4ec
```

## Network Segmentation & Security

```mermaid
graph TB
    subgraph "External"
        Internet["Internet<br/>🌐"]
    end

    subgraph "PUBLIC NETWORK<br/>10.0.3.0/24 - Edge Zone"
        direction TB
        LB["HAProxy<br/>Load Balancer<br/>10.0.3.10"]
    end

    subgraph "DMZ NETWORK<br/>10.0.1.0/24 - Semi-Trusted"
        direction TB
        W1["Web1<br/>10.0.1.10"]
        W2["Web2<br/>10.0.1.11"]
        W3["Web3<br/>10.0.1.12"]
    end

    subgraph "INTERNAL NETWORK<br/>10.0.2.0/24 - Trusted Zone"
        direction TB
        INFRA["DNS + DHCP<br/>Infrastructure"]
        MON["Monitoring<br/>Stack"]
    end

    Internet -->|Port 8080 HTTP| LB
    Internet -->|Port 8443 HTTPS| LB
    LB -->|HTTP Backend| W1
    LB -->|HTTP Backend| W2
    LB -->|HTTPS Backend| W3

    style Internet fill:#c8e6c9
    style LB fill:#fff9c4
    style W1 fill:#ffe0b2
    style W2 fill:#ffe0b2
    style W3 fill:#ffe0b2
    style INFRA fill:#e1bee7
    style MON fill:#e1bee7
```

## Component Summary

| Component | IP Address(es) | Layer | Technology | Purpose |
|-----------|----------------|-------|------------|---------|
| Router | 10.0.1.254, 10.0.2.254, 10.0.3.254 | L3 | FRRouting | Inter-network routing |
| DNS | 10.0.2.10 | L7 | Dnsmasq | Name resolution |
| DHCP | 10.0.2.11 | L7 | ISC DHCP | IP address assignment |
| Web1 | 10.0.1.10 | L7 | Nginx | HTTP web server |
| Web2 | 10.0.1.11 | L7 | Nginx | HTTP web server |
| Web3 | 10.0.1.12 | L6/L7 | Nginx | HTTPS web server |
| HAProxy | 10.0.3.10, 10.0.1.20 | L4/L7 | HAProxy | Load balancing |
| Prometheus-Internal | 10.0.2.19 | - | Prometheus | Metrics (Internal) |
| Prometheus-DMZ | 10.0.1.19 | - | Prometheus | Metrics (DMZ) |
| Prometheus-Public | 10.0.3.19 | - | Prometheus | Metrics (Public) |
| Grafana | 10.0.2.21, 10.0.1.21, 10.0.3.21 | - | Grafana | Visualization |
| K6 | 10.0.2.30, 10.0.1.30 | - | K6 | Load testing |

## Port Mappings

| Host Port | Container | Service | Description |
|-----------|-----------|---------|-------------|
| 8080 | 80 | HAProxy | HTTP Load Balancer |
| 8443 | 443 | HAProxy | HTTPS (SSL termination) |
| 8404 | 8404 | HAProxy | Statistics page |
| 3000 | 3000 | Grafana | Dashboard UI |
| 9090 | 9090 | Prometheus-Internal | Metrics UI (Internal) |
| 9091 | 9090 | Prometheus-DMZ | Metrics UI (DMZ) |
| 9092 | 9090 | Prometheus-Public | Metrics UI (Public) |

## Learning Guide

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

1. **Add a new web server** (web4):
   - Copy `web3/` directory as template
   - Add to `docker-compose.yml` with IP 10.0.1.13 in DMZ
   - Add to HAProxy backend pool in `haproxy/haproxy.cfg`
   - Add DNS entry in `dns/dnsmasq.conf`
   - Add Prometheus target in `monitor/prometheus/prometheus-dmz.yml`

2. **Create custom Grafana dashboards**:
   - Add panels for HAProxy metrics
   - Monitor DNS query rates
   - Track request distribution across web1/web2/web3

3. **Implement caching**:
   - Add Varnish or Nginx caching layer
   - Measure performance improvement with K6

4. **Network traffic analysis**:
   - Use tcpdump to capture packets
   - Analyze with Wireshark
   - Identify different protocol layers

5. **Run K6 load tests and analyze**:
   - Compare response times across test profiles
   - Monitor Grafana dashboards during load tests
   - Tune HAProxy and Nginx for better throughput

## Technology Reference

- **[FRRouting](https://frrouting.org/)**: Open-source routing software suite
- **[Dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html)**: Lightweight DNS/DHCP server
- **[HAProxy](https://www.haproxy.org/)**: High-performance TCP/HTTP load balancer
- **[Prometheus](https://prometheus.io/)**: Time-series metrics database
- **[Grafana](https://grafana.com/)**: Metrics visualization platform
- **[K6](https://k6.io/)**: Modern load testing tool