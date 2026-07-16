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

[ -z "$nudges" ] && exit 0

printf '%s\n%s' "supy-wingspan — the following Supy skill(s) apply to this request; prefer them over ad-hoc steps:" "$nudges"
exit 0
