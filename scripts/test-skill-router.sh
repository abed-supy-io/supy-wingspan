#!/usr/bin/env bash
# Fixture tests for hooks/skill-router.sh: feed a UserPromptSubmit JSON payload
# on stdin and assert the nudge (or the silence) on stdout. The hook must never
# exit non-zero — it degrades open, and an ordinary prompt must add nothing.
#
# Run from the repo root:  bash scripts/test-skill-router.sh
set -euo pipefail

hook="$(cd "$(dirname "$0")/.." && pwd)/hooks/skill-router.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Stack fixtures for the cwd-based gate: the Flutter/design nudges only fire
# when the cwd is (or could be) a repo of the matching stack.
flutter_dir="$tmp/flutter-repo"
mkdir -p "$flutter_dir"
echo 'name: app' >"$flutter_dir/pubspec.yaml"

backend_dir="$tmp/backend-repo"
mkdir -p "$backend_dir"
echo '{"dependencies":{"@nestjs/core":"^10.0.0"}}' >"$backend_dir/package.json"

missing_dir="$tmp/does-not-exist"

fail=0
n=0

# run_case <name> <prompt> <cwd> <expected-substring|<silent>> [forbidden-substring]
run_case() {
  local name="$1" prompt="$2" cwd="$3" expected="$4" forbidden="${5:-}"
  n=$((n + 1))

  local payload out rc=0
  payload=$(printf '{"prompt":"%s","cwd":"%s","hook_event_name":"UserPromptSubmit"}' "$prompt" "$cwd")
  out="$(printf '%s' "$payload" | bash "$hook")" || rc=$?

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
  if [ -n "$forbidden" ] && [[ "$out" == *"$forbidden"* ]]; then
    echo "  ✗ $name: output must not contain '$forbidden', got: $out"
    fail=1
    return
  fi
  echo "  ✓ $name"
}

echo "skill-router.sh fixture tests"

# Universal intents fire regardless of stack.
run_case "commit intent" "please commit these changes" "$backend_dir" "supy-commit"
run_case "commit is case-insensitive" "COMMIT this for me" "$backend_dir" "supy-commit"
run_case "pull-request intent" "open a pr for this branch" "$backend_dir" "supy-create-pr"
run_case "review intent" "review my diff before merging" "$backend_dir" "supy-review"
run_case "rebase intent" "rebase onto main" "$backend_dir" "supy-rebase"
run_case "hotfix intent" "we need an urgent fix in production" "$backend_dir" "supy-hotfix"
run_case "debrief intent" "write a handoff before I leave" "$backend_dir" "supy-debrief"
run_case "baseline intent" "onboard this repo with standards" "$backend_dir" "supy-baseline"
run_case "failing-ci intent" "the github action is broken again" "$backend_dir" "fix-failing-github-actions"
run_case "spec intent" "write an implementation spec from the jira ticket" "$backend_dir" "supy-impl-spec"

# Stack-gated intents: fire in a matching repo, stay silent in a known-other repo.
run_case "figma intent in flutter repo" "implement the design from figma" "$flutter_dir" "supy-figma-implement-design"
run_case "figma intent suppressed in backend repo" "implement the design from figma" "$backend_dir" "<silent>"
run_case "flutter upgrade in flutter repo" "upgrade flutter to the latest sdk" "$flutter_dir" "supy-flutter-upgrade"
run_case "flutter upgrade suppressed in backend repo" "bump the flutter sdk" "$backend_dir" "<silent>"
run_case "code assessment in flutter repo" "run a full code assessment on this repo" "$flutter_dir" "supy-code-assessment"
run_case "release readiness in flutter repo" "are we ready to release to the store" "$flutter_dir" "supy-app-release-readiness"

# Degrade open: unknown cwd must not suppress a stack-gated nudge.
run_case "figma intent with unknown cwd" "implement the figma design" "$missing_dir" "supy-figma-implement-design"

# Multiple intents in one prompt produce multiple nudges.
run_case "combined commit + pr intent" "commit this and open a pr" "$backend_dir" "supy-commit"
run_case "combined nudge includes pr too" "commit this and open a pr" "$backend_dir" "supy-create-pr"

# Ordinary prompts stay silent — the hook must add nothing on normal turns.
run_case "ordinary prompt stays silent" "explain how the auth module works" "$backend_dir" "<silent>"
run_case "unrelated flutter-repo prompt stays silent" "add a loading spinner to the login page" "$flutter_dir" "<silent>"

# A universal nudge must not drag in stack-gated ones.
run_case "commit in backend repo has no flutter nudge" "commit these changes" "$backend_dir" "supy-commit" "supy-flutter-upgrade"

# Empty stdin: silent exit 0.
n=$((n + 1))
rc=0
out="$(printf '' | bash "$hook")" || rc=$?
if [ "$rc" -ne 0 ] || [ -n "$out" ]; then
  echo "  ✗ empty stdin: expected silent exit 0, got rc=$rc out=$out"
  fail=1
else
  echo "  ✓ empty stdin stays silent"
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "skill-router fixture tests FAILED."
  exit 1
fi
echo "All skill-router fixture tests passed."
