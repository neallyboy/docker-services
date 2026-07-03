# Intel Quick Sync Hardware Transcoding for Plex
## Proxmox VE → Unprivileged LXC → Docker → hotio/plex

> **Status:** ✅ Production  
> **Last Updated:** 2026-07-02  
> **Author:** Neal Miran

---

## Table of Contents

- [Overview](#overview)
- [Infrastructure](#infrastructure)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Node Hardware Reference](#node-hardware-reference)
- [Setup Guide](#setup-guide)
  - [Step 1 — Verify iGPU on Proxmox Host](#step-1--verify-igpu-on-proxmox-host)
  - [Step 2 — Install VA-API Drivers on Host](#step-2--install-va-api-drivers-on-host)
  - [Step 3 — Create udev Rule on All Nodes](#step-3--create-udev-rule-on-all-nodes)
  - [Step 4 — Add Device Passthrough to LXC Config](#step-4--add-device-passthrough-to-lxc-config)
  - [Step 5 — Create init-hook-app Script](#step-5--create-init-hook-app-script)
  - [Step 6 — Update Docker Compose](#step-6--update-docker-compose)
  - [Step 7 — Enable Hardware Transcoding in Plex UI](#step-7--enable-hardware-transcoding-in-plex-ui)
  - [Step 8 — Verify Hardware Transcoding](#step-8--verify-hardware-transcoding)
- [File Reference](#file-reference)
- [Migration Guide](#migration-guide)
- [Troubleshooting](#troubleshooting)

---

## Overview

This document describes how Intel Quick Sync hardware transcoding is enabled for Plex running inside a Docker container, itself inside an unprivileged LXC container on Proxmox VE.

The key challenge is passing the Intel iGPU (`/dev/dri`) through three layers of virtualization:

```
Proxmox Host (bare metal)
  └── LXC Container CT102 (unprivileged)
        └── Docker
              └── hotio/plex container
```

Quick Sync offloads video encode/decode to the Intel iGPU, dramatically reducing CPU load and enabling more simultaneous transcodes. With a Plex Pass lifetime subscription, this unlocks hardware-accelerated H.264 encode and HEVC decode.

---

## Infrastructure

| Component | Detail |
|-----------|--------|
| Hypervisor | Proxmox VE (Trixie/Debian 13) |
| Cluster | 3-node (pve01, pve02, pve03) |
| Docker LXC | CT102, unprivileged, Ubuntu 24.04 |
| Docker image | `ghcr.io/hotio/plex` |
| Plex subscription | Lifetime Plex Pass |
| Active transcode node | **pve01** (best iGPU) |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   PROXMOX HOST (pve01)                  │
│                                                         │
│  Intel i7-6700 (Skylake)                                │
│  HD Graphics 530 — Quick Sync                           │
│                                                         │
│  /dev/dri/card0       (226:0,  video:44)                │
│  /dev/dri/renderD128  (226:128, render:993)             │
│                                                         │
│  udev rule → crw-rw-rw- (0666) on all /dev/dri/*       │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │         LXC CT102 (unprivileged, Ubuntu 24.04)    │  │
│  │                                                   │  │
│  │  dev0: /dev/dri/card0,gid=44                      │  │
│  │  dev1: /dev/dri/renderD128,gid=993                │  │
│  │  (Proxmox 8.2+ native device passthrough)         │  │
│  │                                                   │  │
│  │  /dev/dri/card0      → root:video  crw-rw----     │  │
│  │  /dev/dri/renderD128 → root:render crw-rw----     │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │         Docker: hotio/plex container        │  │  │
│  │  │                                             │  │  │
│  │  │  devices: /dev/dri:/dev/dri                 │  │  │
│  │  │                                             │  │  │
│  │  │  init-hook-app:                             │  │  │
│  │  │  ├── installs intel-media-va-driver         │  │  │
│  │  │  ├── creates render group (gid=993)         │  │  │
│  │  │  └── adds hotio → video + render groups     │  │  │
│  │  │                                             │  │  │
│  │  │  VA-API → iHD driver → Quick Sync ✅        │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- Proxmox VE 8.2 or higher (required for native `dev0`/`dev1` syntax)
- Intel CPU with integrated graphics (Haswell/4th gen or newer recommended)
- Plex Pass subscription (required for hardware encoding)
- Docker LXC using `ghcr.io/hotio/plex` image
- `docker-services` git repo cloned on the LXC

---

## Node Hardware Reference

### pve01 — Active Transcode Node ✅ (Recommended)

| Property | Value |
|----------|-------|
| Machine | Dell OptiPlex 7010 SFF |
| CPU | Intel Core i7-6700 @ 3.40GHz |
| iGPU | HD Graphics 530 (Skylake, 6th Gen) |
| EU Count | 24 Execution Units |
| VA-API Driver | Intel iHD (25.2.3) |
| H.264 Decode | ✅ VAEntrypointVLD |
| H.264 Encode | ✅ VAEntrypointEncSliceLP |
| HEVC/H.265 Decode | ✅ VAEntrypointVLD |
| HEVC/H.265 Encode | ❌ Not supported |
| VP8 Decode | ✅ |
| JPEG Encode/Decode | ✅ |
| `/dev/dri` | card0 (226:0), renderD128 (226:128) |

### pve02 — Fallback Node ⚠️ (Limited)

| Property | Value |
|----------|-------|
| Machine | Dell OptiPlex 3040 SFF |
| CPU | Intel Core i7-3770 @ 3.40GHz |
| iGPU | HD Graphics 4000 (Ivy Bridge, 3rd Gen) |
| VA-API Driver | Intel iHD |
| H.264 Decode | ✅ |
| H.264 Encode | ✅ |
| HEVC/H.265 | ❌ Not supported (too old) |
| `/dev/dri` | card1 (226:1), renderD128 (226:128) |

> ⚠️ pve02 uses `card1` instead of `card0`. The LXC `dev0` entry must reference `/dev/dri/card1` if migrating here.

### pve03 — Fallback Node ✅ (Same GPU as pve01)

| Property | Value |
|----------|-------|
| Machine | Dell OptiPlex 3046 SFF |
| CPU | Intel Core i3-6100 @ 3.70GHz |
| iGPU | HD Graphics 530 (Skylake, 6th Gen) |
| VA-API Driver | Intel iHD |
| H.264 Decode | ✅ |
| H.264 Encode | ✅ |
| HEVC/H.265 Decode | ✅ |
| HEVC/H.265 Encode | ❌ |
| `/dev/dri` | card0 (226:0), renderD128 (226:128) |

---

## Setup Guide

### Step 1 — Verify iGPU on Proxmox Host

Run on each Proxmox node to confirm the iGPU is detected and `/dev/dri` exists:

```bash
# Check CPU
cat /proc/cpuinfo | grep "model name" | head -1

# Check DRI devices
ls -la /dev/dri/

# Confirm Intel GPU via PCI
lspci | grep -i vga

# Confirm i915 driver is loaded
lsmod | grep i915
```

Expected output for `/dev/dri/`:
```
crw-rw---- 1 root video  226,   0 ... card0
crw-rw---- 1 root render 226, 128 ... renderD128
```

If `/dev/dri` is empty or missing, check BIOS to ensure iGPU is enabled.

---

### Step 2 — Install VA-API Drivers on Host

On each Proxmox node (Debian Trixie):

```bash
apt update && apt install -y vainfo intel-media-va-driver
```

Verify Quick Sync is functional:

```bash
LIBVA_DRIVER_NAME=iHD vainfo
```

Expected output includes:
```
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 25.x.x
VAProfileH264Main               : VAEntrypointVLD
VAProfileH264Main               : VAEntrypointEncSliceLP
VAProfileHEVCMain               : VAEntrypointVLD
```

---

### Step 3 — Create udev Rule on All Nodes

Run on **each** Proxmox node (pve01, pve02, pve03):

```bash
cat > /etc/udev/rules.d/99-dri-permissions.rules << 'EOF'
KERNEL=="card[0-9]*", SUBSYSTEM=="drm", MODE="0666"
KERNEL=="renderD[0-9]*", SUBSYSTEM=="drm", MODE="0666"
EOF

udevadm control --reload-rules && udevadm trigger
```

Verify permissions:
```bash
ls -la /dev/dri/
```

Expected:
```
crw-rw-rw- 1 root video  226,   0 ... card0
crw-rw-rw- 1 root render 226, 128 ... renderD128
```

> The wildcard `card[0-9]*` handles pve02's `card1` device name automatically.

---

### Step 4 — Add Device Passthrough to LXC Config

On the **active Proxmox node** hosting CT102, edit the LXC config:

```bash
nano /etc/pve/lxc/102.conf
```

Add at the bottom:

```
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/renderD128,gid=993
```

> **Note for pve02:** Use `card1` instead of `card0`:
> ```
> dev0: /dev/dri/card1,gid=44
> ```

Then reboot the LXC:

```bash
pct reboot 102
```

Verify devices are visible inside the LXC:

```bash
pct exec 102 -- ls -la /dev/dri/
```

Expected:
```
crw-rw---- 1 root video  226,   0 ... card0
crw-rw---- 1 root render 226, 128 ... renderD128
```

> **Why `dev0`/`dev1` instead of `lxc.cgroup2` + `lxc.mount.entry`?**  
> Proxmox 8.2+ introduced native device passthrough via `dev0`/`dev1` which correctly handles GID mapping in unprivileged containers. The older cgroup2/mount approach causes ownership to show as `nobody:nogroup` inside the LXC.

---

### Step 5 — Create init-hook-app Script

The `hotio/plex` image uses s6-overlay and sources `/etc/s6-overlay/init-hook-app` during startup if it exists. This script runs before Plex starts and handles:

1. Installing `intel-media-va-driver` (not bundled in the image)
2. Creating the `render` group (GID 993 — not present by default)
3. Adding the `hotio` user to `video` and `render` groups

> **Why is this needed?**  
> hotio's `init-setup/run` script auto-detects `/dev/dri` devices using `find /dev/dri -type c`. Due to a Docker/LXC device passthrough quirk, `find -type c` returns nothing even though the devices exist and are accessible. The `init-hook-app` works around this by explicitly adding group memberships before Plex starts.

The script lives in the git repo at `servarr/init-hook-app`:

```bash
#!/command/with-contenv bash
# shellcheck shell=bash

# Install Intel VA-API driver if not present
if [[ ! -f /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so ]]; then
    apt-get update -qq && apt-get install -y -qq intel-media-va-driver vainfo
fi

# Create render group if it doesn't exist
getent group render > /dev/null 2>&1 || groupadd -g 993 render

# Add hotio to video and render groups
usermod -a -G video,render hotio
```

Make it executable:

```bash
chmod +x /root/docker_services/servarr/init-hook-app
```

---

### Step 6 — Update Docker Compose

The Plex service in `servarr/docker-compose.yml` requires two additions:

1. `devices` — maps `/dev/dri` from the LXC into the container
2. A volume mount for `init-hook-app`

```yaml
  plex:
    container_name: plex
    image: ghcr.io/hotio/plex
    ports:
      - "32400:32400"
    devices:
      - /dev/dri:/dev/dri
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - UMASK=${UMASK}
      - TZ=${TZ}
      - PLEX_CLAIM_TOKEN=${PLEX_CLAIM_TOKEN}
      - PLEX_ADVERTISE_URL=${PLEX_ADVERTISE_URL}
      - PLEX_NO_AUTH_NETWORKS=${PLEX_NO_AUTH_NETWORKS}
      - PLEX_BETA_INSTALL=${PLEX_BETA_INSTALL}
      - PLEX_PURGE_CODECS=${PLEX_PURGE_CODECS}
    volumes:
      - /media/servarr/plex/:/config
      - /media/servarr/plex/transcode:/transcode
      - /mnt/qnap/servarr:/data
      - /root/docker_services/servarr/init-hook-app:/etc/s6-overlay/init-hook-app:ro
    restart: always
```

Recreate the container:

```bash
cd /root/docker_services/servarr
docker compose up -d --force-recreate plex
```

Wait ~60 seconds for the init script to run (apt install takes a moment on first boot), then verify:

```bash
# Confirm hotio is in video and render groups
docker exec plex id hotio
# Expected: uid=1000(hotio) gid=1000(hotio) groups=1000(hotio),44(video),100(users),993(render)

# Confirm VA-API driver is present
docker exec plex find /usr/lib -name "iHD_drv_video.so"

# Confirm Quick Sync is operational
docker exec plex bash -c "LIBVA_DRIVER_NAME=iHD vainfo 2>/dev/null"
```

---

### Step 7 — Enable Hardware Transcoding in Plex UI

1. Open Plex Web UI: `http://<server-ip>:32400/web`
2. Go to **Settings** → (your server) → **Transcoder**
3. Enable **"Use hardware acceleration when available"**
4. Enable **"Use hardware-accelerated video encoding"**
5. Set **Hardware transcoding device** to `Auto`
6. Click **Save Changes**

---

### Step 8 — Verify Hardware Transcoding

Play any video in Plex and force a transcode by lowering the quality below the source bitrate. Then check the **Now Playing** dashboard.

You should see:
```
Video: 1080p (H.264) (hw)
      → SD (H264) — Transcode (hw)
```

The `(hw)` tag on both lines confirms Quick Sync encode and decode are active.

---

## File Reference

```
servarr/
├── docker-compose.yml     # Plex service with devices + init-hook-app volume
└── init-hook-app          # s6 hook: installs VA-API driver, fixes group memberships
```

### `/etc/udev/rules.d/99-dri-permissions.rules` (on each Proxmox node)
```
KERNEL=="card[0-9]*", SUBSYSTEM=="drm", MODE="0666"
KERNEL=="renderD[0-9]*", SUBSYSTEM=="drm", MODE="0666"
```

### `/etc/pve/lxc/102.conf` additions (on active node)
```
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/renderD128,gid=993
```

---

## Migration Guide

If CT102 is migrated to a different Proxmox node:

### Automatic (no action needed)
- `docker-compose.yml` — travels with the git repo
- `init-hook-app` — travels with the git repo
- Plex settings — stored in `/media/servarr/plex/config` (QNAP volume)
- LXC config `dev0`/`dev1` lines — Proxmox migrates these automatically

### Manual (required on destination node)

**1. Verify udev rule exists** (already done on all 3 nodes):
```bash
cat /etc/udev/rules.d/99-dri-permissions.rules
ls -la /dev/dri/
# Should show crw-rw-rw-
```

**2. Verify LXC config device entries survived migration:**
```bash
grep "dev0\|dev1" /etc/pve/lxc/102.conf
```

If missing, re-add:
```bash
nano /etc/pve/lxc/102.conf
# Add:
# dev0: /dev/dri/card0,gid=44    (use card1 on pve02)
# dev1: /dev/dri/renderD128,gid=993
```

**3. Special case — migrating to pve02:**

pve02 uses `card1` not `card0`. Update the LXC config:
```bash
# On pve02 after migration:
sed -i 's|dev0: /dev/dri/card0|dev0: /dev/dri/card1|' /etc/pve/lxc/102.conf
pct reboot 102
```

> ⚠️ pve02 (Ivy Bridge) does not support HEVC hardware encode/decode. Plex will fall back to software transcoding for H.265 content when hosted on pve02.

---

## Troubleshooting

### `/dev/dri` is empty or missing on Proxmox host
- Check BIOS: ensure Intel iGPU is enabled
- Run `lspci | grep VGA` — if no Intel device shown, iGPU is disabled in BIOS
- Run `lsmod | grep i915` — if empty, load the driver: `modprobe i915`

### Devices show as `nobody:nogroup` inside LXC
- The old `lxc.cgroup2` + `lxc.mount.entry` approach causes this in unprivileged containers
- Use the `dev0`/`dev1` native Proxmox syntax instead (requires Proxmox 8.2+)

### `hotio` user not in `video`/`render` groups
- hotio's `find /dev/dri -type c` returns nothing due to Docker/LXC device type quirk
- The `init-hook-app` script works around this — ensure it's mounted correctly:
  ```bash
  docker exec plex ls -la /etc/s6-overlay/init-hook-app
  docker exec plex id hotio
  ```

### `iHD_drv_video.so` not found inside container
- The `init-hook-app` installs it on first run — check if it ran:
  ```bash
  docker logs plex | grep -i "intel\|vaapi\|driver"
  ```
- If not, recreate the container: `docker compose up -d --force-recreate plex`

### Plex not showing `(hw)` during transcode
1. Confirm hardware acceleration is enabled in Plex UI (Settings → Transcoder)
2. Confirm `hotio` is in `video` and `render` groups: `docker exec plex id hotio`
3. Confirm VA-API works: `docker exec plex bash -c "LIBVA_DRIVER_NAME=iHD vainfo 2>/dev/null"`
4. Check Plex logs: `docker logs plex | grep -i "hardware\|transcode\|vaapi"`

### `vainfo` shows no profiles on pve02
- Ivy Bridge (i7-3770) does not support HEVC — this is expected
- H.264 should still work; if not, check driver installation

---

*Generated from a live setup session on 2026-07-02. All commands verified working on Proxmox VE (Trixie), CT102 Ubuntu 24.04 LXC, hotio/plex (Plex 1.43.2).*
