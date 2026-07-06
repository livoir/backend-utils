# backend-stack (Kubernetes)

Umbrella Helm chart that deploys the same services as the root `docker-compose.yaml`
onto Kubernetes, using upstream charts as dependencies instead of hand-rolled manifests.

| Concern | Chart | Replaces (compose) |
|---|---|---|
| Prometheus + Grafana + Alertmanager + node-exporter | `kube-prometheus-stack` | prometheus, grafana, alert-manager, node-exporter |
| Logs | `loki` + `promtail` (DaemonSet) | loki, promtail |
| Traces | `tempo` + `opentelemetry-collector` | tempo, otel-collector |
| Postgres | `postgresql` (bitnami) | postgres |
| Cache | `valkey` (bitnami) | redis / valkey / keydb (pick one) |
| Messaging | `nats` | nats |
| Object storage | `minio` (bitnami) | minio |

## What intentionally changed vs docker-compose

- **node-exporter & promtail** are now **DaemonSets** (one pod per node) — the correct k8s shape, not sidecars.
- **nginx** is gone; expose HTTP via an **Ingress** (your cluster's controller), not a per-app container.
- **named volumes → PVCs**, **mem_limit → `resources.limits`**, **healthchecks → `livenessProbe`/`readinessProbe** (chart-managed).
- **logging rotation** is gone — Kubernetes captures container stdout itself.
- **google-pubsub-emulator** is omitted (it was dev-only). Re-add a chart if you need it.

## Prerequisites

- `helm` >= 3.12 and `kubectl`, pointed at a cluster (kind/k3s/minikube for local).
- A default `StorageClass` that supports `ReadWriteOnce` (for the PVCs). Set `storageClass:` in `values.yaml` if you need a specific one.

## Deploy

```bash
# 1. Add the dependency repos (one-time)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana             https://grafana.github.io/helm-charts
helm repo add openetelemetry      https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add nats                https://nats-io.github.io/k8s/helm/charts/
helm repo add bitnami             https://charts.bitnami.com/bitnami
helm repo update

# 2. Resolve dependencies into charts/
helm dependency update k8s

# 3. Fill in secrets (gitignored)
cp k8s/secrets.yaml.example k8s/secrets.yaml
$EDITOR k8s/secrets.yaml

# 4. Validate BEFORE applying
helm lint k8s -f k8s/values.yaml -f k8s/secrets.yaml
helm template backend k8s -f k8s/values.yaml -f k8s/secrets.yaml -n backend | less

# 5. Install (release name MUST be "backend" — see note below)
helm upgrade --install backend k8s \
  -f k8s/values.yaml -f k8s/secrets.yaml \
  -n backend --create-namespace
```

> **Release name matters.** Inter-service DNS (`backend-loki`, `backend-tempo`, `backend-opentelemetry-collector`) is hard-coded in `values.yaml` for promtail→loki and otel→tempo/otel→prometheus. If you install with a different release name, update those URLs in `values.yaml`, or install with `--set fullnameOverride` per chart.

## Validate it came up

```bash
kubectl -n backend get pods
kubectl -n backend get pvc
# Port-forward Grafana to log in
kubectl -n backend port-forward svc/backend-kube-prometheus-sta-grafana 3000:80
```

## Notes / follow-ups

- **NATS auth**: this chart enables JetStream + persistence but leaves the multi-account/permission model (SYS/APP users) minimal — that config is chart-specific and app-coupled. To replicate the docker-compose `nats-server.conf` accounts, either (a) pass them via the `nats` chart's `auth.accounts` values, or (b) mount a custom ConfigMap and point the chart at it. The bcrypt hashes still belong in a Secret.
- **Secrets**: `secrets.yaml` is a starting point. For production, switch to **External Secrets Operator** (AWS/GCP/Vault) or **SealedSecrets** so no plaintext lives on disk or in values files.
- **Ingress**: disabled by default. Add an `ingress` block under `kube-prometheus-stack.grafana.ingress` (and for any service you want exposed) once you have an ingress controller + hostname.
- **Postgres HA**: bitnami `postgresql` runs a single primary. For real HA, swap to the **CloudNativePG** operator (native k8s Postgres with replication + backups).
- **MinIO**: set `mode: distributed` for HA in production.
- **Versions are pinned** in `Chart.yaml`. Bump deliberately and re-run `helm dependency update`.
