#!/usr/bin/env bash
#
# Host bootstrap for the homelab.
#
# Creates the users/groups the Jellyfin container expects (it runs as 986:984),
# sets up supplementary group membership for GPU + media access, and creates the
# data/media directories with correct ownership.
#
# Idempotent: safe to re-run. Run as root.
#
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

MEDIA_USER="${MEDIA_USER:-kiran}"   # your non-root user; added to the `media` group

# --- Groups ---------------------------------------------------------------
# render (105) is normally created by the OS / GPU driver; create if missing.
getent group render   >/dev/null || groupadd -g 105  render
getent group media    >/dev/null || groupadd -g 1002 media
getent group jellyfin >/dev/null || groupadd -g 984  jellyfin

# --- Users ----------------------------------------------------------------
# Native Jellyfin uid/gid (986/984). The container sets `user: "986:984"` to
# match so it can read/write the data dirs.
if ! id -u jellyfin >/dev/null 2>&1; then
  useradd -u 986 -g 984 -d /var/lib/jellyfin -s /usr/sbin/nologin jellyfin
fi

# --- Group membership -----------------------------------------------------
# Mirrors the live system: render:x:105:jellyfin  media:x:1002:kiran,jellyfin
usermod -aG render jellyfin
usermod -aG media  jellyfin
usermod -aG media  "$MEDIA_USER" || true

# --- Jellyfin data dirs (owner 986:984) -----------------------------------
install -d -o 986 -g 984 -m 0750 /var/lib/jellyfin /var/cache/jellyfin /var/log/jellyfin
install -d -o 986 -g 984 -m 0755 /etc/jellyfin
# NOTE: on a rebuild, restore the contents of /etc/jellyfin and /var/lib/jellyfin
# from backup AFTER running this script (so ownership is correct).

# --- Media mountpoints ----------------------------------------------------
install -d -o "$MEDIA_USER" -g media -m 0775 /media/nfs /media/alldebrid

echo
echo "Bootstrap complete."
echo "Next steps:"
echo "  1. Restore Jellyfin config:  /etc/jellyfin, /var/lib/jellyfin (from backup)"
echo "  2. Configure rclone:         see host/rclone/README.md"
echo "  3. Enable rclone mount:      see host/systemd/"
echo "  4. Bring up the stacks:      apps/stremio, then apps/jellyfin  (see deploy/)"
