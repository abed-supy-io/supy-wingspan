---
name: supy-commit
description: Stage-aware conventional commit per Supy commitlint. Reads commit-conventions.md, inspects staged diff, proposes a compliant commit message (correct type, scope, subject), shows it for confirmation, and commits only after the user approves. Use on any supy-* backend repo before pushing.
---

## Step 1 — Read the governing standard

Read the Supy commit conventions so all subsequent decisions are grounded in them:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/commit-conventions.md"
```

Internalize the allowed types, formatting rules, and red flags from that file. The allowed types are: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`. Do not use `bug`, `hotfix`, `wip`, or any type not in this list — commitlint will reject it.

---

## Step 2 — Inspect the staged diff

Capture the repo root and check what is staged:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
git status --short
git diff --staged --stat
```

If `git rev-parse` fails, stop and print:

```
supy-commit: not inside a git repository — nothing to commit
```

If `git diff --staged --stat` produces no output (nothing staged), print:

```
supy-commit: no staged changes found.
Stage the files you want to commit (git add <files>) and re-run.
```

Then stop. Do not proceed.

If changes are staged, read the full staged diff for content analysis:

```bash
git diff --staged
```

---

## Step 3 — Propose a commit message

Analyse the staged diff and propose a commit message that complies with every rule in the governing standard:

1. **Type**: choose the single most accurate type from the allowed list (`build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`). Never use `bug`, `hotfix`, or `wip`.
2. **Scope**: derive from the domain or library being changed (e.g., `ledger`, `item`, `transfer`). Use comma-separated scopes when the diff genuinely spans multiple domains (e.g., `recipe,wastage`). Omit scope only when the change is truly cross-cutting with no dominant domain.
3. **Subject**: lower-case, imperative mood, no trailing full stop, does not start with a capital letter, does not exceed 100 characters total in the header.
4. **Body** (optional but recommended for non-trivial changes): explain the motivation, not just the mechanics. Each line ≤ 100 characters. Preceded by a blank line.
5. **Footer**: issue references (`closes #N`) if applicable. Preceded by a blank line.
6. **Co-Authored-By trailer**: always append exactly this line in the footer section, preceded by a blank line if no other footer exists:

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

Red flags to avoid (from the standard):
- Any type not in the allowed list
- Uppercase type or subject starting with a capital letter
- Subject ending with a full stop
- Missing scope when the change is clearly scoped to a domain
- Secrets, tokens, or connection strings in the message

Build the proposed message in full and present it as a fenced code block so it is easy to copy:

```
<type>(<scope>): <subject>

<body if applicable>

<footer/issue refs if applicable>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

Below the proposed message, add a brief rationale (1–3 sentences) explaining which type was chosen and why.

---

## Step 4 — Confirm before committing

Display the following prompt to the user before taking any action:

```
supy-commit: proposed message shown above.

Note: if a .husky/commit-msg hook is present, commitlint will validate the message automatically.
Pre-commit hooks (including affected:lint) may also run and can be slow on large monorepos.

Commit with this message? [y/N]
```

- If the user answers `y` or `yes` (case-insensitive): proceed to Step 5.
- Any other answer (including silence, `n`, or editing requests): stop and print:

```
supy-commit: commit aborted — no changes were made.
Adjust the staged files or the proposed message and re-run.
```

Do not commit silently under any circumstance.

---

## Step 5 — Commit

Execute the commit using the confirmed message verbatim:

```bash
git commit -m "<confirmed message>"
```

Pass the full multi-line message via a heredoc or `-m` with embedded newlines to preserve the body and footer formatting. Example pattern:

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

<body>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

After the commit completes, print the resulting SHA and summary:

```bash
git log -1 --oneline
```

If the commit fails (non-zero exit code), print the git error output and stop. Do not retry or amend silently.

---

## Degradation paths

**Not a git repository:** Detected in Step 2. Print the message and stop.

**Nothing staged:** Detected in Step 2. Print the message and stop. Do not auto-stage files.

**User declines confirmation:** Detected in Step 4. Print the abort message and stop. Never commit without explicit approval.

**commitlint or pre-commit hook failure:** The hook runs automatically after `git commit` is issued. If the hook rejects the message, git exits non-zero. Print the hook output, then print:

```
supy-commit: the commit was rejected by a hook. Fix the issue above and re-run supy-commit.
```

Do not amend or retry automatically.

**`${CLAUDE_PLUGIN_ROOT}/config/standards/commit-conventions.md` unreadable:** Warn that the standard could not be loaded, then continue using the type list and rules embedded in Step 1 of this skill as a fallback. Do not abort.
