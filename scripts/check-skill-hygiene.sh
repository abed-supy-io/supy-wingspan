#!/usr/bin/env bash
# Deterministic skill-hygiene gate (R0):
#   Check H — every SKILL.md has a trigger cue and is non-stub.
#   Check O — every documented trigger-overlap pair has a non-empty reason.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
err() { echo "✗ $1"; fail=1; }

# --- Check H: name / description / triggering cue / non-stub body. -------
while IFS= read -r skill; do
  fm="$(awk '/^---$/{n++; next} n==1' "$skill")"
  grep -qE '^name:[[:space:]]*\S'        <<<"$fm" || err "$skill: empty/missing name"
  desc="$(grep -E '^description:' <<<"$fm" | sed -E 's/^description:[[:space:]]*//')"
  [ -n "$desc" ] || err "$skill: empty/missing description"
  grep -qiE 'use when|when ' <<<"$desc"  || err "$skill: description lacks a triggering cue ('use when …')"
  # Body substance: SKILL.md below ~15 non-frontmatter lines is a stub.
  body_lines="$(awk '/^---$/{n++; next} n>=2' "$skill" | grep -cve '^[[:space:]]*$')"
  [ "${body_lines:-0}" -ge 15 ] || err "$skill: decision procedure looks like a stub ($body_lines lines)"
done < <(find skills -name SKILL.md ! -path 'skills/shared/*')

# --- Check O: every registered overlap pair has a non-empty reason. -------
# The registry (config/skill-overlaps.md) is a curated, audit-driven list of
# known-overlapping skill-trigger pairs — not a fuzzy auto-clustering. This
# check only proves every pair *in the registry* is documented; it cannot
# prove the registry is complete, i.e. it cannot prove the absence of
# undocumented overlap. Table format: `| Skill A | Skill B | Overlap | Reason |`.
overlaps_file="config/skill-overlaps.md"
trim() { sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }

if [ ! -f "$overlaps_file" ]; then
  err "missing $overlaps_file"
else
  while IFS='|' read -r _ col_a col_b _ col_reason _; do
    skill_a="$(printf '%s' "$col_a" | trim)"
    skill_b="$(printf '%s' "$col_b" | trim)"
    reason="$(printf '%s' "$col_reason" | trim)"
    # Skip the header row and the '---|---|---|---' separator row.
    case "$skill_a" in
      ""|"Skill A"|*---*) continue ;;
    esac
    [ -n "$reason" ] || err "overlap pair ($skill_a / $skill_b) has no reason"
  done < <(grep -E '^\|' "$overlaps_file")
fi

[ "$fail" -eq 0 ] && echo "✓ skill-hygiene passed"
exit "$fail"
