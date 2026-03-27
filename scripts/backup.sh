#!/bin/bash
# ==============================================================================
# Backup music library and Plex config to a USB drive
# ==============================================================================
# Usage:
#   ./scripts/backup.sh /media/mypassport
# ==============================================================================

set -e

BACKUP_DEST="${1:-/media/mypassport}"

if [ ! -d "$BACKUP_DEST" ]; then
    echo "Error: Backup destination not found: $BACKUP_DEST"
    echo "Usage: $0 /path/to/usb/drive"
    echo ""
    echo "Plug in your WD My Passport and check where it mounted:"
    echo "  lsblk"
    echo "  ls /media/$USER/"
    exit 1
fi

echo "Backing up to: $BACKUP_DEST"
echo ""

# Backup music library
echo "[1/2] Backing up music library..."
mkdir -p "$BACKUP_DEST/music-backup"
rsync -av --progress /mnt/music/ "$BACKUP_DEST/music-backup/"
echo "Music backup complete."
echo ""

# Backup Plex config (metadata, playlists, play history)
echo "[2/2] Backing up Plex config..."
mkdir -p "$BACKUP_DEST/plex-backup"
rsync -av --progress config/plex/ "$BACKUP_DEST/plex-backup/"
echo "Plex config backup complete."
echo ""

echo "=============================================="
echo "Backup complete!"
echo "  Music:  $BACKUP_DEST/music-backup/"
echo "  Config: $BACKUP_DEST/plex-backup/"
echo "=============================================="
