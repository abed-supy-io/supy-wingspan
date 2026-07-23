# R2 "Review Teeth" (data-driven from R1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise review precision and make enforcement real — using R1's true-positive / false-positive data, not guesswork, to decide what to harden. Add a **budget-gated adversarial verification** pass to `supy-review` (High-severity or low-confidence findings only), let reviewers emit **auto-fix suggested diffs** for mechanically-fixable rule classes, **close the residual pre-commit gap** the audit uncovered, and **calibrate the severity rubric** against R1's observed distribution.

**Architecture:** No runtime code — Markdown, shell, JSON. Adversarial verification is a decision procedure documented in `skills/supy-review/SKILL.md` and a new shared reference; it is *gated* so it never applies a blanket token multiplier. Auto-fix extends the existing per-agent `## Output Contract` with an **optional** `suggested fix` diff block (the severity line format is unchanged, so nothing regresses). The pre-commit work **hardens hooks that already ship** — the audit (spec §7, written before this state) said only `flutter` + `k8s-config` had hooks, but on disk **all six code stacks already ship substantive `.husky/pre-commit` / `hooks/pre-commit`** (gitleaks secret-scan + lint-staged + typecheck/analyze); the real residual gap is the **commit-message lint** and **coverage-bar** steps the spec named, plus a graceful **gitleaks-presence guard**. Every new assertion is a deterministic, CI-gated shell check written **before** the artifact it guards.

**Tech Stack:** Bash, `grep`/`jq`, `shellcheck`, Markdown, `git` (local commits only). Zero subagents; zero network.

> **Spec reconciliation note (must survive to execution).** This plan corrects `docs/superpowers/specs/2026-07-23-enhancement-roadmap-refresh-design.md` §1/§7 where they claim only `flutter` + `k8s-config` ship pre-commit hooks. Verified on disk 2026-07-23: `templates/{backend,frontend,firebase-functions,ts-cli,ai-agents}` each ship `.husky/pre-commit` and `templates/flutter/hooks/pre-commit` exists. Task 3 is therefore *harden + close residual gap*, not *add from scratch*. Confirm the on-disk state again at execution time before editing.

## Global Constraints

Every task's requirements implicitly include this section. Values are copied from `docs/superpowers/specs/2026-07-23-enhancement-roadmap-refresh-design.md` §3.

- **Data-driven, not guessed.** Every severity change and every "which findings get verified / auto-fixed" decision traces to an R1 triage entry (`docs/pilots/TRIAGE.md` scorecard). Where R1 data is not yet available at authoring time, the task marks the value **"populate from R1 triage at execution time"** rather than inventing one.
- **Secrets.** NEVER reproduce a secret value. The literal-secret → Secret-Manager-reference auto-fix cites `path:line` and emits a *reference*, never the value.
- **Component bodies** use `${CLAUDE_PLUGIN_ROOT}`, never hardcoded absolute paths. Human-facing docs may use absolute paths.
- **Conventional Commits.** `feat:` / `docs:` / `fix:` (use `fix()`, never `bug()`). Claude-authored commits end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Token / agent budget ("stay green").** The verification pass is **gated** (§4.3): it fires only on High-severity or explicitly low-confidence findings, one skeptic pass each, and degrades cheaply. It must be measured against R1's token baseline (`docs/PILOT.md`) — no unjustified regression. This plan itself spawns zero subagents.
- **Standards-first.** A severity or rule change edits `config/standards/` before the agent that cites it.

## Canonical data (single source of truth)

**Reviewers that gain the auto-fix contract** (all 11): `supy-architecture-reviewer`, `supy-nats-event-reviewer`, `supy-test-quality-reviewer`, `supy-security-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer`, `supy-angular-reviewer`, `supy-flutter-reviewer`, `supy-firebase-functions-reviewer`, `supy-ts-cli-reviewer`, `supy-ai-agents-reviewer`.

**Mechanical rule classes eligible for a suggested diff** (initial set; extend from R1 triage):

| Rule class | Reviewer | Suggested-fix shape |
|---|---|---|
| Missing commit trailer / wrong type | `supy-commit-pr-reviewer` | rewritten commit subject/trailer |
| Wrong import boundary (layer direction) | `supy-architecture-reviewer`, `supy-firebase-functions-reviewer` | corrected import path |
| Literal secret → Secret Manager reference | `supy-secrets-reviewer` | config line replaced with a `path:line`-cited reference (never the value) |
| Missing auth decorator on callable/tool | `supy-firebase-functions-reviewer`, `supy-ai-agents-reviewer` | decorator insertion |

**Code stacks whose hooks are hardened** (Task 3): `backend`, `frontend`, `firebase-functions`, `ts-cli`, `ai-agents` (husky) + `flutter` (plain git hook). `k8s-config` keeps its existing hook.

## File Structure

- `skills/shared/references/adversarial-verification.md` (create) — the gated skeptic protocol (when it fires, the one-pass refute test, cheap degradation, budget note).
- `skills/supy-review/SKILL.md` (modify) — insert the gated verification step + link the reference.
- `scripts/check-review-teeth.sh` (create) — deterministic gate: asserts the SKILL documents the verification gate + budget guard + reference link, and that `review-severity.md` carries a calibration log.
- `agents/supy-*-reviewer.md` (modify, 11) — add an **optional** "Suggested fix" clause to each `## Output Contract`.
- `scripts/validate-agents.sh` (modify) — assert every reviewer's Output Contract documents the optional suggested-fix clause.
- `scripts/check-template-hooks.sh` (create) — assert each code stack's hook has secret-scan + commit-message lint + coverage-bar + gitleaks-presence guard.
- `templates/{backend,frontend,firebase-functions,ts-cli,ai-agents}/.husky/{commit-msg,pre-commit}` and `templates/flutter/hooks/{commit-msg,pre-commit}` (modify/create) — add the missing steps.
- `config/standards/review-severity.md` (modify) — add a "Calibration log" section traceable to R1.
- `.github/workflows/ci.yaml` (modify) — run the two new check scripts (they also match the existing `scripts/*.sh` shellcheck glob).

---

### Task 1: Gated adversarial verification in supy-review

**Files:**
- Create: `skills/shared/references/adversarial-verification.md`, `scripts/check-review-teeth.sh`
- Modify: `skills/supy-review/SKILL.md`

**Interfaces:**
- Produces: a documented gate — verification fires **only** for findings that are High-severity *or* flagged low-confidence; one skeptic pass tries to refute; a finding survives only if not refuted; on budget pressure the pass degrades to "note as unverified" rather than blocking. `check-review-teeth.sh` **Check V** asserts the SKILL links the reference and contains the gate + budget guard.
- Consumes: `config/standards/review-severity.md` (the `high` definition) and the R1 token baseline in `docs/PILOT.md`.

- [ ] **Step 1: Write the gate check first**

Create `scripts/check-review-teeth.sh`:

```bash
#!/usr/bin/env bash
# Deterministic gate for R2 "review teeth": verification protocol + severity log.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
err() { echo "✗ $1"; fail=1; }
ok()  { echo "✓ $1"; }

skill="skills/supy-review/SKILL.md"
ref="skills/shared/references/adversarial-verification.md"

# --- Check V: gated adversarial verification is documented. ---
[ -f "$ref" ] || err "missing $ref"
grep -q "adversarial-verification.md" "$skill" || err "$skill does not link the verification reference"
grep -qiE "high-severity|low-confidence" "$skill" || err "$skill does not state the verification gate (high/low-confidence)"
grep -qiE "budget|degrade|unverified" "$skill" || err "$skill does not state the budget/degradation guard"
[ "$fail" -eq 0 ] && ok "review-teeth checks passed"
exit "$fail"
```

- [ ] **Step 2: Run the check to confirm it fails**

Run: `bash scripts/check-review-teeth.sh`
Expected: `✗ missing skills/shared/references/adversarial-verification.md` (and the SKILL-link errors), exit 1.

- [ ] **Step 3: Author the reference + wire it into the SKILL**

Create `skills/shared/references/adversarial-verification.md` documenting: the gate (High-severity OR reviewer-flagged low-confidence only), the single-pass refutation test ("a second read tries to prove this finding wrong; it survives only if it cannot be refuted from the diff + cited standard"), explicit **no blanket multiplier**, and cheap degradation (under budget pressure, label the finding `unverified` and proceed — never block the whole review). Add a step to `skills/supy-review/SKILL.md` invoking this gate after findings are graded, linking the reference by relative path.

- [ ] **Step 4: Run the check to confirm it passes**

Run: `bash scripts/check-review-teeth.sh`
Expected: `✓ review-teeth checks passed`, exit 0.

- [ ] **Step 5: Shellcheck + commit**

```bash
shellcheck scripts/check-review-teeth.sh
git add scripts/check-review-teeth.sh skills/shared/references/adversarial-verification.md skills/supy-review/SKILL.md
git commit -m "$(cat <<'EOF'
feat: gated adversarial verification in supy-review

A second-pass skeptic refutes High-severity or low-confidence findings only —
no blanket token multiplier, degrades to 'unverified' under budget pressure.
check-review-teeth.sh gates the protocol's presence.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Auto-fix suggested diffs in the Output Contract

**Files:**
- Modify: all 11 `agents/supy-*-reviewer.md`; `scripts/validate-agents.sh`

**Interfaces:**
- Consumes: the existing `## Output Contract` section (present in every reviewer; asserted by `validate-agents.sh:62`) and its severity line format `**[severity: …]** <file>:<line> — <problem> → <fix> (rule: <anchor>)`.
- Produces: an **optional** "Suggested fix" clause — when a finding is in a mechanical rule class, the reviewer MAY append a fenced ` ```diff ` block. `validate-agents.sh` gains a check that each reviewer documents this clause. The severity line format is unchanged; the diff is additive.

- [ ] **Step 1: Add the Output-Contract assertion to validate-agents.sh first**

In `scripts/validate-agents.sh`, alongside the existing Output-Contract presence check (~line 62), add for each reviewer:

```bash
  if ! grep -qiE 'suggested fix' "$file"; then
    err "$file Output Contract does not document the optional suggested-fix clause"
  fi
```

- [ ] **Step 2: Run the validator to confirm it fails**

Run: `bash scripts/validate-agents.sh`
Expected: `✗ agents/supy-architecture-reviewer.md Output Contract does not document…` for all 11 reviewers, non-zero exit.

- [ ] **Step 3: Add the suggested-fix clause to every reviewer's Output Contract**

In each `agents/supy-*-reviewer.md` `## Output Contract`, add a clause (uniform wording, per-reviewer example drawn from the canonical rule-class table):

> **Suggested fix (optional).** When a finding is a mechanical rule violation (see the rule-class list), append a minimal ` ```diff ` block that applies the fix. Never emit a secret value — a literal-secret finding's diff replaces the line with a Secret-Manager *reference* and cites `path:line`. Omit the block when the fix is non-mechanical or ambiguous.

- [ ] **Step 4: Run the validator + full agent suite to confirm pass**

Run: `bash scripts/validate-agents.sh`
Expected: all reviewers pass the new check plus the existing frontmatter/name/Output-Contract checks, exit 0.

- [ ] **Step 5: Shellcheck + commit**

```bash
shellcheck scripts/validate-agents.sh
git add scripts/validate-agents.sh agents/supy-*-reviewer.md
git commit -m "$(cat <<'EOF'
feat: optional auto-fix suggested diffs in reviewer Output Contracts

Every reviewer may now append a minimal diff for mechanical rule classes
(commit trailer, import boundary, literal secret -> Secret Manager reference,
missing auth decorator). Secret values are never reproduced. validate-agents.sh
enforces the clause.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Harden pre-commit hooks + close the residual gap

**Files:**
- Create: `scripts/check-template-hooks.sh`; `templates/*/…/commit-msg` hooks
- Modify: the six code-stack pre-commit hooks; `.github/workflows/ci.yaml`

**Interfaces:**
- Consumes: the existing hooks (gitleaks + lint-staged + typecheck/analyze) discovered in the audit.
- Produces: each code stack's hook set carries **(a)** a secret scan, **(b)** a commit-message lint (`commit-msg` hook running commitlint against `config/standards/commit-conventions.md`), **(c)** a coverage-bar check, and **(d)** a graceful gitleaks-presence guard (clear message + non-zero, not a cryptic `command not found`). `check-template-hooks.sh` asserts all four per stack and is CI-gated.

- [ ] **Step 1: Write the hook-coverage check first**

Create `scripts/check-template-hooks.sh` iterating the code stacks. For each, resolve its hook dir (`.husky/` for husky stacks, `hooks/` for flutter) and assert the pre-commit contains a secret scan (`gitleaks`) with a presence guard (`command -v gitleaks`), that a `commit-msg` hook exists and invokes commitlint, and that a coverage-bar step is referenced. Use `err`/`ok` and iterate a `STACKS` array.

- [ ] **Step 2: Run the check to confirm it fails**

Run: `bash scripts/check-template-hooks.sh`
Expected: `✗` for each stack missing the `commit-msg` hook, the coverage step, and the gitleaks-presence guard, exit 1.

- [ ] **Step 3: Add the missing hook steps**

For each husky stack, add a `commit-msg` hook (`npx --no-install commitlint --edit "$1"`) and prepend the pre-commit's gitleaks call with a presence guard:

```sh
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "pre-commit: gitleaks not found — install with 'brew install gitleaks' (secret scan is non-negotiable)." >&2
  exit 1
fi
```

Add a coverage-bar step (`npx nx affected -t test --coverage` gated to the affected projects, or the stack's equivalent) referencing `config/standards/ci-coverage-baseline`. For `flutter`, add the guard to `hooks/pre-commit` and a `hooks/commit-msg` running the commit-convention check. Keep each hook offline and fast.

- [ ] **Step 4: Run the check to confirm it passes**

Run: `bash scripts/check-template-hooks.sh`
Expected: `✓` per stack, exit 0.

- [ ] **Step 5: Wire both new checks into CI**

In `.github/workflows/ci.yaml`, add a job (or extend an existing structure job) running `bash scripts/check-review-teeth.sh` and `bash scripts/check-template-hooks.sh`. (Both already fall under the `shellcheck` job's `scripts/*.sh` glob.)

- [ ] **Step 6: Shellcheck + commit**

```bash
shellcheck scripts/check-template-hooks.sh
git add scripts/check-template-hooks.sh templates .github/workflows/ci.yaml
git commit -m "$(cat <<'EOF'
feat: harden template pre-commit hooks + commit-msg lint

Adds commit-msg commitlint hooks, a coverage-bar step, and a graceful
gitleaks-presence guard to every code stack's hooks. check-template-hooks.sh
gates the four required steps per stack in CI. Corrects the spec's stale
"only flutter + k8s-config ship hooks" claim.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Severity calibration from R1 data

**Files:**
- Modify: `config/standards/review-severity.md`; `scripts/check-review-teeth.sh`

**Interfaces:**
- Consumes: the R1 triage scorecard (`docs/pilots/TRIAGE.md`) — the observed TP/FP distribution.
- Produces: a "Calibration log" section in `review-severity.md` recording each severity adjustment with a trace to the R1 finding that motivated it. `check-review-teeth.sh` gains **Check C** asserting the section exists.

- [ ] **Step 1: Add Check C to the review-teeth gate first**

In `scripts/check-review-teeth.sh`, add:

```bash
sev="config/standards/review-severity.md"
grep -qi "Calibration log" "$sev" || err "$sev has no 'Calibration log' section (R1 traceability)"
```

- [ ] **Step 2: Run the check to confirm it fails**

Run: `bash scripts/check-review-teeth.sh`
Expected: `✗ config/standards/review-severity.md has no 'Calibration log' section`, exit 1.

- [ ] **Step 3: Add the Calibration log section**

Append a "## Calibration log" to `review-severity.md`: a table `Date | Rule/anchor | Change | Traced to (R1 triage entry)`. Seed it with a header row and the instruction that **each row must cite an R1 triage entry** — the concrete rows are **"populate from R1 triage at execution time"** (R2 runs after R1's scorecard lands). Do not invent severity changes without a TP/FP observation behind them.

- [ ] **Step 4: Run the check + the full docs suite to confirm pass**

Run: `bash scripts/check-review-teeth.sh && bash scripts/validate-agents.sh`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add config/standards/review-severity.md scripts/check-review-teeth.sh
git commit -m "$(cat <<'EOF'
docs: add R1-traceable severity calibration log

review-severity.md gains a Calibration log whose every row must cite the R1
triage entry that motivated the change. check-review-teeth.sh enforces the
section's presence.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## After This Plan (human step — not executable here)

With R1's scorecard and `TRIAGE.md` populated, a maintainer fills the Calibration log rows and the mechanical-rule-class list from real TP/FP data, then runs the 3 flagship stacks again (or their fixtures) to confirm the verification pass costs no more than the R1 token baseline allows. R2 exit criteria (spec §7): verification gated + measured against the R1 baseline (no unjustified regression); auto-fix diffs emitted for at least the mechanical rule classes; all code stacks ship installable hooks with secret-scan + commit-msg lint + coverage-bar; severity rubric updated with per-change R1 traces.

## Self-Review

**1. Spec coverage (refresh spec §7 + §3):**
- Gated adversarial verification (High/low-confidence, no blanket multiplier) → Task 1. ✓
- Auto-fix suggested diffs for mechanical rule classes → Task 2 (secret-safe). ✓
- Fill the pre-commit gap for the 5 stacks → Task 3, **reconciled**: hooks already ship, so *harden + close residual gap* (commit-msg lint, coverage-bar, gitleaks guard); drift flagged in the reconciliation note. ✓
- Severity calibration from R1 data → Task 4, R1-data-dependent rows deferred to execution. ✓
- §3 constraints (no secret values, `${CLAUDE_PLUGIN_ROOT}`, Conventional Commits + trailer, gated budget, zero fan-out, standards-first) → Global Constraints + every task. ✓

**2. Placeholder scan:** The only deferred values are the explicitly-marked "populate from R1 triage at execution time" cells in Task 4 and the mechanical-rule-class extensions in Task 2 — intentional, because R2 consumes R1's output. No stray TODOs in the plan's own logic.

**3. Type consistency:** The 11 reviewer filenames match the canonical list and `validate-agents.sh`'s iteration. The severity line format is quoted verbatim from `review-severity.md` and left unchanged (the diff block is additive). Hook-dir resolution (`.husky/` vs `hooks/`) matches the on-disk audit. New check scripts live under `scripts/*.sh`, already covered by the CI shellcheck glob.

**4. Dependency direction:** R2 is correctly downstream of R1 — verification gating, auto-fix rule classes, and severity rows all consume R1's triage. Nothing in R2 blocks R1.
