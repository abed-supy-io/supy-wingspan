#!/usr/bin/env bash
# Deterministic unit test for the scorecard math in run-review-eval.sh.
# No LLM, no network — feeds canned reviewer output through score_findings.
set -uo pipefail
SCORECARD_LIB_ONLY=1 . evals/run-review-eval.sh
fail=0
check() { # label expected actual
  if [ "$2" = "$3" ]; then echo "ok:   $1"; else echo "FAIL: $1 (want $2, got $3)"; fail=1; fi
}

# Expected: one high finding at file.ts:10. Reviewer output that catches it exactly.
exp='{"verdict":"issues","findings":[{"file":"file.ts","line":10,"severity":"high","rule_contains":"layer"}]}'
got_hit=$'ISSUE file.ts:10 high — layer violation'
read -r tp fp fn < <(score_findings "$exp" "$got_hit")
check "exact match -> tp" 1 "$tp"; check "exact match -> fp" 0 "$fp"; check "exact match -> fn" 0 "$fn"

# Reviewer stays silent -> the planted issue is missed.
read -r tp fp fn < <(score_findings "$exp" "no issues found")
check "silence -> fn" 1 "$fn"; check "silence -> tp" 0 "$tp"

# Clean fixture, reviewer over-fires -> false positive.
clean='{"verdict":"pass","findings":[]}'
read -r tp fp fn < <(score_findings "$clean" $'ISSUE file.ts:3 med — nit')
check "over-fire -> fp" 1 "$fp"; check "over-fire on clean -> fn" 0 "$fn"

# shellcheck disable=SC2015 # echo can't fail; not an if/then/else footgun here.
[ "$fail" -eq 0 ] && echo "test-scorecard: all passed" || { echo "test-scorecard: FAILED"; exit 1; }
