# Web Server 2 - Nginx
# Layer 7 (Application Layer) - HTTP Server
FROM nginx:alpine

# Install utilities for testing and node-exporter
RUN apk add --no-cache \
    curl \
    iputils \
    bind-tools \
    iproute2 \
    prometheus-node-exporter

# Create web content directory
RUN mkdir -p /usr/share/nginx/html

# Create a simple health check endpoint
RUN echo '{"status": "healthy", "server": "web2"}' > /usr/share/nginx/html/health

# Create custom index page
COPY index.html /usr/share/nginx/html/index.html

# Create nginx configuration
RUN cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name web2;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        add_header X-Served-By web2;
    }

    location /health {
        access_log off;
        return 200 '{"status": "healthy", "server": "web2"}';
        add_header Content-Type application/json;
    }

    location /info {
        return 200 'Server: web2\nIP: \$server_addr\nTime: \$time_local\n';
        add_header Content-Type text/plain;
    }
}
EOF

# Copy startup script
COPY start-with-exporter.sh /usr/local/bin/start-with-exporter.sh
RUN chmod +x /usr/local/bin/start-with-exporter.sh

EXPOSE 80 9100

CMD ["/usr/local/bin/start-with-exporter.sh", "nginx", "-g", "daemon off;"]
