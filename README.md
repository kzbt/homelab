# homelab

Kiran's homelab, captured as code so the whole setup is repeatable on a
bare-metal rebuild. Reference system: **Fedora Linux 41 (Server Edition)**.

## What runs

Three Docker containers (plain Docker Compose — no Kubernetes):

| App | Stack | Purpose |
|---|---|---|
| [Jellyfin](apps/jellyfin/) | `apps/jellyfin/docker-compose.yml` | Media server (host networking, Intel iGPU transcoding) |
| [Stremio](apps/stremio/) | `apps/stremio/docker-compose.yml` | `stremio-server` headless backend for Stremio clients |
| [Blocky](apps/blocky/) | `apps/blocky/docker-compose.yml` | DNS-level ad-blocker + resolver for the LAN (binds port 53) |

## Layout

```
docker-compose.yml  # root stack — includes both apps below; `docker compose up -d` here runs everything
apps/        # docker-compose stacks (the source of truth for the live containers)
  jellyfin/
  stremio/
  blocky/
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
sudo host/bootstrap.sh                       # users, groups, dirs, frees port 53
#    + restore /etc/jellyfin, /var/lib/jellyfin from backup
#    + set up rclone (host/rclone/README.md) + enable the mount unit

# 2. apps (root compose file includes all apps/ stacks)
docker compose up -d
```

All three containers (`jellyfin`, `stremio_server`, `blocky`) run under the
single `homelab` Compose project defined by the root `docker-compose.yml`.
Each app's own `apps/*/docker-compose.yml` can still be run standalone with
`-f` if needed, but it will end up under a differently-named project — prefer
the root file for day-to-day use.

## Notes

- The live Jellyfin compose is committed verbatim. The Stremio compose was
  reconstructed from `docker inspect` (the original file had been deleted) — it
  reproduces the running container exactly. See each app's README.
- The `archive/k0s/` directory contains earlier Kubernetes (k0s) manifests that
  were **stubs and never matched the live Docker setup**. Kept for reference only.
- Blocky was previously a native systemd service (`/opt/blocky`); it has been
  fully migrated into `apps/blocky/` and removed from the host.
