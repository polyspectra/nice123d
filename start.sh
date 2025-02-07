#!/bin/bash

# Create required directories with correct permissions
mkdir -p /var/log/nginx
chmod 777 /var/log/nginx
touch /var/log/nginx/error.log
chmod 666 /var/log/nginx/error.log
touch /var/log/nginx/access.log
chmod 666 /var/log/nginx/access.log

# Start Nginx
nginx

# Start the application on port 7861 (Nginx will proxy from 7860)
python -c "import cadviewer; from nicegui import app; app.native.start_args['port'] = 7861; cadviewer.ui.run(native=False, host='0.0.0.0', port=7861)" 