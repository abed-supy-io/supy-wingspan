#!/usr/bin/env bash
# SessionStart hook: detect stack, nudge missing Supy setup. Never fails the session.
set -u
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -z "$root" ] && exit 0
stack=""
if [ -f "$root/nx.json" ] && [ -f "$root/package.json" ]; then
  # Disambiguate the Nx flavour by its framework dependency.
  if grep -q '"@angular/core"' "$root/package.json"; then
    stack="angular-nx"
  elif grep -q '"@nestjs/core"' "$root/package.json"; then
    stack="nestjs-nx"
  else
    stack="nx"
  fi
fi
if [ -f "$root/pubspec.yaml" ]; then stack="flutter"; fi
[ -z "$stack" ] && exit 0   # unknown/mixed: stay silent
msg="supy-wingspan: detected $stack repo."
if [ ! -f "$root/CLAUDE.md" ]; then
  msg="$msg No CLAUDE.md found — run the supy-baseline skill to generate one."
fi
echo "$msg"
exit 0
