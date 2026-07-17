#!/usr/bin/env bash
# verify-pilots.sh — offline structural check for the E1 pilot artifacts.
# No subagents, no network. Run from anywhere in the repo:
#   bash docs/pilots/verify-pilots.sh
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RUNBOOK="$ROOT/docs/pilots/RUNBOOK.md"
RESULTS="$ROOT/docs/pilots/RESULTS-TEMPLATE.md"
TRIAGE="$ROOT/docs/pilots/TRIAGE.md"
DETECT="$ROOT/hooks/detect-stack.sh"
PILOT="$ROOT/docs/PILOT.md"

fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

# Canonical pilot enumeration: "repo|SessionStart substring|reviewer count"
PILOTS=(
  "supy-service-inventory|detected nestjs-nx repo.|6"
  "supy-frontend|detected angular-nx repo.|3"
  "supy-mobile|detected flutter repo.|3"
  "checklist|detected flutter repo.|3"
  "supy-firebase-functions|detected firebase-functions repo (standalone, non-Nx)|3"
  "supy-cli|detected ts-cli repo (standalone commander.js MongoDB scripts runner)|3"
  "supy-ai-agents|detected ai-agents repo (polyglot MCP/agents monorepo, no root orchestration)|3"
  "supy-configmaps|detected k8s-config repo. Secrets MUST live in a Secret/external-secret|2"
)

# Special-stack messages that MUST also appear verbatim in detect-stack.sh
# (guards runbook<->detector drift for the four non-default messages).
SPECIAL_SUBSTRINGS=(
  "detected firebase-functions repo (standalone, non-Nx)"
  "detected ts-cli repo (standalone commander.js MongoDB scripts runner)"
  "detected ai-agents repo (polyglot MCP/agents monorepo, no root orchestration)"
  "detected k8s-config repo. Secrets MUST live in a Secret/external-secret"
)

# --- Check A: runbook exists and covers every pilot repo ---
if [ ! -f "$RUNBOOK" ]; then
  err "runbook missing: $RUNBOOK"
else
  ok "runbook present"
  for row in "${PILOTS[@]}"; do
    repo="${row%%|*}"
    grep -qF "$repo" "$RUNBOOK" || err "runbook missing pilot repo: $repo"
  done
fi

# --- Check B: each pilot's SessionStart substring is in the runbook;
#     the four special-stack messages must also appear verbatim in the detector. ---
if [ -f "$RUNBOOK" ]; then
  for row in "${PILOTS[@]}"; do
    rest="${row#*|}"; sub="${rest%|*}"
    grep -qF "$sub" "$RUNBOOK" || err "runbook missing SessionStart line: $sub"
  done
fi
for sub in "${SPECIAL_SUBSTRINGS[@]}"; do
  grep -qF "$sub" "$DETECT" || err "detector drift — not in detect-stack.sh: $sub"
done

# --- Check C: the runbook names every expected reviewer (documents dispatch sets). ---
REVIEWERS=(
  supy-architecture-reviewer supy-nats-event-reviewer supy-test-quality-reviewer
  supy-security-reviewer supy-angular-reviewer supy-flutter-reviewer
  supy-firebase-functions-reviewer supy-ts-cli-reviewer supy-ai-agents-reviewer
  supy-commit-pr-reviewer supy-secrets-reviewer
)
if [ -f "$RUNBOOK" ]; then
  for r in "${REVIEWERS[@]}"; do
    grep -qF "$r" "$RUNBOOK" || err "runbook does not name reviewer: $r"
  done
fi

# --- Check D: results template exists and carries every required field. ---
RESULT_FIELDS=(
  "Pilot repo" "Stack" "Plugin commit" "Install succeeded"
  "SessionStart line observed" "Matches expected" "Reviewers that ran"
  "Review report header" "Findings triage" "Token baseline"
  "supy-commit message" "Trailer present" "Pushed" "Asset-fix actions" "Pilot passed"
)
if [ ! -f "$RESULTS" ]; then
  err "results template missing: $RESULTS"
else
  ok "results template present"
  for f in "${RESULT_FIELDS[@]}"; do
    grep -qF "$f" "$RESULTS" || err "results template missing field: $f"
  done
fi

# --- Check E: PILOT.md carries a per-stack tracker linking to the runbook. ---
if grep -qF "Per-stack pilot tracker" "$PILOT"; then
  ok "PILOT.md has per-stack tracker"
  for row in "${PILOTS[@]}"; do
    repo="${row%%|*}"
    grep -qF "$repo" "$PILOT" || err "PILOT.md tracker missing pilot repo: $repo"
  done
  grep -qF "pilots/RUNBOOK.md" "$PILOT" || err "PILOT.md tracker does not link to the runbook"
  grep -qiF "token baseline" "$PILOT" || err "PILOT.md tracker missing token-baseline column"
else
  err "PILOT.md missing 'Per-stack pilot tracker' section"
fi

# --- Check F: secret-scan the pilot docs (fail closed; never print the value). ---
SECRET_RE='AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z-]+|ghp_[0-9A-Za-z]{36}'
for f in "$RUNBOOK" "$RESULTS" "$TRIAGE"; do
  [ -f "$f" ] || continue
  if grep -Eq "$SECRET_RE" "$f"; then
    err "possible secret literal in $f (cite path:line, never the value)"
  fi
done
ok "secret scan clean"

# --- Check G: runbook references its sibling artifacts (link integrity). ---
if [ -f "$RUNBOOK" ]; then
  grep -qF "RESULTS-TEMPLATE.md" "$RUNBOOK" || err "runbook does not reference RESULTS-TEMPLATE.md"
  grep -qF "TRIAGE.md" "$RUNBOOK" || err "runbook does not reference TRIAGE.md"
fi

# --- Check H: triage protocol exists and names its core concepts. ---
if [ ! -f "$TRIAGE" ]; then
  err "triage protocol missing: $TRIAGE"
else
  ok "triage protocol present"
  for kw in "true positive" "false positive" "missed" "token baseline" "tick"; do
    grep -qiF "$kw" "$TRIAGE" || err "triage protocol missing concept: $kw"
  done
fi

if [ "$fail" -ne 0 ]; then
  echo "verify-pilots: FAILED"
  exit 1
fi
echo "verify-pilots: all checks passed"
exit 0
