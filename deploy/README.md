# Deploy / rebuild runbook

Ordered steps to bring the homelab back up on a fresh Fedora Server install.

## 0. Base OS

- Fedora Server 41 (or compatible).
- Packages: `docker` + `docker-compose-plugin`, `ffmpeg`, `rclone`, `fuse`.
  ```bash
  sudo dnf install -y docker docker-compose-plugin ffmpeg rclone fuse
  sudo systemctl enable --now docker
  ```
- Add your user to the `docker` group if desired: `sudo usermod -aG docker kiran`.

## 1. Host prerequisites

```bash
sudo host/bootstrap.sh          # creates jellyfin(986:984), media(1002), render(105); data + media dirs
```

Then:

- **Restore Jellyfin config/data** from backup onto `/etc/jellyfin` and
  `/var/lib/jellyfin` (owner must be `986:984`).
- **Confirm GPU**: `ls -l /dev/dri/renderD128` exists and Jellyfin is in group
  `render` (handled by bootstrap).

## 2. AllDebrid mount

```bash
# create the rclone remote interactively (credentials not in repo)
rclone config                       # see host/rclone/README.md
rclone lsd alldebrid:magnets        # verify

# install + enable the FUSE mount unit
sudo install -m0644 host/systemd/rclone-alldebrid-mount.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rclone-alldebrid-mount.service
ls /media/alldebrid                 # should list debrid content
```

## 3. (Optional) NFS library

`/media/nfs` is an external library; mount your NFS share there if used:

```bash
sudo mount -t nfs <server>:/export/media /media/nfs
```

## 4. App stacks

Clone this repo to e.g. `~/homelab`, then:

```bash
docker compose -f apps/stremio/docker-compose.yml  up -d   # http://<host>:11470
docker compose -f apps/jellyfin/docker-compose.yml up -d   # http://<host>:8096
```

> The live containers were launched from different paths
> (`~/jellyfin/docker-compose.yml` for Jellyfin, and a now-deleted
> `~/source/homelab/docker-compose.yaml` for Stremio). This repo is the
> consolidated source of truth going forward; the live containers were left
> untouched.

## 5. Verify

```bash
docker ps                                  # jellyfin + stremio_server up
curl -sI http://localhost:8096  | head -1  # Jellyfin web
curl -sI http://localhost:11470 | head -1  # Stremio server
mount | grep -E 'alldebrid|nfs'            # media mounts present
```
