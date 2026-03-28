# HAProxy Load Balancer
# Layer 4 (Transport) and Layer 7 (Application) load balancing
FROM haproxy:2.8-alpine

# Switch to root to install packages
USER root

# Install utilities for testing and node-exporter
RUN apk add --no-cache \
    curl \
    iputils \
    bind-tools \
    openssl \
    prometheus-node-exporter

# Copy HAProxy configuration
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

# Copy startup script
COPY start-with-exporter.sh /usr/local/bin/start-with-exporter.sh
RUN chmod +x /usr/local/bin/start-with-exporter.sh

# Switch back to haproxy user for security
USER haproxy

# Expose ports
# 80: HTTP
# 443: HTTPS
# 8404: Stats page
# 9100: Node Exporter
EXPOSE 80 443 8404 9100

# Run HAProxy with node-exporter
CMD ["/usr/local/bin/start-with-exporter.sh", "haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
