# Mobula Software Pack

A [Nebari software pack](https://github.com/nebari-dev/nebari-software-pack-template)
that deploys [Mobula](https://github.com/brandonrc/mobula) — the FOSS control
plane for Ray clusters — plus the
[mobula-ui](https://github.com/brandonrc/mobula-ui) dashboard onto a Nebari
Infrastructure Core deployment (nebari-operator, Envoy Gateway, Keycloak,
cert-manager, kuberay-operator, Kueue).

**Deliberately decoupled:** Mobula itself is platform-neutral and runs on any
Kubernetes (or bare `mobula serve`). This repo holds only the Nebari
integration: the Helm chart, the `NebariApp` wiring for routing/TLS/landing
registration, and pack metadata. Per Mobula ADR-0003, both NebariApps are
declared with `auth.enabled: false` — Mobula enforces bearer auth in-process
(and the SPA runs its own OIDC login), because gateway redirect-OIDC would
break `ray job submit` and other API clients.

## What the chart deploys

- **mobula** (control plane): single-replica Deployment (strategy `Recreate`
  — SQLite on an RWO PVC), restricted pod-security posture, `/healthz`
  probes, state on a 2Gi PVC at `/data`.
- **auth**: OIDC against Keycloak by default (`--auth-config` rendered from
  values), or IdP-free local auth (`--local-auth`, ADR-0011), or — explicitly
  opted into — no auth at all.
- **lifecycle**: `--kuberay-namespace` so Mobula creates/manages RayCluster
  CRs via the KubeRay operator and pool quota objects (Cohort /
  ResourceFlavor / ClusterQueue / LocalQueue) via the Kueue CRDs, with a
  dedicated ServiceAccount and exactly-scoped RBAC (see
  `chart/templates/rbac.yaml` for the derivation).
- **mobula-ui** (dashboard): nginx-served SPA with a chart-rendered nginx
  conf proxying `/api/`, `/healthz`, and `/docs` (WebSocket upgrade included
  for log tailing) to this release's mobula Service.
- **NebariApp CRs** (`reconcilers.nebari.dev/v1`): optional hostname + TLS +
  landing-page registration for the API and the UI.

## Install

### Quick start (defaults)

```bash
helm install mobula ./chart -n mobula --create-namespace \
  --set auth.oidc.issuer=https://keycloak.example.com/realms/nebari
```

Defaults: OIDC auth (boot fails fast until the issuer resolves), UI enabled,
KubeRay lifecycle enabled in the release namespace, 2Gi PVC, no NebariApps.

Images default to `:latest` for evaluation; pin a digest for anything real:

```yaml
image:
  tag: "latest@sha256:<digest>"
ui:
  image:
    tag: "latest@sha256:<digest>"
```

### microk8s + Nebari stack example

A full worked example against a microk8s cluster running the Nebari stack.
Keycloak's realm URL is the OIDC issuer; group→role mappings are Keycloak
group paths.

```yaml
# values-nebari.yaml
auth:
  mode: oidc
  oidc:
    issuer: https://nebari.example.com/auth/realms/nebari
    audience: mobula
    groupsClaim: groups
    roles:
      admin: ["/platform-admins"]
      operator: ["/sre"]
      developer: ["/ml-eng"]
      viewer: ["*"]

persistence:
  storageClass: microk8s-hostpath   # "" also works (cluster default)

# Mobula provisions per-project RayClusters (KubeRay) and Kueue pool
# objects into this namespace.
kuberay:
  enabled: true
  namespace: ray-workloads

# Register an existing shared cluster (e.g. deployed by rayserve-pack) with
# the job gateway. The token comes from a Secret, not the ConfigMap:
# auth_token_env names an env var; registryTokenSecret's keys become env
# vars on the mobula container.
clusters:
  - id: shared
    hostname: ray.nebari.example.com
    api_base_url: http://rayserve-kuberay-head-svc.rayserve.svc:8265
    auth_token_env: SHARED_RAY_TOKEN
registryTokenSecret: mobula-registry-tokens

nebariApp:
  api:
    enabled: true
    hostname: mobula-api.nebari.example.com
  ui:
    enabled: true
    hostname: mobula.nebari.example.com
    landingPage:
      enabled: true
```

```bash
kubectl create namespace mobula
kubectl create namespace ray-workloads
kubectl -n mobula create secret generic mobula-registry-tokens \
  --from-literal=SHARED_RAY_TOKEN=<ray-auth-token>
helm install mobula ./chart -n mobula -f values-nebari.yaml
```

Keycloak side: the UI's SSO uses Authorization Code + PKCE with the
compiled-in public client id `mobula` — register a public client named
`mobula` in the realm with `https://mobula.nebari.example.com/auth/callback`
as a valid redirect URI, and make sure the `groups` claim and the `mobula`
audience are mapped onto access tokens. The login page discovers the issuer
at runtime from `GET /api/v1/auth/providers`, so no UI rebuild is needed.

### Local auth (no IdP)

```bash
kubectl -n mobula create secret generic mobula-admin \
  --from-literal=MOBULA_LOCAL_ADMIN_PASSWORD=<password>
helm install mobula ./chart -n mobula \
  --set auth.mode=local \
  --set auth.local.existingSecret=mobula-admin
```

Without the secret, Mobula generates the admin password, prints it once to
the log, and writes it 0600 to `/data/local-admin-password` on the PVC.

### The shared-cluster story (checkmaite / Jupyter)

One shared RayCluster (deployed by
[rayserve-pack](https://github.com/brandonrc/rayserve-pack)) can serve both
interactive users and platform apps: Jupyter users on the Nebari cluster and
services like checkmaite submit Ray jobs through Mobula's gateway hostname
(`ray.nebari.example.com` above) instead of hitting the head node directly,
so every submission is authenticated (Bearer JWT from Keycloak via
`mobula login` / `RAY_JOB_HEADERS`), authorized per group→role mapping,
audited, and attributed for usage metering — while teams that need isolation
get their own per-project RayClusters from Mobula's lifecycle controller in
`kuberay.namespace`, quota-gated by Kueue.

## Notes

- `allowInsecureTransport` defaults to `true`: in-cluster Ray head services
  are plain http and tokens ride only the pod network; set `false` when all
  registered `api_base_url`s are https.
- The mobula container keeps the restricted posture (non-root uid 1001,
  read-only rootfs, no capabilities). The ui container is stock
  `nginx:alpine` and runs its entrypoint as root to bind :80, so it gets a
  minimal-but-not-restricted securityContext (no privilege escalation,
  capabilities dropped to CHOWN/SETGID/SETUID/NET_BIND_SERVICE).
- If the GHCR packages are private, flip them public or configure an
  imagePullSecret.

## Layout

- `chart/` — Helm chart (see `chart/values.yaml` for every knob, documented
  inline).
- `pack-metadata.yaml` — dashboard metadata (experimental).

## License

Apache-2.0. Ray is a registered trademark of LF Projects, LLC.
