#!/bin/bash

# Run Nginx tests
echo "Running Nginx tests..."
if ! ./test_nginx.sh; then
    echo "Nginx tests failed. Check permissions and configuration."
    exit 1
fi

# Create required directories with correct permissions
mkdir -p /var/log/nginx
chmod 777 /var/log/nginx
touch /var/log/nginx/error.log
chmod 666 /var/log/nginx/error.log
touch /var/log/nginx/access.log
chmod 666 /var/log/nginx/access.log

# Start Nginx without user directive
sed -i 's/^user/#user/' /etc/nginx/nginx.conf
nginx

# Start the application on port 7861 (Nginx will proxy from 7860)
python -c "import cadviewer; from nicegui import app; app.native.start_args['port'] = 7861; cadviewer.ui.run(native=False, host='0.0.0.0', port=7861)" 