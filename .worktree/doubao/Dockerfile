# pdoc Docker Image
# Multi-stage build for documentation generation and serving

# Builder stage: Build documentation
FROM python:3.11-slim as builder

WORKDIR /build

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        ca-certificates \
        && \
    rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY setup.py setup.cfg README.md ./
COPY pdoc/ ./pdoc/

RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -e .

# Build documentation
RUN mkdir -p /output && \
    pdoc --html --output-dir /output pdoc && \
    if [ -d "/output/pdoc" ]; then \
        mv /output/pdoc/* /output/ && \
        rmdir /output/pdoc; \
    fi && \
    echo "<html><head><meta http-equiv='refresh' content='0; url=pdoc.html'></head><body>Redirecting...</body></html>" > /output/index.html

# Final stage: Nginx server to serve documentation
FROM nginx:alpine

LABEL maintainer="pdoc Community"
LABEL description="pdoc - Auto-generate API documentation for Python projects"
LABEL org.opencontainers.image.source="https://github.com/pdoc3/pdoc"

# Install necessary packages
RUN apk add --no-cache python3 py3-pip && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Copy built documentation from builder
COPY --from=builder /output /usr/share/nginx/html/docs

# Optionally copy source for live documentation serving
COPY --from=builder /build /pdoc-source

# Configure Nginx
RUN cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html index.htm;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Cache static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, max-age=31536000";
    }

    # Documentation root
    location / {
        try_files \$uri \$uri/ /docs/index.html;
    }

    # Documentation endpoint
    location /docs {
        alias /usr/share/nginx/html/docs;
        try_files \$uri \$uri/ /docs/index.html;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create a simple startup script for live mode
RUN cat > /usr/local/bin/start-live.sh <<'EOF'
#!/bin/sh
set -e

# Install pdoc for live mode
cd /pdoc-source && pip install --no-cache-dir -e .

# Start pdoc HTTP server on port 8080
echo "Starting pdoc live server for module: ${PDOC_MODULE:-pdoc}"
pdoc --http 0.0.0.0:8080 ${PDOC_MODULE:-pdoc}
EOF
RUN chmod +x /usr/local/bin/start-live.sh

# Expose ports
EXPOSE 80 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Default command: serve static documentation
CMD ["nginx", "-g", "daemon off;"]
