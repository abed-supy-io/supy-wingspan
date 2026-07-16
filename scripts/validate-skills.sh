#!/usr/bin/env bash
# Validate that every skill is structurally well-formed:
#   - the directory contains a SKILL.md
#   - the SKILL.md opens with a YAML frontmatter block
#   - the frontmatter declares both `name:` and `description:`
#   - the declared `name:` matches the directory name
# skills/shared/ is a reference-only directory (no SKILL.md) and is skipped.
#
# Run from the repo root:  bash scripts/validate-skills.sh
set -euo pipefail

skills_dir="skills"
fail=0

err() {
  echo "  ✗ $1"
  fail=1
}

for dir in "$skills_dir"/*/; do
  name="$(basename "$dir")"

  # shared/ holds cross-skill references, not a skill.
  if [ "$name" = "shared" ]; then
    continue
  fi

  echo "checking $name"
  skill_file="$dir/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    err "no SKILL.md in $dir"
    continue
  fi

  # Frontmatter must be the very first line.
  if [ "$(head -n 1 "$skill_file")" != "---" ]; then
    err "$skill_file does not start with a '---' frontmatter block"
    continue
  fi

  # Extract the frontmatter (lines between the first two '---' fences).
  frontmatter="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "$skill_file")"

  if ! grep -qE '^name:[[:space:]]*\S' <<<"$frontmatter"; then
    err "$skill_file frontmatter is missing a non-empty 'name:'"
  fi

  if ! grep -qE '^description:[[:space:]]*\S' <<<"$frontmatter"; then
    err "$skill_file frontmatter is missing a non-empty 'description:'"
  fi

  declared="$(grep -E '^name:' <<<"$frontmatter" | head -n 1 | sed -E 's/^name:[[:space:]]*//; s/[[:space:]]*$//')"
  if [ -n "$declared" ] && [ "$declared" != "$name" ]; then
    err "$skill_file declares name '$declared' but lives in directory '$name'"
  fi

  # Claude Code truncates skill descriptions past 1024 characters, and a
  # too-short one gives the router nothing to match on.
  description="$(grep -E '^description:' <<<"$frontmatter" | head -n 1 | sed -E 's/^description:[[:space:]]*//')"
  desc_len=${#description}
  if [ "$desc_len" -gt 1024 ]; then
    err "$skill_file description is $desc_len chars (max 1024)"
  elif [ "$desc_len" -gt 0 ] && [ "$desc_len" -lt 20 ]; then
    err "$skill_file description is only $desc_len chars — too short to route on"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Skill structure validation failed."
  exit 1
fi

echo ""
echo "All skills are structurally valid."
