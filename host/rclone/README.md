# rclone (AllDebrid mount)

The `/media/alldebrid` FUSE mount is provided by an rclone WebDAV remote named
`alldebrid`, mounted read-only by a systemd unit. The Stremio/Jellyfin stacks
consume this directory for debrid-sourced media.

## Components

- `../systemd/rclone-alldebrid-mount.service` — the systemd unit (secret-free).
- `rclone.conf.template` — reference shape of the remote definition.

## The real config is NOT in this repo

`~/.config/rclone/rclone.conf` contains the AllDebrid username and an
rclone-obfuscated password, so it is excluded by the top-level `.gitignore`.

## Restoring on a rebuild

1. Install rclone: `dnf install rclone`.
2. Recreate the remote. The recommended way is interactive:

   ```bash
   rclone config
   # -> n (new remote), name: alldebrid, choose the WebDAV storage,
   #    enter the AllDebrid URL/credentials when prompted.
   ```

   This writes `~/.config/rclone/rclone.conf` with the password obfuscated.

3. Verify: `rclone lsd alldebrid:magnets`.

4. Install + enable the mount unit:

   ```bash
   sudo install -m 0644 host/systemd/rclone-alldebrid-mount.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now rclone-alldebrid-mount.service
   ```

5. Confirm the mount: `mount | grep alldebrid` and `ls /media/alldebrid`.

## Notes

- The unit runs as user `kiran` and mounts with `--uid 1000 --gid 1002`
  (`kiran:media`) and `--allow-other`, so the `media` group (including the
  Jellyfin container) can read the tree.
- It is read-only with `--vfs-cache-mode minimal` and a 10s dir-cache — tuned
  for streaming from AllDebrid.
