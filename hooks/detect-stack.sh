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
# Standalone Firebase Functions backend (non-Nx): firebase.json + a functions/ package.
# Checked before k8s-config so a Firebase repo carrying incidental YAML is not misread.
if [ -z "$stack" ] && [ -f "$root/firebase.json" ] && [ -d "$root/functions" ]; then
  stack="firebase-functions"
fi
# Standalone TypeScript CLI (non-Nx): package.json declaring a `bin` and depending on commander.
# Checked after firebase-functions, before k8s-config, so an incidental Job/ConfigMap YAML in a CLI
# repo is not misread as a k8s-config repo.
if [ -z "$stack" ] && [ -f "$root/package.json" ] && grep -q '"commander"' "$root/package.json" && grep -q '"bin"' "$root/package.json"; then
  stack="ts-cli"
fi
# Polyglot AI-agents monorepo (non-Nx, no root orchestration): a package.json anywhere in the tree
# depends on the MCP SDK or the Claude Agent SDK. Checked after ts-cli (ts-cli inspects only the ROOT
# package.json, and this repo has no root orchestration to misgrab) and before k8s-config.
if [ -z "$stack" ] && grep -rlsq --include='package.json' --exclude-dir='node_modules' -e '@modelcontextprotocol/sdk' -e '@anthropic-ai/claude-agent-sdk' "$root" 2>/dev/null; then
  stack="ai-agents"
fi
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
if [ "$stack" = "firebase-functions" ]; then
  msg="supy-wingspan: detected firebase-functions repo (standalone, non-Nx) — remediation-first: prioritise secrets (Secret Manager, never literals) and runtime-enforced auth markers. Run supy-review (supy-firebase-functions-reviewer); see config/standards/firebase-functions/architecture.md."
  if [ ! -f "$root/CLAUDE.md" ]; then
    msg="$msg No CLAUDE.md found — run the supy-baseline skill to generate one."
  fi
  echo "$msg"
  exit 0
fi
if [ "$stack" = "ts-cli" ]; then
  msg="supy-wingspan: detected ts-cli repo (standalone commander.js MongoDB scripts runner) — a command can mutate a production DB in bulk, so operational safety is load-bearing: layered-env secrets (never literals/argv/logs), explicit prod-mutation confirmation, deterministic exit codes. Run supy-review (supy-ts-cli-reviewer); see config/standards/ts-cli/architecture.md."
  if [ ! -f "$root/CLAUDE.md" ]; then
    msg="$msg No CLAUDE.md found — run the supy-baseline skill to generate one."
  fi
  echo "$msg"
  exit 0
fi
if [ "$stack" = "ai-agents" ]; then
  msg="supy-wingspan: detected ai-agents repo (polyglot MCP/agents monorepo, no root orchestration) — remediation-first: prioritise secret hygiene (env/secret store, never literals/argv/logs), auth on every exposed MCP tool/route, idempotent BullMQ consumers, and non-root containers. Run supy-review (supy-ai-agents-reviewer); see config/standards/ai-agents/architecture.md."
  if [ ! -f "$root/CLAUDE.md" ]; then
    msg="$msg No CLAUDE.md found — run the supy-baseline skill to generate one."
  fi
  echo "$msg"
  exit 0
fi
msg="supy-wingspan: detected $stack repo."
if [ ! -f "$root/CLAUDE.md" ]; then
  msg="$msg No CLAUDE.md found — run the supy-baseline skill to generate one."
fi
echo "$msg"
exit 0
