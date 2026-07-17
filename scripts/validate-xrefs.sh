#!/usr/bin/env bash
# Validate cross-references between plugin components:
#   - every `${CLAUDE_PLUGIN_ROOT}/<path>` cited in agents/, skills/, commands/,
#     and hooks/ resolves to a real file or directory in this repo
#   - every standards file under config/standards/ is cited by at least one
#     agent or skill (an orphaned standard is dead weight)
#
# Run from the repo root:  bash scripts/validate-xrefs.sh
set -euo pipefail

fail=0

err() {
  echo "  ✗ $1"
  fail=1
}

# --- 1. Every ${CLAUDE_PLUGIN_ROOT} reference must resolve. ---------------
echo "checking \${CLAUDE_PLUGIN_ROOT} references resolve"

# Extract `${CLAUDE_PLUGIN_ROOT}/some/path` tokens; strip trailing markdown
# punctuation and `#anchor` fragments before testing existence.
refs="$(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' \
  agents/ skills/ commands/ hooks/ 2>/dev/null \
  | sed -E 's/^\$\{CLAUDE_PLUGIN_ROOT\}\///; s/[.,;:]+$//' \
  | sort -u)"

while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  if [ ! -e "$ref" ]; then
    # Report every file that cites the dangling path.
    citers="$(grep -rlF "\${CLAUDE_PLUGIN_ROOT}/$ref" agents/ skills/ commands/ hooks/ | tr '\n' ' ')"
    err "dangling reference \${CLAUDE_PLUGIN_ROOT}/$ref (cited by: $citers)"
  fi
done <<<"$refs"

# --- 2. Every standards file must be cited somewhere. ---------------------
echo "checking every standards file is cited by an agent, skill, or command"

for std in config/standards/*.md; do
  # README.md is the human-facing index of the standards, not a standard.
  [ "$std" = "config/standards/README.md" ] && continue
  if ! grep -rqF "$std" agents/ skills/ commands/ 2>/dev/null; then
    err "orphaned standard: $std is not cited by any agent, skill, or command"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Cross-reference validation failed."
  exit 1
fi

echo ""
echo "All cross-references resolve."
