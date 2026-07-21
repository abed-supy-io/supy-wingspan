---
name: supy-debrief
description: '[any] Produce a structured handoff/retrospective for the current branch or work session — what changed, why, how it was verified, what''s still open, and follow-ups — from the actual commits and diff. Outputs a ready-to-paste debrief and optionally saves it. Use to wrap up a branch before handing off, after a hotfix, or to capture decisions before context is lost on any supy-* repo.'
---

## Step 1 — Resolve what to debrief

Capture the repo root, branch, and base so the debrief covers exactly the work on this branch:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE_BRANCH=$(bash "${CLAUDE_PLUGIN_ROOT}/skills/supy-rebase/scripts/detect-base-branch.sh")
```

If `git rev-parse` fails, stop and print:

```text
supy-debrief: not inside a git repository — nothing to debrief
```

---

## Step 2 — Gather the raw material

Collect the objective record of the work. Do not invent anything not supported by these outputs.

```bash
# Commits unique to this branch
git log "${BASE_BRANCH}..HEAD" --format='%h %s'

# Shape of the change
git diff "${BASE_BRANCH}...HEAD" --stat

# Files touched, grouped mentally by area
git diff "${BASE_BRANCH}...HEAD" --name-status

# Anything still uncommitted (note it as work-in-progress)
git status --short
```

If `git log ${BASE_BRANCH}..HEAD` is empty AND the working tree is clean, print:

```text
supy-debrief: no commits ahead of <BASE_BRANCH> and a clean tree — nothing to debrief.
```

Then stop.

Read the diff itself where the commit subjects are not self-explanatory — the debrief must reflect
what actually changed, not just the commit headlines.

---

## Step 3 — Synthesize the debrief

Produce the debrief in this exact structure. Keep it factual and concise; lines ≤ 100 characters.

```markdown
# Debrief — <CURRENT_BRANCH>

## Context
<1–2 sentences: what problem this branch set out to solve, and the base it targets.>

## What changed
<Bulleted, grouped by area (agents / skills / config / standards / docs, or by domain).
Describe behaviour, not just filenames.>

## Why — decisions & trade-offs
<The non-obvious choices and why they were made. Alternatives considered and rejected.
This is the part that is lost if not written down now.>

## Verification
<How it was checked: tests added/run, lint/spell status, manual steps, or an honest
"not yet verified" with what remains.>

## Known gaps & risks
<What is intentionally not done, edge cases not covered, and the blast radius.>

## Follow-ups
<Concrete next actions, each as an actionable bullet. Link issues if known.>
```

Rules:

- Be honest about verification. If tests were not run, say so — do not imply green checks that
  did not happen.
- Never include secrets, tokens, or connection strings.
- If there is uncommitted work (Step 2), list it under "Known gaps & risks" as not yet committed.

---

## Step 4 — Output and offer to save

Print the completed debrief to the terminal as a fenced Markdown block so it can be pasted into a
PR description, an issue, or a message.

Then offer to persist it:

```text
supy-debrief: save this debrief to a file? [y/N]
If yes, default path: docs/debriefs/<CURRENT_BRANCH-with-slashes-as-dashes>.md
```

- If the user answers `y`/`yes`: write the debrief to the chosen path (create `docs/debriefs/` if
  needed), then print the path.
- Any other answer: do not write a file — the printed debrief is the deliverable.

Do not commit the file automatically; leave staging and committing to the user (or `supy-commit`).

---

## Degradation paths

**Not a git repository:** Detected in Step 1. Print and stop.

**No commits and clean tree:** Detected in Step 2. Print and stop.

**Detached HEAD / unusual branch name:** The debrief still works; use the short SHA in the title if
the branch name is empty or `HEAD`.

**`detect-base-branch.sh` wrong for this repo:** Override with `SUPY_BASE_BRANCH=<branch>` in the
environment before re-running, so the commit/diff range is correct.
