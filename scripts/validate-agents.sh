#!/usr/bin/env bash
# Validate that every agent is structurally well-formed:
#   - the file opens with a YAML frontmatter block
#   - the frontmatter declares both `name:` and `description:`
#   - the declared `name:` matches the filename (app-readiness agents may
#     carry an `-agent` filename suffix that the declared name drops)
#   - a `model:` key, when present, names a real tier (haiku|sonnet|opus|inherit) —
#     a typo here silently falls back to the default model at dispatch time
#   - top-level review agents contain an `Output Contract` section
#
# Run from the repo root:  bash scripts/validate-agents.sh
set -euo pipefail

fail=0

err() {
  echo "  ✗ $1"
  fail=1
}

check_frontmatter() {
  local file="$1" expected_name="$2"

  if [ "$(head -n 1 "$file")" != "---" ]; then
    err "$file does not start with a '---' frontmatter block"
    return 1
  fi

  local frontmatter
  frontmatter="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$file")"

  if ! grep -qE '^name:[[:space:]]*\S' <<<"$frontmatter"; then
    err "$file frontmatter is missing a non-empty 'name:'"
  fi

  if ! grep -qE '^description:[[:space:]]*\S' <<<"$frontmatter"; then
    err "$file frontmatter is missing a non-empty 'description:'"
  fi

  local declared
  declared="$(grep -E '^name:' <<<"$frontmatter" | head -n 1 | sed -E 's/^name:[[:space:]]*//; s/[[:space:]]*$//')"
  if [ -n "$declared" ] && [ "$declared" != "$expected_name" ]; then
    err "$file declares name '$declared' but expected '$expected_name' from the filename"
  fi

  if grep -qE '^model:' <<<"$frontmatter"; then
    local model
    model="$(grep -E '^model:' <<<"$frontmatter" | head -n 1 | sed -E 's/^model:[[:space:]]*//; s/[[:space:]]*$//')"
    case "$model" in
      haiku|sonnet|opus|inherit) ;;
      *) err "$file declares unknown model '$model' (expected haiku, sonnet, opus, or inherit)" ;;
    esac
  fi
}

# Top-level review agents: frontmatter + name==filename + Output Contract.
for file in agents/*.md; do
  base="$(basename "$file" .md)"
  echo "checking $base"
  check_frontmatter "$file" "$base" || continue

  if ! grep -qE '^#+ .*Output Contract' "$file"; then
    err "$file has no 'Output Contract' section"
  fi

  if ! grep -qiE 'suggested fix' "$file"; then
    err "$file Output Contract does not document the optional suggested-fix clause"
  fi
done

# App-readiness agents: frontmatter + name==filename minus the '-agent' suffix.
for file in agents/app-readiness/*.md; do
  base="$(basename "$file" .md)"
  echo "checking app-readiness/$base"
  check_frontmatter "$file" "${base%-agent}" || continue
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Agent structure validation failed."
  exit 1
fi

echo ""
echo "All agents are structurally valid."
