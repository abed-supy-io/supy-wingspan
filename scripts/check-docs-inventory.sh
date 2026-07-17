#!/usr/bin/env bash
# Guard against doc rot: the component counts the docs claim must match the
# components actually in the tree. Counts only git-tracked files so local
# work-in-progress never skews the numbers.
#
# Checked claims:
#   - README.md and docs/USAGE.md say "N skills"        → skills/*/SKILL.md (excl. shared)
#   - README.md and docs/USAGE.md say "N slash commands" → commands/*.md
#   - docs/USAGE.md says "N review agents"              → agents/*.md (top level)
#   - docs/USAGE.md says "N hooks"                      → hooks/*.sh
#
# Run from the repo root:  bash scripts/check-docs-inventory.sh
set -euo pipefail

fail=0

err() {
  echo "  ✗ $1"
  fail=1
}

skills=$(git ls-files 'skills/*/SKILL.md' | grep -cv '^skills/shared/' || true)
commands=$(git ls-files 'commands/*.md' | grep -c . || true)
agents=$(git ls-files 'agents/*.md' | grep -cv '/app-readiness/' || true)
hooks=$(git ls-files 'hooks/*.sh' | grep -c . || true)

echo "actual inventory: $agents agents / $skills skills / $commands commands / $hooks hooks"

# require_claim <file> <regex> <label>
# The doc must contain the exact current count; any other number for the same
# phrase is stale.
require_claim() {
  local file="$1" pattern="$2" label="$3"
  if ! grep -qE "$pattern" "$file"; then
    err "$file does not state the current count of $label — expected a phrase matching: $pattern"
  fi
}

# forbid_stale <file> <regex> <good> <label>
forbid_stale() {
  local file="$1" pattern="$2" good="$3" label="$4"
  local stale
  stale=$(grep -oE "$pattern" "$file" | grep -v "^${good} " || true)
  if [ -n "$stale" ]; then
    err "$file states a stale $label count: $(echo "$stale" | sort -u | tr '\n' ' ')"
  fi
}

for doc in README.md docs/USAGE.md; do
  require_claim "$doc" "\b${skills} skills\b" "skills"
  forbid_stale "$doc" '[0-9]+ skills' "$skills" "skills"
  require_claim "$doc" "\b${commands} slash commands\b" "slash commands"
  forbid_stale "$doc" '[0-9]+ slash commands' "$commands" "slash commands"
done

require_claim docs/USAGE.md "\b${agents} review agents\b" "review agents"
forbid_stale docs/USAGE.md '[0-9]+ review agents' "$agents" "review agents"

require_claim docs/USAGE.md "\b${hooks} hooks\b" "hooks"
forbid_stale docs/USAGE.md '[0-9]+ hooks' "$hooks" "hooks"

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Docs inventory is out of sync with the tree. Update the counts together"
  echo "(README.md, docs/USAGE.md) — see the 'Keep counts in sync' golden rule."
  exit 1
fi

echo ""
echo "Docs inventory matches the tree."
