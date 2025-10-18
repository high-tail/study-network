# DHCP Server using ISC DHCP
# Provides dynamic IP address assignment
FROM alpine:3.18

# Install ISC DHCP server and utilities
RUN apk add --no-cache \
    dhcp \
    dhcp-server-ldap \
    bind-tools \
    iputils \
    iproute2 \
    prometheus-node-exporter

# Create necessary directories
RUN mkdir -p /var/lib/dhcp /var/run

# Create dhcp lease file
RUN touch /var/lib/dhcp/dhcpd.leases

# Copy startup script
COPY start-with-exporter.sh /usr/local/bin/start-with-exporter.sh
RUN chmod +x /usr/local/bin/start-with-exporter.sh

# Expose DHCP ports and node-exporter port
EXPOSE 67/udp 68/udp 9100

# Run DHCP server in foreground with node-exporter
CMD ["/usr/local/bin/start-with-exporter.sh", "dhcpd", "-f", "-d", "-cf", "/etc/dhcp/dhcpd.conf"]
