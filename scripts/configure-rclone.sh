#!/bin/bash
# ==============================================================================
# Reconfigure rclone (e.g., if Dropbox token expires)
# ==============================================================================

set -e

echo "Starting rclone configuration..."
echo "When prompted, select 'dropbox' as the storage type."
echo "You will need to open a URL on another device to authorize Dropbox access."
echo ""

docker run --rm -it \
    -v "$(pwd)/config/rclone:/config/rclone" \
    rclone/rclone:latest \
    config
