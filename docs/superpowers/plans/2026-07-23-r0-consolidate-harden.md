# R0 "Consolidate & Harden" (cross-cutting) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure the ~30 skills that shipped fast are individually sound and non-overlapping **before** more surface is added — a committed skill quality/overlap audit with a dedup/hardening action list, a deterministic skill-hygiene gate, a documented trigger-overlap registry, and a completeness gate asserting **every reviewer agent has ≥1 eval fixture**. R0 runs **cross-cutting alongside R1** — it neither blocks nor is blocked by the pilots, and it completes the per-reviewer fixture coverage that R1's stack-distinctive fixtures begin.

**Architecture:** No runtime code. The audit is a committed Markdown report (`docs/skill-audit.md`) produced by inspecting every `skills/*/SKILL.md` at execution time; the plan ships the report skeleton + the deterministic gates that keep the findings honest. Two new shell checks (`scripts/check-skill-hygiene.sh`, extending `evals/validate-fixtures.sh`) turn the audit's exit criteria into CI-enforced invariants: each skill has a non-trivial decision procedure + triggering description; each flagged trigger overlap has a documented reason in a registry; each of the 11 reviewers has ≥1 fixture. Every assertion is written **before** the artifact it guards.

**Tech Stack:** Bash, `grep`/`jq`/`awk`, `shellcheck`, Markdown, `git` (local commits only). Zero subagents; zero network.

## Global Constraints

Every task's requirements implicitly include this section. Values are copied from `docs/superpowers/specs/2026-07-23-enhancement-roadmap-refresh-design.md` §3.

- **Secrets.** NEVER reproduce a secret value in any file; cite `path:line` only.
- **Component bodies** use `${CLAUDE_PLUGIN_ROOT}`, never hardcoded absolute paths. Human-facing docs (the audit report) may use repo-relative paths.
- **Conventional Commits.** `feat:` / `docs:` / `fix:` (use `fix()`, never `bug()`). Claude-authored commits end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Token / agent budget ("stay green").** The audit inspects skills with scoped reads (one `SKILL.md` at a time); it uses **zero subagents** and no fan-out. Any large read is degraded to `grep`/`head`.
- **No merges without a reason.** Deduping or merging two skills requires a recorded rationale in the audit; a merge that removes a user-invocable trigger must note the replacement so no workflow silently breaks.
- **Standards-first.** If the audit finds a skill contradicting `config/standards/`, the standard is the source of truth; fix the skill.

## Canonical data (single source of truth)

**All 11 reviewers require ≥1 fixture (R0 exit criterion).** R1 seeds the stack-distinctive dimensions; R0 completes the rest:

| Reviewer | Dimension dir | Seeded by |
|---|---|---|
| `supy-secrets-reviewer` | `secrets` | pre-existing |
| `supy-architecture-reviewer` | `architecture` | R1 |
| `supy-angular-reviewer` | `angular` | R1 |
| `supy-flutter-reviewer` | `flutter` | R1 |
| `supy-firebase-functions-reviewer` | `firebase-functions` | R1 |
| `supy-ts-cli-reviewer` | `ts-cli` | R1 |
| `supy-ai-agents-reviewer` | `ai-agents` | R1 |
| `supy-nats-event-reviewer` | `nats-event` | **R0** |
| `supy-test-quality-reviewer` | `test-quality` | **R0** |
| `supy-security-reviewer` | `security` | **R0** |
| `supy-commit-pr-reviewer` | `commit-pr` | **R0** |

**Skill hygiene minimums** (asserted by the gate): frontmatter `name` + `description` non-empty; a decision procedure present (not a stub); `description` states *when* to use the skill (a triggering phrase), not only *what* it does.

## File Structure

- `docs/skill-audit.md` (create) — the audit report: per-skill row (name, description-quality, decision-procedure depth, `references/` extraction, overlap flag) + a dedup/hardening action list.
- `config/skill-overlaps.md` (create) — the trigger-overlap registry: each intentionally-overlapping skill pair + its documented reason.
- `scripts/check-skill-hygiene.sh` (create) — deterministic skill-hygiene + overlap-registry gate.
- `evals/validate-fixtures.sh` (modify) — extend R1's coverage check to **all 11 reviewers** (Check S → full per-reviewer coverage).
- `evals/fixtures/{nats-event,test-quality,security,commit-pr}/…` (create) — the four nestjs sub-reviewer fixtures.
- `.github/workflows/ci.yaml` (modify) — run `scripts/check-skill-hygiene.sh` (already under the shellcheck glob; add an execution job).

---

### Task 1: Skill-hygiene gate + audit report skeleton

**Files:**
- Create: `scripts/check-skill-hygiene.sh`, `docs/skill-audit.md`
- Modify: `.github/workflows/ci.yaml`

**Interfaces:**
- Consumes: every `skills/*/SKILL.md` and the existing `scripts/validate-skills.sh` conventions (frontmatter parsing).
- Produces: **Check H** — each `SKILL.md` has non-empty `name` + `description`, a `description` containing a triggering cue (`use when` / `when …`), and a body above a minimum substance threshold (decision procedure not a stub). A committed `docs/skill-audit.md` whose per-skill rows are filled at execution time.

- [ ] **Step 1: Write the hygiene check first**

Create `scripts/check-skill-hygiene.sh`:

```bash
#!/usr/bin/env bash
# Deterministic skill-hygiene gate (R0): every SKILL.md has a trigger cue and is non-stub.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
err() { echo "✗ $1"; fail=1; }

while IFS= read -r skill; do
  fm="$(awk '/^---$/{n++; next} n==1' "$skill")"
  grep -qE '^name:[[:space:]]*\S'        <<<"$fm" || err "$skill: empty/missing name"
  desc="$(grep -E '^description:' <<<"$fm" | sed -E 's/^description:[[:space:]]*//')"
  [ -n "$desc" ] || err "$skill: empty/missing description"
  grep -qiE 'use when|when ' <<<"$desc"  || err "$skill: description lacks a triggering cue ('use when …')"
  # Body substance: SKILL.md below ~15 non-frontmatter lines is a stub.
  body_lines="$(awk '/^---$/{n++; next} n>=2' "$skill" | grep -cve '^[[:space:]]*$')"
  [ "${body_lines:-0}" -ge 15 ] || err "$skill: decision procedure looks like a stub ($body_lines lines)"
done < <(find skills -name SKILL.md ! -path 'skills/shared/*')

[ "$fail" -eq 0 ] && echo "✓ skill-hygiene passed"
exit "$fail"
```

- [ ] **Step 2: Run the check to confirm it surfaces real issues**

Run: `bash scripts/check-skill-hygiene.sh`
Expected: either `✓ skill-hygiene passed`, or `✗` lines naming skills whose description lacks a triggering cue / whose body is a stub. **Record every `✗` as an audit finding** — this is the gate doing R0's job. If it passes clean on the first run, tighten the threshold or the cue set until it reflects the real audit, then proceed.

- [ ] **Step 3: Author the audit report + fix the flagged skills**

Create `docs/skill-audit.md` with: an inventory table (`Skill | Description quality | Decision-procedure depth | references/ extracted? | Overlap flag | Action`) covering **every** `skills/*/SKILL.md` (fill rows at execution time by reading each), and a "## Dedup / hardening action list" section. For each skill the gate flagged, either fix it (add a triggering cue, extract long material into `references/`, flesh out a stub) or record an explicit exception in the action list. Re-run the gate until green.

- [ ] **Step 4: Wire the gate into CI**

Add a job to `.github/workflows/ci.yaml` running `bash scripts/check-skill-hygiene.sh`.

- [ ] **Step 5: Shellcheck + commit**

```bash
shellcheck scripts/check-skill-hygiene.sh
git add scripts/check-skill-hygiene.sh docs/skill-audit.md .github/workflows/ci.yaml
git commit -m "$(cat <<'EOF'
feat: skill-hygiene gate + skill audit report

check-skill-hygiene.sh fails CI when a SKILL.md lacks a triggering cue or is a
stub. docs/skill-audit.md records the per-skill audit and the dedup/hardening
action list.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Trigger-overlap registry + gate

**Files:**
- Create: `config/skill-overlaps.md`
- Modify: `scripts/check-skill-hygiene.sh`

**Interfaces:**
- Consumes: the audit's overlap flags (Task 1) and each skill's `description` triggering cue.
- Produces: a registry `config/skill-overlaps.md` listing each intentionally-overlapping skill pair + its documented reason. **Check O** — every skill pair the audit flags as overlapping appears in the registry with a non-empty reason (no undocumented overlap). Detection is audit-driven (a curated flag list), not fuzzy auto-clustering; the check enforces documentation, and the gate honestly notes it cannot prove *absence* of overlap.

- [ ] **Step 1: Add Check O to the hygiene gate first**

In `scripts/check-skill-hygiene.sh`, add: read the audit's flagged pairs from a machine-readable block in `config/skill-overlaps.md` (a table), and assert each flagged pair has a non-empty `Reason` cell; assert the registry file exists. Keep it grep/awk-based and deterministic.

- [ ] **Step 2: Run the check to confirm it fails**

Run: `bash scripts/check-skill-hygiene.sh`
Expected: `✗ missing config/skill-overlaps.md` (and, once created empty, `✗ overlap pair … has no reason`), exit 1.

- [ ] **Step 3: Author the registry**

Create `config/skill-overlaps.md` with a table `Skill A | Skill B | Overlap | Reason (why both exist)`. Populate from the Task-1 audit's overlap flags — e.g. the reactive `supy-feedback` vs. the periodic re-mining skill (R3), or any Jira-spec / git-flow skills that share triggers. Every flagged pair gets a reason or is merged (recording the merge in `docs/skill-audit.md`). Add a one-line caveat that the gate enforces documentation of *known* overlaps, not their absence.

- [ ] **Step 4: Run the check to confirm it passes**

Run: `bash scripts/check-skill-hygiene.sh`
Expected: `✓ skill-hygiene passed`, exit 0.

- [ ] **Step 5: Commit**

```bash
shellcheck scripts/check-skill-hygiene.sh
git add config/skill-overlaps.md scripts/check-skill-hygiene.sh
git commit -m "$(cat <<'EOF'
docs: trigger-overlap registry for skills

config/skill-overlaps.md documents each intentionally-overlapping skill pair
and why both exist; the hygiene gate fails on any flagged pair without a reason.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Complete per-reviewer eval-fixture coverage

**Files:**
- Modify: `evals/validate-fixtures.sh`
- Create: `evals/fixtures/{nats-event,test-quality,security,commit-pr}/…`

**Interfaces:**
- Consumes: R1's `reviewer`-field contract + Check S (`REQUIRED_DIMS`).
- Produces: **Check S extended to all 11 reviewers** — the validator derives the required dimension list from the reviewer agents themselves (every `agents/supy-*-reviewer.md` must have a fixture whose `reviewer` names it), closing the R0 exit criterion. The four missing nestjs sub-reviewer fixtures.

- [ ] **Step 1: Strengthen Check S to derive coverage from the agents**

In `evals/validate-fixtures.sh`, replace/augment R1's static `REQUIRED_DIMS` with a derivation: for every `agents/supy-*-reviewer.md`, assert at least one fixture's `expected.json` has `.reviewer == <that agent>`:

```bash
# --- Check S+: every reviewer agent is exercised by >=1 fixture. ---
for agent_file in agents/supy-*-reviewer.md; do
  rv="$(basename "$agent_file" .md)"
  if ! grep -rl "\"reviewer\"[[:space:]]*:[[:space:]]*\"$rv\"" "$fixtures_root"/*/*/expected.json >/dev/null 2>&1; then
    err "no fixture exercises reviewer: $rv"
  fi
done
```

- [ ] **Step 2: Run the validator to confirm it fails**

Run: `bash evals/validate-fixtures.sh`
Expected (assuming R1 landed its 7 dims): `✗ no fixture exercises reviewer: supy-nats-event-reviewer` (and test-quality, security, commit-pr), exit 1.

- [ ] **Step 3: Author the four missing fixtures**

Create one issues fixture per remaining reviewer, drawn from the nestjs pilot repo's conventions (secrets planted as obvious fakes only, `verdict:"issues"`, `reviewer` set):

| Dimension | Reviewer | Issues fixture (rule) |
|---|---|---|
| `nats-event` | `supy-nats-event-reviewer` | `01-subject-naming` — event subject violating the naming/context-map rule, or business logic in the handler |
| `test-quality` | `supy-test-quality-reviewer` | `01-assertion-free-test` — a test with no meaningful assertion / mocked-under-test |
| `security` | `supy-security-reviewer` | `01-hardcoded-role` — a hardcoded role bypassing Cerbos |
| `commit-pr` | `supy-commit-pr-reviewer` | `01-bad-commit-subject` — a commit subject violating Conventional Commits (e.g. `bug()` type) |

- [ ] **Step 4: Run the validator to confirm full coverage**

Run: `bash evals/validate-fixtures.sh`
Expected: every reviewer exercised, all fixtures structurally valid, exit 0.

- [ ] **Step 5: Shellcheck + commit**

```bash
shellcheck evals/validate-fixtures.sh
git add evals/validate-fixtures.sh evals/fixtures
git commit -m "$(cat <<'EOF'
test: assert every reviewer has >=1 eval fixture

Check S+ derives required coverage from the reviewer agents themselves and
fails CI if any reviewer is unexercised. Adds the four missing nestjs
sub-reviewer fixtures (nats-event, test-quality, security, commit-pr).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## After This Plan (human step — not executable here)

The audit report's action list is triaged into follow-up commits (merges, `references/` extractions, description rewrites) as capacity allows; the gates keep the invariants from regressing. R0 exit criteria (spec §9): audit report committed with a dedup/hardening action list; every reviewer has ≥1 eval fixture (CI-gated); no two skills have overlapping triggers without a documented reason in the registry. Because R0 is cross-cutting, these commits interleave with R1 rather than gating it.

## Self-Review

**1. Spec coverage (refresh spec §9 + §3):**
- Skill quality/overlap audit of all skills (esp. the ~15 shipped off-roadmap) → Task 1 (`docs/skill-audit.md` + hygiene gate). ✓
- Dedup/merge where two skills overlap → Task 1 action list + Task 2 registry (merges recorded). ✓
- Grow eval coverage; each reviewer ≥1 fixture → Task 3 (Check S+ derived from agents). ✓
- Exit: audit report + action list committed; each reviewer ≥1 fixture; no undocumented trigger overlap → all three gated. ✓
- §3 constraints (no secret values, `${CLAUDE_PLUGIN_ROOT}`, Conventional Commits + trailer, scoped reads/zero fan-out, standards-first) → Global Constraints + every task. ✓

**2. Placeholder scan:** The audit *rows* and the overlap *pairs* are filled at execution time by reading the real skills — this is inherent to an audit, and the gates ensure the fills are honest (a stub or undocumented overlap fails CI). No stray TODOs in the plan's logic.

**3. Type consistency:** The 11 reviewer filenames and their dimension dirs match R1's canonical table and R1's `reviewer`-field contract; Check S+ derives from `agents/supy-*-reviewer.md` so it cannot drift from the agent set. The hygiene gate's frontmatter parsing mirrors `scripts/validate-skills.sh`.

**4. Cross-plan seam with R1:** R1 owns the stack-distinctive fixtures + the initial Check S; R0 extends Check S to full per-reviewer coverage and backfills the four nestjs sub-reviewers. No double-authoring: the table's "Seeded by" column assigns each dimension to exactly one plan.
