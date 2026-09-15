# Calibre-Web-Automated

Self-hosted eBook library server ([upstream](https://github.com/crocodilestick/calibre-web-automated)):
Calibre-Web with automatic ingest, format conversion, metadata enforcement and
e-reader (Kindle/Kobo/KOReader) sync. Reached at **https://books.lan**.

Kobo sync broken or books not appearing? See
[TROUBLESHOOTING.md](TROUBLESHOOTING.md) — every failure we hit (TLS, missing
checksum table, OIDC handshake, archived-book state), diagnosed and fixed.

This `docker-compose.yml` is the source of truth for the live
`calibre-web-automated` container. It is included by the root
`../../docker-compose.yml` (same `homelab` project/network as caddy & blocky).

## Key choices

- **Image**: `crocodilestick/calibre-web-automated:v4.0.6` (pinned to the
  latest upstream release).
- **Runs as** `PUID=1000`/`PGID=1000` (kiran) — matches the ownership of the
  binds below.
- **Storage split** (same pattern as the rest of the homelab):
  - `/media/books/library` → `/calibre-library` — the Calibre library
    (`metadata.db` + books) on the `/media` xfs disk. Auto-created on first
    start.
  - `/media/books/ingest` → `/cwa-book-ingest` — drop folder; anything placed
    here is auto-ingested and removed after processing.
  - `/home/kiran/calibre-web-automated/config` → `/config` — app state
    (`app.db`, users/settings, processed-book backups), like stremio's
    `~/stremio`.
- **Networking**: default bridge network, port `8083` published; LAN access is
  via caddy (`books.lan`, see `../proxy/Caddyfile`) with the DNS record in
  `../blocky/config.yaml`.

## First login

- Upstream default admin credentials are `admin` / `admin123`; on this
  instance the admin account is named `kiran` (renamed after first setup).
- **Password login is disabled**: the stored password is a werkzeug hash of
  the empty string, so the login form accepts an empty password field.
  Set directly in `~/calibre-web-automated/config/app.db` (user id 1).
  Note: blanking the stored hash outright would lock the account out —
  `check_password_hash('', '')` is always false, so an empty hash never
  matches. A hash *of* the empty string is the supported way to do this.

## Host prerequisites

`../../host/bootstrap.sh` creates `/media/books`, `/media/books/library` and
`/media/books/ingest` (kiran:media, 0775). The config dir is created on first
run as kiran.


Kobo sync broken or books not appearing? See
[TROUBLESHOOTING.md](TROUBLESHOOTING.md) — every failure we hit (TLS, missing
checksum table, OIDC handshake, archived-book state), diagnosed and fixed.

## Kobo sync

Kobo firmware rejects Caddy's internal TLS CA, so the sync API is served over
plain HTTP (see `../proxy/Caddyfile` — only `/kobo/*`, everything else on http
redirects to https). On the device, `/mnt/onboard/.kobo/Kobo/eReader.conf`
must point at the http URL:

```ini
[SyncService]
api_endpoint=http://books.lan/kobo/<TOKEN>/
```

`<TOKEN>` is the per-user Kobo sync key from the CWA UI (user menu → Kobo
setup dialog shows the full URL — flip its scheme to `http`). USB-connect the
Kobo to edit the file, eject, then tap Sync on the device.

Kobo firmware 4.45+ additionally requires a working OIDC handshake (discovery
→ authorize → token) before it will sync, which CWA v4.0.6 doesn't implement
(upstream issue
[crocodilestick/Calibre-Web-Automated#1418](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1418)).
The proxy serves the handshake instead — see the `http://books.lan` block in
`../proxy/Caddyfile`. Remove that shim when upstream ships the fix.

## Run

```bash
docker compose -f apps/calibre-web-automated/docker-compose.yml up -d
```
