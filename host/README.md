# Host setup

This captures everything that lives on the **host OS** (outside the containers)
and must exist before the app stacks in `../apps/` will work. Captured here so a
bare-metal rebuild is repeatable.

Reference system at time of capture: **Fedora Linux 41 (Server Edition)**.

## What's here

| Path | Purpose |
|---|---|
| `bootstrap.sh` | Create Jellyfin user/group (986/984), `media`/`render` groups, data + media dirs, and free port 53 for Blocky. Run first, as root. |
| `filesystems.md` | Disk layout (`/media` xfs) and the `/media/nfs` + `/media/alldebrid` mounts. |
| `systemd/rclone-alldebrid-mount.service` | systemd unit that FUSE-mounts AllDebrid into `/media/alldebrid`. Secret-free. |
| `rclone/` | Reference template + setup instructions for the rclone AllDebrid remote (credentials live off-repo). |

## Order

1. OS install (Fedora Server) + `dnf install docker docker-compose-plugin ffmpeg rclone`.
2. `sudo ./bootstrap.sh`
3. Restore Jellyfin config/data into `/etc/jellyfin`, `/var/lib/jellyfin` (from backup).
4. Set up rclone + enable the mount unit (see `rclone/README.md`).
5. Bring up the app stacks (see `../deploy/`).

## Key facts the stacks depend on

- **Jellyfin runs as uid/gid `986:984`** (set in compose `user:`). The data dirs
  `/var/lib/jellyfin`, `/etc/jellyfin`, `/var/cache/jellyfin`, `/var/log/jellyfin`
  must be owned by `986:984`. `bootstrap.sh` handles this.
- **GPU**: `/dev/dri/renderD128` (Intel iGPU). Jellyfin is added to group
  `render` (105) for VA-API transcoding. Requires the iGPU + drivers on the host.
- **Media groups**: `media` (1002) owns the libraries; both `kiran` and
  `jellyfin` are members, so the container can read `/media/*`.
- **rclone**: the AllDebrid credentials are NOT in this repo — see `rclone/`.
- **Port 53**: `bootstrap.sh` disables `systemd-resolved`'s stub listener so
  the Blocky container can bind it. If your router or LAN clients are
  configured to use this host for DNS, Blocky must be up for name resolution
  to work network-wide.
