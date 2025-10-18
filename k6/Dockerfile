FROM grafana/k6:latest

USER root

# Install curl for health checks
RUN apk add --no-cache curl

# Copy test scripts
COPY scripts/ /scripts/
COPY config/ /config/

# Make scripts executable
RUN chmod +x /scripts/*.js

# Switch back to k6 user
USER k6

WORKDIR /scripts