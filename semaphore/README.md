# Semaphore Playbooks

This directory holds the Ansible playbooks, inventory, and deployment config for
the [Semaphore](https://semaphoreui.com/) instance that automates routine
maintenance across the homelab. Semaphore itself runs as a Docker container on
`docker-lxc` (LXC 112 on `pve01`), defined in `semaphore/docker-compose.yml`.
Semaphore clones this repo fresh on every job run and executes the referenced
playbook via `ansible-playbook`.

## How it fits together

- **Inventory**: `semaphore/inventory/inventory` — static file, five groups:
  `proxmox` (pve02, pve03, pbs, pve-datacenter-manager, pve01 last),
  `pve_cluster` (pve01-03), `lxc` (guest LXCs, for reference: the LXC update
  playbooks reach them with `pct exec` from the nodes, not over SSH),
  `docker` (FQDNs behind the reverse proxy, currently unused by any playbook),
  `hardware` (NAS/switch/gateway, also currently unused by any playbook).
- **Access key**: all jobs connect as `root` over SSH using a single Semaphore
  access key, assigned to the inventory (not per-template). The key must be
  present in `/root/.ssh/authorized_keys` on every host referenced in the
  `proxmox` and `lxc` inventory groups, including `docker-lxc` itself — jobs
  that target `docker-lxc` still connect over SSH like any other host.
- **Templates vs. playbooks**: 6 distinct playbook files, 6 Semaphore
  templates — one template per playbook. See the sections below.
- **Schedule timezone**: `America/Toronto` (`SEMAPHORE_SCHEDULE_TIMEZONE`).
- **Alerting**: every job failure posts to Gotify (`SEMAPHORE_GOTIFY_URL`).

## Playbooks

### `update-apt-packages-pvehosts.yml`
**Template:** `update-apt-packages-pve-hosts` · **Schedule:** daily 03:00 · **Targets:** `proxmox` group (pve02, pve03, pbs, pve-datacenter-manager, then pve01 last)

Updates apt packages one host at a time (`serial: 1`) so the Proxmox/Ceph
cluster is never mid-upgrade on more than one node simultaneously:

0. Fail straight away unless the host in the `[semaphore_host]` group (pve01, where
   Semaphore itself runs in LXC 112) is the last host in `[proxmox]`
1. `apt update` (cache valid 1h)
2. List and display upgradable packages
3. `apt full-upgrade` + autoremove/autoclean
4. Decide whether to reboot: `/var/run/reboot-required` exists, **or** the running
   kernel differs from the one the next boot will use (the pinned kernel if any,
   else the newest in `/boot`; skipped in containers). Proxmox kernel packages never
   create `/var/run/reboot-required`, so before 2026-09-11 this job never rebooted a
   host for a kernel update. If a reboot is needed:
   - refuse to reboot unless `pvecm status` is quorate (cluster nodes only)
   - enable HA maintenance mode on the node (cluster nodes only)
   - reboot and wait for the node to come back (`wait_for_connection`, 600s timeout)
   - poll `pvecm status` until quorate (30 retries / 10s apart), then disable
     HA maintenance mode (6 retries / 10s apart; cluster nodes only). The
     order matters: `ha-manager` needs quorum and SSH is back before corosync
     is. Until 2026-09-19 the disable ran first, failed with "no quorum!" on
     2026-09-15 and left pve02 in maintenance mode for four days. If either
     step fails, the job fails with a message saying the node is still in
     maintenance mode and the command to clear it.
5. After a kernel reboot, fail if the host did not come up on the expected kernel
   (stops the rolling update instead of rebooting that host again on every run)
6. If a reboot happened on a cluster node, poll `ceph status -f json` until
   all PGs are `active+clean`, all OSDs are up and in, and all monitors are in
   quorum (up to 60 retries / 10s apart) before moving to the next host
7. **pve01 (the Semaphore host) is handled differently**, because rebooting it
   in-line would kill this job. It gets the quorum check, then, for a kernel
   update, a check that GRUB's first entry (`GRUB_DEFAULT=0`) is the target kernel
   so it can't end up rebooting every night. Then `shutdown -r +3`, so the job
   finishes first. There is no HA maintenance mode and nothing checks pve01 or Ceph
   after that reboot; the next run's kernel check confirms the kernel. While pve01
   reboots, its guests (pihole, NPM, the docker LXC with Semaphore and Plex, immich,
   Home Assistant, homepage, homelabhero) are down for a few minutes.

**Why step 6 checks Ceph's state and not `ceph health` (changed 2026-09-11):**
it used to accept `HEALTH_OK` or `HEALTH_WARN`. `HEALTH_WARN` is also what
Ceph reports while PGs are still degraded right after the rebooted node's OSD
rejoins, so the next node could reboot mid-recovery (two OSDs down freezes
I/O on a 3-node, `min_size=2` pool). Separately, since Ceph 20.2.4 the health
status can read `HEALTH_ERR` for reasons that do not affect data (the
`AUTH_INSECURE_*` key-type checks), which would block the job. See the
homelab-ops runbook
`runbooks/2026-09-10-rolling-upgrade-kernel-ceph-gpu-card-renumber.md`.

### `update-apt-packages-lxcs.yml`
**Template:** `update-apt-packages-lxcs` · **Schedule:** daily 02:30 · **Targets:** `pve_cluster` (pve01-03), then every running guest LXC on each node via `pct exec`

Upgrades the OS packages inside the guest containers. Before 2026-09-19 nothing
did: `update-apt-packages-pve-hosts` only covers the Proxmox hosts, PBS and PDM.

1. List the running containers on the node (`pct list`); stopped ones are left alone
2. Drop the CTIDs in `lxc_os_update_exclude` (`semaphore/vars/lxc_updates.yml`):
   - 110 PDM: already upgraded by the 03:00 host job
   - 112 docker: runs Semaphore; a docker-ce upgrade restarts dockerd and kills
     the job doing the upgrade. Update it by hand.
3. For each remaining Debian/Ubuntu container: `apt-get update`, `dist-upgrade`
   (keeping existing config files), `autoremove`, `autoclean`
4. Print one summary line per container (packages upgraded, and whether
   `/var/run/reboot-required` exists). **Containers are never rebooted**; restart
   the ones flagged when convenient.
5. Fail the job (Gotify alert) if any container's upgrade failed

The three nodes run in parallel, so a failure on one doesn't stop the others.
A new container is picked up automatically; to leave one out, add its CTID to
`lxc_os_update_exclude`. Runs at 02:30 so it finishes before the 03:00 host
job starts rebooting nodes.

### `update-lxc-apps.yml`
**Template:** `update-lxc-apps` · **Schedule:** weekly, Saturday 10:00 · **Targets:** `pve_cluster` (pve01-03), one node at a time

Updates the apps themselves by running each container's community-scripts
`update` command, using the upstream
[PVE LXC Apps Updater](https://github.com/community-scripts/ProxmoxVE/blob/main/tools/pve/update-apps.sh)
(`tools/pve/update-apps.sh`) on each node:

1. Pick the running containers on the node that are in `lxc_app_update_allow`
   (`semaphore/vars/lxc_updates.yml`): 100 pihole, 101 nginxproxymanager,
   102 stirling-pdf, 103 homepage, 105 homebridge, 106 prometheus, 113 immich
2. Download `update-apps.sh` to `/root/update-apps.sh` on the node and run it
   unattended. For each container it:
   - backs it up with `vzdump` to `pbs-nvme` (`lxc_app_update_backup_storage`)
   - runs `export PHS_SILENT=1; update` inside it
   - if the update exits non-zero, runs `pct restore --force` from that backup
     and starts it again
3. Print the updater's summary table (also in
   `/usr/local/community-scripts/update_apps/<timestamp>.log` on the node)
4. Check every container it touched is still running
5. Prune old VS Code Remote-SSH server builds (`~/.vscode-server/cli/servers/Stable-*`
   for root and /home users) in **every** running container on the node, not
   just the allowlist: keep the newest build and any build a running process
   uses, delete the rest. Each VS Code update leaves a ~700MB build behind
   (LXC 103 hit 83% disk from five). Skip a container with
   `lxc_vscode_prune_exclude`. A prune error is printed but doesn't fail the job.
6. A final play on localhost fails the job (Gotify alert) if any container
   was FAILED, RESTORED or ERROR, is not running, or a node didn't finish

Deliberately **not** in the allowlist: 110 PDM (apt-managed, host job), 112
docker (runs Semaphore), 114 homelabhero (not a community-scripts container),
115 homeassistant (HA releases break integrations; update it by hand).
Containers are never rebooted (`var_auto_reboot=no`). SKIPPED results (an app
that needs interactive mode, is under-provisioned, or is low on disk) don't
fail the job but show in the summary.

Things to know:
- The updater and each app's `ct/<app>.sh` are fetched from GitHub main on
  every run, so the job runs whatever upstream holds that day. It runs weekly,
  in the daytime, so someone is around if an update breaks an app.
- `pct restore --force` replaces the whole container, including its
  snapshots (100, 105 and 106 still have `pre-debian13-upgrade`). None of the
  allowlisted containers have extra mount points, so the backup covers
  everything; check that before adding one that does.
- Telemetry to community-scripts is turned off with `DIAGNOSTICS=no`.
- **Dry run:** run the template with extra vars `{"lxc_app_update_dry_run": true}`
  to list installed vs. latest versions without backing up or changing anything.
  The VS Code prune step then only lists what it would delete (`WOULD PRUNE`).
  Apps that don't use `check_for_gh_release` (pihole, homebridge) show "skipping"
  there; that only means the dry run can't compare their versions.

### `update-docker-services.yml`
**Template:** `update-docker-services` · **Schedule:** daily 01:20 · **Targets:** `docker-lxc` only

Single consolidated job that pulls + (re)starts every docker-compose stack
under `/root/docker_services/` on `docker-lxc`. The list of stacks to manage
lives in `semaphore/vars/docker_services.yml`, loaded via `vars_files` — **not**
a per-template Semaphore Environment. To bring a new stack under automatic
updates, add its folder name to that file, commit, and push; no Semaphore UI
changes needed.

```yaml
- hosts: docker-lxc
  vars_files:
    - ../vars/docker_services.yml
  tasks:
    - name: Pull latest images for each stack
      shell: docker compose -f {{ item }}/docker-compose.yml pull
      loop: "{{ docker_service_dirs }}"

    - name: Start each stack
      shell: docker compose -f {{ item }}/docker-compose.yml up -d
      loop: "{{ docker_service_dirs }}"
```

This is a `docker compose pull && docker compose up -d` per stack, run for
every entry in `docker_service_dirs` — pulls the latest image tag and
recreates the container if it changed. No image pinning or rollback;
whatever tag the compose file specifies (commonly `latest`) is what gets
deployed.

Current entries in `docker_service_dirs` (`semaphore/vars/docker_services.yml`):
authentik, changedetection, dozzle, gotify, grafana, influxdb, it-tools,
scrypted, servarr, speedtest-tracker, wud.

Deliberately **not** in this list: `semaphore` itself (updating semaphore's
own containers mid-run risks killing the job that's doing the updating —
it's covered by `wud` watching for new images instead) and `portainer`
(updated separately via the Proxmox community helper-script, not compose
pull).

**History:** prior to 2026-07-18 this was 10 separate Semaphore templates,
each pointed at the same playbook with a different `service_dir` supplied via
a per-template Environment, staggered 5 minutes apart (01:00-01:45) to avoid
saturating disk/network I/O on `docker-lxc`. Consolidated into one template
and one schedule once the loop-over-a-list approach made staggering
unnecessary — the shell tasks run sequentially within the single job anyway.

### `maintenance-dockercleanup.yml`
**Template:** `maintenance-dockercleanup` · **Schedule:** daily 02:00 · **Targets:** `docker-lxc`

Reclaims disk space after the nightly image pulls (runs at 02:00, after the
01:20 pull/up job above, before the 03:00 PVE apt run):

1. `docker image prune -a -f` removes every image no container uses
   (including old tags left behind by the pulls above)
2. `docker builder prune -a -f` removes the build cache
3. `docker network prune -f` removes unused networks

The `changed_when` on each task only reports a change if something was
removed, so a clean run shows `ok` rather than `changed`.

**Stopped containers and volumes are never pruned (changed 2026-09-12).**
Step 2 used to be `docker system prune --all -f`, which also deletes stopped
containers. On 2026-09-12 the 01:20 update job left five servarr containers
created but not started (gluetun wasn't healthy in time), and the 02:00 run
deleted them, and then their images. Sonarr, radarr, prowlarr, bazarr and
flaresolverr were down for about 10 hours until someone ran
`docker compose up -d --no-recreate`. A stopped container is now left in
place, which also keeps its image from being pruned.

### `backup-servarr-configs.yml`
**Template:** `backup-servarr-config-giles` · **Schedule:** none (manual trigger only) · **Targets:** `docker-lxc`

Backs up the arr stack's config directories to a QNAP NAS share mounted on
`docker-lxc`:

- `src_dir`: `/media/servarr/` (each arr app's config, e.g.
  `/media/servarr/sonarr/config/`)
- `dest_dir`: `/mnt/qnap/servarr/_applications/`

Runs as the local `servarr` Linux user on `docker-lxc` (`become_user: servarr`,
`ansible_become_method: su`) so the copied files keep servarr's ownership
rather than root's. The `synchronize` task uses `delegate_to: "{{ inventory_hostname }}"`
so rsync executes entirely on `docker-lxc` (both source and destination are
local to that host) rather than treating `dest_dir` as reachable from wherever
`ansible-playbook` itself runs.

Excludes from the sync (`rsync_opts`):
- `*.log` — service log files, not meaningful config state
- `*.db-wal`, `*.db-shm` — SQLite WAL/checkpoint sidecar files for apps like
  Sonarr's `logs.db`; these appear and vanish while the app is live, so
  rsync can hit "file has vanished" mid-copy if they aren't excluded

#### Requirements on `docker-lxc` for this playbook specifically
- `rsync` package installed (not present by default on a minimal Debian LXC)
- Local `servarr` Linux user must exist with a UID that has read access to
  everything under `/media/servarr/`
- `/mnt/qnap/servarr/_applications/` must be a live mount (task only creates
  the final path component, not the mount itself — if the QNAP share isn't
  mounted this will silently write into local disk instead)

## History / gotchas found during the 2026-07-09 outage

All 13 jobs were failing. Root causes, in the order they were found and fixed:

1. **SSH key rejected** on pve01-03 and pbs — Semaphore's configured access
   key ("mac-osx") was no longer in any host's `authorized_keys`. Replaced
   with a dedicated key (Semaphore access key ID 3, `homelabhero-pve-docker`)
   deployed to all four hosts plus `docker-lxc` itself.
2. **Stale inventory IP** — `docker-lxc` pointed at `192.168.10.71` (dead);
   corrected to `192.168.10.41`.
3. **`connection: local` bug** in `backup-servarr-configs.yml` — forced the
   play to run inside the Semaphore container (which has no `servarr` user or
   `/media`/`/mnt/qnap` mounts) instead of connecting to `docker-lxc` over
   SSH. Removed.
4. **Invalid `remote_src` parameter** on the `synchronize` task — not a real
   parameter of that module. Replaced with `delegate_to: "{{ inventory_hostname }}"`,
   the documented pattern for a same-host copy.
5. **`rsync` missing** on `docker-lxc` — installed via apt.
6. **Unreadable/vanishing files** during the actual rsync — see excludes
   above.

Also investigated but **not** changed: the Semaphore container's bundled
`ansible.posix` collection (2.1.0) throws cosmetic deprecation warnings on
every `synchronize` run (internal Ansible import paths slated for removal in
ansible-core 2.24, not yet). Attempted to upgrade to 2.2.1; the container's
actual task-runner process only resolves the collection copy vendored inside
its Python venv (`.../venv/lib/python3.12/site-packages/ansible_collections/`),
not the one `ansible-galaxy collection install` writes to
(`~/.ansible/collections/`), so the upgrade never took effect and briefly
broke the playbook when tested. Reverted. Warnings are harmless; revisit only
if someone wants to patch the venv-bundled copy directly.
