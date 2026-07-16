---
name: fix-failing-github-actions
description: Finds failing GitHub Actions checks for the current branch or PR, fixes the root cause, commits and pushes using Supy conventions, then re-checks after a short wait — looping until every check is green. Use when asked to fix failing CI, fix status checks, fix GitHub Actions, or get the branch green. Stack-agnostic — works in any repo/CI.
---

## When this applies

Any time the current branch has failing GitHub Actions checks (on a PR or on a bare push) and the
goal is to get them green — regardless of stack or language.

## Prerequisites

- `gh` CLI installed and authenticated.
- The current branch is pushed, or a push target is known (e.g. `origin/<branch>`).
- Repository `owner`/`repo` resolvable from `git remote get-url origin` or PR context.

## The loop

Repeat steps 1–6 until every check passes. Cap total wait time (e.g. 10–15 minutes) and re-evaluate
with the user if checks are still pending past that point.

### 1. Resolve branch, PR, and repo context

```bash
git branch --show-current
gh pr view --json number,url 2>/dev/null
git remote get-url origin
```

If no PR exists yet, continue with branch-only checks (step 2 still works against `gh run list`).

### 2. Find the failing checks

```bash
gh run list --branch <branch> --limit 10
```

For any run with status `failure`:

```bash
gh run view <run_id>
gh run view <run_id> --log-failed
```

Use the job names, annotations, and failed step names to decide what to fix. If a GitHub MCP server
is available, `pull_request_read` with `method: "get_status"` (plus `owner`, `repo`, `pullNumber`)
gives a quicker overall pass/fail/pending summary before drilling into `gh run view`.

### 3. Fix the root cause

Match the fix to the failing job, for example:

- **Spell check** (e.g. cspell): add genuinely intentional words to the project's spell-check
  dictionary; fix real typos in the reported files rather than suppressing the check.
- **Lint / format:** run the project's own lint and format commands (from `package.json` scripts,
  a `Makefile`, or CI workflow file) and apply auto-fixes where the tool supports them.
- **Build / compile / test failures:** read the failing test or compiler output from
  `gh run view --log-failed` and fix the actual bug — do not skip or delete the failing test.
- **Dependency / workspace bootstrap issues:** re-run the repo's install/bootstrap command
  (`npm ci`, `pnpm install`, or the monorepo tool's bootstrap command) if the failure is a stale
  lockfile or missing workspace link.
- **PR title / commit lint (semantic PR check):** align the PR title or commit header with this
  repo's Conventional Commits rule — see the **supy-commit** skill for the exact type/scope/subject
  format.

Prefer fixing the root cause over silencing the check. Only widen an allowlist (spell-check
dictionary, lint ignore rule) when the flagged term or pattern is genuinely intentional.

**Security:** never paste a secret, token, or credential into a fix, a log excerpt you quote, or a
commit message — even if it appears in the CI failure output. If a check is failing because a
secret was committed, replace it with a placeholder and flag it to the user instead of resolving it
silently.

### 4. Commit and push

Stage only the files that address the failure (`git add <paths>`, or `git add -p` for partial
files). Use the **supy-commit** skill to build and confirm a Conventional Commits message (with the
`Co-Authored-By` trailer) instead of committing free-form — do not bypass its confirmation step.

Push the branch:

```bash
git push origin <branch>
```

If no PR exists yet and one should be opened, use the **supy-create-pr** skill rather than calling
`gh pr create` directly — it builds a conventional title/description from the branch's commits and
handles the no-remote / no-`gh` degradation path.

### 5. Wait and re-check

```bash
sleep 60
gh run list --branch <branch> --limit 5
```

Or, if using the GitHub MCP server, call `pull_request_read` with `method: "get_status"` again.

### 6. Decide and loop

- **All checks passed:** done — report the green status and stop.
- **Any check still failed:** go back to step 2 with the latest run IDs, then 3, 4, 5, 6.
- **Checks still pending:** wait another minute and re-check (repeat step 5 then 6), up to the
  overall cap from the loop's opening note.

## Conventions

- Fix commits should be small and scoped to one kind of failure (lint vs. tests vs. spell-check) —
  do not bundle unrelated fixes into one commit.
- Every commit goes through the **supy-commit** skill; every new PR goes through the
  **supy-create-pr** skill. Both enforce this repo's Conventional Commits rules and append the
  `Co-Authored-By` trailer — do not hand-roll `git commit -m` or `gh pr create` in this loop.
- When calling GitHub MCP `pull_request_read`, always pass `method`, `owner`, `repo`, and
  `pullNumber`. Resolve the PR number with
  `gh pr list --head <branch> --json number -q '.[0].number'` if it is not already known.

## Degradation paths

**No `gh` CLI or not authenticated:** stop and tell the user to install/authenticate `gh`
(`https://cli.github.com`) — this skill cannot inspect or re-check runs without it.

**No PR open yet:** continue using branch-only checks (`gh run list --branch <branch>`); skip the
`pull_request_read` calls that require a PR number.

**Checks pending past the wait cap:** stop looping automatically and report the current status to
the user rather than waiting indefinitely.
