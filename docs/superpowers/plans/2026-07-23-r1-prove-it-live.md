# R1 "Prove It Live" (hybrid) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the behavioral-eval harness from secrets-only to **every stack's reviewers** so the plugin has reproducible, CI-gated evidence that its reviewers fire on real diffs — per-dimension fixture diffs (secrets scrubbed to `path:line`) paired with an expected-findings manifest, a generic offline runner that emits a **true-positive / false-positive / missed** scorecard with a token estimate, and a deterministic structural gate wired into CI — then record the 3 flagship **live-proof** runs in `docs/PILOT.md` and open the triage→asset-fix loop that feeds R2.

**Architecture:** Reuse the existing `evals/` pattern wholesale. Fixtures stay organized by reviewer **dimension** (`evals/fixtures/<dimension>/<NN-name>/{input.diff,expected.json}`), exactly as `evals/fixtures/secrets/` already is; each dimension maps to one reviewer agent. `expected.json` gains a top-level `reviewer` field naming the agent file, so a single generic runner can drive any reviewer. `run-secrets-eval.sh` is generalized into `run-review-eval.sh <dimension>` (the secrets script becomes a thin shim). The **deterministic, key-free** half — `validate-fixtures.sh`, already the `eval-fixtures` CI job — grows checks for the new field and for per-stack coverage; that is the "test" driven test-first in every task. The scoring math is unit-tested offline (`evals/test-scorecard.sh`) by feeding canned reviewer output through the scorer, so no task depends on non-deterministic LLM output. The live LLM runner and the 3 flagship runs are exercised by a human (they need the `claude` CLI + a real install); this plan authors and gates everything around them.

**Tech Stack:** Bash (POSIX-ish, `bash` arrays), `jq`, `grep`, `shellcheck`, Markdown, `git` (local commits only). No network, no subagents.

## Global Constraints

Every task's requirements implicitly include this section. Values are copied from `docs/superpowers/specs/2026-07-23-enhancement-roadmap-refresh-design.md` §3.

- **Secrets.** NEVER reproduce a secret value in any file, diff, fixture, commit message, or finding. Fixture diffs that *demonstrate* a leaked secret use an obviously-fake planted token (as the existing `secrets` fixtures do) and cite `path:line`; never a real credential.
- **Component bodies** use `${CLAUDE_PLUGIN_ROOT}`, never hardcoded absolute paths. `evals/` scripts and human-facing docs may use repo-relative paths.
- **Conventional Commits.** `feat:` / `docs:` / `fix:` (use `fix()`, never `bug()`). Allowed types: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test. Claude-authored commits end with the trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Token / agent budget ("stay green").** Scoped reads, model tiering, gated verification, bounded fan-out, cheap degradation (§3.5). This plan itself uses **zero subagents** — only local file edits, `jq`, and `bash`. The runner keeps the secrets script's per-reviewer, one-diff-at-a-time cost profile; it never fans out reviewers in parallel.
- **Pilot branches are local-only.** The 3 flagship live runs happen in target repos on throwaway scratch branches that are **never pushed**. This plugin repo lands via PRs to `main`, CI-gated.
- **Standards-first.** A "missed" finding is only fixed by mining the rule into `config/standards/` *before* touching the reviewer agent that must catch it.

## Canonical dimension data (single source of truth)

Every task draws from this table. Reviewer names match `agents/supy-*-reviewer.md`; the `secrets` dimension already exists. Each stack is proven by its **distinctive** dimension; the remaining nestjs sub-reviewers (`nats-event`, `test-quality`, `security`, `commit-pr`) are completed under R0.

| Dimension dir | Reviewer agent | Proves stack(s) | R1 seeds |
|---|---|---|---|
| `secrets` (exists) | `supy-secrets-reviewer` | all stacks incl. k8s-config | +1 k8s ConfigMap fixture |
| `architecture` | `supy-architecture-reviewer` | nestjs-nx | ✔ |
| `angular` | `supy-angular-reviewer` | angular-nx | ✔ |
| `flutter` | `supy-flutter-reviewer` | flutter A + B | ✔ (one per profile) |
| `firebase-functions` | `supy-firebase-functions-reviewer` | firebase-functions | ✔ |
| `ts-cli` | `supy-ts-cli-reviewer` | ts-cli | ✔ |
| `ai-agents` | `supy-ai-agents-reviewer` | ai-agents | ✔ |

**Flagship live-proof stacks** (one real install→detect→`/supy-review` each, recorded in `docs/PILOT.md`): `supy-service-inventory` (nestjs-nx), `supy-frontend` (angular-nx), `supy-mobile` (flutter Profile B).

## File Structure

- `evals/validate-fixtures.sh` (modify) — the deterministic CI gate; grows the `reviewer`-field check and the per-dimension coverage check.
- `evals/run-review-eval.sh` (create) — generic LLM runner: `run-review-eval.sh [dimension] [fixture-substring]`; reconstructs the reviewer named in each fixture's `expected.json`, scores recall/precision, prints a scorecard, estimates tokens.
- `evals/run-secrets-eval.sh` (modify) — becomes a thin shim: `exec run-review-eval.sh secrets "$@"`.
- `evals/test-scorecard.sh` (create) — deterministic unit test of the scoring math (canned reviewer output → asserted TP/FP/missed).
- `evals/fixtures/{architecture,angular,flutter,firebase-functions,ts-cli,ai-agents}/…` (create) — one issues-fixture + one clean-fixture per dimension; two flutter fixtures (Profile A + B).
- `evals/fixtures/secrets/06-k8s-configmap-secret/…` (create) — a k8s-config ConfigMap-secret fixture.
- `evals/README.md` (modify) — document the generalized harness, the `reviewer` field, and how to add a dimension.
- `docs/PILOT.md` (modify) — add a "Live-proof runs (flagship)" section for the 3 flagship stacks and a "Fixture scorecard" pointer.
- `docs/pilots/TRIAGE.md` (modify) — extend the existing triage protocol with the fixture-scorecard → asset-fix loop that becomes R2's input.

---

### Task 1: Extend the fixture contract + deterministic gate

**Files:**
- Modify: `evals/validate-fixtures.sh`
- Create: `evals/fixtures/architecture/01-service-imports-controller/{input.diff,expected.json}`

**Interfaces:**
- Produces: `expected.json` schema extended with a required top-level `"reviewer"` string (an existing `agents/<name>.md` file, sans path/extension). `validate-fixtures.sh` gains **Check R** (every fixture names a `reviewer` whose agent file exists) and keeps the existing structure invariants.
- Consumes: the existing `verdict`/`findings` contract and `fixtures/*/*/` iteration.

- [ ] **Step 1: Add the first non-secrets fixture (issues case)**

Create `evals/fixtures/architecture/01-service-imports-controller/input.diff` — a minimal unified diff that violates the layer-direction rule (a domain/application service importing from the controller/presentation layer). Keep it to a handful of `+` lines with a realistic path, e.g. `libs/inventory/application/src/lib/stock.service.ts` importing from `../../controllers/...`.

Create `evals/fixtures/architecture/01-service-imports-controller/expected.json`:

```json
{
  "reviewer": "supy-architecture-reviewer",
  "description": "Application-layer service imports from the controller layer — a layer-direction (dependency-inversion) violation.",
  "verdict": "issues",
  "findings": [
    { "file": "libs/inventory/application/src/lib/stock.service.ts", "line": 2, "severity": "high", "rule_contains": "layer" }
  ]
}
```

- [ ] **Step 2: Add Check R to the validator**

In `evals/validate-fixtures.sh`, inside the per-fixture loop (after the existing `findings` checks, before the loop closes), add:

```bash
  # --- Check R: fixture names a real reviewer agent. ---
  reviewer="$(jq -r '.reviewer // ""' "$exp_file")"
  if [ -z "$reviewer" ]; then
    err "$name: expected.json has no 'reviewer'"
  elif [ ! -f "agents/$reviewer.md" ]; then
    err "$name: reviewer '$reviewer' has no agents/$reviewer.md"
  fi
```

- [ ] **Step 3: Run the validator to confirm it fails on legacy fixtures**

Run: `bash evals/validate-fixtures.sh`
Expected: `✗` lines for each existing `secrets/*` fixture (`expected.json has no 'reviewer'`), non-zero exit — the new gate is real.

- [ ] **Step 4: Backfill `reviewer` into the 5 existing secrets fixtures**

Add `"reviewer": "supy-secrets-reviewer"` as the first key in each of the 5 `evals/fixtures/secrets/0[1-5]-*/expected.json` files.

- [ ] **Step 5: Run the validator to confirm it passes**

Run: `bash evals/validate-fixtures.sh`
Expected: `checking …` lines for every fixture (including the new `architecture/01-…`), no `✗`, exit 0.

- [ ] **Step 6: Shellcheck + commit**

```bash
shellcheck evals/validate-fixtures.sh
git add evals/validate-fixtures.sh evals/fixtures/architecture evals/fixtures/secrets
git commit -m "$(cat <<'EOF'
test: require a named reviewer per eval fixture

Adds Check R to validate-fixtures.sh (the eval-fixtures CI gate): every
fixture's expected.json must name an existing reviewer agent. Backfills the
secrets fixtures and adds the first architecture-reviewer fixture.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Generalize the runner + unit-test the scorecard

**Files:**
- Create: `evals/run-review-eval.sh`
- Modify: `evals/run-secrets-eval.sh`
- Create: `evals/test-scorecard.sh`

**Interfaces:**
- Consumes: the `reviewer` field (Task 1); the agent-reconstruction + prompt scaffold currently inside `run-secrets-eval.sh`.
- Produces: `run-review-eval.sh [dimension] [filter]` iterating `evals/fixtures/<dimension>/*/`, reconstructing the per-fixture reviewer, scoring recall/precision, printing a per-dimension scorecard (TP / FP / missed) and an approximate token estimate. A pure scoring function `score_findings` (expected-json + reviewer-output → `tp fp fn` counts) that `test-scorecard.sh` drives deterministically.

- [ ] **Step 1: Write the deterministic scorecard unit test first**

Create `evals/test-scorecard.sh` that sources `run-review-eval.sh` in a `SCORECARD_LIB_ONLY=1` mode (guard the runner's main loop behind that env var so sourcing defines functions without executing), then asserts the scoring math on canned inputs:

```bash
#!/usr/bin/env bash
# Deterministic unit test for the scorecard math in run-review-eval.sh.
# No LLM, no network — feeds canned reviewer output through score_findings.
set -uo pipefail
SCORECARD_LIB_ONLY=1 . evals/run-review-eval.sh
fail=0
check() { # label expected actual
  if [ "$2" = "$3" ]; then echo "ok:   $1"; else echo "FAIL: $1 (want $2, got $3)"; fail=1; fi
}

# Expected: one high finding at file.ts:10. Reviewer output that catches it exactly.
exp='{"verdict":"issues","findings":[{"file":"file.ts","line":10,"severity":"high","rule_contains":"layer"}]}'
got_hit=$'ISSUE file.ts:10 high — layer violation'
read -r tp fp fn < <(score_findings "$exp" "$got_hit")
check "exact match -> tp" 1 "$tp"; check "exact match -> fp" 0 "$fp"; check "exact match -> fn" 0 "$fn"

# Reviewer stays silent -> the planted issue is missed.
read -r tp fp fn < <(score_findings "$exp" "no issues found")
check "silence -> fn" 1 "$fn"; check "silence -> tp" 0 "$tp"

# Clean fixture, reviewer over-fires -> false positive.
clean='{"verdict":"pass","findings":[]}'
read -r tp fp fn < <(score_findings "$clean" $'ISSUE file.ts:3 med — nit')
check "over-fire -> fp" 1 "$fp"; check "over-fire on clean -> fn" 0 "$fn"

[ "$fail" -eq 0 ] && echo "test-scorecard: all passed" || { echo "test-scorecard: FAILED"; exit 1; }
```

- [ ] **Step 2: Run the unit test to confirm it fails (runner not written yet)**

Run: `bash evals/test-scorecard.sh`
Expected: fails to source `run-review-eval.sh` (file missing) — confirms the test actually exercises the runner.

- [ ] **Step 3: Write `run-review-eval.sh` (generalized from the secrets runner)**

Create `evals/run-review-eval.sh` by lifting the agent-reconstruction, prompt scaffold, and matching logic out of `run-secrets-eval.sh` and taking the target dimension as an argument:
- Read the reviewer per fixture from `expected.json` (`.reviewer`), reconstruct from `agents/<reviewer>.md` (model from frontmatter unless `MODEL=` overrides).
- Define a pure `score_findings <expected-json> <reviewer-output-text>` that returns `tp fp fn` on stdout using the existing `LINE_TOL` (default 3) file:line matching; a planted finding is TP if matched, FN if missed; any reviewer finding on a `verdict:"pass"` fixture (or beyond the planted set) is FP.
- Guard the fixture-iteration/main block behind `if [ -z "${SCORECARD_LIB_ONLY:-}" ]; then … fi`.
- Accept `run-review-eval.sh [dimension] [filter]`; default dimension iterates every `evals/fixtures/*/`.
- Print a per-dimension scorecard footer: `dimension  fixtures=N  TP=… FP=… missed=…  recall=… precision=…  ~tokens=…` where `~tokens` is `chars(prompt+output)/4` summed (approximate, labelled as such).
- Keep the `claude`-CLI-absent early `SKIPPED` exit so CI/dry environments pass.

- [ ] **Step 4: Run the unit test to confirm it passes**

Run: `bash evals/test-scorecard.sh`
Expected: all `ok:` lines, `test-scorecard: all passed`, exit 0.

- [ ] **Step 5: Reduce the secrets runner to a shim**

Replace the body of `evals/run-secrets-eval.sh` with a shim that preserves its CLI:

```bash
#!/usr/bin/env bash
# Behavioral eval for supy-secrets-reviewer. Now a thin shim over the generic
# runner — kept for back-compat and discoverability.
#   Usage: bash evals/run-secrets-eval.sh [fixture-name-substring]
set -uo pipefail
exec bash "$(dirname "$0")/run-review-eval.sh" secrets "$@"
```

- [ ] **Step 6: Shellcheck + commit**

```bash
shellcheck evals/run-review-eval.sh evals/run-secrets-eval.sh evals/test-scorecard.sh
git add evals/run-review-eval.sh evals/run-secrets-eval.sh evals/test-scorecard.sh
git commit -m "$(cat <<'EOF'
feat: generalize the eval runner to any reviewer

run-review-eval.sh drives any reviewer named in a fixture's expected.json and
prints a TP/FP/missed scorecard with an approximate token estimate.
run-secrets-eval.sh becomes a shim. test-scorecard.sh unit-tests the scoring
math deterministically (no LLM).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Author the per-stack fixture set + coverage gate

**Files:**
- Create: fixtures under `evals/fixtures/{angular,flutter,firebase-functions,ts-cli,ai-agents}/…` and `evals/fixtures/architecture/02-clean-*`; `evals/fixtures/secrets/06-k8s-configmap-secret/…`
- Modify: `evals/validate-fixtures.sh`

**Interfaces:**
- Consumes: the `reviewer`-field contract and Check R (Task 1).
- Produces: ≥1 **issues** fixture and ≥1 **clean** fixture per stack-distinctive dimension; a k8s ConfigMap-secret fixture; **Check S** in the validator asserting every dimension in the canonical table has at least one fixture (per-stack coverage).

- [ ] **Step 1: Add Check S (per-stack coverage) to the validator**

In `evals/validate-fixtures.sh`, after the per-fixture loop, add:

```bash
# --- Check S: every stack-distinctive dimension has at least one fixture. ---
REQUIRED_DIMS=(secrets architecture angular flutter firebase-functions ts-cli ai-agents)
for d in "${REQUIRED_DIMS[@]}"; do
  if ! compgen -G "$fixtures_root/$d/*/expected.json" >/dev/null; then
    err "no fixtures for required dimension: $d"
  fi
done
```

(If `set -e` trips on `compgen` failure, guard with `|| true` as the existing style requires.)

- [ ] **Step 2: Run the validator to confirm Check S fails**

Run: `bash evals/validate-fixtures.sh`
Expected: `✗ no fixtures for required dimension: angular` (and flutter, firebase-functions, ts-cli, ai-agents), non-zero exit.

- [ ] **Step 3: Author the fixtures**

For each dimension below, create `NN-<name>/input.diff` (a small realistic unified diff drawn from the mapped pilot repo's conventions, secrets planted as obvious fakes only) and `NN-<name>/expected.json` (with `reviewer`, `verdict`, `findings`). Author **one issues fixture + one clean fixture** each:

| Dimension | Reviewer | Issues fixture (rule) | Clean fixture |
|---|---|---|---|
| `angular` | `supy-angular-reviewer` | `01-smart-component-http` — a presentational component injecting `HttpClient` directly (module-boundary / NGXS violation) | `02-clean-signal-input` |
| `flutter` | `supy-flutter-reviewer` | `01-profileA-either-swallowed` — Profile A `Either` result ignored / error swallowed; `02-profileB-missing-app-exception` — Profile B path not raising `throwAppException` | `03-clean-bloc-event` |
| `firebase-functions` | `supy-firebase-functions-reviewer` | `01-callable-no-auth` — callable without the auth decorator | `02-clean-trigger-idempotent` |
| `ts-cli` | `supy-ts-cli-reviewer` | `01-prod-no-confirm` — a production-mutating script with no explicit confirmation | `02-clean-script-contract` |
| `ai-agents` | `supy-ai-agents-reviewer` | `01-mcp-tool-no-auth` — an exposed MCP tool/route with no auth + env-config bypass | `02-clean-idempotent-consumer` |
| `secrets` | `supy-secrets-reviewer` | `06-k8s-configmap-secret` — a plaintext credential in a `ConfigMap` (planted fake) | (existing clean fixtures cover this) |

Each `expected.json` clean fixture uses `"verdict": "pass"`, `"findings": []`.

- [ ] **Step 4: Run the validator to confirm it passes**

Run: `bash evals/validate-fixtures.sh`
Expected: every fixture `checking …`, no `✗`, exit 0.

- [ ] **Step 5: Shellcheck + commit**

```bash
shellcheck evals/validate-fixtures.sh
git add evals/validate-fixtures.sh evals/fixtures
git commit -m "$(cat <<'EOF'
test: add per-stack reviewer fixtures + coverage gate

One issues + one clean fixture per stack-distinctive reviewer (architecture,
angular, flutter A/B, firebase-functions, ts-cli, ai-agents) plus a k8s
ConfigMap-secret fixture. Check S fails CI if any required dimension has no
fixture.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Scorecard reporting + token-baseline capture

**Files:**
- Modify: `evals/README.md`
- Modify: `docs/PILOT.md`

**Interfaces:**
- Consumes: `run-review-eval.sh`'s per-dimension scorecard footer (Task 2).
- Produces: documented harness usage (how to run one dimension, read the scorecard, add a dimension) and a "Fixture scorecard" section in `docs/PILOT.md` with a per-dimension table whose "Token baseline" column is filled from the runner's `~tokens` estimate (fixtures) and refined by the flagship live runs (Task 5).

- [ ] **Step 1: Document the generalized harness in `evals/README.md`**

Add sections: the `reviewer` field; `run-review-eval.sh [dimension] [filter]`; that `validate-fixtures.sh` (Checks R + S) is the CI gate while the LLM runner is local/nightly; the token-estimate caveat (`chars/4`, approximate); and a "Adding a dimension" checklist (create `agents/<name>.md`, add `evals/fixtures/<dim>/`, extend `REQUIRED_DIMS`).

- [ ] **Step 2: Add the "Fixture scorecard" section to `docs/PILOT.md`**

Insert a table keyed by dimension with columns: `Dimension | Reviewer | Fixtures | Recall | Precision | Token baseline (~in/out) | Last run`. Seed every row `⏳` (filled when a human runs the LLM half). Add a one-line note that the deterministic structure gate is green in CI (`eval-fixtures` job) and the recall/precision/token columns come from `run-review-eval.sh`.

- [ ] **Step 3: Confirm docs pass the existing checks**

Run: `bash scripts/check-docs-inventory.sh && bash scripts/validate-xrefs.sh`
Expected: exit 0 (these guard component counts + xrefs; the scorecard edits touch neither). If `docs/PILOT.md` link-checks run under lychee, ensure any added intra-repo links resolve.

- [ ] **Step 4: Commit**

```bash
git add evals/README.md docs/PILOT.md
git commit -m "$(cat <<'EOF'
docs: document the generalized eval harness + fixture scorecard

evals/README.md covers the reviewer field, run-review-eval.sh, the CI gate vs.
the local LLM half, and how to add a dimension. PILOT.md gains a per-dimension
scorecard table with a token-baseline column.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Flagship live-proof section + triage→asset-fix loop

**Files:**
- Modify: `docs/PILOT.md`
- Modify: `docs/pilots/TRIAGE.md`

**Interfaces:**
- Consumes: the existing per-stack pilot tracker in `docs/PILOT.md` (from the E1 plan) and `docs/pilots/RUNBOOK.md`.
- Produces: a "Live-proof runs (flagship)" section capturing the 3 real runs, and a TRIAGE extension mapping **fixture scorecard** outcomes (FP → tighten reviewer red-flag / scope rule; missed → mine rule into `config/standards/` then extend the reviewer) into the concrete list that is **R2's input**.

- [ ] **Step 1: Add the flagship live-proof section to `docs/PILOT.md`**

For each of `supy-service-inventory` (nestjs-nx), `supy-frontend` (angular-nx), `supy-mobile` (flutter Profile B), add a subsection with fields a human fills after the run: plugin commit SHA, verbatim SessionStart line, reviewer set dispatched, review-report header, **token/turn count** (the authoritative baseline), and the fixture-vs-live delta note. Cross-link to `docs/pilots/RUNBOOK.md`.

- [ ] **Step 2: Extend `docs/pilots/TRIAGE.md` with the fixture→asset-fix loop**

Add a "Fixture scorecard triage" section: each **false positive** in the scorecard tightens the reviewer's red-flag wording or scopes the rule; each **missed** first mines a rule into the relevant `config/standards/*` file (**standards-first**) then adds reviewer coverage; each confirmed **true positive** is left as-is (regression-locked by its fixture). State explicitly that the resulting action list is **R2's input** and that any reviewer change must not regress a green fixture.

- [ ] **Step 3: Confirm docs checks pass**

Run: `bash scripts/check-docs-inventory.sh && bash scripts/validate-xrefs.sh`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add docs/PILOT.md docs/pilots/TRIAGE.md
git commit -m "$(cat <<'EOF'
docs: add flagship live-proof section + fixture triage loop

PILOT.md records the 3 flagship live runs (token baselines). TRIAGE.md maps
scorecard FPs/misses to reviewer/standards fixes (standards-first) and names
that action list as R2's input.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

## After This Plan (human step — not executable here)

With the harness committed and green in CI, a human with the `claude` CLI runs `bash evals/run-review-eval.sh <dimension>` per stack, pastes recall/precision/token numbers into the `docs/PILOT.md` scorecard, then performs the 3 flagship live runs from `docs/pilots/RUNBOOK.md` and fills the live-proof section. The maintainer triages per the extended `TRIAGE.md`, and the resulting asset-fix list is handed to the **R2 plan**. R1's exit criteria (refresh spec §6): all required-dimension fixture scorecards green + baselined in CI; 3 flagship rows ticked with live token counts; triaged asset-fix list committed.

## Self-Review

**1. Spec coverage (refresh spec §6 + §3):**
- Eval harness extended beyond secrets to all reviewers → Tasks 1–3. ✓
- Expected-findings manifest → `reviewer`-extended `expected.json` (Task 1) + per-stack fixtures (Task 3). ✓
- Offline runner + scorecard (TP/FP/missed) → Task 2. ✓
- Token-baseline capture → runner `~tokens` (Task 2) + scorecard column (Task 4) + flagship live counts (Task 5). ✓
- CI wiring → extends `validate-fixtures.sh`, already the `eval-fixtures` job (Tasks 1, 3). ✓
- 3 flagship live runs in `docs/PILOT.md` → Task 5. ✓
- Triage → asset fixes = R2 input → Task 5 (`TRIAGE.md`), standards-first. ✓
- §3 constraints (no secret values, `${CLAUDE_PLUGIN_ROOT}`, Conventional Commits + trailer, zero fan-out) → Global Constraints + every commit + fake-token fixtures. ✓

**2. Placeholder scan:** No "TBD/TODO" in plan logic. The `<name>`/`NN-…` tokens in Task 3 are the fixture-authoring slots, each backed by a concrete rule + reviewer in the table. `⏳` cells in the scorecard/live-proof tables are intentional human fill-in fields.

**3. Type consistency:** Dimension names, reviewer agent filenames, and `REQUIRED_DIMS` are identical across the canonical table, `validate-fixtures.sh`, and the runner. `expected.json` keeps its existing `verdict`/`findings` invariant (`pass` ⟺ empty findings) and adds one required string field consumed by name.
