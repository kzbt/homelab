# Blocky

Docker-based [Blocky](https://0xerr0r.github.io/blocky/) — a DNS proxy and
ad-blocker for the local network. Migrated from a native systemd install at
`/opt/blocky` (binary `v0.25`) to this container; the systemd unit and
`/opt/blocky` have been removed from the host.

`config.yaml` here is the same config that ran natively — copied over
unchanged. No secrets in it (just public DoH upstreams and local `.lan`
hostname mappings).

## Key choices

- **Image**: `spx01/blocky:v0.25` (pinned to match the version that was
  running natively).
- **Port 53**: Blocky is the DNS resolver for the network — it binds `53/tcp`
  and `53/udp`. Nothing else on the host may bind port 53 (this repo already
  disabled `systemd-resolved`'s stub listener — see `host/README.md`).
- **`cap_add: NET_BIND_SERVICE`**: the image runs as an unprivileged user
  (uid 100), which can't bind port 53 without this capability.
- **Config**: `./config.yaml` is bind-mounted read-only to `/app/config.yml`
  (the path the image expects via `BLOCKY_CONFIG_FILE`).
- **Metrics**: Prometheus metrics exposed on `4000/tcp` at `/metrics`
  (`prometheus: enable: true` in config).

## What it blocks / resolves

- Ad/tracker blocking via the StevenBlack hosts list, refreshed every 24h.
- Upstream resolution via Quad9 and Cloudflare DoH.
- Custom local records (`customDNS.mapping` in `config.yaml`): `jellyfin.lan`,
  `stremio.lan`, `grafana.lan`, `prometheus.lan`, `transmission.lan` →
  `192.168.0.100`. All resolve to this host; `apps/proxy` (Caddy) is what
  routes each hostname to its actual backend over HTTPS with no port number.
  (`transmission` isn't containerized in this repo — the record predates it.)

## Host prerequisites

Port 53 must be free on the host — `systemd-resolved`'s `DNSStubListener` is
already set to `no` (see `host/README.md`). If a client device or the router
points at this host's IP for DNS, that's what makes ad-blocking apply
network-wide; pointing only this host at itself only blocks ads for the host.

## Run

```bash
docker compose -f apps/blocky/docker-compose.yml up -d
```

Test it:

```bash
dig @<host> google.com          # normal resolution
dig @<host> doubleclick.net     # should return 0.0.0.0 (blocked)
```
