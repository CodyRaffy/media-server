#!/bin/bash
# ==============================================================================
# Check the status of the media server
# ==============================================================================

echo "=== Container Status ==="
docker compose ps
echo ""

echo "=== NAS Mount ==="
if mountpoint -q /mnt/music 2>/dev/null; then
    echo "Mounted at /mnt/music"
    MUSIC_COUNT=$(find /mnt/music -type f \( -name "*.flac" -o -name "*.mp3" -o -name "*.m4a" -o -name "*.aac" -o -name "*.wav" -o -name "*.ogg" -o -name "*.wma" -o -name "*.alac" \) 2>/dev/null | wc -l)
    echo "Music files found: $MUSIC_COUNT"
    MUSIC_SIZE=$(du -sh /mnt/music 2>/dev/null | cut -f1)
    echo "Library size: $MUSIC_SIZE"
else
    echo "WARNING: NAS not mounted at /mnt/music"
    echo "Try: sudo mount -a"
fi
echo ""

echo "=== Last rclone Sync ==="
if [ -f config/rclone/sync.log ]; then
    tail -5 config/rclone/sync.log
else
    echo "No sync log found yet"
fi
echo ""

echo "=== Plex Server ==="
PLEX_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if curl -s "http://localhost:32400/identity" > /dev/null 2>&1; then
    echo "Plex is running"
    echo "Web UI: http://${PLEX_IP}:32400/web"
else
    echo "Plex is not responding"
    echo "Check logs: docker compose logs plex"
fi
echo ""

echo "=== Resource Usage ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null
