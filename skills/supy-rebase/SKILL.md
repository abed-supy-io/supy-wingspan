---
name: supy-rebase
description: '[any] Safely rebase the current branch onto its integration base (auto-detected default branch). Snapshots a safety ref, fetches the latest base, rebases, and walks conflicts one commit at a time — never force-pushing without explicit confirmation. Use to bring a feature branch up to date before review or merge on any supy-* repo.'
---

## Step 1 — Resolve the branch context

Capture the repo root, current branch, and base branch:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE_BRANCH=$(bash "${CLAUDE_PLUGIN_ROOT}/skills/supy-rebase/scripts/detect-base-branch.sh")
```

If `git rev-parse` fails (not a git repo), stop and print:

```text
supy-rebase: not inside a git repository — nothing to do
```

If `CURRENT_BRANCH` equals `BASE_BRANCH`, stop and print:

```text
supy-rebase: already on the base branch (<BASE_BRANCH>) — nothing to rebase.
Switch to your feature branch and re-run.
```

If `CURRENT_BRANCH` is `HEAD` (detached), stop and print:

```text
supy-rebase: HEAD is detached — check out a named branch before rebasing.
```

---

## Step 2 — Require a clean working tree

A rebase must not run over uncommitted work. Check:

```bash
git status --porcelain
```

If this produces any output, stop and print:

```text
supy-rebase: working tree is not clean.
Commit (try supy-commit) or stash your changes, then re-run.
```

Do not auto-stash. The user decides what to do with pending work.

---

## Step 3 — Record a safety ref and fetch the base

Before rewriting history, record where the branch currently points so it can always be recovered:

```bash
PRE_REBASE_SHA=$(git rev-parse HEAD)
echo "supy-rebase: safety ref — if anything goes wrong, run: git reset --hard ${PRE_REBASE_SHA}"
```

Fetch the latest base from the remote (tolerate no-remote):

```bash
git fetch origin "${BASE_BRANCH}" 2>/dev/null || echo "supy-rebase: no remote fetch — rebasing onto local ${BASE_BRANCH}"
```

Determine the rebase target: prefer the freshly-fetched remote ref, fall back to the local branch:

```bash
if git rev-parse --verify --quiet "origin/${BASE_BRANCH}" >/dev/null; then
  TARGET="origin/${BASE_BRANCH}"
else
  TARGET="${BASE_BRANCH}"
fi
```

Show how far behind/ahead the branch is so the user understands the scope:

```bash
git log --oneline "${TARGET}..HEAD"   # commits that will be replayed
git log --oneline "HEAD..${TARGET}"   # commits being caught up to
```

If there are no commits to catch up to (`HEAD..${TARGET}` is empty), print:

```text
supy-rebase: <CURRENT_BRANCH> is already up to date with <TARGET> — nothing to do.
```

Then stop.

---

## Step 4 — Rebase

Run the rebase onto the target:

```bash
git rebase "${TARGET}"
```

- **Clean rebase (exit 0):** proceed to Step 6.
- **Conflicts (non-zero exit):** proceed to Step 5.

---

## Step 5 — Resolve conflicts one commit at a time

If the rebase stops on a conflict, do not abandon it silently. For each conflicted step:

1. List the conflicts:

```bash
git status --short | grep '^UU\|^AA\|^DD\|^U\|^A\|^D'
git diff --name-only --diff-filter=U
```

2. Resolve each file, preserving BOTH the base's intent and the branch's intent — never blindly take one side. Read the surrounding code and reconcile.
3. Stage the resolved files and continue:

```bash
git add <resolved files>
git rebase --continue
```

Repeat until the rebase completes or the user chooses to stop.

If conflicts are too complex or the user wants out, abort cleanly — this restores the pre-rebase state exactly:

```bash
git rebase --abort
```

After an abort, print:

```text
supy-rebase: rebase aborted — branch restored to its pre-rebase state (<PRE_REBASE_SHA>).
```

Never run `git rebase --skip` unless the user explicitly asks — skipping silently drops a commit.

---

## Step 6 — Verify, then handle the push

After a successful rebase, confirm the result:

```bash
git log --oneline "${TARGET}..HEAD"
git status
```

A rebased branch that was already pushed has diverged from its remote and needs a force push. **Never force-push without explicit confirmation.** Present:

```text
supy-rebase: <CURRENT_BRANCH> was rebased onto <TARGET>.

If this branch was already pushed, updating the remote requires a force push.
Use the safe form (refuses to overwrite others' work):

  git push --force-with-lease origin <CURRENT_BRANCH>

Force-push now? [y/N]
```

- If the user answers `y`/`yes` and an upstream/remote exists: run the `--force-with-lease` push above.
- Any other answer: stop and print the command for them to run later. Do not push.

Never use a bare `git push --force`; always `--force-with-lease`.

---

## Degradation paths

**Not a git repository:** Detected in Step 1. Print and stop.

**On the base branch / detached HEAD:** Detected in Step 1. Print and stop.

**Dirty working tree:** Detected in Step 2. Print and stop — never auto-stash.

**No remote:** Step 3 rebases onto the local base branch and notes it. Step 6 skips the push prompt if no upstream exists.

**Conflicts:** Handled interactively in Step 5. `git rebase --abort` always restores the pre-rebase state recorded in Step 3.

**`detect-base-branch.sh` unavailable or wrong:** The script always prints a branch (falls back to `main`). If the detected base is wrong for this repo, re-run with an override: `SUPY_BASE_BRANCH=<branch>` in the environment.
