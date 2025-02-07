#!/bin/bash

# Start the application on port 7861 first
python -m cadviewer &
APP_PID=$!

# Wait for the app to be ready
echo "Waiting for NiceGUI to start..."
while ! curl -s http://127.0.0.1:7861 > /dev/null; do
    sleep 1
done
echo "NiceGUI is ready"

# Start Nginx (which listens on 7860)
nginx

# Wait for the app to exit
wait $APP_PID 