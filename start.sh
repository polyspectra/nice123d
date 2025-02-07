#!/bin/bash

# Start Nginx (which listens on 7860)
nginx

# Start the application on port 7861 (Nginx will proxy from 7860)
python -m cadviewer 