# homelab

Kiran's homelab, captured as code so the whole setup is repeatable on a
bare-metal rebuild. Reference system: **Fedora Linux 41 (Server Edition)**.

## What runs

Two Docker containers (plain Docker Compose — no Kubernetes):

| App | Stack | Purpose |
|---|---|---|
| [Jellyfin](apps/jellyfin/) | `apps/jellyfin/docker-compose.yml` | Media server (host networking, Intel iGPU transcoding) |
| [Stremio](apps/stremio/) | `apps/stremio/docker-compose.yml` | `stremio-server` headless backend for Stremio clients |

## Layout

```
apps/        # docker-compose stacks (the source of truth for the live containers)
  jellyfin/
  stremio/
host/        # host-OS prerequisites: users/groups, disks, mounts, systemd
  bootstrap.sh
  filesystems.md
  systemd/   # rclone-alldebrid-mount.service
  rclone/    # rclone.conf.template (credentials are NOT committed)
deploy/      # ordered runbook for a full rebuild
archive/     # older/experimental approaches kept for reference (not live)
```

## Secrets

There is exactly one secret: the **AllDebrid rclone credentials**
(`~/.config/rclone/rclone.conf`). It is deliberately **not** committed; only a
redacted template lives in `host/rclone/`. See `host/rclone/README.md` to
restore it on a rebuild.

## Quick rebuild (summary)

Full detail in `deploy/`. In short:

```bash
# 1. host
sudo host/bootstrap.sh                       # users, groups, dirs
#    + restore /etc/jellyfin, /var/lib/jellyfin from backup
#    + set up rclone (host/rclone/README.md) + enable the mount unit

# 2. apps
docker compose -f apps/stremio/docker-compose.yml  up -d
docker compose -f apps/jellyfin/docker-compose.yml up -d
```

## Notes

- The live Jellyfin compose is committed verbatim. The Stremio compose was
  reconstructed from `docker inspect` (the original file had been deleted) — it
  reproduces the running container exactly. See each app's README.
- The `archive/k0s/` directory contains earlier Kubernetes (k0s) manifests that
  were **stubs and never matched the live Docker setup**. Kept for reference only.
