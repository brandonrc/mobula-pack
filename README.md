# Mobula Software Pack

A [Nebari software pack](https://github.com/nebari-dev/nebari-software-pack-template)
that deploys [Mobula](https://github.com/brandonrc/mobula) — the FOSS control
plane for Ray clusters — onto a Nebari Infrastructure Core deployment.

**Deliberately decoupled:** Mobula itself is platform-neutral and runs on any
Kubernetes (or bare `mobula serve`). This repo holds only the Nebari
integration: the Helm chart, the `NebariApp` wiring for routing/TLS/landing
registration, and pack metadata. Per Mobula ADR-0003, the NebariApp is
declared with `auth.enabled: false` — Mobula enforces bearer auth in-process,
because SecurityPolicy redirect-OIDC would break `ray job submit` and other
API clients.

## Layout

- `chart/` — Helm chart: Mobula deployment, service, cluster-registry
  ConfigMap, optional NebariApp.
- `pack-metadata.yaml` — dashboard metadata (experimental).

## Status

Scaffold. Blocked on the first published Mobula container image
(`ghcr.io/brandonrc/mobula`); the image-publish workflow lands in the main
repo. Until then, install with a locally built image:

```bash
docker build -t mobula:dev ../mobula   # Dockerfile lands with the image workflow
helm install mobula ./chart -n mobula --create-namespace \
  --set image.repository=mobula --set image.tag=dev
```

## License

Apache-2.0. Ray is a registered trademark of LF Projects, LLC.
