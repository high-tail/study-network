# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker-based network lab for learning OSI layers 3-7. Simulates a multi-tier network with routing, DNS, DHCP, load balancing, web servers, and monitoring.

**Architecture**: Three isolated Docker networks (DMZ, Internal, Public) connected via FRRouting router.

## Quick Reference

### Build and Run

```bash
docker compose build              # Build all containers
docker compose up -d              # Start environment
docker compose ps                 # Check health status
docker compose down               # Stop environment
docker compose down -v            # Stop and remove volumes
docker compose up -d --build <service>  # Rebuild specific service
```

### Testing

```bash
./scripts/test_all.sh             # Run all tests
./scripts/test_connectivity.sh    # Layer 3 routing
./scripts/test_dns.sh             # DNS resolution
./scripts/test_http.sh            # HTTP load balancing
./scripts/test_https.sh           # TLS/HTTPS (requires certs)
```

### K6 Performance Tests

```bash
./scripts/run_k6_smoke.sh         # Quick 1-min verification
./scripts/run_k6_load.sh          # 16-min load test
./scripts/run_k6_stress.sh        # ~8.5-min stress test (100 VUs)
./scripts/run_k6_spike.sh         # ~5.5-min spike test (200 VUs)
./scripts/run_k6_tests.sh         # Interactive menu (all tests)
```

All K6 tests target HAProxy's DMZ IP (10.0.1.20), not the public endpoint.

### Debugging

```bash
docker logs -f netlab-<service>   # Follow service logs
docker exec netlab-router vtysh   # Router CLI
docker exec netlab-router ip route show  # Routing table
docker exec netlab-<container> ping <ip>  # Test connectivity
docker exec netlab-dns nslookup <host> 127.0.0.1          # Test DNS (from DNS container)
docker exec netlab-k6 nslookup <host> 10.0.2.10           # Test DNS (from Internal network)
```

## Network IP Allocation

| Service | IP Address(es) | Network |
|---------|---------------|---------|
| Router | 10.0.1.254, 10.0.2.254, 10.0.3.254 | All |
| DNS | 10.0.2.10 | Internal |
| DHCP | 10.0.2.11 | Internal |
| Web1 | 10.0.1.10 | DMZ |
| Web2 | 10.0.1.11 | DMZ |
| Web3 (HTTPS) | 10.0.1.12 | DMZ |
| HAProxy | 10.0.3.10 (public), 10.0.1.20 (dmz) | Public, DMZ |
| Prometheus-Internal | 10.0.2.19 | Internal |
| Prometheus-DMZ | 10.0.1.19 | DMZ |
| Prometheus-Public | 10.0.3.19 | Public |
| Grafana | 10.0.2.21, 10.0.1.21, 10.0.3.21 | All |
| K6 | 10.0.2.30 (internal), 10.0.1.30 (dmz) | Internal, DMZ |

**Domain**: All services use `.netlab.local` (DNS at 10.0.2.10)

## Service Configuration Locations

| Service | Config Files |
|---------|-------------|
| Router | `router/frr.conf`, `router/daemons` |
| DNS | `dns/dnsmasq.conf` |
| DHCP | `dhcp/dhcpd.conf` |
| HAProxy | `haproxy/haproxy.cfg` |
| Web servers | `web1/`, `web2/`, `web3/` (Nginx + index.html) |
| Prometheus | `monitor/prometheus/prometheus-{internal,dmz,public}.yml` |
| Grafana | `monitor/grafana/` |
| K6 | `k6/scripts/` |

### After Config Changes

```bash
docker compose up -d --build <service>  # Most services need rebuild
docker compose restart dns dhcp         # DNS/DHCP can just restart
curl -X POST http://localhost:9090/-/reload  # Prometheus hot reload
```

## Adding New Components

### New Web Server

1. Create `webN/` with Dockerfile and index.html (use `web1/` as template)
2. Add to `docker-compose.yml` with IP in DMZ (next: 10.0.1.13)
3. Add to HAProxy backend(s) in `haproxy/haproxy.cfg`
4. Add DNS entry in `dns/dnsmasq.conf`
5. Add Prometheus target in `monitor/prometheus/prometheus-dmz.yml`

**Note**: HAProxy has separate backends: `web_servers` (HTTP, web1+web2 only) and `web_servers_mixed` (HTTPS, web1+web2+web3).

### New Network Segment

1. Define network in `docker-compose.yml` (e.g., 10.0.4.0/24)
2. Attach router with new IP (e.g., 10.0.4.254)
3. Update `router/frr.conf` with routes
4. Create new Prometheus config for the network

## TLS/HTTPS

```bash
./scripts/generate-certs.sh       # Generate CA and certificates
./scripts/test_https.sh           # Test HTTPS endpoints
```

Certificates: `certs/` directory (gitignored, self-signed, 365-day validity). HAProxy requires combined PEM: `cat cert.pem key.pem > haproxy.pem`.

## Development Guidelines

- Test connectivity after networking changes: `./scripts/test_all.sh`
- Verify routing: `docker exec netlab-router ip route show`
- Check DNS from multiple containers before committing
- Each container runs node-exporter on port 9100 for metrics
- All services have health checks - check with `docker compose ps`
- All container names use `netlab-` prefix (e.g., `netlab-router`, `netlab-web1`)
- `.env` file contains all IPs, ports, credentials, and image versions
- Active Prometheus configs are `monitor/prometheus/prometheus-{internal,dmz,public}.yml`

### Known Gaps

- **Prometheus gaps**: Grafana (`grafana/grafana` image) and K6 (`grafana/k6` image) do not run node-exporter, so they are not scraped by any Prometheus instance
- **DNS reachability**: The DNS server (10.0.2.10) is only directly reachable from the Internal network (10.0.2.0/24). Containers in DMZ/Public use Docker's internal resolver and cannot query it by IP. Use `netlab-dns` (127.0.0.1) or `netlab-k6` for DNS testing.
- **Cross-network ping**: End hosts route through Docker's gateway (10.0.X.1), not the FRRouting router. Cross-network pings from DMZ/Public containers to other networks will fail. Test cross-network routing from `netlab-router` instead.

## Common Issues

### Container Build Errors
HAProxy Alpine base requires root for package install:
```dockerfile
USER root
RUN apk add --no-cache curl iputils bind-tools openssl
USER haproxy
```

### Routing Not Working
```bash
docker exec netlab-router sysctl net.ipv4.ip_forward  # Should be 1
docker exec netlab-router ip route show               # Check routes
```

### DNS Not Resolving
```bash
docker exec netlab-dns nslookup web1.netlab.local 127.0.0.1
docker logs netlab-dns
```

### Port Conflicts
Check host ports: 3000, 8080, 8404, 8443, 9090, 9091, 9092

### Resource Requirements
Minimum 4GB RAM, recommended 6GB+ for all Prometheus instances

## Access Points

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin/admin |
| HAProxy Stats | http://localhost:8404/stats | admin/admin |
| Prometheus-Internal | http://localhost:9090 | - |
| Prometheus-DMZ | http://localhost:9091 | - |
| Prometheus-Public | http://localhost:9092 | - |
| Load Balanced HTTP | http://localhost:8080 | - |
| Load Balanced HTTPS | https://localhost:8443 | - |
