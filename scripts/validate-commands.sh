#!/usr/bin/env bash
# Validate that every slash command is structurally well-formed:
#   - the file opens with a YAML frontmatter block
#   - the frontmatter declares a non-empty `description:` and `argument-hint:`
#   - the body passes `$ARGUMENTS` through (commands take arguments; a command
#     that ignores them silently is a wiring bug)
#   - the body cites at least one `${CLAUDE_PLUGIN_ROOT}` component path, so the
#     command is anchored to a skill/standard (resolution of each cited path is
#     covered by validate-xrefs.sh)
#
# Run from the repo root:  bash scripts/validate-commands.sh
set -euo pipefail

fail=0

err() {
  echo "  ✗ $1"
  fail=1
}

for file in commands/*.md; do
  base="$(basename "$file" .md)"
  echo "checking $base"

  if [ "$(head -n 1 "$file")" != "---" ]; then
    err "$file does not start with a '---' frontmatter block"
    continue
  fi

  frontmatter="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$file")"

  if ! grep -qE '^description:[[:space:]]*\S' <<<"$frontmatter"; then
    err "$file frontmatter is missing a non-empty 'description:'"
  fi

  if ! grep -qE '^argument-hint:[[:space:]]*\S' <<<"$frontmatter"; then
    err "$file frontmatter is missing a non-empty 'argument-hint:'"
  fi

  body="$(awk 'f{print} /^---[[:space:]]*$/{if(NR>1)f=1}' "$file")"

  # shellcheck disable=SC2016 # the literal string '$ARGUMENTS' is the target
  if ! grep -qF '$ARGUMENTS' <<<"$body"; then
    err "$file body never references \$ARGUMENTS despite declaring an argument-hint"
  fi

  # shellcheck disable=SC2016 # the literal string '${CLAUDE_PLUGIN_ROOT}' is the target
  if ! grep -qF '${CLAUDE_PLUGIN_ROOT}' <<<"$body"; then
    err "$file body cites no \${CLAUDE_PLUGIN_ROOT} path — commands must anchor to a plugin component"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Command structure validation failed."
  exit 1
fi

echo ""
echo "All commands are structurally valid."
