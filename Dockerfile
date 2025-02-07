FROM python:3.11-slim

WORKDIR /code

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy only pyproject.toml first to leverage Docker cache
COPY pyproject.toml .

# Install project and dependencies
RUN pip install .

# Copy the rest of the application
COPY . .

# Expose port 7860 for Hugging Face Spaces
EXPOSE 7860

CMD ["python", "-c", "import cadviewer; from nicegui import app; app.native.start_args['port'] = 7860; cadviewer.ui.run(native=False, host='0.0.0.0', port=7860)"] 