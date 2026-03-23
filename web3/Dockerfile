# Web Server 3 - Nginx with HTTPS/TLS
# Layer 7 (Application Layer) - HTTPS Server with TLS termination
FROM nginx:alpine

# Install utilities for testing and node-exporter
RUN apk add --no-cache \
    curl \
    iputils \
    bind-tools \
    iproute2 \
    openssl \
    prometheus-node-exporter

# Create web content directory
RUN mkdir -p /usr/share/nginx/html

# Create directories for SSL certificates
RUN mkdir -p /etc/nginx/ssl

# Create a simple health check endpoint (HTTP and HTTPS)
RUN echo '{"status": "healthy", "server": "web3", "tls": "enabled"}' > /usr/share/nginx/html/health

# Create custom index page
COPY index.html /usr/share/nginx/html/index.html

# Create nginx configuration with HTTPS support
RUN cat > /etc/nginx/conf.d/default.conf <<'EOF'
# HTTP Server - Redirect to HTTPS
server {
    listen 80;
    server_name web3.netlab.local web3;

    # Health check endpoint (HTTP) - for monitoring
    location /health {
        access_log off;
        return 200 '{"status": "healthy", "server": "web3", "protocol": "http"}';
        add_header Content-Type application/json;
    }

    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name web3.netlab.local web3;

    # TLS/SSL Configuration
    ssl_certificate /etc/nginx/ssl/web3-cert.pem;
    ssl_certificate_key /etc/nginx/ssl/web3-key.pem;

    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # SSL session cache for performance
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        add_header X-Served-By web3;
        add_header X-Protocol $server_protocol;
        add_header X-TLS-Version $ssl_protocol;
        add_header X-TLS-Cipher $ssl_cipher;
    }

    location /health {
        access_log off;
        return 200 '{"status": "healthy", "server": "web3", "protocol": "https", "tls": "$ssl_protocol"}';
        add_header Content-Type application/json;
    }

    location /info {
        return 200 'Server: web3\nIP: $server_addr\nTime: $time_local\nProtocol: $server_protocol\nTLS Version: $ssl_protocol\nCipher: $ssl_cipher\n';
        add_header Content-Type text/plain;
    }

    location /tls-info {
        return 200 '{"server": "web3", "protocol": "$server_protocol", "tls_version": "$ssl_protocol", "cipher": "$ssl_cipher", "session_reused": "$ssl_session_reused"}';
        add_header Content-Type application/json;
    }
}
EOF

# Copy startup script
COPY start-with-exporter.sh /usr/local/bin/start-with-exporter.sh
RUN chmod +x /usr/local/bin/start-with-exporter.sh

EXPOSE 80 443 9100

CMD ["/usr/local/bin/start-with-exporter.sh", "nginx", "-g", "daemon off;"]
