# E1 "Prove It Live" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author the offline scaffolding a human needs to run the supy-wingspan plugin end-to-end on one real repo per stack — a per-stack pilot runbook, a results-capture template, a triage protocol, and a per-stack tracker in `docs/PILOT.md` — guarded by a deterministic verifier that keeps those docs consistent with the plugin's actual stack detection.

**Architecture:** All deliverables are Markdown docs under `docs/pilots/` plus edits to `docs/PILOT.md`. Their "test" is a single offline bash verifier, `docs/pilots/verify-pilots.sh`, built up check-by-check test-first. The verifier reads `hooks/detect-stack.sh` to cross-check that every SessionStart line the runbook promises actually matches what the detector emits (drift guard), asserts each artifact's required structure, and secret-scans the docs. No subagents, no network — the plan runs entirely as local file edits + `bash`/`shellcheck`.

**Tech Stack:** Markdown, Bash (POSIX-ish, `bash` arrays), `grep`, `shellcheck`, `git` (local commits only).

## Global Constraints

Every task's requirements implicitly include this section. Values are copied verbatim from `docs/superpowers/specs/2026-07-16-enhancement-roadmap-design.md`.

- **Pilot branches are local-only.** Scratch branches created inside pilot repos are throwaway and **never pushed**. This plugin repo itself lives on GitHub (PRs to `main`, CI-gated) — its own commits land through the normal PR flow.
- **Secrets.** NEVER reproduce a secret value in any file, diff, commit message, or finding. Cite `path:line` only. (Reinforces the org security rule and `supy-secrets-reviewer`.)
- **Conventional Commits.** `feat:` / `docs:` / `fix:` (use `fix()`, never `bug()`). Claude-authored commits end with the standard `Co-Authored-By: Claude <model> <noreply@anthropic.com>` trailer for the model that produced them.
- **Token / agent budget ("stay green").** This plan uses **zero subagents** and **zero network calls** — only local file edits and one offline `bash` verifier. Keep it that way: do not dispatch Explore/review agents to execute these tasks.
- **Human-in-the-loop.** The live `/plugin install` + `/supy-review` + `supy-commit` runs in each target repo are performed by a **human after this plan completes** — they cannot be driven headlessly. This plan authors the scaffolding; §"After This Plan" documents the handoff.
- **Docs may use absolute paths.** Component bodies must use `${CLAUDE_PLUGIN_ROOT}`, but these are human-facing docs; prefer the portable `~/Projects/supy-projects/supy-wingspan` form for install commands.

## Canonical pilot data (single source of truth)

Every task below draws from this table. Reviewer counts and SessionStart lines are ground-truthed against `hooks/detect-stack.sh` and `README.md`.

| # | Stack (profile) | Pilot repo | Expected SessionStart line (verbatim substring) | Reviewers dispatched |
|---|---|---|---|---|
| 1 | nestjs-nx | `supy-service-inventory` | `supy-wingspan: detected nestjs-nx repo.` | 6 — `supy-architecture-reviewer`, `supy-nats-event-reviewer`, `supy-test-quality-reviewer`, `supy-commit-pr-reviewer`, `supy-security-reviewer`, `supy-secrets-reviewer` |
| 2 | angular-nx | `supy-frontend` | `supy-wingspan: detected angular-nx repo.` | 3 — `supy-angular-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` |
| 3 | flutter (Profile B) | `supy-mobile` | `supy-wingspan: detected flutter repo.` | 3 — `supy-flutter-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` |
| 4 | flutter (Profile A) | `checklist` | `supy-wingspan: detected flutter repo.` | 3 — `supy-flutter-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` |
| 5 | firebase-functions | `supy-firebase-functions` | `supy-wingspan: detected firebase-functions repo (standalone, non-Nx)` | 3 — `supy-firebase-functions-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` |
| 6 | ts-cli | `supy-cli` | `supy-wingspan: detected ts-cli repo (standalone commander.js MongoDB scripts runner)` | 3 — `supy-ts-cli-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` |
| 7 | ai-agents | `supy-ai-agents` | `supy-wingspan: detected ai-agents repo (polyglot MCP/agents monorepo, no root orchestration)` | 3 — `supy-ai-agents-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` |
| 8 | k8s-config | `supy-configmaps` | `supy-wingspan: detected k8s-config repo. Secrets MUST live in a Secret/external-secret` | 2 — `supy-secrets-reviewer`, `supy-commit-pr-reviewer` |

## File Structure

- `docs/pilots/verify-pilots.sh` (create) — offline verifier; the "test" for every doc task. Grows one check-block per task.
- `docs/pilots/RUNBOOK.md` (create) — per-stack pilot runbook (8 pilots). Shared preamble + one section per pilot: install, expected SessionStart line, expected reviewer set, representative-change hint, `/supy-review`, `supy-commit`, token capture, cleanup.
- `docs/pilots/RESULTS-TEMPLATE.md` (create) — uniform per-pilot capture form.
- `docs/pilots/TRIAGE.md` (create) — protocol for converting captured results into asset fixes and ticking the tracker.
- `docs/PILOT.md` (modify) — add a "Per-stack pilot tracker" table linking to the runbook, with a token-baseline column.

---

### Task 1: Verifier skeleton + runbook coverage

**Files:**
- Create: `docs/pilots/verify-pilots.sh`
- Create: `docs/pilots/RUNBOOK.md`

**Interfaces:**
- Produces: `docs/pilots/verify-pilots.sh` defining bash arrays `PILOTS` (rows `repo|sessionstart-substring|reviewer-count`) and `SPECIAL_SUBSTRINGS`, plus helpers `err()`/`ok()` and vars `ROOT`/`RUNBOOK`/`RESULTS`/`TRIAGE`/`DETECT`/`PILOT`. Later tasks append checks that consume these.
- Produces: `docs/pilots/RUNBOOK.md` with a shared preamble and 8 `## Pilot N — <stack>: <repo>` section headings, each naming its pilot repo.

- [ ] **Step 1: Write the verifier with Check A only**

Create `docs/pilots/verify-pilots.sh`:

```bash
#!/usr/bin/env bash
# verify-pilots.sh — offline structural check for the E1 pilot artifacts.
# No subagents, no network. Run from anywhere in the repo:
#   bash docs/pilots/verify-pilots.sh
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RUNBOOK="$ROOT/docs/pilots/RUNBOOK.md"
RESULTS="$ROOT/docs/pilots/RESULTS-TEMPLATE.md"
TRIAGE="$ROOT/docs/pilots/TRIAGE.md"
DETECT="$ROOT/hooks/detect-stack.sh"
PILOT="$ROOT/docs/PILOT.md"

fail=0
err() { echo "FAIL: $1"; fail=1; }
ok()  { echo "ok:   $1"; }

# Canonical pilot enumeration: "repo|SessionStart substring|reviewer count"
PILOTS=(
  "supy-service-inventory|detected nestjs-nx repo.|6"
  "supy-frontend|detected angular-nx repo.|3"
  "supy-mobile|detected flutter repo.|3"
  "checklist|detected flutter repo.|3"
  "supy-firebase-functions|detected firebase-functions repo (standalone, non-Nx)|3"
  "supy-cli|detected ts-cli repo (standalone commander.js MongoDB scripts runner)|3"
  "supy-ai-agents|detected ai-agents repo (polyglot MCP/agents monorepo, no root orchestration)|3"
  "supy-configmaps|detected k8s-config repo. Secrets MUST live in a Secret/external-secret|2"
)

# Special-stack messages that MUST also appear verbatim in detect-stack.sh
# (guards runbook<->detector drift for the four non-default messages).
SPECIAL_SUBSTRINGS=(
  "detected firebase-functions repo (standalone, non-Nx)"
  "detected ts-cli repo (standalone commander.js MongoDB scripts runner)"
  "detected ai-agents repo (polyglot MCP/agents monorepo, no root orchestration)"
  "detected k8s-config repo. Secrets MUST live in a Secret/external-secret"
)

# --- Check A: runbook exists and covers every pilot repo ---
if [ ! -f "$RUNBOOK" ]; then
  err "runbook missing: $RUNBOOK"
else
  ok "runbook present"
  for row in "${PILOTS[@]}"; do
    repo="${row%%|*}"
    grep -qF "$repo" "$RUNBOOK" || err "runbook missing pilot repo: $repo"
  done
fi

if [ "$fail" -ne 0 ]; then
  echo "verify-pilots: FAILED"
  exit 1
fi
echo "verify-pilots: all checks passed"
exit 0
```

- [ ] **Step 2: Run the verifier to confirm it fails**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: prints `FAIL: runbook missing: .../docs/pilots/RUNBOOK.md`, then `verify-pilots: FAILED`, exit code 1.

- [ ] **Step 3: Create the runbook skeleton (preamble + 8 headings)**

Create `docs/pilots/RUNBOOK.md`:

````markdown
# supy-wingspan Per-Stack Pilot Runbook

This runbook is the **human-run** procedure that proves supy-wingspan works
end-to-end on one real repo per stack. It generalizes the original
`nestjs-nx` checklist in [`../PILOT.md`](../PILOT.md) to all pilots. Record
each run in a copy of [`RESULTS-TEMPLATE.md`](RESULTS-TEMPLATE.md), then
triage per [`TRIAGE.md`](TRIAGE.md) and tick the tracker in
[`../PILOT.md`](../PILOT.md).

## Ground rules

- **Local-only.** Do a scratch branch and delete it after. **Never push.**
- **Secrets.** If a finding references a secret, cite `path:line` — never
  copy the value into the results file.
- **Representative change.** Make one small, real edit so the branch diff is
  non-empty (`/supy-review` reviews the whole branch diff vs. the merge-base
  with `origin/main`/`main`, not just the last commit).
- **Token capture.** After `/supy-review`, note the approximate tokens and
  turn count for that review (from the session UI) — this is the stack's
  "green" baseline recorded in the tracker.

## Shared steps (every pilot)

1. Open a Claude Code session inside the pilot repo.
2. Enable the plugin:
   ```
   /plugin marketplace add ~/Projects/supy-projects/supy-wingspan
   /plugin install supy-wingspan@supy
   ```
3. Scroll to session start; confirm the expected SessionStart line (below).
4. Create a scratch branch and make the representative change:
   ```bash
   git checkout -b pilot/supy-wingspan-test
   # make the small edit named in the pilot section, then:
   git add <file>
   ```
5. Run `/supy-review` with no arguments; confirm the expected reviewer set
   dispatches and a consolidated report is emitted.
6. Invoke the `supy-commit` skill; confirm a Conventional-Commits message
   ending with the required trailer, and that nothing is pushed.
7. Capture tokens/turns for the `/supy-review` run.
8. Clean up:
   ```bash
   git checkout main && git branch -D pilot/supy-wingspan-test
   ```

## Pilot 1 — nestjs-nx: supy-service-inventory

## Pilot 2 — angular-nx: supy-frontend

## Pilot 3 — flutter (Profile B): supy-mobile

## Pilot 4 — flutter (Profile A): checklist

## Pilot 5 — firebase-functions: supy-firebase-functions

## Pilot 6 — ts-cli: supy-cli

## Pilot 7 — ai-agents: supy-ai-agents

## Pilot 8 — k8s-config: supy-configmaps
````

- [ ] **Step 4: Make the verifier executable and run it to confirm it passes**

Run: `chmod +x docs/pilots/verify-pilots.sh && bash docs/pilots/verify-pilots.sh`
Expected: prints `ok:   runbook present` and `verify-pilots: all checks passed`, exit code 0.

- [ ] **Step 5: Shellcheck the verifier**

Run: `shellcheck docs/pilots/verify-pilots.sh`
Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add docs/pilots/verify-pilots.sh docs/pilots/RUNBOOK.md
git commit -m "$(cat <<'EOF'
docs: add E1 pilot verifier + runbook skeleton

verify-pilots.sh (offline, no agents) checks the pilot docs cover every
stack and stay consistent with detect-stack.sh. RUNBOOK.md carries the
shared human-run procedure + one heading per pilot.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Fill each runbook pilot section

**Files:**
- Modify: `docs/pilots/RUNBOOK.md`
- Modify: `docs/pilots/verify-pilots.sh`

**Interfaces:**
- Consumes: `PILOTS`, `SPECIAL_SUBSTRINGS`, `err`, `ok`, `RUNBOOK`, `DETECT` from Task 1.
- Produces: each `## Pilot N` section populated with its SessionStart line, reviewer set (naming every expected reviewer), and representative-change hint; verifier Checks B and C.

- [ ] **Step 1: Add Checks B and C to the verifier**

In `docs/pilots/verify-pilots.sh`, insert this block immediately **before** the final `if [ "$fail" -ne 0 ]` tail:

```bash
# --- Check B: each pilot's SessionStart substring is in the runbook;
#     the four special-stack messages must also appear verbatim in the detector. ---
if [ -f "$RUNBOOK" ]; then
  for row in "${PILOTS[@]}"; do
    rest="${row#*|}"; sub="${rest%|*}"
    grep -qF "$sub" "$RUNBOOK" || err "runbook missing SessionStart line: $sub"
  done
fi
for sub in "${SPECIAL_SUBSTRINGS[@]}"; do
  grep -qF "$sub" "$DETECT" || err "detector drift — not in detect-stack.sh: $sub"
done

# --- Check C: the runbook names every expected reviewer (documents dispatch sets). ---
REVIEWERS=(
  supy-architecture-reviewer supy-nats-event-reviewer supy-test-quality-reviewer
  supy-security-reviewer supy-angular-reviewer supy-flutter-reviewer
  supy-firebase-functions-reviewer supy-ts-cli-reviewer supy-ai-agents-reviewer
  supy-commit-pr-reviewer supy-secrets-reviewer
)
if [ -f "$RUNBOOK" ]; then
  for r in "${REVIEWERS[@]}"; do
    grep -qF "$r" "$RUNBOOK" || err "runbook does not name reviewer: $r"
  done
fi
```

- [ ] **Step 2: Run the verifier to confirm the new checks fail**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: multiple `FAIL: runbook missing SessionStart line: ...` and `FAIL: runbook does not name reviewer: ...`, then `verify-pilots: FAILED`, exit code 1. (Check B's detector-drift lines pass — those strings are in `detect-stack.sh`.)

- [ ] **Step 3: Populate each pilot section**

For each pilot, replace its `## Pilot N — ...` heading line in `docs/pilots/RUNBOOK.md` with the heading followed by this block, substituting the four slots from the table below:

```markdown
- **Expected SessionStart line:** `<SESSIONSTART>`
- **Expected reviewers (<COUNT>):** <REVIEWERS>
- **Representative change:** <CHANGE_HINT>
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.
```

Slot values per pilot:

| Pilot | `<SESSIONSTART>` | `<COUNT>` | `<REVIEWERS>` | `<CHANGE_HINT>` |
|---|---|---|---|---|
| 1 supy-service-inventory | `supy-wingspan: detected nestjs-nx repo.` | 6 | `supy-architecture-reviewer`, `supy-nats-event-reviewer`, `supy-test-quality-reviewer`, `supy-commit-pr-reviewer`, `supy-security-reviewer`, `supy-secrets-reviewer` | add a method stub to an existing interactor, or a field to a NATS handler DTO |
| 2 supy-frontend | `supy-wingspan: detected angular-nx repo.` | 3 | `supy-angular-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` | add a `signal` input to a dumb component, or a new NGXS action |
| 3 supy-mobile | `supy-wingspan: detected flutter repo.` | 3 | `supy-flutter-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` | add a field to a freezed state or a new BLoC event (Profile B: `PageState`/`throwAppException`) |
| 4 checklist | `supy-wingspan: detected flutter repo.` | 3 | `supy-flutter-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` | add a `UseCase` param or a new `Failure` subtype (Profile A: `dartz`/`Either`) |
| 5 supy-firebase-functions | `supy-wingspan: detected firebase-functions repo (standalone, non-Nx)` | 3 | `supy-firebase-functions-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` | add a field to a callable's request DTO, or a new Firestore trigger stub |
| 6 supy-cli | `supy-wingspan: detected ts-cli repo (standalone commander.js MongoDB scripts runner)` | 3 | `supy-ts-cli-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` | add an option to an existing `IScript`, or a new script stub |
| 7 supy-ai-agents | `supy-wingspan: detected ai-agents repo (polyglot MCP/agents monorepo, no root orchestration)` | 3 | `supy-ai-agents-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` | add a field to an MCP tool input schema, or a BullMQ job payload field |
| 8 supy-configmaps | `supy-wingspan: detected k8s-config repo. Secrets MUST live in a Secret/external-secret` | 2 | `supy-secrets-reviewer`, `supy-commit-pr-reviewer` | add or edit a **non-secret** ConfigMap key (NEVER a real secret value) |

- [ ] **Step 4: Run the verifier to confirm it passes**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: `ok:` lines for runbook + reviewers, `verify-pilots: all checks passed`, exit code 0.

- [ ] **Step 5: Shellcheck the verifier**

Run: `shellcheck docs/pilots/verify-pilots.sh`
Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add docs/pilots/RUNBOOK.md docs/pilots/verify-pilots.sh
git commit -m "$(cat <<'EOF'
docs: fill per-stack pilot sections in the runbook

Each of the 8 pilots now states its expected SessionStart line, reviewer
set, and a representative change. verify-pilots.sh Checks B/C assert the
lines match detect-stack.sh and every reviewer is named.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Results-capture template

**Files:**
- Create: `docs/pilots/RESULTS-TEMPLATE.md`
- Modify: `docs/pilots/verify-pilots.sh`

**Interfaces:**
- Consumes: `err`, `ok`, `RESULTS` from Task 1.
- Produces: `docs/pilots/RESULTS-TEMPLATE.md` with all required capture fields; verifier Check D asserting each field heading is present.

- [ ] **Step 1: Add Check D to the verifier**

Insert immediately **before** the final `if [ "$fail" -ne 0 ]` tail:

```bash
# --- Check D: results template exists and carries every required field. ---
RESULT_FIELDS=(
  "Pilot repo" "Stack" "Plugin commit" "Install succeeded"
  "SessionStart line observed" "Matches expected" "Reviewers that ran"
  "Review report header" "Findings triage" "Token baseline"
  "supy-commit message" "Trailer present" "Pushed" "Asset-fix actions" "Pilot passed"
)
if [ ! -f "$RESULTS" ]; then
  err "results template missing: $RESULTS"
else
  ok "results template present"
  for f in "${RESULT_FIELDS[@]}"; do
    grep -qF "$f" "$RESULTS" || err "results template missing field: $f"
  done
fi
```

- [ ] **Step 2: Run the verifier to confirm Check D fails**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: `FAIL: results template missing: .../docs/pilots/RESULTS-TEMPLATE.md`, then `verify-pilots: FAILED`, exit code 1.

- [ ] **Step 3: Create the results template**

Create `docs/pilots/RESULTS-TEMPLATE.md`:

```markdown
# Pilot Result — <pilot repo>

Copy this file to `docs/pilots/results/<repo>.md` and fill it in during the
run. **Never paste a secret value** — cite `path:line` only.

## Run metadata
- Pilot repo: `<repo>`
- Stack (+ profile): `<stack>`
- Date: `<YYYY-MM-DD>`
- Operator: `<name>`
- Plugin commit: `<supy-wingspan short SHA at time of run>`

## Install
- Install succeeded (Y/N): ``
- Errors (if any): ``

## Detection
- SessionStart line observed (verbatim): ``
- Matches expected (Y/N): ``

## Review dispatch
- Reviewers that ran: ``
- Matches expected set (Y/N): ``
- Review report header: ``

## Findings triage
Verdict is one of: TP (true positive), FP (false positive), MISSED (a real
issue the reviewers did not flag).

| # | Severity | file:line | Reviewer | Verdict | Note (no secret values) |
|---|---|---|---|---|---|
|   |          |           |          |         |                         |

## Token baseline
- Approx tokens (in / out) for the `/supy-review` turn: ``
- Turns: ``
- Notes (was this unexpectedly expensive vs. other stacks?): ``

## Commit
- `supy-commit` message (redact any secret): ``
- Trailer present (Y/N): ``
- Pushed (must be N): ``

## Asset-fix actions
Action is one of: reinforce rule · tighten reviewer red-flag · scope rule ·
mine new rule · none.

| Finding | Action | Target file | Status |
|---|---|---|---|
|         |        |             |        |

## Sign-off
- Pilot passed (Y/N): ``
- Notes: ``
```

- [ ] **Step 4: Run the verifier to confirm it passes**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: `ok:   results template present` and `verify-pilots: all checks passed`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add docs/pilots/RESULTS-TEMPLATE.md docs/pilots/verify-pilots.sh
git commit -m "$(cat <<'EOF'
docs: add E1 pilot results-capture template

Uniform per-pilot form: install, detection, reviewer dispatch, findings
triage (TP/FP/MISSED, path:line only), token baseline, commit, and
asset-fix actions. verify-pilots.sh Check D asserts every field is present.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Per-stack tracker in PILOT.md + secret scan

**Files:**
- Modify: `docs/PILOT.md`
- Modify: `docs/pilots/verify-pilots.sh`

**Interfaces:**
- Consumes: `PILOTS`, `err`, `ok`, `PILOT`, `RUNBOOK`, `RESULTS`, `TRIAGE` from Task 1.
- Produces: a "Per-stack pilot tracker" section in `docs/PILOT.md` linking to the runbook with a token-baseline column; verifier Checks E (tracker rows), F (secret scan of the pilot docs), and G (runbook references its sibling docs).

- [ ] **Step 1: Add Checks E, F, G to the verifier**

Insert immediately **before** the final `if [ "$fail" -ne 0 ]` tail:

```bash
# --- Check E: PILOT.md carries a per-stack tracker linking to the runbook. ---
if grep -qF "Per-stack pilot tracker" "$PILOT"; then
  ok "PILOT.md has per-stack tracker"
  for row in "${PILOTS[@]}"; do
    repo="${row%%|*}"
    grep -qF "$repo" "$PILOT" || err "PILOT.md tracker missing pilot repo: $repo"
  done
  grep -qF "docs/pilots/RUNBOOK.md" "$PILOT" || err "PILOT.md tracker does not link to the runbook"
  grep -qiF "token baseline" "$PILOT" || err "PILOT.md tracker missing token-baseline column"
else
  err "PILOT.md missing 'Per-stack pilot tracker' section"
fi

# --- Check F: secret-scan the pilot docs (fail closed; never print the value). ---
SECRET_RE='AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z-]+|ghp_[0-9A-Za-z]{36}'
for f in "$RUNBOOK" "$RESULTS" "$TRIAGE"; do
  [ -f "$f" ] || continue
  if grep -Eq "$SECRET_RE" "$f"; then
    err "possible secret literal in $f (cite path:line, never the value)"
  fi
done
ok "secret scan clean"

# --- Check G: runbook references its sibling artifacts (link integrity). ---
if [ -f "$RUNBOOK" ]; then
  grep -qF "RESULTS-TEMPLATE.md" "$RUNBOOK" || err "runbook does not reference RESULTS-TEMPLATE.md"
  grep -qF "TRIAGE.md" "$RUNBOOK" || err "runbook does not reference TRIAGE.md"
fi
```

- [ ] **Step 2: Run the verifier to confirm Check E fails**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: `FAIL: PILOT.md missing 'Per-stack pilot tracker' section`, then `verify-pilots: FAILED`, exit code 1. (Check F passes — docs are clean; Check G passes — the Task 1 preamble already references both siblings.)

- [ ] **Step 3: Add the tracker to PILOT.md**

In `docs/PILOT.md`, immediately **after** the `## Pilot exercise checklist` section (i.e., before `## Graceful degradation` on line 96), insert:

```markdown
## Per-stack pilot tracker

The checklist above is the worked `nestjs-nx` example. The full human-run
procedure for **every** stack lives in [`pilots/RUNBOOK.md`](pilots/RUNBOOK.md);
capture each run with [`pilots/RESULTS-TEMPLATE.md`](pilots/RESULTS-TEMPLATE.md)
and triage per [`pilots/TRIAGE.md`](pilots/TRIAGE.md). Tick a row once its
pilot's findings are triaged and any asset fixes are committed. **Token
baseline** records approx `/supy-review` cost (in/out tokens · turns) — the
per-stack "green" bar for later phases.

| # | Stack (profile) | Pilot repo | Detected ✓ | Reviewers ✓ | Findings triaged | Token baseline (in/out · turns) | Status |
|---|---|---|---|---|---|---|---|
| 1 | nestjs-nx | `supy-service-inventory` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 2 | angular-nx | `supy-frontend` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 3 | flutter (Profile B) | `supy-mobile` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 4 | flutter (Profile A) | `checklist` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 5 | firebase-functions | `supy-firebase-functions` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 6 | ts-cli | `supy-cli` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 7 | ai-agents | `supy-ai-agents` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
| 8 | k8s-config | `supy-configmaps` | ⏳ | ⏳ | ⏳ | ⏳ | ⏳ |
```

- [ ] **Step 4: Run the verifier to confirm it passes**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: `ok:   PILOT.md has per-stack tracker`, `ok:   secret scan clean`, `verify-pilots: all checks passed`, exit code 0.

- [ ] **Step 5: Shellcheck the verifier**

Run: `shellcheck docs/pilots/verify-pilots.sh`
Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add docs/PILOT.md docs/pilots/verify-pilots.sh
git commit -m "$(cat <<'EOF'
docs: add per-stack pilot tracker to PILOT.md

8-row tracker linking to pilots/RUNBOOK.md with a token-baseline column.
verify-pilots.sh Checks E/F/G assert the tracker rows, secret-scan the
pilot docs, and confirm runbook link integrity.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Triage protocol + handoff note

**Files:**
- Create: `docs/pilots/TRIAGE.md`
- Modify: `docs/pilots/verify-pilots.sh`

**Interfaces:**
- Consumes: `err`, `ok`, `TRIAGE` from Task 1.
- Produces: `docs/pilots/TRIAGE.md` describing how captured results become asset fixes and tracker ticks; verifier Check H asserting the protocol names its core concepts.

- [ ] **Step 1: Add Check H to the verifier**

Insert immediately **before** the final `if [ "$fail" -ne 0 ]` tail:

```bash
# --- Check H: triage protocol exists and names its core concepts. ---
if [ ! -f "$TRIAGE" ]; then
  err "triage protocol missing: $TRIAGE"
else
  ok "triage protocol present"
  for kw in "true positive" "false positive" "missed" "token baseline" "tick"; do
    grep -qiF "$kw" "$TRIAGE" || err "triage protocol missing concept: $kw"
  done
fi
```

- [ ] **Step 2: Run the verifier to confirm Check H fails**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: `FAIL: triage protocol missing: .../docs/pilots/TRIAGE.md`, then `verify-pilots: FAILED`, exit code 1.

- [ ] **Step 3: Create the triage protocol**

Create `docs/pilots/TRIAGE.md`:

```markdown
# Pilot Triage Protocol

Turns each filled [`RESULTS-TEMPLATE.md`](RESULTS-TEMPLATE.md) into concrete
asset fixes and a ticked row in [`../PILOT.md`](../PILOT.md). Local-only;
cite `path:line`, never secret values.

## Inputs
- One filled results file per pilot under `docs/pilots/results/<repo>.md`.

## Per-finding decision
For every row in a pilot's **Findings triage** table:

- **True positive** → the rule fired correctly. Reinforce it: keep the rule,
  and if it was borderline, add a one-line example to the relevant
  `config/standards/*` file so it is unambiguous next time.
- **False positive** → the reviewer over-fired. Fix the reviewer: tighten the
  red-flag wording in `agents/supy-*-reviewer.md`, or scope the underlying
  rule in `config/standards/*` so it no longer matches the safe case.
- **Missed** → a real issue the reviewers did not flag. Mine a new rule into
  the relevant `config/standards/*` file and add coverage to the matching
  `agents/supy-*-reviewer.md`.

Every asset edit is a local `docs:`/`fix:` commit with the required trailer.
Never push.

## Token-baseline gate
Record each pilot's `/supy-review` token/turn cost in the PILOT.md tracker's
**Token baseline** column. If one stack's review is markedly more expensive
than its peers, note it as a candidate for E2's scoped-read / model-tiering
work — deepening review quality in E2 must not regress these baselines
without justification.

## Completion
Tick a tracker row when: detection matched (Detected ✓), the expected
reviewer set ran (Reviewers ✓), every finding is triaged (Findings triaged),
and its asset fixes are committed. Set the row **Status** to ✅. E1 is done
when all eight rows are ✅.
```

- [ ] **Step 4: Run the verifier to confirm the full suite passes**

Run: `bash docs/pilots/verify-pilots.sh`
Expected: all `ok:` lines (runbook, reviewers, results template, tracker, secret scan, triage), `verify-pilots: all checks passed`, exit code 0.

- [ ] **Step 5: Shellcheck the verifier**

Run: `shellcheck docs/pilots/verify-pilots.sh`
Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add docs/pilots/TRIAGE.md docs/pilots/verify-pilots.sh
git commit -m "$(cat <<'EOF'
docs: add pilot triage protocol + finalize E1 verifier

TRIAGE.md maps findings (TP/FP/MISSED) to reinforce/tighten/scope/mine
asset actions, sets the token-baseline gate for E2, and the tracker-tick
completion rule. verify-pilots.sh Check H closes the suite.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## After This Plan (human step — not executable here)

With the scaffolding committed, a human runs each pilot from
`docs/pilots/RUNBOOK.md`, capturing results with `RESULTS-TEMPLATE.md`. The
maintainer then triages per `TRIAGE.md`, commits the resulting asset fixes,
and ticks the `docs/PILOT.md` tracker. E1 completes when all eight rows are
✅ with token baselines recorded — which becomes the input to the E2 plan.

## Self-Review

**1. Spec coverage (against `2026-07-16-enhancement-roadmap-design.md` §6 + §4):**
- Per-stack pilot runbook (`docs/pilots/RUNBOOK.md`) → Tasks 1–2. ✓
- Results-capture template (`docs/pilots/RESULTS-TEMPLATE.md`) → Task 3. ✓
- Finalized 8-pilot mapping incl. flutter Profile A second pilot → canonical table + Tasks 2, 4. ✓
- Tick `docs/PILOT.md` checkboxes / tracker → Task 4 (tracker) + "After This Plan" (ticking). ✓
- Triage of findings → asset fixes (reinforce/tighten/scope/mine) → Task 5. ✓
- Token baseline captured per stack + "green" threshold → results template Token baseline field (T3), tracker column (T4), triage gate (T5). ✓
- §4 scoped/offline discipline → whole plan uses zero subagents, one offline verifier. ✓
- §3 constraints (local-only, no secret values, trailer) → Global Constraints + every commit + Check F. ✓

**2. Placeholder scan:** No "TBD/TODO". The `<...>` tokens in doc *bodies* (results template, runbook slots) are intentional human fill-in fields, each backed by complete surrounding structure and a data table — not plan placeholders. Every code/step block is complete.

**3. Type consistency:** The verifier's `PILOTS` rows, `SPECIAL_SUBSTRINGS`, `REVIEWERS`, and `RESULT_FIELDS` arrays are defined once (Task 1 / their introducing task) and consumed by name thereafter; SessionStart substrings match `hooks/detect-stack.sh` verbatim; reviewer names match the 11 agents in `docs/PILOT.md`. Pilot repo names are identical across the canonical table, runbook, tracker, and verifier.
