# Archived: k0s (Kubernetes) manifests

These were the first attempt at capturing the homelab as Kubernetes (k0s)
manifests. They are **stubs that never matched the live setup** and were not
actually deployed — e.g. `image: jellyfin/jellyfin:latest` (live is pinned to
`10.11.1`), placeholder hostPaths, a `LoadBalancer` service, and a `5Gi` PVC,
none of which correspond to the running containers.

Kept here for reference/history only. The live setup is Docker Compose under
`../../apps/`.

| File | Notes |
|---|---|
| `deployment.yaml` | Stub; used `image: latest`, hostPath `/media/nfs`. |
| `pvc.yaml` | Stub `5Gi` claim, unused. |
| `service.yaml` | Stub `LoadBalancer` on port 8097→8096; live Jellyfin uses host networking on 8096. |
