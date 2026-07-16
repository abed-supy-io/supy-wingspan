#!/usr/bin/env bash
# Print the branch this repo should be rebased onto (the integration base).
#
# Resolution order:
#   1. Explicit override: $SUPY_BASE_BRANCH, if set and non-empty.
#   2. The remote's default branch (origin/HEAD -> refs/remotes/origin/<base>).
#   3. `git remote show origin` "HEAD branch".
#   4. First existing of: main, master, develop.
#   5. Fallback: main.
#
# Prints exactly one branch name to stdout and exits 0. Never fails the caller:
# on any error it degrades to the next candidate. Diagnostics go to stderr.
set -uo pipefail

log() { echo "detect-base-branch: $*" >&2; }

# 1. Explicit override.
if [ -n "${SUPY_BASE_BRANCH:-}" ]; then
  echo "$SUPY_BASE_BRANCH"
  exit 0
fi

# Must be inside a work tree; if not, fall back to main.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "not inside a git work tree — falling back to 'main'"
  echo "main"
  exit 0
fi

# 2. origin/HEAD symbolic ref (fast, no network).
base="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
if [ -n "$base" ]; then
  echo "$base"
  exit 0
fi

# 3. Ask the remote (may hit the network; tolerate failure).
base="$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')"
if [ -n "$base" ] && [ "$base" != "(unknown)" ]; then
  echo "$base"
  exit 0
fi

# 4. First conventional base branch that exists locally or on the remote.
for candidate in main master develop; do
  if git show-ref --verify --quiet "refs/heads/$candidate" \
    || git show-ref --verify --quiet "refs/remotes/origin/$candidate"; then
    echo "$candidate"
    exit 0
  fi
done

# 5. Give up gracefully.
log "could not detect a base branch — falling back to 'main'"
echo "main"
exit 0
