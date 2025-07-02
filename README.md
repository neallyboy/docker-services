# Docker Services

This repository contains multiple services configured to run using Docker. Below is a description of each service, its purpose, and instructions on how to start and stop them.

---

## Services Overview

Each service has its own `.env` file for configuration. Ensure these files are properly set up before running the services. The `.env` files are excluded from version control (`.gitignore`) for security reasons. Make sure to back them up securely.

---

### 1. **Authentik**
- **Purpose**: Identity provider for managing authentication and authorization.
- **Start Command**:
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
- **Start Command**:
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
- **Start Command**:
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
- **Start Command**:
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
- **Start Command**:
  ```bash
  docker compose -f servarr/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f servarr/docker-compose.yml down
  ```

---

### 6. **Speedtest Tracker**
- **Purpose**: Monitors and logs internet speed tests.
- **Start Command**:
  ```bash
  docker compose -f speedtest-tracker/docker-compose.yml up -d
  ```
- **Stop Command**:
  ```bash
  docker compose -f speedtest-tracker/docker-compose.yml down
  ```

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