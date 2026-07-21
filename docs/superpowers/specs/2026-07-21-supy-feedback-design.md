# supy-feedback — capture standards feedback and open a PR

**Date:** 2026-07-21
**Status:** Approved design, ready for planning

## Problem

While working in a Supy repo (backend, frontend, Flutter, etc.) the user often
discovers feedback about the engineering standards themselves — "we never use
Cubit, only Bloc", "secrets must never be in a ConfigMap", a wording fix, a new
rule. Today there is no path from *noticing* that in a working repo to *landing*
it in `supy-wingspan`, where the standards, skills, and agents live. The user
has to switch repos, remember the feedback, find the right file, and open a PR
by hand.

## Goal

From **any** Supy repo where the plugin is installed, let the user hand Claude a
piece of feedback and have it become a reviewed pull request against
`abed-supy-io/supy-wingspan` — targeting the correct standard (and only the
skill/agent that directly contradicts it), with provenance attached.

## Non-goals

- Not auto-merging. The PR is always human-reviewed on GitHub.
- Not batching or queuing feedback. One invocation → one PR.
- Not a hook that auto-detects "this looks like feedback". Invocation is
  explicit (`/supy-feedback` or asking Claude to file feedback).
- Not editing the installed plugin cache in place.

## Approach (chosen: temp clone + `gh`)

The skill does a shallow `gh repo clone abed-supy-io/supy-wingspan` into the
scratchpad directory, reads the **fresh** standards there (authoritative, not
the possibly-stale plugin cache), applies the edit, and opens the PR via `gh`.

Rejected alternatives:

- **GitHub API via `gh api`** (build blob→tree→commit→ref→PR without a clone):
  fiddly scripting, can't easily run the repo's markdownlint/cspell, and a clean
  local diff is harder to show.
- **Edit the plugin cache in place and push**: mutates the user's installed
  plugin, the cache checkout typically has no push remote / detached HEAD, and
  it drifts from GitHub.

## Components

Two new files, following the existing `supy-review` command→skill pattern. Both
are auto-discovered by directory; no `plugin.json` change is needed.

| Path | Purpose |
|---|---|
| `commands/supy-feedback.md` | Thin command. Invokes the skill, passing `$ARGUMENTS` as the feedback text. |
| `skills/supy-feedback/SKILL.md` | The decision procedure below. |

The command mirrors `commands/supy-review.md`: a short front-matter block with
`description` + `argument-hint`, then a body that invokes the skill at
`${CLAUDE_PLUGIN_ROOT}/skills/supy-feedback/SKILL.md`.

## Workflow (SKILL.md steps)

1. **Capture feedback + provenance.**
   - Feedback text: from `$ARGUMENTS`; if empty, from the recent conversation
     (ask the user to state it if unclear).
   - Provenance: current repo name (`basename` of `git rev-parse --show-toplevel`),
     detected stack (reuse the stack-detection logic / `detect-stack.sh` output
     if available; otherwise infer from the git remote or key files), and the
     triggering file/snippet if one is present in the conversation context.

2. **Clone fresh.** Shallow clone into the scratchpad:
   `gh repo clone abed-supy-io/supy-wingspan <scratch>/supy-wingspan -- --depth 1`.
   If this fails, fall back per the error-handling section.

3. **Map feedback → target file(s).** Read `config/standards/` (and, if relevant,
   `skills/` and `agents/`) in the clone. Prefer editing the standard — it is the
   source of truth per this repo's own working rule. Add a skill/agent file to
   the same change **only** when it directly contradicts the new rule. If no file
   is an obvious home, ask the user which area it belongs to rather than guessing.

4. **Draft the edit.** Apply the change in the clone. Keep the diff minimal and
   in the voice/format of the surrounding standard.

5. **Confirm with the user.** Show the target file(s) and the exact diff. Wait
   for explicit approval. The user may redirect the target file or reword. If
   they decline, stop without pushing.

6. **Land it.**
   - Branch: `feedback/<short-kebab-slug>`.
   - Commit type by nature of change, validated against
     `config/standards/commit-conventions.md`:
     `fix` (correcting a wrong rule), `feat` (new/stricter enforceable rule), or
     `docs` (clarification/wording). Use the `supy-commit` conventions.
   - Push the branch, run `gh pr create` with the title = commit subject and the
     body below, and return the PR URL to the user.

## PR body shape

```text
## What
<one-line summary of the rule change>

## Why
<the feedback, verbatim>

## Source
Repo: <repo-name> · Stack: <detected-stack>
Triggering example: <path:line> (omit if none)
```

## Error handling (silent, non-fatal — never crash a session)

| Condition | Behavior |
|---|---|
| `gh` not authenticated / no network | Stop before pushing. Print the proposed diff so the user can apply it manually. |
| Feedback maps to no obvious file | Ask the user which area (standard / skill / agent) it belongs to. |
| Clone fails | Fall back to reading the local plugin cache (`${CLAUDE_PLUGIN_ROOT}`) for mapping, still produce and show the diff, and tell the user the PR step needs a working `gh`. |
| Not in a git repo | Provenance degrades gracefully (no repo/stack/example); the feedback still flows. |

## Testing / validation

Per this repo's rule, a skill/command is not done until exercised in a real
session: install the checkout as a local marketplace, invoke `/supy-feedback`
from a repo of a known stack, and confirm (a) the correct standard is targeted,
(b) the diff is shown before any push, (c) a real PR opens with provenance, and
(d) the `gh`-unavailable path degrades to a printed diff without crashing.
