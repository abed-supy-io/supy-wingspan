#!/usr/bin/env bash
# Validate that every eval fixture is structurally well-formed. This is the
# deterministic, API-key-free half of the eval harness — safe to gate CI on.
# The LLM scoring half lives in run-secrets-eval.sh (needs the claude CLI).
#
# Each fixture directory must contain:
#   - input.diff       a non-empty unified diff to feed the reviewer
#   - expected.json    the ground-truth verdict + findings
#
# expected.json contract:
#   - description   non-empty string
#   - verdict       "pass" | "issues"
#   - findings      array; each item has file (string), line (int>=1),
#                   severity ("high"|"med"|"low"), rule_contains (string)
#   - invariant     verdict=="pass"  <=>  findings is empty
#
# Run from the repo root:  bash evals/validate-fixtures.sh
set -euo pipefail

fixtures_root="evals/fixtures"
fail=0

err() {
  echo "  ✗ $1"
  fail=1
}

if [ ! -d "$fixtures_root" ]; then
  echo "No fixtures directory at $fixtures_root — nothing to validate."
  exit 0
fi

for dir in "$fixtures_root"/*/*/; do
  [ -d "$dir" ] || continue
  name="${dir#"$fixtures_root"/}"
  name="${name%/}"
  echo "checking $name"

  diff_file="$dir/input.diff"
  exp_file="$dir/expected.json"

  if [ ! -s "$diff_file" ]; then
    err "$name: input.diff is missing or empty"
  fi

  if [ ! -f "$exp_file" ]; then
    err "$name: expected.json is missing"
    continue
  fi

  if ! jq empty "$exp_file" 2>/dev/null; then
    err "$name: expected.json is not valid JSON"
    continue
  fi

  # description present and non-empty.
  if [ "$(jq -r '.description // "" | length' "$exp_file")" -eq 0 ]; then
    err "$name: expected.json has no non-empty 'description'"
  fi

  # verdict is one of the two allowed values.
  verdict="$(jq -r '.verdict // ""' "$exp_file")"
  case "$verdict" in
    pass | issues) ;;
    *) err "$name: verdict '$verdict' is not 'pass' or 'issues'" ;;
  esac

  # findings must be an array.
  if [ "$(jq -r '.findings | type' "$exp_file" 2>/dev/null)" != "array" ]; then
    err "$name: 'findings' must be an array"
    continue
  fi

  # verdict/findings invariant.
  n_findings="$(jq '.findings | length' "$exp_file")"
  if [ "$verdict" = "pass" ] && [ "$n_findings" -ne 0 ]; then
    err "$name: verdict is 'pass' but findings is non-empty"
  fi
  if [ "$verdict" = "issues" ] && [ "$n_findings" -eq 0 ]; then
    err "$name: verdict is 'issues' but findings is empty"
  fi

  # Each finding is well-shaped.
  invalid="$(jq -r '
    [ .findings[]
      | select(
          (.file | type != "string" or length == 0)
          or (.line | type != "number" or . < 1)
          or ((.severity // "") | (. != "high" and . != "med" and . != "low"))
          or (has("rule_contains") | not)
        )
    ] | length' "$exp_file")"
  if [ "$invalid" -ne 0 ]; then
    err "$name: $invalid finding(s) malformed (need file:string, line:int>=1, severity:high|med|low, rule_contains:present)"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "Fixture validation failed."
  exit 1
fi

echo ""
echo "All eval fixtures are structurally valid."
