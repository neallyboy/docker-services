# Docker Services

This repository contains multiple services configured to run using Docker. Below is a description of each service, its purpose, and instructions on how to start and stop them.

---

## Run or Stop All Services

### Run All Services
To start all services defined in this repository:
```bash
docker compose -f authentik/docker-compose.yml -f changedetection/docker-compose.yml -f dozzle/docker-compose.yml -f gotify/docker-compose.yml -f grafana/docker-compose.yml -f influxdb/docker-compose.yml -f it-tools/docker-compose.yml -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml -f scrypted/docker-compose.yml -f semaphore/docker-compose.yml -f servarr/docker-compose.yml -f speedtest-tracker/docker-compose.yml -f uptime-kuma/docker-compose.yml -f wud/docker-compose.yml up -d
```

### Stop All Services
To stop all services:
```bash
docker compose -f authentik/docker-compose.yml -f changedetection/docker-compose.yml -f dozzle/docker-compose.yml -f gotify/docker-compose.yml -f grafana/docker-compose.yml -f influxdb/docker-compose.yml -f it-tools/docker-compose.yml -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml -f scrypted/docker-compose.yml -f semaphore/docker-compose.yml -f servarr/docker-compose.yml -f speedtest-tracker/docker-compose.yml -f uptime-kuma/docker-compose.yml -f wud/docker-compose.yml down
```

### Update All Services
To pull the latest images for all services:
```bash
docker compose -f authentik/docker-compose.yml -f changedetection/docker-compose.yml -f dozzle/docker-compose.yml -f gotify/docker-compose.yml -f grafana/docker-compose.yml -f influxdb/docker-compose.yml -f it-tools/docker-compose.yml -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml -f scrypted/docker-compose.yml -f semaphore/docker-compose.yml -f servarr/docker-compose.yml -f speedtest-tracker/docker-compose.yml -f uptime-kuma/docker-compose.yml -f wud/docker-compose.yml pull
```

---

## Services Overview

Each service has its own `.env` file for configuration. Ensure these files are properly set up before running the services. The `.env` files are excluded from version control (`.gitignore`) for security reasons. Make sure to back them up securely.

---

### 1. **Authentik**
- **Purpose**: Identity provider for managing authentication and authorization.
- **Update Command**:
  ```bash
  docker compose -f authentik/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f authentik/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f authentik/docker-compose.yml down
  ```

---

### 2. **Grafana**
- **Purpose**: Monitoring and visualization tool for metrics and logs.
- **Update Command**:
  ```bash
  docker compose -f grafana/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f grafana/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f grafana/docker-compose.yml down
  ```

---

### 3. **InfluxDB**
- **Purpose**: Time-series database for storing metrics and events.
- **Update Command**:
  ```bash
  docker compose -f influxdb/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f influxdb/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f influxdb/docker-compose.yml down
  ```

---

### 4. **IT Tools**
- **Purpose**: Collection of tools for IT management and troubleshooting.
- **Update Command**:
  ```bash
  docker compose -f it-tools/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f it-tools/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f it-tools/docker-compose.yml down
  ```

---

### 5. **Servarr**
- **Purpose**: Suite of tools for managing media libraries (e.g., Sonarr, Radarr).
- **Update Command**:
  ```bash
  docker compose -f servarr/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f servarr/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f servarr/docker-compose.yml down
  ```
- **No VPN (since 2026-09-13)**: the stack is usenet-only, so radarr, sonarr, prowlarr
  and bazarr run on the normal `servarr_default` network with their own ports, as the
  Servarr wiki and TRaSH Guides recommend. gluetun, flaresolverr and the
  `servarr-reconcile.service` boot workaround were removed with it. Apps reach each
  other by container name (`http://radarr:7878`, `http://sabnzbd:8081`, and so on).
- **Plex transcodes** go to a 4 GB tmpfs at `/transcode` (Plex setting "Transcoder
  temporary directory" = `/transcode`), not the Ceph rootfs.

---

### 6. **Speedtest Tracker**
- **Purpose**: Monitors and logs internet speed tests.
- **Update Command**:
  ```bash
  docker compose -f speedtest-tracker/docker-compose.yml -f uptime-kuma/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f speedtest-tracker/docker-compose.yml -f uptime-kuma/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f speedtest-tracker/docker-compose.yml -f uptime-kuma/docker-compose.yml down
  ```

---

### 7. **Changedetection**
- **Purpose**: Monitors web pages for changes and sends alerts.
- **Update Command**:
  ```bash
  docker compose -f changedetection/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f changedetection/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f changedetection/docker-compose.yml down
  ```

---

### 8. **Dozzle**
- **Purpose**: Real-time Docker container log viewer.
- **Update Command**:
  ```bash
  docker compose -f dozzle/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f dozzle/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f dozzle/docker-compose.yml down
  ```

---

### 9. **Gotify**
- **Purpose**: Self-hosted push notification server.
- **Update Command**:
  ```bash
  docker compose -f gotify/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f gotify/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f gotify/docker-compose.yml down
  ```

---

### 10. **Semaphore**
- **Purpose**: Web UI for running Ansible automation tasks.
- **Update Command**:
  ```bash
  docker compose -f semaphore/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f semaphore/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f semaphore/docker-compose.yml down
  ```

---

### 11. **WUD (What's Up Docker)**
- **Purpose**: Tracks Docker image updates and can trigger update workflows.
- **Update Command**:
  ```bash
  docker compose -f wud/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f wud/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f wud/docker-compose.yml down
  ```

### 12. **Scrypted**
- **Purpose**: Camera hub. Pulls the Nest cameras from Google Device Access and
  publishes them to Apple Home (HomeKit) and as RTSP rebroadcast streams that
  Home Assistant's Generic Camera entries use.
- **Update Command**:
  ```bash
  docker compose -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml -f scrypted/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml -f scrypted/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml -f scrypted/docker-compose.yml down
  ```
- **Host networking**: the container uses `network_mode: host` (HomeKit needs mDNS),
  so the UI is on https://192.168.10.41:10443 and http://192.168.10.41:11080.
  RTSP rebroadcast ports are set per camera in Scrypted and land on the LXC's IP.
- **State** (plugins and `scrypted.db`) lives in `scrypted/volume/`, which is
  gitignored. Back it up: losing it means re-pairing every camera in the Home app.
- Updated nightly by the Semaphore `update-docker-services` job. A new image
  recreates the container, so cameras drop out of Apple Home for a minute or two.

---

### 13. **Scrutiny**
- **Purpose**: Hard drive and SSD health (S.M.A.R.T.) dashboard for the Proxmox nodes. This is the web UI and API
  only (`http://192.168.10.41:8080`). The data comes from `scrutiny-collector-metrics` on pve01, pve02 and pve03,
  run every 6 hours by the `scrutiny-collector.timer` systemd timer. Metrics are stored in the `influxdb2` container
  under the `scrutiny` org, so the container joins the `influxdb_default` network.
- **Setup**: `.env` needs `SCRUTINY_INFLUXDB_TOKEN`, an all-access token for the `scrutiny` org only:
  ```bash
  docker exec influxdb2 influx org create -n scrutiny
  docker exec influxdb2 influx auth create --org scrutiny --all-access --description scrutiny-web
  ```
- **Update Command**:
  ```bash
  docker compose -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f pulse/docker-compose.yml -f scrutiny/docker-compose.yml down
  ```
- Updated nightly by the Semaphore `update-docker-services` job. The `v0.9-web` tag only moves on patch releases;
  a minor or major upgrade is a deliberate tag change here. The collector binaries on the nodes are updated by hand.

---

### 14. **Pulse**
- **Purpose**: Proxmox VE and PBS monitoring with alerting: node/guest health, storage, backup age, and per-guest
  thresholds. Complements PDM (which manages) and Grafana (which charts history). `http://192.168.10.41:7655`.
- **Setup**: open the UI, complete the bootstrap-token first run, then Settings > Nodes and run the generated setup
  script on a cluster node. That script creates the read-only Proxmox monitoring user and token, so no Proxmox
  credentials are stored in this repo.
- **Update Command**:
  ```bash
  docker compose -f pulse/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f pulse/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f pulse/docker-compose.yml down
  ```
- Pinned to a stable tag; upstream also ships `-beta` tags, which the `wud.tag.include` label filters out.

---

### 15. **Uptime Kuma**
- **Purpose**: Uptime and latency checks with their own notifications and history. `http://192.168.10.41:3011`
  (host port 3011 because semaphore already uses 3001).
- **Setup**: create the admin account on first open, add monitors **by IP:port** (every `*.lan.digitalflex.ca` name
  resolves to NPM, so a name-based check only tests NPM), add the Gotify notification, and create a status page if
  you want the Homepage widget (it reads a status page slug).
- **Update Command**:
  ```bash
  docker compose -f uptime-kuma/docker-compose.yml pull
  ```
- **Start Command**:
  The start command can be performed after the update command. The containers will be re-created using the latest local container
  ```bash
  docker compose -f uptime-kuma/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f uptime-kuma/docker-compose.yml down
  ```

---

## Semaphore playbooks

`semaphore/playbooks/` holds the Ansible that Semaphore runs (from its own
clone of this repo, so a push is live on the next run). Templates and
schedules are created by hand in the Semaphore UI.

- `update-scrutiny-collector.yml` (new 2026-09-19, suggested schedule: weekly,
  alongside `update-lxc-apps`): updates `/opt/scrutiny/bin/scrutiny-collector-metrics`
  on pve01-03. The collector is a GitHub release binary, so no package manager
  updates it. The job compares the installed `--version` with the latest
  release, verifies the download against the sha256 digest GitHub reports for
  that asset, installs it, then runs the collector once to prove the new build
  works. Dry run: extra var `scrutiny_collector_check_only=true`.

---

## General Instructions

### Prerequisites
- Ensure Docker is installed on your system.
- Use `docker compose` (not `docker-compose`) for managing services.

### Viewing Logs
To view logs for a specific service:
```bash
docker compose logs <service-name>
```

### Docker Cleanup (Prune)
Use prune commands to clean up unused Docker resources.

- Prune unused data and volumes in one command:
  ```bash
  docker system prune --volumes
  ```

- Prune unused data (stopped containers, unused networks, dangling images, and build cache):
  ```bash
  docker system prune
  ```

- Prune everything above including unused images, without confirmation:
  ```bash
  docker system prune -a --volumes -f
  ```

- Prune unused volumes:
  ```bash
  docker volume prune
  ```

- Prune unused volumes without confirmation:
  ```bash
  docker volume prune -f
  ```

Be careful: prune commands permanently remove unused resources.