# DNS Server using Dnsmasq
# Provides local DNS resolution for the network lab
FROM alpine:3.18

# Install dnsmasq and utilities
RUN apk add --no-cache \
    dnsmasq \
    bind-tools \
    iputils \
    curl \
    prometheus-node-exporter

# Create dnsmasq configuration directory
RUN mkdir -p /etc/dnsmasq.d

# Copy startup script
COPY start-with-exporter.sh /usr/local/bin/start-with-exporter.sh
RUN chmod +x /usr/local/bin/start-with-exporter.sh

# Expose DNS port and node-exporter port
EXPOSE 53/udp 53/tcp 9100

# Run dnsmasq in foreground with node-exporter
CMD ["/usr/local/bin/start-with-exporter.sh", "dnsmasq", "--no-daemon", "--log-queries", "--log-facility=-"]
