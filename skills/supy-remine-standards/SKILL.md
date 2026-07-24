---
name: supy-remine-standards
description: '[any] Deliberately re-mine the Supy engineering standards across the live repos and propose a reviewable config/standards diff. A human-triggered periodic sweep that complements the reactive supy-feedback loop: it dispatches one read-only Explore per repo in small waves under a strict token budget, each returning a uniform capped report, reconciles the findings against the current standards, and opens one PR against supy-wingspan. Use for a scheduled standards refresh across the fleet — not for a single in-flight divergence (that is supy-feedback).'
---

You are running a **deliberate standards re-mine**: a periodic sweep across the
live Supy repos that reconciles what the code actually does against
`config/standards/` and proposes one reviewable diff. This is the counterpart
to `supy-feedback` — that skill captures a single divergence noticed in-flight;
this one sweeps on purpose across many repos.

This sweep spends real tokens across many subagents. **Obey the fan-out budget
in Step 3 strictly** and confirm scope with the user before spending anything.

Do not push anything until the user has approved the diff (Step 5).

## Step 1 — Scope the sweep (confirm before spending)

Ask the user (or take from the argument) two things and stop until you have them:

1. **Which repos** to sweep. Default set is the eight pilot repos, all present
   locally under `~/Projects/supy-projects/`: `supy-service-inventory`,
   `supy-frontend`, `supy-mobile`, `checklist`, `supy-firebase-functions`,
   `supy-cli`, `supy-ai-agents`, `supy-configmaps`.
2. **Which standards area(s)** to re-mine (e.g. NATS event patterns, module
   boundaries, CI coverage), or "all". Narrower scope = cheaper sweep.

State the repo count and the wave plan (Step 3) back to the user and get a go
before dispatching any subagent.

## Step 2 — Clone the standards repo fresh

Reuse the `supy-feedback` mechanics so you read the authoritative source, using
a fixed absolute path so a stale clone can't linger:

```bash
WORK="${TMPDIR:-/tmp}/supy-remine/supy-wingspan"
rm -rf "$WORK"
mkdir -p "$(dirname "$WORK")"
gh repo clone abed-supy-io/supy-wingspan "$WORK" -- --depth 1
```

`SRC` is what the rest of the steps read and diff against:

```bash
SRC="$WORK"; DEGRADED=0            # clone succeeded
SRC="${CLAUDE_PLUGIN_ROOT}"; DEGRADED=1   # clone failed (no gh/auth/network)
```

Each `bash` block is a fresh shell — re-set `WORK`/`SRC`/`DEGRADED` at the top
of any later block, or run Step 5/6 as one block. A `git -C ""` silently falls
back to the user's own repo, breaking the "operate on the clone" guarantee.

On `DEGRADED=1` you still run the sweep, reconcile, and show the diff against
`${CLAUDE_PLUGIN_ROOT}` — only Step 6 differs (print, no PR).

## Step 3 — Bounded fan-out sweep (THE BUDGET — do not exceed)

This is the load-bearing constraint (roadmap §4.5). Dispatch **one read-only
Explore subagent per repo**, in **waves of at most 4 repos**, awaiting each wave
before starting the next. Each Explore subagent gets this uniform contract:

- **Read-only.** It may read and grep; it must not write, edit, or run builds.
- **Targeted reads, not whole-repo sweeps.** Give it an explicit short read
  list scoped to the standards area(s) from Step 1 — e.g. the CI workflow YAML,
  the module-boundary / lint config, and at most a handful of representative
  source files named by that area. No recursive full-tree scans.
- **Uniform report, hard-capped at ≤45 lines.** The report states, per standard
  area: does the repo **confirm** the current rule, **diverge** from it, or show
  a **new** pattern not yet codified — each with a `path:line` citation.
- **Secrets:** cite `path:line` only. Never copy a secret value into the report.

Dispatch template (one per repo, ≤4 concurrent):

```text
You are a read-only Explore agent auditing <repo> for a standards re-mine.
Do NOT write, edit, or build. Read ONLY these targets: <explicit list for the
chosen standards area>. Report, in ≤45 lines, per standard area, one of
CONFIRM / DIVERGE / NEW with a path:line citation. Cite path:line only — never
paste a secret value.
```

Do not raise the wave size or the line cap to "save time" — the cap is what
keeps the sweep inside the token budget. If a repo is missing locally, skip it
and note the skip; do not substitute a whole-repo scan elsewhere.

## Step 4 — Reconcile against the current standards

Collect the per-repo reports and reconcile them against `config/standards/`
under `SRC`, using the `docs/analysis/SYNTHESIS.md` legend:

- **Confirmed** (standard already right) — no change.
- **Divergent** (standard stale/wrong, or repos inconsistent) — reconcile the
  standard, naming the exact target file.
- **New** (real recurring pattern not yet codified) — add a rule to the target
  standard.

Produce a short reconciliation summary (which standard file each delta targets)
before drafting any edit — this is what makes the resulting PR reviewable.

## Step 5 — Draft one minimal diff + confirm (gate)

Draft the **minimal** edits against `SRC`, matching the voice and Markdown
structure of each standard. Do not reformat unrelated lines. On `DEGRADED=1`,
`SRC` is the read-only plugin cache — compute and show the edit, do not write
into the cache.

Show the user: the target file path(s) and the exact diff
(`git -C "$SRC" diff`). Wait for explicit approval. Apply any redirection they
ask for and re-show. If they decline, stop and leave no branch behind.

## Step 6 — Land one PR

If `DEGRADED=1`, take the degradation path (print the diff, tell the user to
apply it and fix `gh`; no crash). Otherwise open **one** PR for the whole sweep.
Run as a single bash block (shell vars don't survive across blocks):

```bash
WORK="${TMPDIR:-/tmp}/supy-remine/supy-wingspan"
SLUG="remine-$(basename "$PWD")"   # or a date-scoped slug supplied by the user
git -C "$WORK" checkout -b "remine/$SLUG"
git -C "$WORK" add -A
git -C "$WORK" commit -m "docs(standards): re-mine sweep — reconcile drifted rules

Deliberate periodic re-mine across <N> repos.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git -C "$WORK" push -u origin "remine/$SLUG"
gh --repo abed-supy-io/supy-wingspan pr create \
  --title "docs(standards): re-mine sweep — reconcile drifted rules" \
  --body "$(cat <<'EOF'
## What
Periodic standards re-mine: reconciled the rules below against current repo state.

## Reconciliation
<confirmed / divergent / new summary, per target standard file>

## Source
Deliberate sweep across: <repo list>
Swept areas: <standards areas>
EOF
)"
```

Choose `docs` when the sweep only clarifies/reconciles wording, `feat` when it
adds a new enforceable rule, `fix` when it corrects a wrong rule — validated
against `config/standards/commit-conventions.md`. After `gh pr create` succeeds,
print the PR URL.

## Error handling summary

| Condition | Behavior |
|---|---|
| Scope (repos/areas) unclear | Ask; stop until answered. Do not sweep blind. |
| `gh` unavailable / clone fails | `DEGRADED=1`: sweep, reconcile, print the diff; no crash. |
| A target repo missing locally | Skip it, note the skip; never substitute a whole-repo scan. |
| Sweep finds no drift | Report "all swept standards confirmed"; no branch, no PR. |
| User declines the diff | Stop; leave no branch. |
| A secret value appears in a report | Redact to `path:line` before it enters the diff or PR body. |
