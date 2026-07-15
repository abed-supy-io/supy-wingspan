---
source: supy-configmaps (per-service `{service}-{env}.yaml`, preview-configmaps/, prod-configmaps/, infra-configmaps/), supy-manifest (apps/ ArgoCD Applications, charts/, secret references)
mined_on: 2026-07-15
confidence: high
---

# Secrets & Configuration Handling

**Stack-agnostic.** This standard governs *every* Supy repo — backend, frontend, Flutter,
infra, CLI, and Kubernetes config — because any diff in any repo can commit a credential.
It is the highest-priority cross-cutting standard: it directly enforces the organization
rule that secrets, API keys, and tokens must never be exposed. A committed secret is a
**high-severity, merge-blocking** finding regardless of stack.

The analysis of `supy-configmaps` found plaintext third-party credentials committed inside
Kubernetes `ConfigMap` `data:` blocks (Twilio, Firebase, SendGrid, Lightspeed, Xero, SFTP,
Slack webhooks, OAuth secrets, and more — across dev/preview/prod). This standard codifies
the remediation and the guardrails that stop it recurring.

> **Never reproduce a secret value.** When reviewing, reporting, or remediating, cite the
> **file path and line only** — never echo the token, key, password, or webhook itself into
> a diff, a review comment, a commit message, or any external service. If someone pastes a
> live secret to you, refuse it and tell them (organization rule).

## Rules

1. **No secret value in version control, ever.** Tokens, API keys, passwords, private keys,
   connection strings with embedded credentials, OAuth client secrets, signing secrets, and
   webhook URLs containing a secret path/token MUST NOT appear in any committed file — not in
   `ConfigMap` `data:`, not in `.env` files, not in source, not in test fixtures, not in
   Helm `values.yaml`, not in CI YAML literals. Secrets belong only in a secret store.
2. **Config vs. Secret separation (Kubernetes).** Split each service's configuration into two
   objects: a `kind: ConfigMap` holding *only* non-sensitive values (hostnames, ports, feature
   flags, log levels, public URLs) named `{svc}-{env}-config.yaml`, and a `kind: Secret` (or an
   external-secret reference) holding everything sensitive. A `ConfigMap` `data:` block must
   never contain a credential.
3. **Externalize secrets to a managed store.** Sensitive values live in one of: a K8s
   `kind: Secret` populated out-of-band, `external-secrets` (ExternalSecret → cloud secret
   manager), `sealed-secrets` (encrypted-at-rest, safe to commit), or Vault. Prefer
   `external-secrets`/`sealed-secrets` over a bare `Secret` so nothing sensitive is ever
   committed in plaintext. Workloads reference secrets via `envFrom`/`secretKeyRef`, never
   inline literals.
4. **DRY environments with Kustomize.** Do not duplicate a service's config across
   `dev`/`preview`/`prod` files. Use a Kustomize `base/` with per-environment `overlays/` that
   patch only what differs. Environment stratification by copy-paste (the current
   `supy-configmaps` layout) is a divergence to migrate away from.
5. **Secret-scanning pre-commit hook is mandatory and REJECTS commits.** Every repo that can
   hold config or code MUST run a secret scanner (`gitleaks`, `detect-secrets`, or equivalent)
   as a pre-commit hook whose non-zero exit **blocks the commit**. A scanner that only warns is
   non-compliant. See `${CLAUDE_PLUGIN_ROOT}/templates/k8s-config/` for a ready-to-use config.
6. **Validate manifests in CI.** K8s config/manifest repos must run `kubeval` or `kube-linter`
   (schema + misconfiguration checks) on changed YAML in CI. `supy-manifest` already runs
   Datree; a config repo without any validation gate is a divergence.
7. **Rotate on exposure.** If a secret was ever committed (even to a `dev` branch, even if later
   removed), it is compromised: it must be rotated at the provider and purged from history —
   deleting the line in a new commit is insufficient. Flag every historically-committed secret
   for rotation, not just removal.
8. **App code reads secrets from the environment.** Application code obtains secrets from
   injected env vars / a secrets client at runtime. Hardcoded fallbacks
   (`process.env.X || 'sk_live_...'`), committed `.env` with real values, and secrets baked
   into container images or build args are prohibited. `.env.example` may list keys with empty
   or obviously-fake placeholder values only.
9. **Secrets never leave the boundary.** Do not log secret values, do not put them in error
   messages, Sentry breadcrumbs, analytics, or URLs, and do not paste them into any external
   tool. Sanitize before capture (pairs with the Flutter `flutter_secure_storage` +
   sanitized-Sentry rule and the frontend interceptor rules).

## Examples

### Good — config and secret separated (Kustomize base)

```yaml
# base/supy-api-config.yaml  — non-sensitive ONLY
apiVersion: v1
kind: ConfigMap
metadata:
  name: supy-api-config
data:
  NATS_URL: "nats://nats.prod.svc:4222"
  LOG_LEVEL: "info"
  PUBLIC_APP_URL: "https://app.supy.io"
```

```yaml
# base/supy-api-external-secret.yaml — sensitive values pulled from the cloud secret manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: supy-api-secrets
spec:
  secretStoreRef: { name: gcp-secret-manager, kind: ClusterSecretStore }
  target: { name: supy-api-secrets }   # becomes a kind: Secret at runtime
  dataFrom:
    - extract: { key: supy-api-prod }  # key in the manager, NOT a value in git
```

```yaml
# workload consumes both — no inline credentials
envFrom:
  - configMapRef: { name: supy-api-config }
  - secretRef:    { name: supy-api-secrets }
```

### Bad — credential committed in a ConfigMap (the finding this standard exists to stop)

```yaml
# WRONG: secrets in a ConfigMap data: block, committed in plaintext
apiVersion: v1
kind: ConfigMap
metadata:
  name: supy-api-dev
data:
  TWILIO_AUTH_TOKEN: "<REDACTED — never commit a real value here>"
  SENDGRID_API_KEY: "<REDACTED>"
  # …fix: move every sensitive key to a Secret/ExternalSecret, keep only
  # non-sensitive config here, and rotate anything that was ever committed.
```

```typescript
// WRONG: hardcoded secret fallback in application code
const key = process.env.STRIPE_KEY || 'sk_live_<REDACTED>'; // rotate + remove
```

## Red flags

- Any credential-looking value (`*_TOKEN`, `*_KEY`, `*_SECRET`, `*_PASSWORD`, `authToken`,
  `apiKey`, bearer tokens, private-key PEM blocks, `postgres://user:pass@…`, webhook URLs with
  embedded tokens) inside a committed file — **highest severity.**
- A `kind: ConfigMap` whose `data:` contains anything sensitive (belongs in a `Secret`).
- `.env` with real values committed; a real secret in a test fixture or seed file.
- A repo holding config/secrets with **no** secret-scanning pre-commit hook, or a hook that
  only warns instead of failing the commit.
- Environment configs duplicated file-by-file with no Kustomize base/overlay.
- K8s config/manifest changes merged with no `kubeval`/`kube-linter`/Datree gate.
- A secret removed in a later commit but not rotated at the provider (still compromised).
- Secret values written to logs, Sentry, analytics, error messages, or URLs.

## Source

- `supy-configmaps` — per-service `{service}-{env}.yaml` files with plaintext third-party
  credentials in `ConfigMap` `data:` blocks (paths recorded in the analysis; **values never
  reproduced**); no Kustomize, no validation, no pre-commit scanning. The BLOCKING finding.
- `supy-manifest` — ArgoCD App-of-Apps consuming `kind: Secret` references
  (`auth-tokens-keys`, `firebase-service-account-key-secret`); Datree CI validation gate on
  changed YAML — the target-state model config repos should converge toward.
- Organization security rule — secrets/keys/tokens must never be exposed; reject any pasted
  secret and tell the person.
