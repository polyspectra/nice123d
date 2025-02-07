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
RUN chmod +x start.sh test_nginx.sh

# Configure Nginx with proper permissions
RUN mkdir -p /var/lib/nginx/body && \
    mkdir -p /var/lib/nginx/fastcgi && \
    mkdir -p /var/lib/nginx/proxy && \
    mkdir -p /var/lib/nginx/scgi && \
    mkdir -p /var/lib/nginx/uwsgi && \
    mkdir -p /run/nginx && \
    chown -R www-data:www-data /var/lib/nginx && \
    chown -R www-data:www-data /var/log/nginx && \
    chown -R www-data:www-data /run/nginx && \
    chmod 755 /var/lib/nginx && \
    chmod -R 755 /var/lib/nginx/* && \
    chmod -R 755 /var/log/nginx && \
    chmod -R 755 /run/nginx

# Create a test script for build-time verification
RUN echo '#!/bin/bash\n\
echo "Starting test server on port 7861..."\n\
python3 -m http.server 7861 &\n\
SERVER_PID=$!\n\
\n\
echo "Starting test server on port 3939..."\n\
python3 -m http.server 3939 &\n\
VIEWER_PID=$!\n\
\n\
echo "Starting nginx..."\n\
nginx\n\
\n\
echo "Waiting for servers to start..."\n\
sleep 2\n\
\n\
echo "Testing main app proxy..."\n\
MAIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:7860/)\n\
echo "Main app status: $MAIN_STATUS"\n\
\n\
echo "Testing viewer proxy..."\n\
VIEWER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:7860/proxy/3939/viewer)\n\
echo "Viewer status: $VIEWER_STATUS"\n\
\n\
nginx -s stop\n\
kill $SERVER_PID $VIEWER_PID\n\
\n\
if [ "$MAIN_STATUS" = "200" ] && [ "$VIEWER_STATUS" = "200" ]; then\n\
    echo "All tests passed!"\n\
    exit 0\n\
else\n\
    echo "Tests failed!"\n\
    exit 1\n\
fi' > /code/test_build.sh && chmod +x /code/test_build.sh

# Run the build-time test
RUN /code/test_build.sh

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