#!/usr/bin/env bash
# Deterministic skill-hygiene gate (R0): every SKILL.md has a trigger cue and is non-stub.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
err() { echo "✗ $1"; fail=1; }

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

[ "$fail" -eq 0 ] && echo "✓ skill-hygiene passed"
exit "$fail"
