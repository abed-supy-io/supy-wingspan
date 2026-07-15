#!/usr/bin/env bash
# SessionStart hook: detect stack, nudge missing Supy setup. Never fails the session.
set -u
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -z "$root" ] && exit 0
stack=""
if [ -f "$root/nx.json" ] && [ -f "$root/package.json" ]; then
  # Disambiguate the Nx flavour by its framework dependency.
  if grep -q '"@angular/core"' "$root/package.json"; then
    stack="angular-nx"
  elif grep -q '"@nestjs/core"' "$root/package.json"; then
    stack="nestjs-nx"
  else
    stack="nx"
  fi
fi
if [ -f "$root/pubspec.yaml" ]; then stack="flutter"; fi
# Kubernetes config/manifest repo: ConfigMap/Secret YAML or a kustomization, and not an app stack.
if [ -z "$stack" ]; then
  if [ -f "$root/kustomization.yaml" ] || grep -rlsq --include='*.yaml' -e 'kind: ConfigMap' -e 'kind: Secret' "$root" 2>/dev/null; then
    stack="k8s-config"
  fi
fi
[ -z "$stack" ] && exit 0   # unknown/mixed: stay silent
if [ "$stack" = "k8s-config" ]; then
  echo "supy-wingspan: detected k8s-config repo. Secrets MUST live in a Secret/external-secret, never in a ConfigMap — run supy-review (supy-secrets-reviewer) and see config/standards/secrets-and-config.md."
  exit 0
fi
msg="supy-wingspan: detected $stack repo."
if [ ! -f "$root/CLAUDE.md" ]; then
  msg="$msg No CLAUDE.md found — run the supy-baseline skill to generate one."
fi
echo "$msg"
exit 0
