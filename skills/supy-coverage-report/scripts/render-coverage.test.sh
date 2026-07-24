#!/usr/bin/env bash
# TDD structure test for render-coverage.sh — offline, deterministic, no API key.
# Run from the repo root:
#   bash skills/supy-coverage-report/scripts/render-coverage.test.sh
set -uo pipefail

script="skills/supy-coverage-report/scripts/render-coverage.sh"
tmp="$(mktemp -d)"
fail=0

# (a) lcov tracefile at 82% (LH=41 / LF=50) -> "82%", PASS, exit 0.
cat > "$tmp/pass.info" <<'LCOV'
TN:
SF:lib/foo.dart
LF:50
LH:41
end_of_record
LCOV
got="$(bash "$script" --label supy-mobile --floor 80 --lcov "$tmp/pass.info")"; rc=$?
printf '%s\n' "$got" | grep -q '82%'  || { echo "FAIL(a): want 82% in: $got"; fail=1; }
printf '%s\n' "$got" | grep -q 'PASS' || { echo "FAIL(a): want PASS in: $got"; fail=1; }
[ "$rc" -eq 0 ] || { echo "FAIL(a): want exit 0 for above-floor, got $rc"; fail=1; }

# (b) lcov tracefile at 60% (LH=30 / LF=50) -> "60%", FAIL, exit 1.
cat > "$tmp/fail.info" <<'LCOV'
SF:lib/bar.dart
LF:50
LH:30
end_of_record
LCOV
got="$(bash "$script" --label checklist --floor 80 --lcov "$tmp/fail.info")"; rc=$?
printf '%s\n' "$got" | grep -q '60%'  || { echo "FAIL(b): want 60% in: $got"; fail=1; }
printf '%s\n' "$got" | grep -q 'FAIL' || { echo "FAIL(b): want FAIL in: $got"; fail=1; }
[ "$rc" -eq 1 ] || { echo "FAIL(b): want exit 1 for below-floor, got $rc"; fail=1; }

# (c) --stack flutter-melos resolves the floor to 85%.
got="$(bash "$script" --label pkgs --stack flutter-melos --pct 90)"; rc=$?
printf '%s\n' "$got" | grep -q 'floor 85%' || { echo "FAIL(c): want floor 85% in: $got"; fail=1; }

rm -rf "$tmp"
[ "$fail" -eq 0 ] && echo "render-coverage: all tests passed"
exit "$fail"
