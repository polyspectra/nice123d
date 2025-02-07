FROM python:3.11-slim

WORKDIR /code

# Install build dependencies and wget
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create matplotlib config directory with proper permissions
ENV MPLCONFIGDIR=/tmp/matplotlib

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
    chown -R 1000:1000 /opt/openvscode-server

# Expose port 7860 for Hugging Face Spaces
EXPOSE 7860

# Run the application
CMD ["python", "-c", "import cadviewer; from nicegui import app; app.native.start_args['port'] = 7860; cadviewer.ui.run(native=False, host='0.0.0.0', port=7860)"] 