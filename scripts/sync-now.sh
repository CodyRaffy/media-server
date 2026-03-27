#!/bin/bash
# ==============================================================================
# Trigger an immediate Dropbox sync (outside the scheduled interval)
# ==============================================================================

set -e

# Load .env
if [ -f .env ]; then
    source .env
elif [ -f ../.env ]; then
    source ../.env
fi

REMOTE="${RCLONE_REMOTE:-dropbox}"
DROPBOX_PATH="${DROPBOX_MUSIC_PATH:-/Music}"
MUSIC_DIR="${MUSIC_PATH:-/mnt/music}"

echo "Syncing ${REMOTE}:${DROPBOX_PATH} -> ${MUSIC_DIR}"
echo "This may take a while depending on your library size..."
echo ""

docker run --rm \
    -v "$(pwd)/config/rclone:/config/rclone" \
    -v "${MUSIC_DIR}:/music" \
    rclone/rclone:latest \
    sync "${REMOTE}:${DROPBOX_PATH}" /music --verbose --progress

echo ""
echo "Sync complete!"
