# Media Server Plan

## Goal

Stream a personal ripped CD collection (stored in Dropbox) to Alexa smart speakers throughout the house via voice control, and to an iPhone when away from home.

---

## Hardware (All Existing)

| Device | Role | Details |
|---|---|---|
| **Raspberry Pi 4 4GB** | Media server (runs Plex in Docker alongside RetroPie) | CanaKit Starter PRO Kit, 32GB SD card |
| **WD My Cloud NAS** | Music file storage | Network-attached, accessible via SMB/NFS |
| **Dropbox** | Source of truth for ripped CD library | Cloud storage where CDs are currently stored |
| **Alexa Smart Speakers** | Home playback with voice control | Multiple throughout the house |
| **iPhone** | Remote playback | Via Plexamp app |
| **WD My Passport 1TB** | Backup (optional) | USB portable drive |
| **WD My Passport 2TB** | Backup (optional) | USB portable drive |

---

## Architecture

```
┌──────────────┐  rclone sync   ┌─────────────────────┐
│   Dropbox    │───────────────►│   WD My Cloud NAS   │
│   (source)   │   scheduled    │   (music storage)   │
└──────────────┘                └──────────┬──────────┘
                                           │ SMB/NFS
                                           │ mount
                                ┌──────────▼──────────┐
                                │   Raspberry Pi 4    │
                                │                     │
                                │  RetroPie (as-is)   │
                                │  Docker:            │
                                │   └── Plex Server   │
                                │                     │
                                │  /mnt/music → NAS   │
                                └─────────┬───────────┘
                                          │
                                   ┌──────┴──────┐
                                   │             │
                              ┌────▼──┐   ┌──────▼────┐
                              │ Alexa │   │  Plexamp  │
                              │ Skill │   │ (iPhone)  │
                              └───────┘   └───────────┘
```

### How It Works

1. **Dropbox** holds the original ripped CD files (source of truth)
2. **rclone** syncs Dropbox to the WD My Cloud NAS on a schedule (e.g., every 6 hours)
3. The **Raspberry Pi** mounts the NAS music folder over the local network via SMB
4. **Plex Media Server** runs in Docker on the Pi, reads music from the NAS mount
5. **Alexa** uses the official Plex skill for voice-controlled playback at home
6. **Plexamp** on iPhone provides high-quality playback on the go

### Why This Architecture

- **Pi stays lean** -- no music files on the 32GB SD card, leaving room for RetroPie
- **NAS handles storage** -- music library can grow without Pi storage constraints
- **RetroPie is unaffected** -- Docker containers run alongside it without conflict
- **Dropbox remains the source** -- add new CDs to Dropbox, they automatically appear in Plex

---

## Software Stack

| Software | Purpose | Runs On | Cost |
|---|---|---|---|
| **Docker** | Container runtime | Raspberry Pi | Free |
| **Plex Media Server** | Indexes and serves music library | Raspberry Pi (Docker) | Free |
| **rclone** | Syncs Dropbox to NAS on a schedule | Raspberry Pi (Docker or cron) | Free |
| **Plex Alexa Skill** | Voice control -- "Alexa, ask Plex to play..." | Alexa cloud | Free |
| **Plexamp** (iPhone) | Dedicated music player with offline downloads | iPhone | Requires Plex Pass |
| **Plex Pass** | Unlocks Plexamp, lyrics, sonic analysis | Plex account | ~$5/mo or $120 lifetime |

### Plex Pass vs Free Plex App

#### What You Get for Free

| Feature | Available? |
|---|---|
| Stream your full music library | Yes |
| Alexa voice control | Yes |
| Browse by artist/album/genre | Yes |
| Create playlists | Yes |
| Remote access (away from home) | Yes |
| Album art & metadata matching | Yes |
| Stream to Alexa speakers from app | Yes |

#### What Plex Pass Adds (~$5/mo or $120 lifetime)

| Feature | Why it matters |
|---|---|
| **Plexamp app** | Dedicated music player with much better UX than the general Plex app |
| **Offline downloads** | Save albums to your iPhone for listening without WiFi/data |
| **Lyrics** | Synced lyrics display during playback |
| **Sonic analysis** | Smart playlists based on mood, tempo, BPM (like Spotify's "vibes") |
| **Loudness leveling** | Consistent volume across tracks from different albums |
| **Gapless playback** | Seamless transitions (important for live albums, concept albums like Dark Side of the Moon) |
| **Crossfade** | Smooth blending between tracks |
| **Sweet Fades** | Intelligent fade that detects silence vs. live transitions |

**The Alexa voice control works the same either way.** The free app covers all the basics. Plex Pass is really about the iPhone listening experience -- offline downloads, gapless playback, and a cleaner music-focused app.

**Recommendation:** Start free. If you want a better phone experience, the $5/mo plan lets you try Plexamp without committing to the $120 lifetime price.

---

## Music Library Organization

Plex works best when music files follow this folder structure:

```
/Music/
  Artist Name/
    Album Name (Year)/
      01 - Track Name.flac
      02 - Track Name.flac
      ...
```

### Supported Formats

Plex handles all common audio formats: FLAC, ALAC, MP3, AAC, WAV, OGG, WMA. No conversion needed.

### Tagging

Plex reads embedded metadata tags (artist, album, track number, etc.). If your rips were done with a tool like EAC, dBpoweramp, or iTunes, they likely already have good tags. Plex will also match against its own metadata databases to fill in album art and additional info.

---

## Setup Steps

### Step 1: Prepare the NAS

1. Create a shared folder on the WD My Cloud for music (e.g., `Music`)
2. Note the NAS IP address and share credentials
3. Ensure SMB file sharing is enabled (it is by default on WD My Cloud)

### Step 2: Install Docker on the Raspberry Pi

Docker installs alongside RetroPie with no conflicts. SSH into the Pi and run:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt-get install -y docker-compose-plugin

# Reboot to apply group changes
sudo reboot
```

### Step 3: Mount the NAS on the Pi

```bash
# Install CIFS utilities for SMB mounting
sudo apt-get install -y cifs-utils

# Create mount point
sudo mkdir -p /mnt/music

# Create a credentials file (so password isn't in fstab)
sudo nano /etc/nas-credentials
```

Add to the credentials file:

```
username=YOUR_NAS_USERNAME
password=YOUR_NAS_PASSWORD
```

Secure it:

```bash
sudo chmod 600 /etc/nas-credentials
```

Add to `/etc/fstab` for automatic mounting on boot:

```
//NAS_IP_ADDRESS/Music /mnt/music cifs credentials=/etc/nas-credentials,uid=1000,gid=1000,iocharset=utf8 0 0
```

Mount it:

```bash
sudo mount -a
```

Verify:

```bash
ls /mnt/music
```

### Step 4: Create the Docker Compose File

Create a directory for the media server config:

```bash
mkdir -p ~/media-server
```

Create `~/media-server/docker-compose.yml`:

```yaml
services:
  plex:
    image: lscr.io/linuxserver/plex:latest
    container_name: plex
    network_mode: host
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York  # Change to your timezone
      - VERSION=docker
    volumes:
      - ./plex-config:/config
      - /mnt/music:/music:ro
    restart: unless-stopped

  rclone-sync:
    image: rclone/rclone:latest
    container_name: rclone-sync
    environment:
      - TZ=America/New_York  # Change to your timezone
    volumes:
      - ./rclone-config:/config/rclone
      - /mnt/music:/music
    # Sync every 6 hours
    entrypoint: /bin/sh
    command: >
      -c 'while true; do
        echo "Starting Dropbox sync at $$(date)";
        rclone sync dropbox:/path/to/your/music /music --verbose;
        echo "Sync complete at $$(date). Sleeping 6 hours...";
        sleep 21600;
      done'
    restart: unless-stopped
```

### Step 5: Configure rclone for Dropbox

```bash
# Run rclone config interactively
docker run --rm -it \
  -v ~/media-server/rclone-config:/config/rclone \
  rclone/rclone:latest \
  config
```

Follow the prompts:
1. Choose `n` for new remote
2. Name it `dropbox`
3. Select `Dropbox` from the provider list
4. Follow the OAuth flow to authorize access (you'll need to open a URL in a browser)
5. Save the config

**Note:** Since the Pi is headless, rclone will give you a URL to open on another device to complete the Dropbox authorization. Copy that URL, open it on your phone or PC, authorize, and paste the token back.

### Step 6: Start Everything

```bash
cd ~/media-server
docker compose up -d
```

Verify containers are running:

```bash
docker compose ps
```

### Step 7: Configure Plex

1. Open a browser and go to `http://PI_IP_ADDRESS:32400/web`
2. Sign in or create a Plex account
3. Name your server (e.g., "Home Music")
4. Add a music library:
   - Type: **Music**
   - Name: **Music**
   - Add folder: `/music`
5. Let Plex scan and index your library

### Step 8: Enable the Plex Alexa Skill

1. Open the **Alexa app** on your iPhone
2. Go to **Skills & Games**
3. Search for **Plex**
4. Enable the skill and **link your Plex account**
5. Follow the prompts to select your Plex server

### Step 9: Install Plexamp on iPhone

1. Download **Plexamp** from the App Store
2. Sign in with your Plex account
3. Select your server
4. Enable **offline downloads** for albums you want available without WiFi

---

## Voice Commands (Alexa)

Once set up, you can say:

| Command | What it does |
|---|---|
| "Alexa, ask Plex to play Abbey Road" | Plays a specific album |
| "Alexa, ask Plex to play The Beatles" | Plays music by an artist |
| "Alexa, ask Plex to play jazz" | Plays by genre |
| "Alexa, ask Plex to shuffle my music" | Shuffles entire library |
| "Alexa, ask Plex to play my playlist Road Trip" | Plays a specific playlist |
| "Alexa, ask Plex to pause" | Pauses playback |
| "Alexa, ask Plex to skip" | Skips to next track |
| "Alexa, ask Plex what's playing" | Shows current track info |

---

## Remote Access (Away from Home)

Plex automatically configures remote access in most cases. To verify:

1. Go to **Plex Web** > **Settings** > **Remote Access**
2. Ensure it shows "Fully accessible outside your network"
3. If not, you may need to set up port forwarding on your router for port **32400**

Once enabled, Plexamp on your iPhone works anywhere -- home WiFi, cellular, or other networks.

---

## Backup Strategy (Optional)

Use the WD My Passport portable drives for backup:

| Drive | Use |
|---|---|
| **1TB My Passport** | Periodic backup of music library from NAS |
| **2TB My Passport** | Backup of RetroPie saves/ROMs and Plex config |

Simple backup with rsync (run periodically):

```bash
# Backup music to My Passport (when plugged into Pi)
rsync -av /mnt/music/ /media/mypassport/music-backup/

# Backup Plex config
rsync -av ~/media-server/plex-config/ /media/mypassport/plex-backup/
```

---

## Cost Summary

| Item | Cost |
|---|---|
| Hardware | **$0** (all existing) |
| Plex Media Server | **Free** |
| Plex Alexa Skill | **Free** |
| Docker / rclone | **Free** |
| Plexamp (iPhone) | **Plex Pass required** (~$5/mo or $120 lifetime) |
| **Total** | **$0 - $5/mo** |

---

## Troubleshooting

### Plex can't see music files
- Check the NAS mount: `ls /mnt/music`
- If empty, remount: `sudo mount -a`
- Check the NAS is online and accessible

### Alexa says "I can't find your Plex server"
- Ensure Plex is running: `docker compose ps`
- Re-link the Plex skill in the Alexa app
- Make sure the Pi and Alexa are on the same network

### rclone sync isn't working
- Check logs: `docker compose logs rclone-sync`
- Re-run rclone config if Dropbox token expired
- Verify Dropbox path in docker-compose.yml matches your actual folder path

### Plex is slow or buffering
- Music streaming is lightweight, so this is usually a network issue
- Ensure the Pi is connected via Ethernet, not WiFi, if possible
- Check NAS network connection

### RetroPie seems slower
- Check resource usage: `htop`
- Plex should use minimal CPU for music; if it's high, check if Plex is transcoding unnecessarily
- In Plex settings, set music quality to "Original" to avoid transcoding
