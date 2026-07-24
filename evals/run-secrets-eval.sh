#!/usr/bin/env bash
# Behavioral eval for supy-secrets-reviewer. Now a thin shim over the generic
# runner — kept for back-compat and discoverability.
#   Usage: bash evals/run-secrets-eval.sh [fixture-name-substring]
set -uo pipefail
exec bash "$(dirname "$0")/run-review-eval.sh" secrets "$@"
