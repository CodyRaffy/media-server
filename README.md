# Media Server

A Docker-based Plex media server setup for Raspberry Pi that streams a personal music library (synced from Dropbox) to Alexa speakers and iPhone via Plexamp.

## Architecture

```
Dropbox  ──rclone sync──▶  WD My Cloud NAS  ──SMB mount──▶  Raspberry Pi 4
                                                              └── Docker
                                                                   ├── Plex Media Server
                                                                   └── rclone (scheduled sync)
                                                                          │
                                                              ┌───────────┴───────────┐
                                                              ▼                       ▼
                                                        Alexa Skill              Plexamp (iPhone)
```

- **Dropbox** is the source of truth for ripped CDs
- **rclone** syncs Dropbox to the NAS on a configurable schedule (default: every 6 hours)
- **Plex** runs in Docker on the Pi, serving music from the NAS mount
- **Alexa** provides voice-controlled playback at home via the Plex skill
- **Plexamp** provides mobile playback on iPhone (requires Plex Pass)

## Prerequisites

- Raspberry Pi 4 (runs alongside RetroPie)
- WD My Cloud NAS (or any SMB-accessible network storage)
- Dropbox account with your music library
- Plex account (free; Plex Pass needed for Plexamp)

## Quick Start

1. **Clone and configure:**

   ```bash
   git clone https://github.com/CodyRaffy/media-server.git
   cd media-server
   cp .env.example .env
   # Edit .env with your NAS IP, credentials, Dropbox path, etc.
   ```

2. **Run the setup script:**

   ```bash
   chmod +x scripts/*.sh
   ./scripts/setup.sh
   ```

   This installs Docker, mounts the NAS, configures rclone for Dropbox, and starts the services.

3. **Configure Plex:**

   Open `http://<PI_IP>:32400/web`, sign in, and add a Music library pointing to `/music`.

4. **Connect Alexa:**

   Enable the Plex skill in the Alexa app and link your Plex account.

## Services

| Service | Image | Purpose |
|---|---|---|
| `plex` | `lscr.io/linuxserver/plex:latest` | Media server — indexes and streams music |
| `rclone-sync` | `rclone/rclone:latest` | Syncs Dropbox to NAS on a schedule |

## Configuration

All settings are in `.env` (see [`.env.example`](.env.example) for defaults):

| Variable | Default | Description |
|---|---|---|
| `TIMEZONE` | `America/New_York` | Your timezone |
| `MUSIC_PATH` | `/mnt/music` | NAS mount point on the Pi |
| `RCLONE_REMOTE` | `dropbox` | rclone remote name |
| `DROPBOX_MUSIC_PATH` | `/Music` | Path to music folder in Dropbox |
| `SYNC_INTERVAL` | `21600` (6 hours) | Seconds between Dropbox syncs |
| `NAS_IP` | — | NAS IP address |
| `NAS_SHARE` | — | NAS share name |
| `NAS_USERNAME` | — | NAS login username |
| `NAS_PASSWORD` | — | NAS login password |

## Scripts

| Script | Description |
|---|---|
| `scripts/setup.sh` | Full first-time setup (Docker, NAS mount, rclone, start services) |
| `scripts/configure-rclone.sh` | Reconfigure rclone (e.g., if Dropbox token expires) |
| `scripts/sync-now.sh` | Trigger an immediate Dropbox sync |
| `scripts/backup.sh <path>` | Backup music and Plex config to a USB drive |
| `scripts/status.sh` | Check container status, NAS mount, sync logs, and resource usage |

## Common Commands

```bash
docker compose ps              # Check container status
docker compose logs -f         # View live logs
docker compose restart         # Restart services
./scripts/sync-now.sh          # Trigger an immediate sync
./scripts/status.sh            # Full status check
```

## Alexa Voice Commands

| Command | Action |
|---|---|
| "Alexa, ask Plex to play Abbey Road" | Play a specific album |
| "Alexa, ask Plex to play The Beatles" | Play by artist |
| "Alexa, ask Plex to play jazz" | Play by genre |
| "Alexa, ask Plex to shuffle my music" | Shuffle entire library |

## Music Library Format

Plex works best with this folder structure:

```
/Music/
  Artist Name/
    Album Name (Year)/
      01 - Track Name.flac
```

Supported formats: FLAC, ALAC, MP3, AAC, WAV, OGG, WMA.

## Troubleshooting

- **Plex can't see music** — Check NAS mount: `ls /mnt/music`, try `sudo mount -a`
- **Alexa can't find server** — Verify Plex is running (`docker compose ps`), re-link the Plex skill
- **rclone sync failing** — Check `docker compose logs rclone-sync`, reconfigure with `./scripts/configure-rclone.sh`
- **Plex buffering** — Use Ethernet over WiFi; set music quality to "Original" to avoid transcoding
