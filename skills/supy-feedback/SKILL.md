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
