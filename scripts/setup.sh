#!/bin/bash
# ==============================================================================
# Media Server - Full Setup Script
# ==============================================================================
# Run this on your Raspberry Pi to set up everything:
#   chmod +x scripts/setup.sh
#   ./scripts/setup.sh
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Check we're on the Pi ---
if [ "$(uname -m)" != "aarch64" ] && [ "$(uname -m)" != "armv7l" ]; then
    warn "This script is intended for Raspberry Pi (ARM). Detected: $(uname -m)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# --- Load .env if it exists ---
if [ -f .env ]; then
    info "Loading configuration from .env"
    source .env
else
    error ".env file not found. Copy .env.example to .env and fill in your values first:\n  cp .env.example .env"
fi

# --- Step 1: Install Docker ---
info "Step 1: Installing Docker..."
if command -v docker &> /dev/null; then
    info "Docker already installed: $(docker --version)"
else
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker "$USER"
    rm /tmp/get-docker.sh
    info "Docker installed. You may need to log out and back in for group changes."
fi

# --- Step 2: Install Docker Compose plugin ---
info "Step 2: Checking Docker Compose..."
if docker compose version &> /dev/null; then
    info "Docker Compose already available: $(docker compose version)"
else
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    info "Docker Compose installed."
fi

# --- Step 3: Install CIFS utilities ---
info "Step 3: Installing CIFS utilities for NAS mounting..."
sudo apt-get install -y cifs-utils

# --- Step 4: Set up NAS mount ---
info "Step 4: Setting up NAS mount..."
sudo mkdir -p /mnt/music

# Create credentials file
sudo bash -c "cat > /etc/nas-credentials << EOF
username=${NAS_USERNAME}
password=${NAS_PASSWORD}
EOF"
sudo chmod 600 /etc/nas-credentials

# Add to fstab if not already there
FSTAB_ENTRY="//${NAS_IP}/${NAS_SHARE} /mnt/music cifs credentials=/etc/nas-credentials,uid=1000,gid=1000,iocharset=utf8,nofail 0 0"
if grep -q "/mnt/music" /etc/fstab; then
    warn "NAS mount already exists in /etc/fstab -- skipping"
else
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
    info "Added NAS mount to /etc/fstab"
fi

# Mount it
sudo mount -a
if mountpoint -q /mnt/music; then
    info "NAS mounted successfully at /mnt/music"
else
    warn "NAS mount may have failed. Check your NAS_IP and NAS_SHARE in .env"
    warn "You can try manually: sudo mount -a"
fi

# --- Step 5: Create config directories ---
info "Step 5: Creating config directories..."
mkdir -p config/plex
mkdir -p config/rclone

# --- Step 6: Configure rclone ---
info "Step 6: Configuring rclone for Dropbox..."
if [ -f config/rclone/rclone.conf ]; then
    info "rclone config already exists -- skipping"
    info "To reconfigure, run: ./scripts/configure-rclone.sh"
else
    info "Starting rclone configuration..."
    info "When prompted, select 'dropbox' as the storage type."
    info "You will need to open a URL on another device to authorize Dropbox access."
    echo ""
    docker run --rm -it \
        -v "$(pwd)/config/rclone:/config/rclone" \
        rclone/rclone:latest \
        config
fi

# --- Step 7: Start services ---
info "Step 7: Starting media server..."
docker compose up -d

# --- Done ---
echo ""
echo "=============================================="
info "Setup complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Open Plex Web UI: http://$(hostname -I | awk '{print $1}'):32400/web"
echo "  2. Sign in to your Plex account"
echo "  3. Add a Music library pointing to /music"
echo "  4. Enable the Plex Alexa skill in the Alexa app"
echo "  5. Install Plexamp on your iPhone"
echo ""
echo "Useful commands:"
echo "  docker compose ps          -- check container status"
echo "  docker compose logs -f     -- view live logs"
echo "  docker compose restart     -- restart services"
echo "  ./scripts/sync-now.sh      -- trigger an immediate Dropbox sync"
echo ""
