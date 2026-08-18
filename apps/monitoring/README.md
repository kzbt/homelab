# Monitoring

Prometheus + Grafana + node-exporter, giving a Grafana dashboard for both host
health and Blocky's DNS metrics.

## Components

| Service | Image | Purpose |
|---|---|---|
| `node-exporter` | `quay.io/prometheus/node-exporter:v1.12.1` | Exposes host CPU/mem/disk/network metrics on `9100`. |
| `prometheus` | `prom/prometheus:v3.14.0` | Scrapes `node-exporter` and Blocky's `/metrics`, stores time series. |
| `grafana` | `grafana/grafana:13.2.0` | Dashboards, pre-provisioned. |

## Key choices

- **`node-exporter` uses `network_mode: host` + `pid: host`** with the whole
  host bind-mounted read-only at `/host` (`--path.rootfs=/host`). This is the
  [officially documented](https://github.com/prometheus/node_exporter#docker)
  way to run it in Docker — without host networking, metrics like network
  interface stats would reflect the container's own namespace instead of the
  host's.
- Because node-exporter has no container name to scrape (host networking),
  Prometheus reaches it via `host.docker.internal` (`extra_hosts:
  host-gateway`), while Blocky is reached by container name (`blocky:4000`)
  since both are on the same default Compose network.
- **Prometheus published on host port `9091`, not `9090`** — Cockpit (Fedora's
  built-in web console) already owns `9090` on this host.
- **Grafana auto-provisions**: the Prometheus datasource
  (`grafana/provisioning/datasources/`) and two dashboards
  (`grafana/dashboards/`, loaded via `grafana/provisioning/dashboards/`) —
  nothing to configure by hand after `docker compose up -d`.
  - `node-exporter-full.json` — the community ["Node Exporter
    Full"](https://grafana.com/grafana/dashboards/1860) dashboard (id 1860).
  - `blocky.json` — Blocky's own official dashboard, fetched from
    [`0xERR0R/blocky`](https://github.com/0xERR0R/blocky/blob/main/docs/blocky-grafana.json).
- Grafana's admin password is **not** set via env/committed anywhere — it
  starts as the Grafana default (`admin`/`admin`) and forces a password
  change on first login. Data (including the changed password) persists in
  the `grafana-data` volume.

## Run

```bash
docker compose -f apps/monitoring/docker-compose.yml up -d
```

- Grafana: `http://<host>:3000`
- Prometheus: `http://<host>:9091`
