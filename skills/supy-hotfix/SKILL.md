---
name: supy-hotfix
description: '[any] Drive an urgent production fix end to end — branch from the up-to-date base, make the smallest possible change, commit it as a conventional `fix`, run the review reviewers, and fast-track a PR. Enforces hotfix discipline (minimal diff, no scope creep, no banned `hotfix` commit type). Use when a production defect needs a targeted fix now on any supy-* repo.'
---

## Step 0 — Hotfix discipline

A hotfix is the **smallest change that resolves the specific defect** — nothing else. Before
touching code, state (to the user, in one line) the exact defect being fixed. Then hold the diff to
that. No refactors, no drive-by cleanups, no dependency bumps. Anything larger belongs in a normal
feature branch, not a hotfix.

Note the commit-type trap: Supy commitlint **rejects** `hotfix` as a type. A hotfix is committed as
`fix` (see `config/standards/commit-conventions.md`). The word "hotfix" lives in the branch name and
the PR context, never in the commit type.

---

## Step 1 — Resolve context and confirm the base

Capture the repo root, current branch, and the base to branch from:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE_BRANCH=$(bash "${CLAUDE_PLUGIN_ROOT}/skills/supy-rebase/scripts/detect-base-branch.sh")
```

If `git rev-parse` fails, stop and print:

```text
supy-hotfix: not inside a git repository — nothing to do
```

Confirm the base with the user — a hotfix must target whatever branch production deploys from,
which is usually the default branch but not always:

```text
supy-hotfix: production fixes will branch from <BASE_BRANCH>.
Is that the branch production deploys from? [Y/n]  (answer 'n' to name a different base)
```

If the user names a different base, use it. Record as `BASE_BRANCH`.

---

## Step 2 — Require a clean tree, then cut the hotfix branch

Refuse to start over uncommitted work:

```bash
git status --porcelain
```

If non-empty, stop and print:

```text
supy-hotfix: working tree is not clean.
Commit or stash your current work before starting a hotfix.
```

Fetch the freshest base and create the hotfix branch from it. Derive a short slug from the defect
(lower-case, hyphenated), and cut the branch directly from the remote base so the fix is not built
on stale code:

```bash
git fetch origin "${BASE_BRANCH}" 2>/dev/null || true
if git rev-parse --verify --quiet "origin/${BASE_BRANCH}" >/dev/null; then
  START_POINT="origin/${BASE_BRANCH}"
else
  START_POINT="${BASE_BRANCH}"
fi
git switch -c "hotfix/<slug>" "${START_POINT}"
```

Confirm the new branch and its start point to the user before editing.

---

## Step 3 — Make the minimal fix

Implement the smallest change that resolves the stated defect. As you go:

- Touch only the files required by the fix.
- Add or adjust the narrowest test that would have caught this defect, if the stack supports it.
- Do not reformat untouched lines or rename anything incidental.

Show the diff and confirm it is scoped to the defect before committing:

```bash
git diff
```

---

## Step 4 — Commit as a conventional `fix`

Stage the fix and invoke the `supy-commit` skill to produce a compliant message. The type will be
`fix`; the scope is the affected domain. Do not hand-write `hotfix:` — commitlint will reject it.

```bash
git add <files changed by the fix>
```

Then run `supy-commit`. It reads the commit standard, proposes the message, and commits only after
your confirmation.

---

## Step 5 — Review before it ships

Production changes still get reviewed. Invoke the `supy-review` skill so the stack-appropriate
reviewers and the always-on secrets reviewer run against the hotfix diff. Treat any high-severity
finding — especially a leaked secret — as blocking.

If `supy-review` surfaces a blocking finding, fix it (staying within hotfix scope) and re-commit
before proceeding.

---

## Step 6 — Fast-track the PR

Invoke the `supy-create-pr` skill to build and open the PR. In the PR description, make the urgency
and blast radius explicit by adding a leading note:

```text
> **Hotfix** — targeted production fix for <one-line defect>.
> Risk: <what this touches / does not touch>. Rollback: revert this PR.
```

Everything else follows the standard PR template `supy-create-pr` produces.

---

## Step 7 — Flag the follow-ups

A hotfix is not finished when it merges. Before closing out, remind the user (print this list):

```text
supy-hotfix: after this merges, confirm the follow-ups:
  1. The fix reaches every long-lived branch it needs to (e.g. main and any release/develop line)
     — a fix that only lands on one branch will regress on the next release.
  2. If a release tag is expected, let release-please open its PR (fix -> patch bump).
  3. Capture the root cause — consider running supy-debrief to record what happened and why.
```

---

## Degradation paths

**Not a git repository:** Detected in Step 1. Print and stop.

**Dirty working tree:** Detected in Step 2. Print and stop — never auto-stash.

**No remote to fetch:** Step 2 branches from the local base and continues. `supy-create-pr` (Step 6)
already degrades to printing a ready-to-paste PR when `gh`/remote are unavailable.

**Scope creep detected:** If the diff in Step 3 grows beyond the stated defect, stop and warn the
user that this should be a normal feature branch, not a hotfix. Do not silently expand scope.

**`detect-base-branch.sh` wrong for this repo:** Step 1 confirms the base with the user; override by
answering `n` and naming the correct branch.
