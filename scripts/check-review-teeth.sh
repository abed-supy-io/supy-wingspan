#!/usr/bin/env bash
# Deterministic gate for R2 "review teeth": verification protocol + severity log.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
err() { echo "✗ $1"; fail=1; }
ok()  { echo "✓ $1"; }

skill="skills/supy-review/SKILL.md"
ref="skills/shared/references/adversarial-verification.md"

# --- Check V: gated adversarial verification is documented. ---
[ -f "$ref" ] || err "missing $ref"
grep -q "adversarial-verification.md" "$skill" || err "$skill does not link the verification reference"
grep -qiE "high-severity|low-confidence" "$skill" || err "$skill does not state the verification gate (high/low-confidence)"
grep -qiE "budget|degrade|unverified" "$skill" || err "$skill does not state the budget/degradation guard"

# --- Check C: severity calibration log is present (R1 traceability). ---
sev="config/standards/review-severity.md"
grep -qi "Calibration log" "$sev" || err "$sev has no 'Calibration log' section (R1 traceability)"

[ "$fail" -eq 0 ] && ok "review-teeth checks passed"
exit "$fail"
