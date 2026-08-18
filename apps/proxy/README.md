# Proxy

Caddy reverse proxy, giving every app a plain hostname over HTTPS with no
port number — `https://jellyfin.lan` instead of `http://jellyfin.lan:8096`.

## Routes

| Hostname | Backend |
|---|---|
| `jellyfin.lan` | `192.168.0.100:8096` (Jellyfin, host networking) |
| `stremio.lan` | `stremio_server:11470` |
| `grafana.lan` | `grafana:3000` |
| `prometheus.lan` | `prometheus:9090` |

DNS for all four `.lan` names is provided by Blocky (`apps/blocky/config.yaml`
`customDNS.mapping`) — Caddy only handles the HTTP(S) routing once a request
already lands on this host.

## Key choices

- **Image**: `caddy:2.11.4-alpine` (pinned).
- **HTTPS via Caddy's internal CA**: `.lan` isn't a real public TLD, so
  Let's Encrypt is a non-starter. Each site block sets `tls internal`, which
  makes Caddy mint certs from its own local CA instead — confirmed working
  (`issuer=CN=Caddy Local Authority ...`). Certs and the CA's key material
  persist in the `caddy-data` volume.
- **Jellyfin is proxied to its real LAN IP (`192.168.0.100:8096`), not
  `host.docker.internal`**: Jellyfin (`network_mode: host`) only binds
  `127.0.0.1` and `192.168.0.100` explicitly, not `0.0.0.0` — so the bridge
  gateway IP Docker gives you for `host.docker.internal` gets "connection
  refused". Its real LAN IP is directly reachable from the container instead
  and works because that IP is DHCP-reserved (see the root README) and
  already hardcoded throughout `apps/blocky/config.yaml`.
- **Networks**: Caddy joins both `default` (reaches `blocky`/`grafana`/
  `prometheus`, the project's default network) and `homelab` (the network
  `apps/stremio` explicitly defines, to reach `stremio_server`).

## Trusting the certs on client devices

Without installing the CA, browsers will show a certificate warning (safe to
click through for a homelab, but avoidable). `caddy-local-ca.crt` in this
folder is Caddy's public root certificate (no private key) exported from the
running container — install it as a trusted root CA on any device you want a
green padlock on:

- **macOS**: open the file in Keychain Access, then set it to "Always Trust".
- **Windows**: double-click → Install Certificate → Local Machine → "Place
  in the following store" → Trusted Root Certification Authorities.
- **iOS**: AirDrop/email the file to the device, install the profile in
  Settings, then enable full trust under Settings → General → About →
  Certificate Trust Settings.
- **Android**: Settings → Security → Encryption & credentials → Install a
  certificate → CA certificate.

If Caddy's CA is ever regenerated (e.g. the `caddy-data` volume is wiped),
re-export it:

```bash
docker cp caddy:/data/caddy/pki/authorities/local/root.crt apps/proxy/caddy-local-ca.crt
```

## Run

```bash
docker compose -f apps/proxy/docker-compose.yml up -d
```
