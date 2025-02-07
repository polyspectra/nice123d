#!/bin/bash

# Function to log messages
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Test Nginx directories and permissions
test_nginx() {
    log_msg "Testing Nginx configuration..."

    # Test directory existence and permissions
    directories=(
        "/var/log/nginx"
        "/var/lib/nginx"
        "/var/lib/nginx/body"
        "/run/nginx"
        "/etc/nginx"
    )

    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            log_msg "ERROR: Directory $dir does not exist"
            return 1
        fi
        
        # Test write permissions
        if ! touch "$dir/test_file" 2>/dev/null; then
            log_msg "ERROR: Cannot write to $dir"
            return 1
        fi
        rm -f "$dir/test_file"
        
        log_msg "OK: $dir exists and is writable"
    done

    # Test Nginx configuration
    if ! nginx -t; then
        log_msg "ERROR: Nginx configuration test failed"
        return 1
    fi

    log_msg "Nginx configuration test passed"
    return 0
}

# Run the test
test_nginx 