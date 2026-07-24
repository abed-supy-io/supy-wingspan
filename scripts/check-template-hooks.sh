#!/usr/bin/env bash
# Gate for template hook hardening: every code stack's pre-commit must carry a
# gitleaks secret scan with a presence guard and a coverage-bar step, and every
# stack must ship a commit-msg hook that enforces Conventional Commits (via
# commitlint for husky stacks, via a shell regex for the plain-git flutter hook).
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
err() { echo "✗ $1"; fail=1; }
ok()  { echo "✓ $1"; }

coverage_ref="config/standards/ci-coverage-baseline.md"
commit_ref="config/standards/commit-conventions.md"
commit_types="build chore ci docs feat fix perf refactor revert style test"

# name:hookdir:style(husky|plain):expected coverage command substring
STACKS=(
  "ai-agents:.husky:husky:nx affected -t test --coverage"
  "firebase-functions:.husky:husky:npm --prefix functions test -- --coverage"
  "ts-cli:.husky:husky:npm test -- --coverage"
  "backend:.husky:husky:nx affected -t test --coverage"
  "frontend:.husky:husky:nx affected -t test --coverage"
  "flutter:hooks:plain:flutter test --coverage"
)

for entry in "${STACKS[@]}"; do
  IFS=':' read -r stack hookdir style covcmd <<< "$entry"
  pre="templates/$stack/$hookdir/pre-commit"
  msg="templates/$stack/$hookdir/commit-msg"
  stack_fail=0

  if [ ! -f "$pre" ]; then
    err "$stack: missing pre-commit hook ($pre)"
    stack_fail=1
  else
    grep -q "gitleaks protect" "$pre" || { err "$stack: pre-commit missing gitleaks secret scan"; stack_fail=1; }
    grep -q "command -v gitleaks" "$pre" || { err "$stack: pre-commit missing gitleaks presence guard"; stack_fail=1; }
    grep -qF "$coverage_ref" "$pre" || { err "$stack: pre-commit missing coverage-bar reference ($coverage_ref)"; stack_fail=1; }
    grep -qF "$covcmd" "$pre" || { err "$stack: pre-commit missing coverage command ($covcmd)"; stack_fail=1; }
  fi

  if [ ! -f "$msg" ]; then
    err "$stack: missing commit-msg hook ($msg)"
    stack_fail=1
  elif [ "$style" = "husky" ]; then
    grep -q "commitlint --edit" "$msg" || { err "$stack: commit-msg does not invoke commitlint"; stack_fail=1; }
  else
    grep -qF "$commit_ref" "$msg" || { err "$stack: commit-msg missing reference to $commit_ref"; stack_fail=1; }
    # Anchor the type-presence check on the line that actually defines the validation
    # regex, not the whole file — a type surviving only in a comment must not false-pass.
    regex_line=$(grep "type_regex=" "$msg")
    if [ -z "$regex_line" ]; then
      err "$stack: commit-msg has no type_regex= line to anchor the type-presence check on"
      stack_fail=1
    else
      missing_types=""
      for t in $commit_types; do
        echo "$regex_line" | grep -qw "$t" || missing_types="$missing_types $t"
      done
      [ -z "$missing_types" ] || { err "$stack: commit-msg missing conventional-commit type(s):$missing_types"; stack_fail=1; }
    fi
    grep -q "exit 1" "$msg" || { err "$stack: commit-msg does not exit non-zero on a bad type"; stack_fail=1; }
  fi

  [ "$stack_fail" -eq 0 ] && ok "$stack: hook set complete (secret scan + guard, commit-msg lint, coverage bar)"
done

[ "$fail" -eq 0 ] && ok "template-hooks checks passed"
exit "$fail"
