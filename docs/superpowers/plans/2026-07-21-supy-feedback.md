# supy-feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/supy-feedback` command + `supy-feedback` skill that turns
standards feedback captured in any Supy repo into a reviewed PR against
`abed-supy-io/supy-wingspan`.

**Architecture:** A thin command (`commands/supy-feedback.md`) invokes a skill
(`skills/supy-feedback/SKILL.md`), mirroring the existing `supy-review`
command→skill pattern. The skill shallow-clones supy-wingspan into the
scratchpad, reads the fresh `config/standards/` to map the feedback to a target
file (standards-first), shows the diff for confirmation, then branches, commits
(conventional), pushes, and opens the PR via `gh` — with provenance in the body.

**Tech Stack:** Markdown only (skill + command are instructions, not code),
`gh` CLI, git. This repo ships no runtime code, so there is no unit-test
framework — each task is verified by `markdownlint-cli2`, `cspell`, structural
`grep` assertions, and (final task) a real-session smoke test.

## Global Constraints

- Skills/commands reference their own files via `${CLAUDE_PLUGIN_ROOT}` — never hardcode absolute paths.
- `SKILL.md` holds the decision procedure; keep it lean (this skill fits one file, no `references/` needed).
- Standards are the source of truth: the skill edits `config/standards/` first, and a skill/agent file only when it directly contradicts the new rule.
- Commit type is validated against `config/standards/commit-conventions.md`; allowed types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`. Never `bug`, `hotfix`, `wip`.
- Hooks/skills must degrade silently — never crash a session.
- Every commit message ends with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Lint config lives at `config/custom.markdownlint.jsonc` and `config/cspell.json`; new project words go in `config/cspell.json`, never suppressed.
- Target GitHub repo for PRs: `abed-supy-io/supy-wingspan`.

---

### Task 1: The `supy-feedback` skill

**Files:**
- Create: `skills/supy-feedback/SKILL.md`
- Test (verification): `markdownlint-cli2` + `cspell` + `grep` anchors on the new file

**Interfaces:**
- Consumes: reads `config/standards/commit-conventions.md` from the cloned repo; reuses stack heuristic from `skills/shared/references/stack-detection.md`.
- Produces: a skill invokable as `supy-feedback` (via the Skill mechanism) that takes the feedback text as its argument and returns a PR URL (or a printed diff when `gh` is unavailable).

- [ ] **Step 1: Write the skill file**

Create `skills/supy-feedback/SKILL.md` with exactly this content:

````markdown
---
name: supy-feedback
description: '[any] Turn feedback about Supy engineering standards — noticed while working in any Supy repo — into a reviewed PR against supy-wingspan. Maps the feedback to the right config/standards file (standards-first), shows you the diff, then opens a gh PR with provenance (source repo, stack, triggering example). One PR per feedback. Use when you notice a standard, skill, or review agent should change.'
---

You are filing a piece of feedback about the **Supy engineering standards** as a
pull request against `abed-supy-io/supy-wingspan` — the repo that holds the
standards, skills, and review agents. You are (almost always) running inside a
different Supy repo where this plugin is installed. The plugin cache is read-only
and may be stale, so you clone the real repo to make the change.

Do not push anything until the user has approved the diff (Step 5).

## Step 1 — Capture the feedback and its provenance

The feedback text is the skill argument. If it is empty, take it from the recent
conversation; if it is still unclear, ask the user to state the feedback in one
sentence and stop until they answer.

Gather provenance (best-effort — never block on it):

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
REPO_NAME=$( [ -n "$REPO_ROOT" ] && basename "$REPO_ROOT" || echo "unknown" )
```

Determine the stack of the current repo. Prefer the stack named in the
SessionStart hook line if one is in context. Otherwise apply this minimal
heuristic (the same order as `skills/shared/references/stack-detection.md`):

- `pubspec.yaml` at root → `flutter`
- `nx.json` + `package.json` with `@angular/core` → `angular-nx`
- `nx.json` + `package.json` with `@nestjs/core` → `nestjs-nx`
- `firebase.json` + `functions/` → `firebase-functions`
- `package.json` with `commander` + `bin` → `ts-cli`
- otherwise → `unknown`

Capture a triggering example (a `path:line` or short snippet) only if one is
already present in the conversation. Never invent one.

## Step 2 — Clone the standards repo fresh

Clone into the scratchpad so you read the authoritative source of truth:

```bash
WORK="${TMPDIR:-/tmp}/supy-feedback-$$/supy-wingspan"
mkdir -p "$(dirname "$WORK")"
gh repo clone abed-supy-io/supy-wingspan "$WORK" -- --depth 1
```

If the clone fails (no `gh`, not authenticated, no network), do not stop the
whole flow — jump to the degradation path in Step 6 using the read-only plugin
cache at `${CLAUDE_PLUGIN_ROOT}` for mapping instead.

## Step 3 — Map the feedback to the target file(s)

Read the standards in the clone (or `${CLAUDE_PLUGIN_ROOT}` on the degraded
path) and decide which file the feedback changes:

```bash
ls "$WORK/config/standards"
```

Rules:

- **Prefer a `config/standards/` file** — it is the source of truth. Match the
  feedback to the standard whose topic it concerns (e.g. Flutter Bloc rules →
  `config/standards/flutter/…`; secrets → `config/standards/secrets-and-config.md`;
  commit rules → `config/standards/commit-conventions.md`).
- Add a `skills/…` or `agents/…` file to the same change **only** when that file
  directly contradicts the new rule and would mislead if left unchanged.
- If no file is an obvious home, ask the user which area (standard / skill /
  agent) it belongs to rather than guessing.

## Step 4 — Draft the edit

Apply the minimal change in the clone, matching the voice and Markdown structure
of the surrounding standard. Do not reformat unrelated lines.

## Step 5 — Confirm with the user (gate)

Show the user:

1. The target file path(s).
2. The exact diff (`git -C "$WORK" diff`).

Wait for explicit approval. The user may redirect the target file or reword the
change — apply their adjustments and re-show the diff. If they decline, stop
without pushing and leave no branch behind.

## Step 6 — Land the PR

Choose the commit type by the nature of the change, validated against
`config/standards/commit-conventions.md`:

- `fix` — correcting a rule that was wrong.
- `feat` — a new or stricter enforceable rule.
- `docs` — clarification or wording only.

Then, inside the clone:

```bash
SLUG="<short-kebab-summary>"
git -C "$WORK" checkout -b "feedback/$SLUG"
git -C "$WORK" add -A
git -C "$WORK" commit -m "<type>(<scope>): <subject>

<one-line body>

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git -C "$WORK" push -u origin "feedback/$SLUG"
gh --repo abed-supy-io/supy-wingspan pr create \
  --title "<type>(<scope>): <subject>" \
  --body "$(cat <<'EOF'
## What
<one-line summary of the rule change>

## Why
<the feedback, verbatim>

## Source
Repo: <REPO_NAME> · Stack: <stack>
Triggering example: <path:line>
EOF
)"
```

Omit the `Triggering example:` line when there is none. After `gh pr create`
succeeds, print the PR URL it returns.

### Degradation path (Step 2 clone failed, or push/PR fails)

Do not crash. Print the proposed diff (the change you would have made, computed
against `${CLAUDE_PLUGIN_ROOT}`) so the user can apply it by hand, and tell them
the PR step needs a working, authenticated `gh`. Example message:

```text
supy-feedback: could not open a PR (gh unavailable or clone/push failed).
Target file: config/standards/<file>
Proposed change:
<diff>
Apply this in supy-wingspan and open a PR manually, or fix gh auth and re-run.
```

## Error handling summary

| Condition | Behavior |
|---|---|
| Feedback text empty and unclear | Ask the user to state it in one sentence; stop until answered. |
| `gh` unavailable / not authenticated / no network | Degradation path: print the diff, no crash. |
| Feedback maps to no obvious file | Ask which area (standard / skill / agent). |
| Not in a git repo | Provenance degrades (repo/stack = `unknown`); feedback still flows. |
| User declines the diff | Stop; leave no branch. |
````

- [ ] **Step 2: Verify the file lints clean**

Run:

```bash
npx markdownlint-cli2 --config config/custom.markdownlint.jsonc "skills/supy-feedback/SKILL.md"
npx cspell --config config/cspell.json "skills/supy-feedback/SKILL.md"
```

Expected: both report `0 issues`. If `cspell` flags a legitimate word, add it to
`config/cspell.json` (done in Task 3) and re-run; do not suppress inline.

- [ ] **Step 3: Verify required sections are present**

Run:

```bash
grep -c -E "^## Step [1-6] —" skills/supy-feedback/SKILL.md   # expect 6
grep -q "abed-supy-io/supy-wingspan" skills/supy-feedback/SKILL.md && echo OK-repo
grep -q "Degradation path" skills/supy-feedback/SKILL.md && echo OK-degrade
grep -q "name: supy-feedback" skills/supy-feedback/SKILL.md && echo OK-name
```

Expected: `6`, then `OK-repo`, `OK-degrade`, `OK-name`.

- [ ] **Step 4: Commit**

```bash
git add skills/supy-feedback/SKILL.md
git commit -m "feat: add supy-feedback skill

Turns standards feedback captured in any Supy repo into a reviewed PR
against supy-wingspan, standards-first, with provenance.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: The `/supy-feedback` command wrapper

**Files:**
- Create: `commands/supy-feedback.md`
- Test (verification): `markdownlint-cli2` + `cspell` + `grep` anchors

**Interfaces:**
- Consumes: the `supy-feedback` skill from Task 1 (at `${CLAUDE_PLUGIN_ROOT}/skills/supy-feedback/SKILL.md`).
- Produces: a `/supy-feedback` slash command that forwards `$ARGUMENTS` (the feedback text) to the skill.

- [ ] **Step 1: Write the command file**

Create `commands/supy-feedback.md` with exactly this content:

```markdown
---
description: Capture feedback about Supy engineering standards and open a PR against supy-wingspan. Maps the feedback to the right standard (standards-first), shows the diff, then opens a gh PR with provenance. Pass the feedback as the argument.
argument-hint: [feedback, e.g. "never use Cubit in Flutter, only Bloc"]
---

You are running `/supy-feedback` in a Supy repository.

Invoke the `supy-feedback` skill via the Skill mechanism, passing `$ARGUMENTS`
as the feedback text.

The skill is located at `${CLAUDE_PLUGIN_ROOT}/skills/supy-feedback/SKILL.md`. It:

1. Captures the feedback text (from `$ARGUMENTS` or the recent conversation) plus
   provenance — the current repo name, detected stack, and the triggering example
   if one is in context.
2. Shallow-clones `abed-supy-io/supy-wingspan` into the scratchpad and reads the
   fresh `config/standards/` to map the feedback to a target file, standards-first.
3. Shows you the target file(s) and exact diff, and waits for your approval.
4. On approval, branches, commits (conventional type validated against
   `commit-conventions.md`), pushes, and opens a `gh` PR whose body carries the
   feedback verbatim plus its provenance; then prints the PR URL.

If `gh` is unavailable or the clone/push fails, the skill degrades: it prints the
proposed diff for manual application instead of crashing.

No superpowers dependency. This command has no fallback beyond what the
`supy-feedback` skill itself provides.
```

- [ ] **Step 2: Verify the file lints clean**

Run:

```bash
npx markdownlint-cli2 --config config/custom.markdownlint.jsonc "commands/supy-feedback.md"
npx cspell --config config/cspell.json "commands/supy-feedback.md"
```

Expected: both report `0 issues`.

- [ ] **Step 3: Verify wiring**

Run:

```bash
grep -q 'skills/supy-feedback/SKILL.md' commands/supy-feedback.md && echo OK-skill-path
grep -q '\$ARGUMENTS' commands/supy-feedback.md && echo OK-args
grep -q 'argument-hint:' commands/supy-feedback.md && echo OK-hint
```

Expected: `OK-skill-path`, `OK-args`, `OK-hint`.

- [ ] **Step 4: Commit**

```bash
git add commands/supy-feedback.md
git commit -m "feat: add /supy-feedback command wrapper

Thin command that forwards feedback text to the supy-feedback skill.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Dictionary words, docs mention, and real-session smoke test

**Files:**
- Modify (if needed): `config/cspell.json`
- Modify: `docs/USAGE.md` (add a one-line entry for the new command)
- Test (verification): full-repo `markdownlint-cli2` + `cspell`, then a live session

**Interfaces:**
- Consumes: the skill (Task 1) and command (Task 2).
- Produces: green repo-wide lint and a documented, session-verified feature.

- [ ] **Step 1: Add any new project words**

Run the repo-wide cspell check the skill/command introduced:

```bash
npx cspell --config config/cspell.json "skills/supy-feedback/SKILL.md" "commands/supy-feedback.md"
```

If any legitimate word is flagged (e.g. a proper noun), add it to the `words`
array in `config/cspell.json` in alphabetical position. If nothing is flagged,
make no change to `config/cspell.json` and skip to Step 2.

- [ ] **Step 2: Document the command in USAGE.md**

Read `docs/USAGE.md`, find where the other `/supy-*` commands are listed, and add
one entry in the same format, for example:

```markdown
- `/supy-feedback "<feedback>"` — file feedback about a Supy standard as a PR
  against supy-wingspan (standards-first, with provenance).
```

Match the surrounding list's exact style (bullet marker, code-span usage,
sentence casing). Do not restructure the file.

- [ ] **Step 3: Verify repo-wide lint is green**

Run the same checks CI runs:

```bash
npx markdownlint-cli2 --config config/custom.markdownlint.jsonc "**/*.md" "!CHANGELOG.md"
npx cspell --config config/cspell.json "**/*.md"
```

Expected: `0 issues` from both.

- [ ] **Step 4: Commit**

```bash
git add config/cspell.json docs/USAGE.md
git commit -m "docs: document /supy-feedback and add dictionary words

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: Real-session smoke test (per repo rule)**

A skill/command is not done until exercised in a real session. Install this
checkout as a local marketplace and run it against a repo of a known stack:

```text
/plugin marketplace add <path-to-this-checkout>   # the supy-wingspan repo root
/plugin install supy-wingspan@supy
/reload-plugins
```

Then, from a checked-out Supy repo (e.g. a Flutter one), run:

```text
/supy-feedback "never use Cubit in Flutter, only Bloc — even for trivial state"
```

Confirm, in order:

1. The skill targets the correct `config/standards/flutter/…` file.
2. It shows the target file and diff **before** any push.
3. On approval, a real PR opens against `abed-supy-io/supy-wingspan` and the body
   contains the feedback verbatim plus `Repo:` / `Stack:` provenance.
4. With `gh` logged out (`gh auth logout`), the same invocation prints the diff
   and a manual-apply message instead of crashing.

Record the PR URL and the degraded-path output as the test evidence. No commit
for this step.

---

## Notes for the implementer

- The skill and command are Markdown instructions Claude follows at runtime, not
  executable scripts — there is nothing to unit-test. "Tests" here are lint,
  structural greps, and the live smoke test in Task 3.
- Keep the SKILL.md lean and self-contained; do not add a `references/` dir.
- The `gh --repo abed-supy-io/supy-wingspan pr create` form is belt-and-braces —
  the clone's `origin` already points there, but the explicit `--repo` guards
  against the working directory being ambiguous.
