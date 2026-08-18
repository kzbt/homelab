# Filesystems & mounts

## Local disks (from `/etc/fstab`)

| Mountpoint | FS | Source |
|---|---|---|
| `/` | xfs | `UUID=2d001867-…` |
| `/boot` | xfs | `UUID=504f7e71-…` |
| `/boot/efi` | vfat | `UUID=7755-BFA1` |
| `/home` | xfs | `UUID=1e33685b-…` |
| `/media` | xfs | `UUID=6e76f8ef-…` |

`/media` is its own xfs disk — the media libraries live here.

## Media library mounts

### `/media/nfs`  — NFS library (currently disconnected)

A directory of `movies/` and `shows/`. It is **not currently mounted** (no active
NFS mount, no fstab entry, no autofs unit) at time of capture. Treat this as an
**external/optional** library: on a rebuild, mount your NFS share here, e.g.

```bash
sudo mount -t nfs <nfs-server>:/export/media /media/nfs
# or add an /etc/fstab entry.
```

Jellyfin bind-mounts `/media/nfs` with `propagation: slave`, so an NFS mount made
on the host *after* the container starts remains visible inside the container.

### `/media/alldebrid`  — rclone FUSE mount (AllDebrid)

Provided by `systemd/rclone-alldebrid-mount.service` (see `rclone/README.md`).
Read-only WebDAV remote `alldebrid:magnets`, mounted as user `kiran` with
`uid 1000:gid 1002` (kiran:media) and `--allow-other`.

Both `/media/nfs` and `/media/alldebrid` are pre-created by `bootstrap.sh` with
ownership `kiran:media`, mode `0775`.
