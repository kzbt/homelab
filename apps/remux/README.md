# Remux

[Remux](https://github.com/lostb1t/remux) — self-hosted media server written in
Rust with a **Jellyfin-compatible API**. Being evaluated as a replacement for
the jellyfin + stremio_server pair: it speaks the Jellyfin API to unmodified
Jellyfin clients (web, Infuse, Swiftfin, Android), and consumes Stremio
add-ons directly, so the separate `stremio_server` container becomes
redundant if the trial sticks.

**Status: TRIAL — running alongside jellyfin, nothing migrated.** Jellyfin
stays up at `https://jellyfin.lan` and remains the source of truth. Remux has
its own user/db state under `/home/kiran/remux`; wiping that directory resets
it completely.

## What it serves

- `/` — stock **jellyfin-web** v10.11.9 UI (login, libraries, playback)
- `/admin` — remux's own dashboard (Dioxus WASM): addons, users, settings,
  streams, IPTV, tasks
- Jellyfin REST API for native clients

## Reachable at

- `https://remux.lan` (Caddy → `remux:3000` on the `homelab` network)

No host port is published — host 3000 is grafana's. LAN clients that use
blocky DNS get `remux.lan` → 192.168.0.100 automatically.

## Key choices

- **Image**: `ghcr.io/lostb1t/remux:0.26.0` (pinned; upstream also ships
  `latest` and `nightly`). Upstream Dockerfile: debian trixie-slim +
  jellyfin-ffmpeg7 + mesa-va-drivers + Intel compute runtime + yt-dlp, runs
  as root, `EXPOSE 3000`, `CMD ./remux-server`.
- **Data**: single `/data` bind (`/home/kiran/remux`) — sqlite db, logs,
  torrent cache. Same host-dir pattern as the stremio stack.
- **Media**: `/media/nfs` and `/media/alldebrid` bind-mounted with slave
  propagation, mirroring the jellyfin stack, so local-file libraries can be
  pointed at the same paths.
- **Transcoding**: `/dev/dri` passed through; VA-API on the Intel iGPU should
  work out of the box thanks to the drivers baked into the image.
- **Healthcheck**: upstream's own `curl -f http://localhost:3000/health`.

## Host prerequisites

Identical to the jellyfin stack: `/dev/dri` present, `/media/nfs` and
`/media/alldebrid` mountable. No users/groups needed (container runs as root).

## Run

```bash
docker compose up -d          # from repo root (remux is included there)
```

## Trial notes / next steps

- [ ] First-run: jellyfin-web startup wizard at `https://remux.lan` (creates
      the admin user), or `POST /Startup/User` directly.
- [ ] Add Stremio add-ons in `/admin` (copy addon manifests from the existing
      stremio-server setup in `/home/kiran/stremio/server-settings.json`).
- [ ] Point a local-file library at `/media/nfs` / `/media/alldebrid` and
      compare metadata/playback against jellyfin.
- [ ] Try a real Jellyfin client (Infuse/Android) against `https://remux.lan`.
- [ ] If it sticks: retire `apps/jellyfin` + `apps/stremio`, move
      `jellyfin.lan` → remux in Caddy/blocky, update READMEs.
