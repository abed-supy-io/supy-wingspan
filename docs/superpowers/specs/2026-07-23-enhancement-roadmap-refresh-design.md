# supy-wingspan Enhancement Roadmap — Refresh (R1–R4)

**Date:** 2026-07-23
**Status:** Approved design (pending user review of this spec)
**Author:** supy-wingspan maintainers (via Claude Opus 4.8)
**Supersedes sequencing of:** `docs/superpowers/specs/2026-07-16-enhancement-roadmap-design.md` (E1–E4)

---

## 1. Context — where we actually are

The original E1–E4 roadmap (2026-07-16) sequenced **prove → deepen → extend →
broaden**. One week later, at **v0.1.5**, a state audit shows the plugin grew
in the opposite order: **capability outran proof.**

Audit against the original roadmap:

| Roadmap item | Phase | State | Evidence |
|---|---|---|---|
| Pilot scaffolding (runbook, results template, triage, verifier) | E1 | ✅ Done | `docs/pilots/{RUNBOOK,RESULTS-TEMPLATE,TRIAGE}.md`, `verify-pilots.sh` |
| **Actual pilot runs + token baselines** | E1 | ❌ Not done | all 8 rows in `docs/PILOT.md` still ⏳ |
| Severity rubric | E2 | ✅ Done | `config/standards/review-severity.md` |
| **Adversarial / skeptic verification pass** | E2 | ❌ Not done | absent from `skills/supy-review/SKILL.md` |
| **Auto-fix / suggested-diff findings** | E2 | ❌ Not done | no reviewer emits diffs |
| Per-stack local pre-commit hooks | E2 | 🟡 Partial | only `flutter` + `k8s-config` ship hooks; 5 stacks don't |
| `/supy-onboard` + CLAUDE.md drift check | E3 | ✅ Done | `commands/supy-onboard.md` |
| `/supy-release` + changelog | E3 | ✅ Done | `commands/supy-release.md` |
| **Standards-drift re-mining (periodic)** | E3 | 🟡 Partial | `supy-feedback` covers it *reactively*; no periodic re-mine |
| **Coverage dashboard / reporter** | E3 | ❌ Not done | — |
| Broaden stacks (React/Go/Python/IaC) | E4 | ❌ Not started | still 7–8 stacks |

Beyond the roadmap, **~15 skills** shipped that E1–E4 never contemplated:
Jira→spec (`supy-impl-spec`, `supy-spike-spec`), git flow (`supy-hotfix`,
`supy-rebase`, `supy-debrief`), cross-repo (`supy-feature-fanout`), KG
(`supy-kg`), Figma (`supy-figma-to-tickets`, `supy-figma-implement-design`),
Flutter delivery (`supy-app-release-readiness`, `supy-flutter-upgrade`,
`supy-e2e-tests`, `supy-code-assessment`, `supy-analyze-native-codebase`,
`supy-interview-feedback`), and the `supy-feedback` loop.

**The through-line:** the plugin is **broad and unproven** where the roadmap
intended it to become **narrow and proven first**. The refresh corrects the
order.

## 2. Goal

Move `supy-wingspan` from "broad but unproven" to "proven on real Supy repos,
sharpened by that evidence, self-maintaining, and consolidated" — reusing the
existing `evals/` harness as the proof engine, and keeping every phase after R1
**fed by R1's data rather than by guesswork.**

## 3. Binding constraints (carried forward, unchanged)

1. **Git host reality.** This plugin repo lives on GitHub: changes land via PRs
   to `main`, CI gates merges, release-please cuts releases. Pilot scratch
   branches inside target repos are throwaway and **never pushed**.
2. **Secrets.** NEVER reproduce a secret value in any file, diff, commit
   message, fixture, or finding. Cite `path:line` only.
3. **Conventional Commits.** `feat:` / `docs:` / `fix:` (use `fix()`, never
   `bug()`). Claude-authored commits end with the standard `Co-Authored-By`
   trailer for the model that produced them.
4. **Component bodies** use `${CLAUDE_PLUGIN_ROOT}`, never hardcoded absolute
   paths. Absolute paths are allowed only in human-facing docs and fixtures.
5. **Token / agent budget ("stay green").** The §4 budget rules of the original
   roadmap remain in force: scoped reads, model tiering, gated verification,
   bounded fan-out for mining, cheap degradation.

## 4. Key decisions locked in (this refresh)

- **Priority = close the evidence gap (R1) first.** Everything else waits on or
  is shaped by pilot data.
- **Pilot model = hybrid.** One *live* end-to-end run per flagship stack proves
  the real install→detect→dispatch path; *fixture-based* regression pilots for
  all 8 stacks make proof reproducible and CI-gated. All 8 pilot repos are
  already checked out locally under `~/Projects/supy-projects/`, so access is
  not a blocker — the manual runbook friction was.
- **R0 (consolidate/harden the ~30 skills) is cross-cutting**, running alongside
  R1, not a blocking gate.
- **Coverage dashboard is kept** (R3), not cut.
- **Phase order = R1 → R2 → R3 → R4**, with R0 continuous.

## 5. Sequence

```text
R1 Prove it live (hybrid)  ──▶  R2 Review teeth  ──▶  R3 Self-maintenance  ──▶  R4 Broaden stacks
   evidence + baselines          verify+autofix+hooks    dashboard + re-mining     (on-demand)
        │
        └─▶ R0 (cross-cutting): consolidate & harden the ~30 skills; grow eval coverage
```

Rationale: prove the existing surface works (R1) before sharpening it (R2);
sharpen before automating self-maintenance (R3); broaden stacks last (R4),
reusing the proven authoring pattern. R0 runs continuously because skill
consolidation neither blocks nor is blocked by the pilots — and R1's fixtures
give non-secrets reviewers eval coverage for free.

---

## 6. R1 — Prove it live (hybrid) — *the priority*

**Objective:** produce reproducible evidence that every stack's reviewers fire
correctly on real diffs, capture token baselines, and turn the findings into a
triaged asset-fix list that seeds R2.

**Deliverables:**

1. **Eval harness extended beyond secrets to all reviewers.** For each of the 8
   stacks, capture a representative real diff from its local pilot repo into
   `evals/fixtures/<stack>/` (secrets scrubbed to `path:line`), paired with an
   **expected-findings manifest** (what each reviewer *should* flag). Build an
   offline runner + **scorecard** (true-positive / false-positive / missed) and
   a **token-baseline capture** per stack. Wire into CI so a reviewer regression
   fails the build. Reuses the existing `evals/run-secrets-eval.sh` +
   `validate-fixtures.sh` pattern.
2. **Live proof runs** on the 3 flagship stacks — `supy-service-inventory`
   (nestjs-nx), `supy-frontend` (angular-nx), `supy-mobile` (flutter Profile B):
   one real `/plugin install` → SessionStart detection → `/supy-review` each,
   recorded in `docs/PILOT.md` with token/turn counts and the detected-stack
   line.
3. **Triage → asset fixes.** Each finding classified TP / FP / missed; TPs
   reinforce a rule, FPs tighten a reviewer red-flag or scope a rule, misses
   mine a new rule into `config/standards/`. The triaged list is R2's input.

**Pilot-repo mapping** (unchanged from the original E1 table; all present
locally):

| Stack (profile) | Pilot repo | Fixture | Live proof |
|---|---|---|---|
| nestjs-nx | `supy-service-inventory` | ✔ | ✔ (flagship) |
| angular-nx | `supy-frontend` | ✔ | ✔ (flagship) |
| flutter (Profile B) | `supy-mobile` | ✔ | ✔ (flagship) |
| flutter (Profile A) | `checklist` | ✔ | — |
| firebase-functions | `supy-firebase-functions` | ✔ | — |
| ts-cli | `supy-cli` | ✔ | — |
| ai-agents | `supy-ai-agents` | ✔ | — |
| k8s-config | `supy-configmaps` | ✔ | — |

**Exit criteria:** all 8 fixture scorecards green and baselined in CI; the 3
flagship rows in `docs/PILOT.md` ticked with live token counts; triaged
asset-fix list committed.

## 7. R2 — Review teeth (data-driven from R1)

**Objective:** raise review precision and make enforcement real, using R1's
true/false-positive data — not guesswork — to decide what to harden.

**Deliverables:**

- **Adversarial verification** in `supy-review`, gated (per the budget rules) to
  High-severity or low-confidence findings: a second-pass skeptic tries to
  refute; a finding survives only if not refuted. No blanket token multiplier.
- **Auto-fix suggested diffs** where a rule violation has a mechanical fix
  (missing commit trailer, wrong import boundary, literal secret → Secret
  Manager reference): the reviewer emits a concrete suggested diff, not just a
  flag.
- **Fill the pre-commit gap.** Only `flutter` and `k8s-config` ship local hooks
  today; add offline pre-commit hooks (secret-scan, commit-message lint,
  coverage-bar check) to the remaining 5 stacks — backend, frontend,
  firebase-functions, ts-cli, ai-agents — under `templates/<stack>/`.
- **Severity calibration.** Calibrate `config/standards/review-severity.md`
  against R1's real TP/FP distribution so Critical/Important/Minor reflect
  observed impact.

**Exit criteria:** verification pass gated and measured against the R1 token
baseline (no unjustified regression); auto-fix diffs emitted for at least the
mechanical rule classes; all 8 stacks ship installable local hooks; severity
rubric updated with a note tracing each change to pilot data.

## 8. R3 — Self-maintenance (finishes original E3)

**Objective:** make the plugin keep its own source of truth current and make
coverage visible.

**Deliverables:**

- **Coverage dashboard / reporter** that renders the `ci-coverage-baseline` bars
  per repo (kept, not cut).
- **Dedicated standards re-mining skill** — human-triggered, periodic, bounded
  fan-out (one read-only Explore per repo in small waves) across the live repos,
  proposing a reviewable `config/standards/` diff. Complements the *reactive*
  `supy-feedback` skill already shipped: `supy-feedback` captures a divergence
  noticed in-flight; re-mining sweeps deliberately.

**Exit criteria:** the reporter renders bars for a pilot repo; the re-mining
skill produces a reviewable standards diff within the token budget on a
deliberately-drifted target.

## 9. R0 — Consolidate & harden (cross-cutting)

**Objective:** ensure the ~30 skills that shipped fast are individually sound
and non-overlapping before more surface is added.

**Deliverables:**

- **Skill quality/overlap audit** of all skills (with attention to the ~15
  shipped outside the original roadmap): flag duplication, thin decision
  procedures, missing `references/` extraction, and unclear triggering
  descriptions. Dedup or merge where two skills cover the same ground.
- **Grow eval coverage** for non-secrets reviewers — this falls out of R1's
  fixtures for free; R0 ensures each reviewer has at least one fixture asserting
  a known finding.

**Exit criteria:** audit report committed with a dedup/hardening action list;
each reviewer has ≥1 eval fixture; no two skills have overlapping triggers
without a documented reason.

## 10. R4 — Broaden stack coverage (last, on-demand)

**Objective:** extend to stacks likely to appear in the fleet, reusing the
proven authoring pattern (standard + reviewer + skill(s) + template + ordered
detection branch).

- Candidate stacks: React/Next.js, Go, Python services, IaC (Terraform/Pulumi).
- **Only author a stack when a real repo warrants it** — no speculative stacks.
- Each new stack follows the same asset-set contract and `detect-stack.sh`
  ordering discipline (watch for `package.json` collisions).

**Exit criteria:** per warranted stack — full asset set, correctly-ordered
detection branch, `plugin-validator` VALID, a fixture pilot, and (for the first
repo) a live proof run.

## 11. Out of scope (YAGNI)

- Enforcement in target repos that depends on a CI service or Git-host hooks —
  local pre-commit hooks remain the chosen mechanism.
- Speculative new stacks with no live repo (R4 is on-demand only).
- Reproducing or handling secret *values* anywhere — only `path:line`.
- Re-running the *live* pilot loop for all 8 stacks; only the 3 flagship stacks
  get a live run — the other 5 are proven by fixtures.

## 12. Next step

On approval of this spec, produce the **R1 implementation plan** via
`superpowers:writing-plans` — extending the eval harness to all 8 stacks and
capturing the flagship live baselines are R1's first deliverables. R2–R4 sharpen
into their own plans as R1 evidence lands; R0 runs as a continuous track.
