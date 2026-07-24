#!/usr/bin/env bash
# Render one coverage bar for a repo/package against its ci-coverage-baseline
# floor. Deterministic, offline, fixture-testable. The stack->floor mapping
# mirrors config/standards/ci-coverage-baseline.md.
#
# Usage:
#   render-coverage.sh --label <name> --floor <int> --lcov <path>
#   render-coverage.sh --label <name> --floor <int> --pct  <int>
#   render-coverage.sh --label <name> --stack <stack> --lcov <path>
#
# Exit: 0 when coverage >= floor, 1 when below, 2 on usage error.
set -uo pipefail

label="" floor="" pct="" lcov="" stack=""
while [ $# -gt 0 ]; do
  case "$1" in
    --label) label="${2:-}"; shift 2 ;;
    --floor) floor="${2:-}"; shift 2 ;;
    --pct)   pct="${2:-}";   shift 2 ;;
    --lcov)  lcov="${2:-}";  shift 2 ;;
    --stack) stack="${2:-}"; shift 2 ;;
    *) echo "render-coverage: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Stack -> floor, mirroring config/standards/ci-coverage-baseline.md.
if [ -z "$floor" ] && [ -n "$stack" ]; then
  case "$stack" in
    flutter-app)    floor=80 ;;
    flutter-melos)  floor=85 ;;
    flutter-plugin) floor=70 ;;
    *)              floor=0  ;;
  esac
fi

[ -n "$label" ] || { echo "render-coverage: --label required" >&2; exit 2; }
[ -n "$floor" ] || { echo "render-coverage: --floor or --stack required" >&2; exit 2; }

# Derive percentage from an lcov tracefile when not given directly.
if [ -z "$pct" ] && [ -n "$lcov" ]; then
  [ -f "$lcov" ] || { echo "render-coverage: lcov not found: $lcov" >&2; exit 2; }
  lf="$(awk -F: '/^LF:/{s+=$2} END{print s+0}' "$lcov")"
  lh="$(awk -F: '/^LH:/{s+=$2} END{print s+0}' "$lcov")"
  if [ "$lf" -gt 0 ]; then
    pct="$(awk "BEGIN{printf \"%d\", (100*$lh)/$lf}")"
  else
    pct=0
  fi
fi
[ -n "$pct" ] || { echo "render-coverage: --pct or --lcov required" >&2; exit 2; }

# 20-cell ASCII bar.
filled=$(( pct / 5 ))
[ "$filled" -gt 20 ] && filled=20
[ "$filled" -lt 0 ] && filled=0
bar=""
i=0
while [ "$i" -lt 20 ]; do
  if [ "$i" -lt "$filled" ]; then bar="${bar}#"; else bar="${bar}-"; fi
  i=$(( i + 1 ))
done

if [ "$pct" -ge "$floor" ]; then mark="PASS"; else mark="FAIL"; fi
printf '%-20s [%s] %3d%%  (floor %d%% %s)\n' "$label" "$bar" "$pct" "$floor" "$mark"

[ "$pct" -ge "$floor" ]
