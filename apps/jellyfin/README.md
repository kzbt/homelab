# Jellyfin

Docker-based Jellyfin media server, running on host networking with Intel iGPU
(VA-API) hardware transcoding.

This `docker-compose.yml` is the verbatim source of truth for the live
`jellyfin` container and is committed unchanged.

## Key choices

- **Image**: `jellyfin/jellyfin:10.11.1` (pinned to a specific release).
- **Networking**: `network_mode: host` — Jellyfin discovers clients and handles
  multicast (e.g. DLNA/SSDP) more reliably on host networking. No ports are
  published explicitly because of this.
- **Runs as** `user: "986:984"` to match the native Jellyfin uid/gid that owns
  `/var/lib/jellyfin`, `/etc/jellyfin`, `/var/cache/jellyfin`, `/var/log/jellyfin`.
  Added to supplementary groups `105` (render) and `1002` (media).
- **GPU transcoding**: `devices: /dev/dri:/dev/dri` plus membership in the
  `render` group (105) gives the container access to `/dev/dri/renderD128`
  (Intel iGPU).
- **Config/data**: the host's native Jellyfin directories are bind-mounted at
  their canonical paths, so no in-container config changes were needed when
  moving from the native install to the container.
- **Media libraries** (`/media/nfs`, `/media/alldebrid`) are bind-mounted with
  `propagation: slave` so NFS/FUSE mounts created on the host *after* the
  container starts remain visible inside the container.

## Host prerequisites

See `../../host/README.md` and `../../host/bootstrap.sh`. In short the host must
have, before bringing this up:

- Groups `jellyfin (984)`, `media (1002)`, `render (105)`, and the host user in
  `media`.
- `/var/lib/jellyfin`, `/etc/jellyfin`, `/var/cache/jellyfin`, `/var/log/jellyfin`
  owned by `986:984` (restored from backup on a rebuild).
- `/dev/dri` present (Intel iGPU + `render` group).
- `/media/nfs` and `/media/alldebrid` mountable (see `../../host/`).

## Run

```bash
docker compose -f apps/jellyfin/docker-compose.yml up -d
```

Because the container uses host networking, Jellyfin is reached on
`http://<host>:8096`.
