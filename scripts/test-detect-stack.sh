#!/usr/bin/env bash
# Fixture tests for hooks/detect-stack.sh: build a throwaway git repo per
# detection branch (including the deliberate ordering collisions) and assert
# the hook's stdout. The hook must never exit non-zero.
#
# Run from the repo root:  bash scripts/test-detect-stack.sh
set -euo pipefail

hook="$(cd "$(dirname "$0")/.." && pwd)/hooks/detect-stack.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
n=0

# run_case <name> <expected-substring> <setup-function>
run_case() {
  local name="$1" expected="$2" setup="$3"
  n=$((n + 1))
  local dir="$tmp/case-$n"
  mkdir -p "$dir"
  git -C "$dir" init -q
  "$setup" "$dir"

  local out rc=0
  out="$(cd "$dir" && bash "$hook")" || rc=$?

  if [ "$rc" -ne 0 ]; then
    echo "  ✗ $name: hook exited $rc (must always exit 0)"
    fail=1
    return
  fi
  if [ "$expected" = "<silent>" ]; then
    if [ -n "$out" ]; then
      echo "  ✗ $name: expected no output, got: $out"
      fail=1
      return
    fi
  elif [[ "$out" != *"$expected"* ]]; then
    echo "  ✗ $name: expected substring '$expected', got: ${out:-<empty>}"
    fail=1
    return
  fi
  echo "  ✓ $name"
}

# --- fixture builders ------------------------------------------------------

setup_angular() {
  echo '{"dependencies":{"@angular/core":"^17.0.0"}}' >"$1/package.json"
  echo '{}' >"$1/nx.json"
}
setup_nestjs() {
  echo '{"dependencies":{"@nestjs/core":"^10.0.0"}}' >"$1/package.json"
  echo '{}' >"$1/nx.json"
}
setup_plain_nx() {
  echo '{"dependencies":{}}' >"$1/package.json"
  echo '{}' >"$1/nx.json"
}
setup_flutter() {
  echo 'name: app' >"$1/pubspec.yaml"
}
# pubspec must win even when Nx markers are present.
setup_flutter_over_nx() {
  setup_nestjs "$1"
  echo 'name: app' >"$1/pubspec.yaml"
}
setup_firebase() {
  echo '{}' >"$1/firebase.json"
  mkdir -p "$1/functions"
  echo '{"dependencies":{"firebase-functions":"^4.0.0"}}' >"$1/functions/package.json"
}
# firebase-functions must win over k8s-config when incidental ConfigMap YAML exists.
setup_firebase_over_k8s() {
  setup_firebase "$1"
  printf 'kind: ConfigMap\n' >"$1/incidental.yaml"
}
setup_ts_cli() {
  echo '{"bin":{"supy":"./dist/main.js"},"dependencies":{"commander":"^12.0.0"}}' >"$1/package.json"
}
# ts-cli must win over k8s-config when an incidental Job/ConfigMap YAML exists.
setup_ts_cli_over_k8s() {
  setup_ts_cli "$1"
  printf 'kind: ConfigMap\n' >"$1/job.yaml"
}
setup_ai_agents() {
  mkdir -p "$1/agents/cortex"
  echo '{"dependencies":{"@modelcontextprotocol/sdk":"^1.0.0"}}' >"$1/agents/cortex/package.json"
}
# ai-agents detection must skip node_modules copies of the SDK.
setup_ai_agents_node_modules_only() {
  mkdir -p "$1/node_modules/@modelcontextprotocol/sdk"
  echo '{"name":"@modelcontextprotocol/sdk"}' >"$1/node_modules/@modelcontextprotocol/sdk/package.json"
}
setup_k8s_kustomize() {
  echo 'resources: []' >"$1/kustomization.yaml"
}
setup_k8s_configmap() {
  mkdir -p "$1/manifests"
  printf 'kind: Secret\n' >"$1/manifests/db.yaml"
}
setup_unknown() {
  echo 'just a readme' >"$1/README.md"
}
setup_nestjs_with_claude_md() {
  setup_nestjs "$1"
  echo '# repo' >"$1/CLAUDE.md"
}

# --- cases -----------------------------------------------------------------

echo "detect-stack.sh fixture tests"
run_case "angular-nx" "detected angular-nx repo." setup_angular
run_case "nestjs-nx" "detected nestjs-nx repo." setup_nestjs
run_case "plain nx" "detected nx repo." setup_plain_nx
run_case "flutter" "detected flutter repo." setup_flutter
run_case "flutter overrides nx" "detected flutter repo." setup_flutter_over_nx
run_case "firebase-functions" "detected firebase-functions repo (standalone, non-Nx)" setup_firebase
run_case "firebase beats k8s-config" "detected firebase-functions repo" setup_firebase_over_k8s
run_case "ts-cli" "detected ts-cli repo (standalone commander.js MongoDB scripts runner)" setup_ts_cli
run_case "ts-cli beats k8s-config" "detected ts-cli repo" setup_ts_cli_over_k8s
run_case "ai-agents" "detected ai-agents repo (polyglot MCP/agents monorepo" setup_ai_agents
run_case "ai-agents ignores node_modules" "<silent>" setup_ai_agents_node_modules_only
run_case "k8s-config via kustomization" "Secrets MUST live in a Secret/external-secret" setup_k8s_kustomize
run_case "k8s-config via Secret manifest" "detected k8s-config repo." setup_k8s_configmap
run_case "unknown stack stays silent" "<silent>" setup_unknown
run_case "no CLAUDE.md nudge" "No CLAUDE.md found — run the supy-baseline skill" setup_nestjs
run_case "CLAUDE.md present, no nudge" "detected nestjs-nx repo." setup_nestjs_with_claude_md

# The nudge must be absent when CLAUDE.md exists — assert the negative directly.
n=$((n + 1))
dir="$tmp/case-$n"
mkdir -p "$dir"; git -C "$dir" init -q
setup_nestjs_with_claude_md "$dir"
out="$(cd "$dir" && bash "$hook")"
if [[ "$out" == *"No CLAUDE.md found"* ]]; then
  echo "  ✗ CLAUDE.md present but nudge still emitted"
  fail=1
else
  echo "  ✓ nudge suppressed when CLAUDE.md exists"
fi

# Outside a git repo the hook must stay silent and exit 0.
n=$((n + 1))
dir="$tmp/case-$n"; mkdir -p "$dir"
out="$(cd "$dir" && GIT_CEILING_DIRECTORIES="$tmp" bash "$hook")" && rc=0 || rc=$?
if [ "$rc" -ne 0 ] || [ -n "$out" ]; then
  echo "  ✗ non-git dir: expected silent exit 0, got rc=$rc out=$out"
  fail=1
else
  echo "  ✓ non-git dir stays silent"
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "detect-stack fixture tests FAILED."
  exit 1
fi
echo "All detect-stack fixture tests passed."
