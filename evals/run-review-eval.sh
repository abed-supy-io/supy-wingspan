#!/usr/bin/env bash
# Behavioral eval for any Supy review agent, driven by each fixture's declared
# `reviewer` in expected.json. Generalized from run-secrets-eval.sh (now a
# thin shim over this).
#
# For each fixture under evals/fixtures/<dimension>/ (or every dimension, if
# none given), this reconstructs the reviewer from its own agents/<reviewer>.md
# — so the eval always tracks the real agent — feeds it the planted diff, and
# scores its Output Contract against expected.json:
#   - recall    (did it catch the planted findings?)   — false negatives are unsafe
#   - precision (did it stay silent on clean diffs?)    — false positives erode trust
#
# This is non-deterministic (it calls an LLM) and needs the `claude` CLI with
# working credentials, so it is NOT a default CI gate — run it locally or
# nightly. The deterministic fixture-structure check is validate-fixtures.sh;
# the deterministic scoring-math check is test-scorecard.sh.
#
# Usage:   bash evals/run-review-eval.sh [dimension] [fixture-name-substring]
# Env:     MODEL=<tier>   override the agent's declared model
#          LINE_TOL=<n>   line-number match tolerance (default 3)
set -uo pipefail

dimension="${1:-}"
filter="${2:-}"
LINE_TOL="${LINE_TOL:-3}"

# --- Pure scoring: expected-json + reviewer-output-text -> "tp fp fn" --------
# A planted (expected) finding is a TP if some actual finding shares its file
# basename and lands within LINE_TOL lines; otherwise it's an FN. Any actual
# finding left unmatched (including every one on a verdict:"pass" fixture,
# which plants none) is an FP. Prints exactly "tp fp fn" on stdout.
score_findings() {
  local exp_json="$1" out_text="$2"
  local tol="${LINE_TOL:-3}"

  local -a exp_files=() exp_lines=()
  while IFS=$'\t' read -r ef el; do
    [ -z "$ef" ] && continue
    exp_files+=("$ef")
    exp_lines+=("$el")
  done < <(jq -r '.findings[]? | [(.file|split("/")|last), .line] | @tsv' <<<"$exp_json")

  local -a act_files=() act_lines=()
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    local af="${tok%:*}" al="${tok##*:}"
    act_files+=("$(basename "$af")")
    act_lines+=("$al")
  done < <(grep -oE '[A-Za-z0-9._/-]+:[0-9]+' <<<"$out_text")

  local n_exp=${#exp_files[@]} n_act=${#act_files[@]}
  local -a used=()
  local i
  for ((i = 0; i < n_act; i++)); do used[i]=0; done

  local tp=0 fp=0 fn=0 e a hit dist
  for ((e = 0; e < n_exp; e++)); do
    hit=0
    for ((a = 0; a < n_act; a++)); do
      [ "${used[a]}" -eq 1 ] && continue
      if [ "${act_files[a]}" = "${exp_files[e]}" ]; then
        dist=$((act_lines[a] > exp_lines[e] ? act_lines[a] - exp_lines[e] : exp_lines[e] - act_lines[a]))
        if [ "$dist" -le "$tol" ]; then
          used[a]=1
          hit=1
          tp=$((tp + 1))
          break
        fi
      fi
    done
    [ "$hit" -eq 0 ] && fn=$((fn + 1))
  done
  for ((a = 0; a < n_act; a++)); do
    [ "${used[a]}" -eq 0 ] && fp=$((fp + 1))
  done

  echo "$tp $fp $fn"
}

if [ -z "${SCORECARD_LIB_ONLY:-}" ]; then

  if ! command -v claude >/dev/null 2>&1; then
    echo "SKIPPED: the 'claude' CLI is not on PATH — this eval needs it to invoke the reviewer."
    exit 0
  fi

  if [ -n "$dimension" ]; then
    fixture_roots=("evals/fixtures/$dimension")
  else
    fixture_roots=(evals/fixtures/*/)
  fi

  # Ask the reconstructed reviewer to judge one diff. Echoes its raw Output
  # Contract text.
  run_reviewer() {
    local prompt="$1" model="$2"
    # Run from a scratch dir so the agent has no repo to snoop even if it
    # ignores the no-tools instruction.
    (cd "$(mktemp -d)" && claude -p "$prompt" --model "$model" 2>/dev/null)
  }

  overall_failed=0

  for root in "${fixture_roots[@]}"; do
    [ -d "$root" ] || continue
    dim="$(basename "$root")"

    dim_tp=0 dim_fp=0 dim_fn=0 dim_n=0 dim_tokens=0
    declare -a rows=()

    for dir in "$root"/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      [ -n "$filter" ] && [[ "$name" != *"$filter"* ]] && continue

      exp_file="$dir/expected.json"
      [ -f "$exp_file" ] || continue
      exp_json="$(cat "$exp_file")"
      reviewer="$(jq -r '.reviewer' "$exp_file")"
      agent_file="agents/$reviewer.md"
      if [ ! -f "$agent_file" ]; then
        echo "ERROR: $agent_file not found for fixture $dim/$name (run from the repo root)." >&2
        overall_failed=$((overall_failed + 1))
        continue
      fi
      dim_n=$((dim_n + 1))

      # --- Reconstruct the reviewer from its agent file --------------------
      # Model: from frontmatter unless overridden. Body: everything after
      # frontmatter.
      model="${MODEL:-$(awk -F': *' '/^model:/{print $2; exit}' "$agent_file")}"
      model="${model:-haiku}"
      agent_body="$(awk 'f&&/^---[[:space:]]*$/{f=2;next} /^---[[:space:]]*$/{if(!f){f=1;next}} f==2{print}' "$agent_file")"
      diff_content="$(cat "$dir/input.diff")"

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

      echo "▶ [$dim] $name  (reviewer: $reviewer, model: $model)"
      out="$(run_reviewer "$prompt" "$model")"

      read -r ftp ffp ffn < <(score_findings "$exp_json" "$out")
      dim_tp=$((dim_tp + ftp))
      dim_fp=$((dim_fp + ffp))
      dim_fn=$((dim_fn + ffn))
      # Approximate token estimate: chars(prompt+output)/4, labelled as such.
      dim_tokens=$((dim_tokens + (${#prompt} + ${#out}) / 4))

      if [ "$ffp" -eq 0 ] && [ "$ffn" -eq 0 ]; then
        rows+=("PASS  $name  — tp=$ftp fp=$ffp fn=$ffn")
      else
        rows+=("FAIL  $name  — tp=$ftp fp=$ffp fn=$ffn")
        overall_failed=$((overall_failed + 1))
      fi
    done

    [ "$dim_n" -eq 0 ] && continue

    echo ""
    echo "================ $dim reviewer eval ================"
    if [ "${#rows[@]}" -gt 0 ]; then
      for r in "${rows[@]}"; do echo "  $r"; done
    fi
    echo "------------------------------------------------------"
    recall="n/a"
    precision="n/a"
    [ $((dim_tp + dim_fn)) -gt 0 ] && recall="$(awk "BEGIN{printf \"%.2f\", $dim_tp/($dim_tp+$dim_fn)}")"
    [ $((dim_tp + dim_fp)) -gt 0 ] && precision="$(awk "BEGIN{printf \"%.2f\", $dim_tp/($dim_tp+$dim_fp)}")"
    echo "$dim  fixtures=$dim_n  TP=$dim_tp FP=$dim_fp missed=$dim_fn  recall=$recall precision=$precision  ~tokens=$dim_tokens"
    echo "======================================================"
  done

  [ "$overall_failed" -eq 0 ]
fi
