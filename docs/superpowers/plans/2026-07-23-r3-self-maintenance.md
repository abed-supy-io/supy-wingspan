# R3 — Self-maintenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver R3 of the refreshed roadmap
(`docs/superpowers/specs/2026-07-23-enhancement-roadmap-refresh-design.md`, §8):
make the plugin keep its own source of truth current and make coverage visible.
Two deliverables — (1) a **coverage reporter** that renders the
`ci-coverage-baseline` bars per repo, and (2) a **standards re-mining skill**
that deliberately sweeps the live repos under a bounded token budget and
proposes a reviewable `config/standards/` diff — complementing the *reactive*
`supy-feedback` skill already shipped.

**Architecture:** Two new `[any]` (universal) skills.

- `supy-coverage-report` — a thin `SKILL.md` (stack detection + artifact
  discovery + routing) wrapping a bundled, deterministic
  `scripts/render-coverage.sh`. The bar-rendering logic is a pure, offline,
  fixture-testable transformation, so it lives in a **shell script** and is
  TDD'd against a coverage fixture; the skill only routes to it. Mirrors the
  existing `skills/<name>/scripts/` convention.
- `supy-remine-standards` — an instructions-only `SKILL.md`. It reuses
  `supy-feedback`'s clone-and-PR mechanics but sweeps **deliberately** across
  all live repos: one read-only Explore subagent per repo, in small waves,
  each returning a uniform capped report, reconciled into **one** reviewable
  `config/standards/` diff. It enforces the §4.5 bounded-fan-out budget in its
  own instructions.

**Tech Stack:** Markdown (both skills' bodies) + POSIX shell (the reporter
script and its test). This repo ships no runtime code and has no unit-test
framework, so verification per task is: the bundled `render-coverage.test.sh`
(red→green), `markdownlint-cli2`, `cspell`, the repo's structural validators
(`validate-skills.sh`, `validate-xrefs.sh`, `check-docs-inventory.sh`,
`validate-fixtures.sh`, `shellcheck`), and a final real-session smoke test.

## Global Constraints

- Components reference their own files via `${CLAUDE_PLUGIN_ROOT}` — never hardcode absolute paths. Absolute paths are allowed only in human-facing docs and fixtures.
- **Secrets:** NEVER reproduce a secret value in any file, diff, commit message, fixture, or finding. Cite `path:line` only. Both skills must state this and never echo a secret. Coverage artifacts (`lcov.info`, `coverage-summary.json`) carry no secrets, but the re-mining Explore reports must cite `path:line`, never values.
- `SKILL.md` holds the decision procedure; keep it lean. `supy-coverage-report` pushes its rendering logic into `scripts/`; `supy-remine-standards` fits one file (no `references/` needed).
- **Standards are the source of truth:** the re-mining skill reconciles against, and proposes edits to, `config/standards/` first — an `agents/`/`skills/` edit only when that file directly contradicts a changed rule.
- **Conventional Commits** validated against `config/standards/commit-conventions.md`; allowed types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`. Never `bug`, `hotfix`, `wip`. Every Claude-authored commit ends with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Hooks/skills degrade silently** — never crash a session. No coverage artifact → say how to produce one and stop; `gh` unavailable → print the diff, no crash.
- **Token / agent budget ("stay green").** The re-mining sweep obeys the original roadmap §4.5 bounded-fan-out rule verbatim: one read-only Explore per repo, in small waves, uniform ≤45-line report, targeted reads over whole-repo sweeps.
- Lint config lives at `config/custom.markdownlint.jsonc` and `config/cspell.json`; new project words go in `config/cspell.json` (alphabetical, case-insensitive), never suppressed.
- Target GitHub repo for PRs: `abed-supy-io/supy-wingspan`.
- **Do NOT `git add` or `git commit`** while implementing this plan unless a task explicitly says so — the final smoke test is manual.

---

### Task 1: Failing test for the coverage renderer (TDD red)

Write the test before the script so the red→green cycle is real.

**Files:**
- Create: `skills/supy-coverage-report/scripts/render-coverage.test.sh`

**Interfaces:**
- Consumes: the not-yet-written `scripts/render-coverage.sh` sibling.
- Produces: an offline, deterministic test that exits `0` when the renderer behaves and non-zero otherwise. Asserts three contracts: (a) an lcov tracefile at 82% renders `82%` + `PASS` and exits 0; (b) a tracefile at 60% renders `60%` + `FAIL` and exits 1; (c) `--stack flutter-melos` resolves the floor to `85%`.

- [ ] **Step 1: Write the test file** with exactly this content:

````bash
#!/usr/bin/env bash
# TDD structure test for render-coverage.sh — offline, deterministic, no API key.
# Run from the repo root:
#   bash skills/supy-coverage-report/scripts/render-coverage.test.sh
set -uo pipefail

script="skills/supy-coverage-report/scripts/render-coverage.sh"
tmp="$(mktemp -d)"
fail=0

# (a) lcov tracefile at 82% (LH=41 / LF=50) -> "82%", PASS, exit 0.
cat > "$tmp/pass.info" <<'LCOV'
TN:
SF:lib/foo.dart
LF:50
LH:41
end_of_record
LCOV
got="$(bash "$script" --label supy-mobile --floor 80 --lcov "$tmp/pass.info")"; rc=$?
printf '%s\n' "$got" | grep -q '82%'  || { echo "FAIL(a): want 82% in: $got"; fail=1; }
printf '%s\n' "$got" | grep -q 'PASS' || { echo "FAIL(a): want PASS in: $got"; fail=1; }
[ "$rc" -eq 0 ] || { echo "FAIL(a): want exit 0 for above-floor, got $rc"; fail=1; }

# (b) lcov tracefile at 60% (LH=30 / LF=50) -> "60%", FAIL, exit 1.
cat > "$tmp/fail.info" <<'LCOV'
SF:lib/bar.dart
LF:50
LH:30
end_of_record
LCOV
got="$(bash "$script" --label checklist --floor 80 --lcov "$tmp/fail.info")"; rc=$?
printf '%s\n' "$got" | grep -q '60%'  || { echo "FAIL(b): want 60% in: $got"; fail=1; }
printf '%s\n' "$got" | grep -q 'FAIL' || { echo "FAIL(b): want FAIL in: $got"; fail=1; }
[ "$rc" -eq 1 ] || { echo "FAIL(b): want exit 1 for below-floor, got $rc"; fail=1; }

# (c) --stack flutter-melos resolves the floor to 85%.
got="$(bash "$script" --label pkgs --stack flutter-melos --pct 90)"; rc=$?
printf '%s\n' "$got" | grep -q 'floor 85%' || { echo "FAIL(c): want floor 85% in: $got"; fail=1; }

rm -rf "$tmp"
[ "$fail" -eq 0 ] && echo "render-coverage: all tests passed"
exit "$fail"
````

- [ ] **Step 2: Watch it fail.** Run:

```bash
bash skills/supy-coverage-report/scripts/render-coverage.test.sh; echo "exit=$?"
```

Expected: a non-zero exit (the script does not exist yet — `bash: ...: No such file or directory` for each case, and `exit=1`). This confirms the test actually exercises the script.

---

### Task 2: The `render-coverage.sh` renderer (TDD green)

**Files:**
- Create: `skills/supy-coverage-report/scripts/render-coverage.sh`

**Interfaces:**
- Consumes: CLI flags `--label <name>` (required), one of `--floor <int>` or `--stack <stack>`, and one of `--pct <int>` or `--lcov <path>`.
- Produces: one line on stdout — `<label> [########------------]  NN%  (floor MM% PASS|FAIL)` — and exit code `0` when `pct >= floor`, else `1`. Stack→floor mapping mirrors `config/standards/ci-coverage-baseline.md` (flutter-app 80, flutter-melos 85, flutter-plugin 70, else 0). Uses ASCII `#`/`-` for the bar (no Unicode, keeps lint/cspell clean).

- [ ] **Step 1: Write the script** with exactly this content:

````bash
#!/usr/bin/env bash
# Render one coverage bar for a repo/package against its ci-coverage-baseline
# floor. Deterministic, offline, fixture-testable. The stack->floor mapping
# mirrors config/standards/ci-coverage-baseline.md.
#
# Usage:
#   render-coverage.sh --label <name> --floor <int> --lcov <path>
#   render-coverage.sh --label <name> --floor <int> --pct  <int>
#   render-coverage.sh --label <name> --stack <stack> --lcov <path>
#
# Exit: 0 when coverage >= floor, 1 when below, 2 on usage error.
set -uo pipefail

label="" floor="" pct="" lcov="" stack=""
while [ $# -gt 0 ]; do
  case "$1" in
    --label) label="${2:-}"; shift 2 ;;
    --floor) floor="${2:-}"; shift 2 ;;
    --pct)   pct="${2:-}";   shift 2 ;;
    --lcov)  lcov="${2:-}";  shift 2 ;;
    --stack) stack="${2:-}"; shift 2 ;;
    *) echo "render-coverage: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Stack -> floor, mirroring config/standards/ci-coverage-baseline.md.
if [ -z "$floor" ] && [ -n "$stack" ]; then
  case "$stack" in
    flutter-app)    floor=80 ;;
    flutter-melos)  floor=85 ;;
    flutter-plugin) floor=70 ;;
    *)              floor=0  ;;
  esac
fi

[ -n "$label" ] || { echo "render-coverage: --label required" >&2; exit 2; }
[ -n "$floor" ] || { echo "render-coverage: --floor or --stack required" >&2; exit 2; }

# Derive percentage from an lcov tracefile when not given directly.
if [ -z "$pct" ] && [ -n "$lcov" ]; then
  [ -f "$lcov" ] || { echo "render-coverage: lcov not found: $lcov" >&2; exit 2; }
  lf="$(awk -F: '/^LF:/{s+=$2} END{print s+0}' "$lcov")"
  lh="$(awk -F: '/^LH:/{s+=$2} END{print s+0}' "$lcov")"
  if [ "$lf" -gt 0 ]; then
    pct="$(awk "BEGIN{printf \"%d\", (100*$lh)/$lf}")"
  else
    pct=0
  fi
fi
[ -n "$pct" ] || { echo "render-coverage: --pct or --lcov required" >&2; exit 2; }

# 20-cell ASCII bar.
filled=$(( pct / 5 ))
[ "$filled" -gt 20 ] && filled=20
[ "$filled" -lt 0 ] && filled=0
bar=""
i=0
while [ "$i" -lt 20 ]; do
  if [ "$i" -lt "$filled" ]; then bar="${bar}#"; else bar="${bar}-"; fi
  i=$(( i + 1 ))
done

if [ "$pct" -ge "$floor" ]; then mark="PASS"; else mark="FAIL"; fi
printf '%-20s [%s] %3d%%  (floor %d%% %s)\n' "$label" "$bar" "$pct" "$floor" "$mark"

[ "$pct" -ge "$floor" ]
````

- [ ] **Step 2: Watch it pass.** Run:

```bash
bash skills/supy-coverage-report/scripts/render-coverage.test.sh; echo "exit=$?"
```

Expected final lines: `render-coverage: all tests passed` and `exit=0`.

- [ ] **Step 3: Lint the script.** Run:

```bash
shellcheck skills/supy-coverage-report/scripts/render-coverage.sh && echo OK
```

Expected: `OK` (no findings). Fix any `SC****` warnings before continuing.

---

### Task 3: The `supy-coverage-report` skill

**Files:**
- Create: `skills/supy-coverage-report/SKILL.md`

**Interfaces:**
- Consumes: reads `config/standards/ci-coverage-baseline.md` (satisfies the `validate-xrefs.sh` no-orphan rule for that standard); calls `${CLAUDE_PLUGIN_ROOT}/skills/supy-coverage-report/scripts/render-coverage.sh`; reuses the stack heuristic from `skills/shared/references/stack-detection.md`.
- Produces: a skill invokable as `supy-coverage-report` that prints one bar per package/repo, or a clear "no coverage artifact — run tests with coverage first" message. Never writes files, never echoes secrets.

- [ ] **Step 1: Write the skill file** with exactly this content:

````markdown
---
name: supy-coverage-report
description: '[any] Render coverage bars for a Supy repo against its ci-coverage-baseline floor. Detects the stack, finds the coverage artifact (lcov.info or Jest coverage-summary.json), compares to the floor from config/standards/ci-coverage-baseline.md, and prints a labelled PASS/FAIL bar per package. Use when you want a quick visual of whether a repo meets its coverage gate, or to assemble a fleet coverage snapshot. Read-only — never writes files or echoes secrets.'
---

You render a **coverage snapshot** for the current Supy repo: one bar per
package, each compared to the coverage floor codified in
`config/standards/ci-coverage-baseline.md`. This is read-only and offline — you
never run the repo's tests, write files, or push anything. If a coverage
artifact is missing, you say how to produce it and stop.

## Step 1 — Detect the stack and its floor

Prefer the stack named in the SessionStart hook line if one is in context.
Otherwise apply the canonical order in
`skills/shared/references/stack-detection.md`. Map the stack to the
`render-coverage.sh` `--stack` value:

- Flutter app → `flutter-app` (floor 80%)
- Flutter melos packages → `flutter-melos` (floor 85%)
- Flutter plugin → `flutter-plugin` (floor 70%)
- Node/TS stacks (nestjs-nx, angular-nx, firebase-functions, ts-cli,
  ai-agents) → pass an explicit `--floor` read from the repo's own
  `coverageThreshold` / lcov gate, per `config/standards/ci-coverage-baseline.md`.

## Step 2 — Find the coverage artifact

Look, in order, for the artifact the repo's own CI produces:

```bash
# Flutter / lcov-based
ls coverage/lcov.info 2>/dev/null
# Jest json-summary reporter
ls coverage/coverage-summary.json 2>/dev/null
```

For a melos monorepo, look for a `coverage/lcov.info` per package under
`packages/*/coverage/lcov.info`.

If no artifact exists, degrade gracefully — do not fabricate numbers:

```text
supy-coverage-report: no coverage artifact found.
Produce one first, e.g.:  flutter test --coverage   (or)   nx test <proj> --coverage
Then re-run this skill.
```

Stop there.

## Step 3 — Render the bars

Call the bundled renderer once per package. Never re-implement the maths here —
the script is the single source of the bar logic and is TDD-tested.

```bash
SCRIPT="${CLAUDE_PLUGIN_ROOT}/skills/supy-coverage-report/scripts/render-coverage.sh"
# Flutter app example:
bash "$SCRIPT" --label "$(basename "$PWD")" --stack flutter-app --lcov coverage/lcov.info
# melos: one call per package
for f in packages/*/coverage/lcov.info; do
  bash "$SCRIPT" --label "$(basename "$(dirname "$(dirname "$f")")")" --stack flutter-melos --lcov "$f"
done
```

For Jest `coverage-summary.json`, read `.total.lines.pct` (rounded to an
integer) and pass it via `--pct` with an explicit `--floor`:

```bash
PCT="$(jq -r '.total.lines.pct | floor' coverage/coverage-summary.json)"
bash "$SCRIPT" --label "$(basename "$PWD")" --floor 80 --pct "$PCT"
```

Print the collected bars as the result. A non-zero exit from the script for a
package means that package is **below floor** — surface it as a FAIL bar, do
not treat it as an error to abort on.

## Step 4 — Never leak secrets

Coverage artifacts do not contain credentials, but if you ever surface a file
path or snippet alongside the bars, cite `path:line` only — never a secret
value. This skill writes nothing and pushes nothing.

## Error handling summary

| Condition | Behavior |
|---|---|
| No coverage artifact | Print how to produce one; stop. No fabricated numbers. |
| A package is below floor | Render its FAIL bar; continue with the others; do not abort. |
| Stack undetected | Ask the user for the floor, or pass an explicit `--floor`. |
| `jq` unavailable (Jest path) | Say so and ask the user for the line-coverage %; render with `--pct`. |
````

- [ ] **Step 2: Validate skill structure.** Run:

```bash
bash scripts/validate-skills.sh 2>&1 | tail -5
```

Expected: no failure mentioning `supy-coverage-report` (name matches dir, starts with `---`, declares `name` + a 20–1024-char `description`).

---

### Task 4: The `supy-remine-standards` skill

**Files:**
- Create: `skills/supy-remine-standards/SKILL.md`

**Interfaces:**
- Consumes: reuses `supy-feedback`'s clone-and-PR mechanics (fixed `WORK` path, `SRC`/`DEGRADED`); reads the current `config/standards/` from the fresh clone; dispatches read-only **Explore** subagents (one per repo). Reconciliation mirrors the confirmed/divergent/new legend of `docs/analysis/SYNTHESIS.md`.
- Produces: **one** reviewable `config/standards/` diff landed as a single PR against `abed-supy-io/supy-wingspan` (or, on the degraded path, a printed diff). Complements — does not duplicate — `supy-feedback` (reactive, single divergence). This skill is the deliberate cross-repo sweep.

- [ ] **Step 1: Write the skill file** with exactly this content:

````markdown
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
````

- [ ] **Step 2: Validate skill structure.** Run:

```bash
bash scripts/validate-skills.sh 2>&1 | tail -5
```

Expected: no failure mentioning `supy-remine-standards`.

---

### Task 5: Wire the two skills into docs, spelling, and counts

Adding two skills bumps the tracked skill count 31 → 33. `check-docs-inventory.sh`
gates the exact numbers in `README.md` and `docs/USAGE.md`, and both skill
tables must list the new skills.

**Files:**
- Edit: `config/cspell.json`
- Edit: `README.md`
- Edit: `docs/USAGE.md`

**Interfaces:**
- Consumes: current counts (`31 skills`, `8 slash commands` — commands unchanged, no new command).
- Produces: `33 skills` everywhere the count appears, both skill tables updated, and new project words spelled-clean.

- [ ] **Step 1: Add project words to `config/cspell.json`.** Insert, in
  correct alphabetical position within the `words` array, each of: `lcov`,
  `remine`, `remining`, `tracefile`. (`lcov` after `lProj`/before `LTRB` region
  — place per case-insensitive order; `remine`/`remining` near `redeliverable`;
  `tracefile` near `traceparent`.) Do not reformat the rest of the array.

- [ ] **Step 2: Bump the counts and skill breakdown in `README.md`.**
  - Line ~53: `**8 slash commands** and **31 skills**` → `...and **33 skills**`.
  - Line ~264: `**31 skills**, grouped by stack ... 13 Universal (review, baseline, commit, create-pr, rebase, hotfix, debrief, fix-failing-github-actions, impl-spec, spike-spec, feature-fanout, feedback, kg)` → `**33 skills** ... 15 Universal (... , feedback, kg, coverage-report, remine-standards)`.

- [ ] **Step 3: Add rows to the README `### Skills` table.** Under the
  Universal group of the 2-column table (`| \`skill\` | description |`), add:

```markdown
| `supy-coverage-report` | Render coverage bars for the repo against its `ci-coverage-baseline` floor. |
| `supy-remine-standards` | Deliberate periodic sweep of the live repos that proposes a reviewable `config/standards` diff. |
```

- [ ] **Step 4: Bump the counts in `docs/USAGE.md`.**
  - Line ~132: `**31 skills**` → `**33 skills**`.
  - Line ~381 (the tree comment): `# 31 skills, one dir each` → `# 33 skills, one dir each`.

- [ ] **Step 5: Add rows to the `docs/USAGE.md` skills table.** In the
  3-column table with columns skill, stack, description — add the new skill with stack `any`:

```markdown
| `supy-coverage-report` | any | Render coverage bars for the repo against its `ci-coverage-baseline` floor (read-only). |
| `supy-remine-standards` | any | Deliberate periodic re-mine across the live repos; proposes one reviewable `config/standards` diff. |
```

---

### Task 6: Full validation gate

Run every check CI runs, plus the repo's structural validators, so the two new
skills are provably wired correctly.

**Files:** none (verification only).

- [ ] **Step 1: Structural validators.** Run:

```bash
bash scripts/validate-skills.sh && \
bash scripts/validate-xrefs.sh && \
bash scripts/check-docs-inventory.sh && \
bash evals/validate-fixtures.sh && \
echo "ALL VALIDATORS OK"
```

Expected: `ALL VALIDATORS OK`.
- `validate-xrefs.sh` must confirm `${CLAUDE_PLUGIN_ROOT}/skills/supy-coverage-report/scripts/render-coverage.sh` resolves **and** that `config/standards/ci-coverage-baseline.md` is now cited (by `supy-coverage-report`).
- `validate-fixtures.sh` must stay green — confirming the coverage test fixtures do **not** live under `evals/fixtures/` (they are generated in-test under a temp dir, so its `*/*/` glob never sees them).

- [ ] **Step 2: Lint.** Run:

```bash
npx markdownlint-cli2 --config config/custom.markdownlint.jsonc "**/*.md" "!CHANGELOG.md" && \
npx cspell --config config/cspell.json "**/*.md" && \
shellcheck skills/supy-coverage-report/scripts/*.sh && \
echo "LINT OK"
```

Expected: `LINT OK`. Any cspell miss → add the word to `config/cspell.json` (Task 5 Step 1), never suppress.

- [ ] **Step 3: Re-run the renderer test** to confirm nothing regressed:

```bash
bash skills/supy-coverage-report/scripts/render-coverage.test.sh
```

Expected: `render-coverage: all tests passed`.

---

### Task 7: Real-session smoke test (R3 exit criteria)

Per CLAUDE.md, a skill is not done until run in a real session; per the spec §8
exit criteria, the reporter must render bars for a pilot repo and the re-mining
skill must produce a reviewable standards diff within the token budget on a
deliberately-drifted target.

**Files:** none (manual verification; records outcomes only — do not commit).

- [ ] **Step 1: Install this checkout as a local marketplace and reload.**

```text
/plugin marketplace add <path-to-this-checkout>
/plugin install supy-wingspan@supy
/reload-plugins
```

- [ ] **Step 2: Coverage reporter on a pilot repo.** In `supy-mobile` (has
  `coverage/lcov.info` after `flutter test --coverage`), invoke
  `supy-coverage-report`. Expected: one or more bars like
  `supy-mobile          [################----]  82%  (floor 80% PASS)`. If no
  artifact, confirm the skill prints the "produce one first" message and stops
  (degrades, no crash).

- [ ] **Step 3: Re-mining on a deliberately-drifted target.** Pick one repo and
  one narrow standards area. Invoke `supy-remine-standards` scoped to that repo
  and area. Confirm, in order: (a) it asks for/echoes scope and the wave plan
  before dispatching; (b) it dispatches **one** read-only Explore for that repo
  with a targeted read list and a ≤45-line report; (c) it reconciles into a
  named-file summary; (d) it shows a diff and waits at the gate. Decline at the
  gate so nothing is pushed. Record the approximate token/turn count to confirm
  the sweep stayed inside budget.

- [ ] **Step 4: Record results.** Note both outcomes (bars rendered; drift diff
  produced within budget) wherever R3 status is tracked. Do not `git commit` —
  the human lands these changes via PR to `main`.

---

## Self-Review (writing-plans)

- **Bite-sized & TDD:** Task 1 writes a failing test, Task 2 makes it pass, Task 3+ build on green. Each step has an exact command and expected output.
- **No placeholders:** every file is given verbatim; the only `<...>` tokens are inside skill-body templates that the skill fills **at runtime** (repo names, diffs), which is correct — they are not implementer gaps.
- **Interfaces stated per task:** consumes/produces blocks name the concrete inputs, the `${CLAUDE_PLUGIN_ROOT}` path, and the standards citation that satisfies `validate-xrefs.sh`.
- **Constraints honored:** secrets → `path:line` only (stated in both skills); `${CLAUDE_PLUGIN_ROOT}` for the script path; Conventional Commits + `Co-Authored-By`; silent degradation; bounded fan-out verbatim from §4.5.
- **Fixture-safety verified:** coverage test fixtures are created in a temp dir inside the test, never under `evals/fixtures/`, so `validate-fixtures.sh` (`*/*/` glob) stays green.
- **Counts reconciled:** 31 → 33 skills bumped in all four locations `check-docs-inventory.sh` checks; commands unchanged at 8 (no new command).
- **Scope:** R3 only. R0/R1/R2/R4 are separate plans; this plan does not touch reviewers, hooks, or the eval runner beyond citing them.
