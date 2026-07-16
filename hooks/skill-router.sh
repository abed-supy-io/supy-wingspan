#!/usr/bin/env bash
# UserPromptSubmit hook: routes a Supy engineering intent to the skill that handles it.
# Soft nudge only — it never blocks the prompt and never fails the session. When the prompt
# matches no known intent it stays completely silent (no output, exit 0), so it adds nothing
# to context on ordinary turns.
set -u

# The prompt payload arrives as JSON on stdin. Degrade silently on any read error.
payload="$(cat 2>/dev/null || true)"
[ -z "$payload" ] && exit 0

# Lowercase copy for case-insensitive matching. Matching against the whole payload is safe:
# none of the JSON field names (prompt, session_id, hook_event_name, cwd) contain a trigger word.
p="$(printf '%s' "$payload" | tr '[:upper:]' '[:lower:]')"

has() { printf '%s' "$p" | grep -Eq "$1"; }

# Lightweight, cwd-based stack gate. Stack-specific nudges (Flutter, design) only fire in a repo of
# the matching stack, so a backend dev never sees Flutter suggestions and vice-versa. Universal
# nudges (commit/PR/review/rebase/hotfix/debrief/baseline/CI/spec) ignore this and always fire.
# Degrade open: if we can't tell the stack, don't suppress — a missing nudge is worse than an extra.
cwd="$(printf '%s' "$payload" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"//;s/"$//' | head -n1)"
IS_FLUTTER=unknown
IS_FRONTEND=unknown
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  if [ -f "$cwd/pubspec.yaml" ] || find "$cwd" -maxdepth 2 -name pubspec.yaml -not -path '*/.*' -not -path '*/build/*' 2>/dev/null | grep -q .; then
    IS_FLUTTER=yes
  else
    IS_FLUTTER=no
  fi
  if [ -f "$cwd/angular.json" ] || { [ -f "$cwd/nx.json" ] && grep -rqs '"@angular/core"' "$cwd/package.json" 2>/dev/null; }; then
    IS_FRONTEND=yes
  else
    IS_FRONTEND=no
  fi
fi
# True unless we positively know the stack is something else.
maybe_flutter() { [ "$IS_FLUTTER" != no ]; }
maybe_design()  { [ "$IS_FLUTTER" != no ] || [ "$IS_FRONTEND" != no ]; }

nudges=""
add() { nudges="${nudges}- ${1}
"; }

# Commit intent — always via the conventional-commit skill, never a raw git commit.
if has 'commit'; then
  add "Committing? Use the **supy-commit** skill — it writes a Conventional Commits message grounded in config/standards/commit-conventions.md and adds the Co-Authored-By trailer. Don't hand-write \`git commit -m\`."
fi

# Pull-request intent.
if has 'pull request|open (a|the) pr|raise (a|the) pr|create (a|the) pr|submit (a|the) pr'; then
  add "Opening a PR? Use the **supy-create-pr** skill for a conventional title + Summary/Changes/Test-evidence body."
fi

# Review intent.
if has 'review|check my (changes|diff|work)|before (i )?(commit|merge|push)'; then
  add "Reviewing changes? Run the **supy-review** skill — it detects the stack and dispatches the matching reviewers in parallel, then consolidates by severity."
fi

# Rebase / branch-update intent.
if has 'rebase|update (my )?branch|onto (main|master|develop)|catch up with (main|master)'; then
  add "Rebasing? Use the **supy-rebase** skill — clean-tree gate, a PRE_REBASE_SHA safety ref, one-commit-at-a-time conflict resolution, and --force-with-lease only after you confirm."
fi

# Hotfix intent.
if has 'hotfix|hot fix|production fix|prod fix|urgent fix|emergency fix'; then
  add "Shipping a hotfix? Use the **supy-hotfix** skill — cuts hotfix/<slug> from the remote base, keeps the diff minimal, commits as \`fix\`, then handles review, PR, and back-merge."
fi

# Debrief / handoff intent.
if has 'debrief|hand ?off|wrap ?up|retrospective|post ?mortem|summar(y|ise|ize) (the|my) (branch|work|changes)'; then
  add "Wrapping up? Use the **supy-debrief** skill — a structured handoff (context, what changed, why, verification, gaps, follow-ups) built from the actual commits and diff."
fi

# Baseline / CLAUDE.md intent.
if has 'baseline|claude\.md|onboard (this |the )?repo|generate .*standards'; then
  add "Setting up repo standards? Use the **supy-baseline** skill to generate or refresh this repo's CLAUDE.md from the canonical template + repo inspection."
fi

# Failing CI / GitHub Actions intent.
if has 'failing (ci|action|workflow|build|check)|ci (is )?fail|github action.*(fail|red|broken)|fix (the )?(ci|pipeline|workflow)|red (ci|build|check)'; then
  add "CI red? Use the **fix-failing-github-actions** skill — it pulls the failing run logs, fixes the root cause, and loops until the checks pass (delegating commit/PR to supy-commit and supy-create-pr)."
fi

# Spec authoring intent (implementation / spike specs from a ticket).
if has 'impl(ementation)? spec|spike (spec|ticket|investigat)|write (a |the )?spec|spec from (jira|ticket)|technical spec'; then
  add "Writing a spec? Use **supy-impl-spec** for an implementation spec or **supy-spike-spec** for a time-boxed investigation — both turn a Jira/GitHub ticket into a structured doc under docs/specs/."
fi

# Figma / design intent (frontend + Flutter repos only).
if maybe_design && has 'figma|design system|implement (the )?design|design token'; then
  add "Working from Figma? Use **supy-figma-implement-design** to build a design into Flutter (tokens, Widgetbook, goldens), or **supy-figma-to-tickets** to break a Figma flow into GitHub/Jira issues."
fi

# Whole-repo audit / assessment intent (Flutter/Dart + native — Flutter repos only).
if maybe_flutter && has 'code assessment|assess (the )?(code|repo|codebase)|audit (the )?(code|repo|codebase)|health check|native (code )?(audit|assessment)'; then
  add "Auditing a whole codebase? Use **supy-code-assessment** for a Flutter/Dart project audit, or **supy-analyze-native-codebase** for the native (Android/iOS) layers. For a single diff, use supy-review instead."
fi

# Release-readiness intent (Flutter repos only).
if maybe_flutter && has 'release readiness|ready to release|release check|store (submission|readiness)|app store review'; then
  add "Prepping a release? Use the **supy-app-release-readiness** skill — it audits each target platform (Android/iOS/web/desktop) in parallel and produces a RELEASE_TODO.md."
fi

# Flutter/SDK upgrade intent (Flutter repos only).
if maybe_flutter && has 'flutter upgrade|upgrade flutter|bump (the )?(flutter|dart) (sdk|version)|dart sdk upgrade'; then
  add "Bumping Flutter/Dart? Use the **supy-flutter-upgrade** skill — it updates pubspec/.fvmrc/workflows across every package, re-runs pub get + analyze, and reviews breaking-change notes."
fi

[ -z "$nudges" ] && exit 0

printf '%s\n%s' "supy-wingspan — the following Supy skill(s) apply to this request; prefer them over ad-hoc steps:" "$nudges"
exit 0
