# k8s-config template — secret-safe configuration

Drop-in scaffolding for a Supy Kubernetes config repo (the `supy-configmaps` remediation
target). Enforces `config/standards/secrets-and-config.md`.

> **Never commit a secret value.** These files show *structure* only. Real secret values live
> in the cloud secret manager / a `Secret` populated out-of-band — never in git.

## What to copy

- **`.pre-commit-config.yaml`** → repo root. Install with `pre-commit install`. The `gitleaks`
  hook blocks any commit containing a secret (rule 5). Keep the `kube-linter` hook for k8s
  repos (rule 6); drop it elsewhere.
- **`base/` + `overlays/`** → the Kustomize layout that replaces per-environment file
  duplication (rule 4). One `base/`, one overlay per environment patching only what differs.

## Config vs. Secret (rules 2–3)

Split every service into:

```text
base/
  <svc>-config.yaml          # kind: ConfigMap — NON-sensitive only (hosts, ports, flags)
  <svc>-external-secret.yaml # kind: ExternalSecret — pulls sensitive values from the manager
  kustomization.yaml
overlays/
  dev/       kustomization.yaml   # patches base for dev
  preview/   kustomization.yaml
  prod/      kustomization.yaml
```

Sensitive values (`*_TOKEN`, `*_KEY`, `*_SECRET`, `*_PASSWORD`, secret-bearing webhooks) go to
the `ExternalSecret` (or `sealed-secrets`/`Secret` populated out-of-band) — **never** into a
`ConfigMap` `data:` block. Workloads consume both via `envFrom` (`configMapRef` + `secretRef`).

## If a secret was ever committed (rule 7)

Removing the line is **not** enough — the value is compromised. Rotate it at the provider and
purge it from history. Deleting-only is a review finding, not a fix.
