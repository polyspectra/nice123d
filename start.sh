#!/bin/bash

# Start Nginx
nginx

# Start the application on port 7861 (Nginx will proxy from 7860)
python -c "import cadviewer; from nicegui import app; app.native.start_args['port'] = 7861; cadviewer.ui.run(native=False, host='0.0.0.0', port=7861)" 