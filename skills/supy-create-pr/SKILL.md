---
name: supy-create-pr
description: Build a conventional PR title and description from branch commits and diff, enforce Supy commit-type rules, and either open the PR via gh or output a ready-to-paste title+body for manual creation. Use after supy-review passes on a supy-* backend repo.
---

## Step 1 — Read the governing standard

Read the Supy commit conventions so the PR title type is validated against the same rules as commit messages:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/commit-conventions.md"
```

Internalize the allowed types, formatting rules, and red flags. The allowed types are: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`. Do not use `bug`, `hotfix`, `wip`, or any type not in this list.

---

## Step 2 — Resolve the branch context

Capture the repo root and current branch:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
```

If `git rev-parse` fails (not a git repo), stop and print:

```
supy-create-pr: not inside a git repository — nothing to do
```

Determine the base branch. Try, in order:

```bash
# Try to detect the default branch from the remote
git remote show origin 2>/dev/null | grep "HEAD branch" | awk '{print $NF}'
```

If that yields nothing (no remote or command fails), fall back to `main`. Capture as `BASE_BRANCH`.

Collect all commits on this branch that are not yet in `BASE_BRANCH`:

```bash
git log ${BASE_BRANCH}..HEAD --oneline
```

If this produces no output (no commits ahead of base), print:

```
supy-create-pr: no commits found ahead of <BASE_BRANCH>.
Make sure you have committed your changes (try supy-commit) and are on the correct branch.
```

Then stop.

Also read the full diff for context:

```bash
git diff ${BASE_BRANCH}...HEAD --stat
git diff ${BASE_BRANCH}...HEAD
```

---

## Step 3 — Probe environment (remote and gh availability)

Run these checks and record the results — they determine Step 6's execution path:

```bash
# Check for any configured remote
HAS_REMOTE=$(git remote | grep -q . && echo true || echo false)

# Check whether the gh CLI is available
HAS_GH=$(command -v gh >/dev/null 2>&1 && echo true || echo false)

# Check whether an upstream tracking branch exists
HAS_UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 && echo true || echo false)
```

Do not abort at this point. Record the values. The degradation decision is made in Step 6.

---

## Step 4 — Build the PR title

Analyse the commits and diff. Choose a single conventional type that best represents the dominant change:

1. **Type**: one of `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`. Never use `bug`, `hotfix`, or `wip`.
2. **Scope**: derive from the primary domain affected. Use comma-separated scopes only if the PR genuinely spans two domains equally. Omit scope when the change is cross-cutting with no dominant domain.
3. **Subject**: lower-case, imperative mood, no trailing full stop, does not start with a capital letter. Total header (type + scope + subject) ≤ 100 characters.

The PR title follows the same format as a commit header:

```
<type>(<scope>): <subject>
```

Examples of valid PR titles:
- `feat(ledger): add stock-movement RPC handler`
- `fix(item): correct unit conversion in output transformer`
- `refactor(recipe,wastage): migrate write side to CQRS commands layer`

---

## Step 5 — Build the PR description

Compose a structured PR description in Markdown using the commits and diff. Use this template:

```markdown
## Summary

<1–3 bullet points describing what changed and why — the motivation, not just the mechanics>

## Changes

<bulleted list of concrete changes, grouped by file or domain if the PR is large>

## Test evidence

<describe what was tested: unit tests added/updated, manual verification steps, or note if no automated tests were added and why>

## Issue references

<list any linked issues: "closes #N" or "relates to #N"; omit this section if none>
```

Rules for the description:
- Each line ≤ 100 characters.
- Body must explain motivation, not just repeat the diff.
- Do not include secrets, tokens, or connection strings.
- Append the Co-Authored-By footer after the last section:

```
---
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

---

## Step 6 — Open PR or output for manual creation

Use the values recorded in Step 3 to choose the execution path.

### Path A — `gh` available AND remote exists AND upstream is set

Push the current branch and open a PR:

```bash
REMOTE=$(git remote | head -1)
git push -u "${REMOTE}" ${CURRENT_BRANCH}
gh pr create \
  --title "<PR title from Step 4>" \
  --body "$(cat <<'EOF'
<PR description from Step 5>
EOF
)"
```

After `gh pr create` succeeds, print the PR URL returned by `gh`.

If `git push` fails (e.g., permission denied, branch protection), print the error and fall through to Path B — do not abort.

### Path B — `gh` unavailable OR no remote OR no upstream (degradation)

Do not attempt to push or call `gh`. Instead, print the following to the terminal so the user can paste it directly:

```
supy-create-pr: gh CLI is unavailable or no remote is configured — outputting PR details for manual creation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PR TITLE (copy this line):

<PR title from Step 4>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PR DESCRIPTION (copy everything below):

<PR description from Step 5>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

To create the PR manually:
1. Push your branch:  git push -u <remote> <branch>
2. Open a PR in your Git host (GitHub / GitLab / Bitbucket).
3. Paste the title and description above.
```

Print the reason for degradation as one of:
- `gh CLI not found (install from https://cli.github.com)`
- `no git remote configured (add one with: git remote add origin <url>)`
- `branch has no upstream tracking ref (push with: git push -u origin <branch>)`

---

## Degradation paths

**Not a git repository:** Detected in Step 2. Print the message and stop.

**No commits ahead of base:** Detected in Step 2. Print the message and stop.

**`gh` unavailable:** Detected in Step 3. Executed via Path B in Step 6. Always outputs a complete, ready-to-paste PR title and description — never errors out.

**No remote configured:** Detected in Step 3. Executed via Path B. Same as above.

**No upstream tracking ref:** Detected in Step 3. Executed via Path B. Same as above.

**`git push` fails in Path A:** Fall through to Path B and output the PR details for manual creation. Print the push error so the user knows what went wrong.

**`${CLAUDE_PLUGIN_ROOT}/config/standards/commit-conventions.md` unreadable:** Warn that the standard could not be loaded, continue using the type list in Step 1 as a fallback. Do not abort.
