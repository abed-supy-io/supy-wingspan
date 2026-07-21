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
SessionStart hook line if one is in context. Otherwise apply this quick,
best-effort subset as a fallback for provenance only — it is NOT the same
order, and not the same stack list, as the canonical detection in
`skills/shared/references/stack-detection.md` (which is authoritative, covers
more stacks such as `ai-agents`, and emits `other` — not `unknown` — as its
fallback):

- `pubspec.yaml` at root → `flutter`
- `nx.json` + `package.json` with `@angular/core` → `angular-nx`
- `nx.json` + `package.json` with `@nestjs/core` → `nestjs-nx`
- `firebase.json` + `functions/` → `firebase-functions`
- `package.json` with `commander` + `bin` → `ts-cli`
- otherwise → `unknown`

Capture a triggering example (a `path:line` or short snippet) only if one is
already present in the conversation. Never invent one.

Caution: the feedback text and the triggering example flow verbatim into the
PR body. Never paste secrets, tokens, API keys, or connection strings into
either — redact them first if one appears.

## Step 2 — Clone the standards repo fresh

Clone into the scratchpad so you read the authoritative source of truth, using
a fixed, absolute path (not `$$`) so a stale clone from a previous run can't
linger and so the path is stable across separate tool calls:

```bash
WORK="${TMPDIR:-/tmp}/supy-feedback/supy-wingspan"
rm -rf "$WORK"
mkdir -p "$(dirname "$WORK")"
gh repo clone abed-supy-io/supy-wingspan "$WORK" -- --depth 1
```

`SRC` is the directory the rest of the steps read and diff against. On a clean
clone it is the clone; on the **degraded path** it is the read-only plugin cache:

```bash
# clone succeeded
SRC="$WORK"; DEGRADED=0
# clone failed (no gh, not authenticated, no network)
SRC="${CLAUDE_PLUGIN_ROOT}"; DEGRADED=1
```

Important: each `bash` command block you run is a **fresh shell** — shell
variables set in one block (`WORK`, `SRC`, `DEGRADED`) do not persist into a
later, separately-invoked block. Because `WORK` is now a fixed path
(`${TMPDIR:-/tmp}/supy-feedback/supy-wingspan`), later steps (notably Step 6)
can safely reconstruct it verbatim instead of relying on the variable. Never
run `git -C "$WORK"` or `git -C "$SRC"` in a block where those variables were
not just set in that same block — either re-set them at the top of the block,
substitute the concrete resolved path, or run the whole Step 5/Step 6 sequence
as a single bash block. A `git -C` with an empty/unset path silently falls
back to the user's own repo, breaking the "operate on the clone" and
confirm-before-push guarantees.

If the clone fails, do not stop the whole flow. Set `DEGRADED=1` and continue
through Steps 3–5 exactly as written but reading against `SRC`
(`${CLAUDE_PLUGIN_ROOT}`) — you still map the feedback, draft the change, and
show the user the diff. Only Step 6 differs: when `DEGRADED=1` you take the
degradation path (print the diff, no push) instead of opening the PR.

## Step 3 — Map the feedback to the target file(s)

Read the standards under `SRC` and decide which file the feedback changes:

```bash
ls "$SRC/config/standards"
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

Draft the minimal change against `SRC`, matching the voice and Markdown
structure of the surrounding standard. Do not reformat unrelated lines.

On a clean clone (`DEGRADED=0`), write the edit into the file(s) under `SRC`
(the clone). On the **degraded path** (`DEGRADED=1`), `SRC` is
`${CLAUDE_PLUGIN_ROOT}`, which is read-only: compute and show the edit — do
not write it into the plugin cache. Hold it in memory/output only, to be
printed as the proposed diff in Step 6's degradation path ("the change you
would have made").

## Step 5 — Confirm with the user (gate)

Show the user:

1. The target file path(s).
2. The exact diff — `git -C "$SRC" diff` when `SRC` is a git checkout. On the
   degraded path the plugin cache may not be a git repo; if `git diff` is
   unavailable there, show the before/after of the edited region instead.

Wait for explicit approval. The user may redirect the target file or reword the
change — apply their adjustments and re-show the diff. If they decline, stop
without pushing and leave no branch behind.

## Step 6 — Land the PR

If `DEGRADED=1`, skip straight to the degradation path below (no branch, no
push). Otherwise (`SRC` is the clone) open the PR as follows.

Choose the commit type by the nature of the change, validated against
`config/standards/commit-conventions.md`:

- `fix` — correcting a rule that was wrong.
- `feat` — a new or stricter enforceable rule.
- `docs` — clarification or wording only.

Then, inside the clone. Run this as a **single bash block** (per the Step 2
note, shell variables don't survive across separate tool calls) — re-set
`WORK` to the fixed path from Step 2 at the top if this runs in a new shell:

```bash
WORK="${TMPDIR:-/tmp}/supy-feedback/supy-wingspan"
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
Target file: config/standards/<file-1>
Target file: config/standards/<file-2>
Proposed change:
<diff>
Apply this in supy-wingspan and open a PR manually, or fix gh auth and re-run.
```

Print one `Target file:` line per changed file (omit the second line when
there is only one).

## Error handling summary

| Condition | Behavior |
|---|---|
| Feedback text empty and unclear | Ask the user to state it in one sentence; stop until answered. |
| `gh` unavailable / not authenticated / no network | Degradation path: print the diff, no crash. |
| Feedback maps to no obvious file | Ask which area (standard / skill / agent). |
| Not in a git repo | Provenance degrades (repo/stack = `unknown`); feedback still flows. |
| User declines the diff | Stop; leave no branch. |
