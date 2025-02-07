FROM python:3.11-slim

WORKDIR /code

# Install build dependencies, wget, and OpenGL/X11 libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    libgl1-mesa-glx \
    libgl1-mesa-dev \
    libx11-6 \
    libx11-dev \
    libxrender1 \
    nginx \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create matplotlib config directory with proper permissions
ENV MPLCONFIGDIR=/tmp/matplotlib

# Create cache directories with proper permissions
RUN mkdir -p /.cache/ezdxf && \
    chmod 777 /.cache/ezdxf && \
    mkdir -p /tmp/ocpvscode && \
    chmod 777 /tmp/ocpvscode

# Set OCP_VSCODE_LOCK_DIR environment variable
ENV OCP_VSCODE_LOCK_DIR=/tmp/ocpvscode

# Copy application files first
COPY . .

# Set up startup script with correct permissions
RUN chmod +x start.sh

# Configure Nginx with proper permissions
RUN mkdir -p /var/lib/nginx/body && \
    mkdir -p /var/lib/nginx/proxy && \
    mkdir -p /run/nginx && \
    chown -R www-data:www-data /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx && \
    chown -R www-data:www-data /run/nginx && \
    chmod 755 /var/lib/nginx && \
    chmod -R 755 /var/lib/nginx/* && \
    chmod -R 755 /var/log/nginx && \
    chmod -R 755 /run/nginx && \
    rm -f /etc/nginx/sites-enabled/default

# Create nginx configuration for port forwarding
RUN echo 'worker_processes 1;\n\
error_log stderr info;\n\
pid /run/nginx/nginx.pid;\n\
events {\n\
    worker_connections 1024;\n\
}\n\
http {\n\
    access_log /dev/stdout;\n\
    upstream nicegui {\n\
        server 127.0.0.1:7861;\n\
    }\n\
    upstream viewer {\n\
        server 127.0.0.1:3939;\n\
    }\n\
    server {\n\
        listen 7860;\n\
        server_name localhost;\n\
        location / {\n\
            proxy_pass http://nicegui;\n\
            proxy_http_version 1.1;\n\
            proxy_set_header Upgrade $http_upgrade;\n\
            proxy_set_header Connection "upgrade";\n\
            proxy_set_header Host $host;\n\
        }\n\
        location /proxy/3939/viewer {\n\
            proxy_pass http://viewer/viewer;\n\
            proxy_http_version 1.1;\n\
            proxy_set_header Upgrade $http_upgrade;\n\
            proxy_set_header Connection "upgrade";\n\
            proxy_set_header Host $host;\n\
            proxy_read_timeout 86400;\n\
        }\n\
    }\n\
}' > /etc/nginx/nginx.conf

# Create a non-root user and set up home directory
RUN useradd -m -d /home/appuser -s /bin/bash appuser && \
    touch /home/appuser/.ocpvscode && \
    echo "{}" > /home/appuser/.ocpvscode && \
    chown -R appuser:appuser /home/appuser && \
    chmod 666 /home/appuser/.ocpvscode

# Install uv and create virtual environment
RUN pip install uv && \
    uv venv /opt/venv

# Activate virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Install project and dependencies using uv
RUN uv pip install .

# Download and setup openvscode-server
RUN wget https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-v1.86.2/openvscode-server-v1.86.2-linux-x64.tar.gz -O /tmp/openvscode-server.tar.gz && \
    tar -xzf /tmp/openvscode-server.tar.gz -C /opt && \
    rm /tmp/openvscode-server.tar.gz && \
    mv /opt/openvscode-server-v1.86.2-linux-x64 /opt/openvscode-server

# Set permissions for the entire /code directory and nginx config
RUN chown -R appuser:appuser /code && \
    chown -R appuser:appuser /opt/openvscode-server && \
    chown -R appuser:appuser /etc/nginx && \
    chmod -R 755 /etc/nginx

# Switch to non-root user
USER appuser
ENV HOME=/home/appuser

# Expose port 7860 for Hugging Face Spaces
EXPOSE 7860

# Run the startup script
CMD ["./start.sh"] 