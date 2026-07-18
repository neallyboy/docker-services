# Semaphore Playbooks

This directory holds the Ansible playbooks, inventory, and deployment config for
the [Semaphore](https://semaphoreui.com/) instance that automates routine
maintenance across the homelab. Semaphore itself runs as a Docker container on
`docker-lxc` (LXC 112 on `pve01`), defined in `semaphore/docker-compose.yml`.
Semaphore clones this repo fresh on every job run and executes the referenced
playbook via `ansible-playbook`.

## How it fits together

- **Inventory**: `semaphore/inventory/inventory` — static file, four groups:
  `proxmox` (pve01-03, pbs), `lxc` (per-container hosts including `docker-lxc`),
  `docker` (FQDNs behind the reverse proxy, currently unused by any playbook),
  `hardware` (NAS/switch/gateway, also currently unused by any playbook).
- **Access key**: all jobs connect as `root` over SSH using a single Semaphore
  access key, assigned to the inventory (not per-template). The key must be
  present in `/root/.ssh/authorized_keys` on every host referenced in the
  `proxmox` and `lxc` inventory groups, including `docker-lxc` itself — jobs
  that target `docker-lxc` still connect over SSH like any other host.
- **Templates vs. playbooks**: 4 distinct playbook files, 4 Semaphore
  templates — one template per playbook. See the table below.
- **Schedule timezone**: `America/Toronto` (`SEMAPHORE_SCHEDULE_TIMEZONE`).
- **Alerting**: every job failure posts to Gotify (`SEMAPHORE_GOTIFY_URL`).

## Playbooks

### `update-apt-packages-pvehosts.yml`
**Template:** `update-apt-packages-pve-hosts` · **Schedule:** daily 03:00 · **Targets:** `proxmox` group (pve01, pve02, pve03, pbs)

Updates apt packages one host at a time (`serial: 1`) so the Proxmox/Ceph
cluster is never mid-upgrade on more than one node simultaneously:

1. `apt update` (cache valid 1h)
2. List and display upgradable packages
3. `apt full-upgrade` + autoremove/autoclean
4. Check `/var/run/reboot-required`; if present, reboot and wait for the node
   to come back (`wait_for_connection`, 600s timeout)
5. If a reboot happened, poll `ceph health` until `HEALTH_OK` or `HEALTH_WARN`
   (up to 30 retries / 10s apart) before moving to the next host

**Note:** the `when` condition on the final Ceph-health task —
`inventory_hostname == groups['proxmox'][-1] or inventory_hostname != groups['proxmox'][-1]`
— is always true (it's a tautology covering both branches of its own
comparison), so in practice the clause does nothing beyond the
`reboot_required_file.stat.exists` check already ANDed with it. Looks like a
leftover from an attempt to only wait for Ceph health after the last host in
the group. Not fixed as part of this pass since it's harmless (equivalent to
just checking reboot-required) — flagging for whoever touches this playbook
next.

### `update-docker-services.yml`
**Template:** `update-docker-services` · **Schedule:** daily 01:00 · **Targets:** `docker-lxc` only

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
servarr, speedtest-tracker, wud.

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
01:00 pull/up job above, before the 03:00 PVE apt run):

1. `docker image prune -a -f` — removes all images not referenced by a
   running container (including old tags left behind by the pulls above)
2. `docker system prune --volumes --all -f` — also removes stopped
   containers, unused networks, build cache, **and unused volumes**

The `changed_when` on both tasks only reports a change if reclaimed space is
non-zero, so a clean run shows `ok` rather than `changed`.

**Caution:** `--volumes` on the second prune will delete any Docker volume
not currently attached to a running container. Compose stacks that store
state in named volumes are safe only as long as their containers are running
when this job fires nightly; a stack that's manually stopped for
maintenance risks losing its volume the next time this job runs.

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
