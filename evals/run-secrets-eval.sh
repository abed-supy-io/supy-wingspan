#!/usr/bin/env bash
# Behavioral eval for the supy-secrets-reviewer agent.
#
# For each fixture under evals/fixtures/secrets/, this feeds the planted diff to
# the reviewer (reconstructed from its own agents/supy-secrets-reviewer.md so the
# eval always tracks the real agent), parses the Output Contract it returns, and
# scores it against expected.json — measuring BOTH:
#   - recall    (did it catch the planted secret?)     — false negatives are unsafe
#   - precision (did it stay silent on clean diffs?)    — false positives erode trust
#
# This half is non-deterministic (it calls an LLM) and needs the `claude` CLI with
# working credentials, so it is NOT a default CI gate — run it locally or nightly.
# The deterministic fixture-structure check is validate-fixtures.sh.
#
# Usage:   bash evals/run-secrets-eval.sh [fixture-name-substring]
# Env:     MODEL=<tier>   override the agent's declared model
#          LINE_TOL=<n>   line-number match tolerance (default 3)
set -uo pipefail

agent_file="agents/supy-secrets-reviewer.md"
fixtures_root="evals/fixtures/secrets"
filter="${1:-}"
LINE_TOL="${LINE_TOL:-3}"

if ! command -v claude >/dev/null 2>&1; then
  echo "SKIPPED: the 'claude' CLI is not on PATH — this eval needs it to invoke the reviewer."
  exit 0
fi
if [ ! -f "$agent_file" ]; then
  echo "ERROR: $agent_file not found (run from the repo root)." >&2
  exit 2
fi

# --- Reconstruct the reviewer from its agent file ------------------------------
# Model: from frontmatter unless overridden. Body: everything after frontmatter.
model="${MODEL:-$(awk -F': *' '/^model:/{print $2; exit}' "$agent_file")}"
model="${model:-haiku}"
agent_body="$(awk 'f&&/^---[[:space:]]*$/{f=2;next} /^---[[:space:]]*$/{if(!f){f=1;next}} f==2{print}' "$agent_file")"

# --- Metric accumulators ------------------------------------------------------
tp=0 fp=0 fn=0
n_fixtures=0 n_failed=0
declare -a rows=()

# Ask the reviewer to judge one diff. Echoes its raw Output Contract text.
run_reviewer() {
  local diff_content="$1"
  local prompt
  prompt="$(cat <<PROMPT
You are acting AS the specialized review agent specified below. Follow its
instructions exactly, especially its Output Contract. Do NOT use any tools and do
NOT try to read files from disk — base your review solely on the diff provided.
Treat the diff as the complete changeset against the merge base.

===== AGENT SPECIFICATION =====
$agent_body
===== END AGENT SPECIFICATION =====

Review this diff and respond in EXACTLY the Output Contract format:

\`\`\`diff
$diff_content
\`\`\`
PROMPT
)"
  # Run from a scratch dir so the agent has no repo to snoop even if it ignores
  # the no-tools instruction.
  ( cd "$(mktemp -d)" && claude -p "$prompt" --model "$model" 2>/dev/null )
}

for dir in "$fixtures_root"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  [ -n "$filter" ] && [[ "$name" != *"$filter"* ]] && continue
  n_fixtures=$((n_fixtures + 1))

  exp="$dir/expected.json"
  exp_verdict="$(jq -r '.verdict' "$exp")"

  echo "▶ $name  (expect: $exp_verdict)"
  out="$(run_reviewer "$(cat "$dir/input.diff")")"

  # --- Parse the agent output -------------------------------------------------
  # Actual verdict: PASS only if the header says so AND no finding bullets exist.
  bullets=()
  while IFS= read -r line; do
    [ -n "$line" ] && bullets+=("$line")
  done < <(printf '%s\n' "$out" | grep -E '^[[:space:]]*-[[:space:]]+\*\*\[severity:' || true)
  n_actual=${#bullets[@]}
  if printf '%s' "$out" | grep -qiE '##.*supy-secrets-reviewer.*pass' && [ "$n_actual" -eq 0 ]; then
    act_verdict="pass"
  else
    act_verdict="issues"
  fi

  # --- Score ------------------------------------------------------------------
  fixture_ok=1
  notes=""

  if [ "$exp_verdict" = "pass" ]; then
    # Precision test: any reported finding is a false positive.
    if [ "$act_verdict" = "pass" ]; then
      notes="clean PASS ✓"
    else
      fixture_ok=0
      fp=$((fp + n_actual))
      notes="FALSE POSITIVE — reported $n_actual finding(s) on a clean diff"
    fi
  else
    # Recall test: every expected finding must be detected.
    local_matched=0
    n_exp="$(jq '.findings | length' "$exp")"
    # Track which actual bullets matched an expectation (for FP accounting).
    declare -a used=(); for ((i=0;i<n_actual;i++)); do used[i]=0; done

    while IFS= read -r f; do
      ef="$(jq -r '.file' <<<"$f")"; ef_base="$(basename "$ef")"
      el="$(jq -r '.line' <<<"$f")"
      exp_severity="$(jq -r '.severity' <<<"$f")"
      exp_rule="$(jq -r '.rule_contains // ""' <<<"$f")"

      hit=0
      for ((i=0;i<n_actual;i++)); do
        [ "${used[i]}" -eq 1 ] && continue
        b="${bullets[i]}"
        # Extract "path:line" token and severity from the bullet.
        fl="$(grep -oE '[A-Za-z0-9._/-]+:[0-9]+' <<<"$b" | head -n1)"
        af="${fl%:*}"; al="${fl##*:}"
        [ -z "$al" ] && continue
        act_severity="$(grep -oiE 'severity:[[:space:]]*(high|med|low)' <<<"$b" | grep -oiE '(high|med|low)$' | tr '[:upper:]' '[:lower:]')"
        # Match on file basename + line within tolerance.
        if [ "$(basename "$af")" = "$ef_base" ] && [ "$((al>el?al-el:el-al))" -le "$LINE_TOL" ]; then
          used[i]=1; hit=1; local_matched=$((local_matched + 1))
          [ -n "$exp_severity" ] && [ "$act_severity" != "$exp_severity" ] && notes+="[sev want $exp_severity got ${act_severity:-?}] "
          [ -n "$exp_rule" ] && ! grep -qiF "$exp_rule" <<<"$b" && notes+="[rule want '$exp_rule'] "
          break
        fi
      done
      if [ "$hit" -eq 0 ]; then
        fn=$((fn + 1)); fixture_ok=0
        notes+="MISSED $ef_base:$el ($exp_severity). "
      fi
    done < <(jq -c '.findings[]' "$exp")

    tp=$((tp + local_matched))
    # Any actual bullet that matched nothing expected is a false positive.
    for ((i=0;i<n_actual;i++)); do
      [ "${used[i]}" -eq 0 ] && fp=$((fp + 1)) && notes+="[extra finding] "
    done
    [ "$fixture_ok" -eq 1 ] && notes="detected $local_matched/$n_exp ✓ $notes"
  fi

  if [ "$fixture_ok" -eq 1 ]; then
    rows+=("PASS  $name  — $notes")
  else
    rows+=("FAIL  $name  — $notes")
    n_failed=$((n_failed + 1))
  fi
done

# --- Report -------------------------------------------------------------------
echo ""
echo "================ secrets-reviewer eval ================"
[ "${#rows[@]}" -gt 0 ] && for r in "${rows[@]}"; do echo "  $r"; done
echo "------------------------------------------------------"
precision="n/a"; recall="n/a"
[ $((tp + fp)) -gt 0 ] && precision="$(awk "BEGIN{printf \"%.2f\", $tp/($tp+$fp)}")"
[ $((tp + fn)) -gt 0 ] && recall="$(awk "BEGIN{printf \"%.2f\", $tp/($tp+$fn)}")"
echo "  fixtures: $n_fixtures   failed: $n_failed"
echo "  true-pos: $tp   false-pos: $fp   false-neg: $fn"
echo "  precision: $precision   recall: $recall   (model: $model)"
echo "======================================================"

[ "$n_failed" -eq 0 ]
