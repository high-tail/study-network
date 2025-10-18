# Layer 3 Network Router using FRRouting
FROM frrouting/frr:v8.4.0

# Install additional network utilities for testing and node-exporter
RUN apk add --no-cache \
    iproute2 \
    iputils \
    tcpdump \
    curl \
    bind-tools \
    prometheus-node-exporter

# Enable IP forwarding
RUN echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Create FRR configuration directory
RUN mkdir -p /etc/frr

# Set proper permissions
RUN chown -R frr:frr /etc/frr

# Copy startup script
COPY start-with-exporter.sh /usr/local/bin/start-with-exporter.sh
RUN chmod +x /usr/local/bin/start-with-exporter.sh

EXPOSE 2601 2605 9100

CMD ["/usr/local/bin/start-with-exporter.sh", "/usr/lib/frr/docker-start"]
