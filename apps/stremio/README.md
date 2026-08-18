# Stremio (stremio-server)

Docker-based `stremio-server`, the headless backend that Stremio clients connect
to. This compose file was **reconstructed from `docker inspect`** of the live
`stremio_server` container because the original compose file
(`~/source/homelab/docker-compose.yaml`) had been deleted.

## Key choices

- **Image**: `stremio/server:latest`, server version **4.20.14** (image built
  2025-11-25). Pin by digest for strict reproducibility — see the comment at the
  top of `docker-compose.yml`.
- **Ports**: `11470` and `12470` published to the host.
- **Data dir**: host `/home/kiran/stremio` is bind-mounted to
  `/root/.stremio-server`. This holds `server-settings.json`, `localFiles`,
  `localFilesMeta`, and the `stremio-cache/` directory.
- **ffmpeg**: the container bind-mounts the **host** `/bin/ffmpeg` and
  `/bin/ffprobe` and points `FFMPEG_BIN`/`FFPROBE_BIN` at them. The host must
  therefore have ffmpeg installed (on this Fedora 41 host: `ffmpeg-7.1.2`).
- **Network**: a named bridge network `homelab` (functionally irrelevant — all
  client access is via the published host ports).
- **Casting**: disabled (`CASTING_DISABLED=1`).

## Files in this folder

- `docker-compose.yml` — the stack definition (source of truth).
- `server-settings.json` — canonical server tuning (the live copy in the data
  dir is the same). On deploy, copy it into the bind-mounted data dir
  (`/home/kiran/stremio/`) before (or instead of) starting the container.

## What is NOT committed

- `stremio-cache/` — runtime cache (transient, owned by root, large). Excluded
  via the top-level `.gitignore`.
- `localFiles`, `localFilesMeta` — empty runtime files.

## Host prerequisites

- ffmpeg/ffprobe on the host (`dnf install ffmpeg`).
- `/home/kiran/stremio` existing and containing the desired `server-settings.json`.

## Run

```bash
docker compose -f apps/stremio/docker-compose.yml up -d
```

Clients point at `http://<host>:11470`.
