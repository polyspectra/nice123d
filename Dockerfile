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

# Create a non-root user and set up home directory
RUN useradd -m -d /home/appuser -s /bin/bash appuser && \
    touch /home/appuser/.ocpvscode && \
    echo "{}" > /home/appuser/.ocpvscode && \
    chown -R appuser:appuser /home/appuser && \
    chmod 666 /home/appuser/.ocpvscode

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /run/nginx && \
    chown -R appuser:appuser /run/nginx && \
    chown -R appuser:appuser /var/log/nginx && \
    chown -R appuser:appuser /var/lib/nginx

# Install uv and create virtual environment
RUN pip install uv && \
    uv venv /opt/venv

# Activate virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Copy only pyproject.toml first to leverage Docker cache
COPY pyproject.toml .

# Install project and dependencies using uv
RUN uv pip install .

# Copy the rest of the application
COPY . .

# Download and setup openvscode-server
RUN wget https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-v1.86.2/openvscode-server-v1.86.2-linux-x64.tar.gz -O /tmp/openvscode-server.tar.gz && \
    tar -xzf /tmp/openvscode-server.tar.gz -C /opt && \
    rm /tmp/openvscode-server.tar.gz && \
    mv /opt/openvscode-server-v1.86.2-linux-x64 /opt/openvscode-server && \
    chown -R appuser:appuser /opt/openvscode-server

# Switch to non-root user
USER appuser
ENV HOME=/home/appuser

# Expose port 7860 for Hugging Face Spaces
EXPOSE 7860

# Create startup script
COPY start.sh /code/start.sh
RUN chmod +x /code/start.sh

# Run the startup script
CMD ["/code/start.sh"] 