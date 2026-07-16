# supy-wingspan Enhancement Roadmap — Design

**Date:** 2026-07-16
**Status:** Approved design (pending user review of this spec)
**Author:** supy-wingspan maintainers (via Claude Opus 4.8)

---

## 1. Context

`supy-wingspan` reached a validated v0.1.0 baseline: **7 stacks, 11 review agents,
14 skills, 4 commands, 9-way ordered stack detection**, all passing
`plugin-dev:plugin-validator` and `shellcheck`. The mined standards under
`config/standards/` were extracted from an exhaustive analysis of all 26 live
Supy repos (`docs/analysis/`).

What the plugin does *not* yet have is **evidence that it works on real repos**,
**enforcement teeth beyond advisory review**, and **self-maintenance** as the
standards drift. This roadmap sequences four enhancement phases (E1–E4) that
close those gaps, in an order chosen so each phase de-risks the next.

## 2. Goal

Move `supy-wingspan` from "validated in the abstract" to "proven on live Supy
repos, enforced locally, self-maintaining, and broader in stack coverage" —
**without ever pushing to a Git host** and **without exceeding a healthy
agent/token budget per operation**.

## 3. Binding constraints (carried from the project)

1. **LOCAL-ONLY.** There is no Git host. Every phase commits locally and
   **NEVER pushes**. No CI service, no PR platform, no remote hooks.
2. **Secrets.** NEVER reproduce a secret value in any file, diff, commit
   message, or review finding. Cite `path:line` only. (Reinforces the org
   security rule and the plugin's own `supy-secrets-reviewer`.)
3. **Conventional Commits.** `feat:` / `docs:` / `fix:` (use `fix()`, never
   `bug()`). Every commit ends with the trailer
   `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
4. **Component bodies** use `${CLAUDE_PLUGIN_ROOT}`, never hardcoded absolute
   paths. Absolute paths are allowed only in human-facing docs.
5. **Human-in-the-loop for live pilots.** E1 pilots require a human to run
   `/plugin install` and the core loop inside each target repo — this cannot be
   driven headlessly. The maintainer's job is to author the runbook, then
   convert the human's findings into asset fixes.

## 4. Cross-cutting concern: token / agent budget ("stay green")

Because `/supy-review` fans out up to **6 reviewers in parallel** (nestjs-nx),
token cost is a first-class design constraint, not an afterthought. Every phase
below is bound by these rules:

1. **Scoped reads.** Each reviewer reads only its dimension's standard file(s),
   addressed by H2 anchor where possible, plus the diff under review — never the
   whole `config/standards/` tree. `supy-review` hands the diff to agents as a
   single file; only the consolidated report returns to the main loop.
2. **Model tiering.** Mechanical reviewers (commit/PR conventions, secrets
   pattern-scan) run on a cheap/fast model; judgment-heavy reviewers
   (architecture, security) run on a stronger model. The model is specified
   per agent, never left to inherit the session default.
3. **Budgeted verification (E2).** The adversarial/skeptic verification pass is
   **gated** — it runs only on High-severity or low-confidence findings, so
   deepening quality does not multiply the token bill across every finding.
4. **Baseline + threshold.** During E1 pilots, capture the approximate
   tokens/turns per `/supy-review` per stack, record it in `docs/PILOT.md`, and
   set a "green" threshold. Any later change (E2+) that regresses the baseline
   must justify itself in its commit message.
5. **Bounded fan-out for mining.** Standards-drift re-mining (E2/E3) caps
   parallel Explore subagents per wave (reuse the Phase-1 wave discipline: one
   read-only Explore per repo, in small waves, uniform ≤45-line report), and
   prefers targeted reads over whole-repo sweeps.
6. **Degrade cheaply.** When Cortex MCP is connected, reviewers pull targeted
   lookups (entity, handler contract, coding rule), never bulk dumps.

## 5. Phase sequence and rationale

Order is **prove → deepen → extend capability → broaden stacks**. We prove the
existing 7 stacks work (E1) before deepening review quality (E2), because pilot
findings tell us *which* rules actually fire and are worth hardening. New
capabilities (E3) build on a deepened, trusted review core. Broadening to new
stacks (E4) comes last: it reuses the now-proven Phase 3–6 authoring pattern and
should not dilute effort until the core is solid.

```
E1 Prove it live ──▶ E2 Deepen review + local hooks ──▶ E3 New capabilities ──▶ E4 Broaden stacks
     (evidence)          (quality + enforcement)            (self-maintaining)       (reuse pattern)
```

---

## 6. E1 — Prove it live

**Objective:** Run the plugin end-to-end on one real repo per stack; convert
findings into concrete asset fixes; tick the `docs/PILOT.md` checkboxes.

**What the maintainer authors (committed to `docs/`, local only):**

- **Per-stack pilot runbook** (`docs/pilots/RUNBOOK.md`): the exact steps a human
  runs in each pilot repo — `/plugin marketplace add`, `/plugin install`, open a
  scratch branch, make a representative change, run `/supy-review`, then
  `supy-commit`; what to copy back (the consolidated report, the detected stack
  line, rough token/turn count).
- **Results-capture template** (`docs/pilots/RESULTS-TEMPLATE.md`): a uniform
  form per pilot — stack detected (correct?), reviewers dispatched (expected
  set?), findings (true positive / false positive / missed), token baseline,
  and asset-fix actions.

**What the human runs** (per pilot repo): install → representative change →
`/supy-review` → `supy-commit`, then pastes the captured results back.

**What the maintainer does with results:** triage each finding — true positives
reinforce a rule; false positives get a reviewer red-flag tightened or a rule
scoped; misses get a new rule mined into the standard. Then tick the matching
`docs/PILOT.md` checkbox and record the token baseline.

**Finalized pilot-repo mapping (one per stack):**

| Stack | Pilot repo | Why this one |
|---|---|---|
| nestjs-nx | `supy-service-inventory` | Canonical service; already partially mined — good re-verify target |
| angular-nx | `supy-frontend` | The only Angular repo; highest-confidence match |
| flutter (Profile B) | `supy-mobile` | Profile B (`PageState`/`throwAppException`) — the main app |
| flutter (Profile A) | `checklist` | Recommended 2nd pilot — Profile A (`Either`/dartz); the profiles diverge enough to warrant both |
| firebase-functions | `supy-firebase-functions` | The standalone Firebase repo (remediation-first stack) |
| ts-cli | `supy-cli` | The standalone CLI repo |
| ai-agents | `supy-ai-agents` | The polyglot monorepo; also hosts Cortex MCP |
| k8s-config | `supy-configmaps` | The repo whose committed plaintext secrets triggered the secrets standard |

**Exit criteria:** every stack row in `docs/PILOT.md` ticked with a captured
result; token baseline recorded per stack; a triaged list of asset fixes
applied and committed locally.

**Token discipline:** E1 spends tokens mostly in the human's own review runs
(outside the maintainer's budget). The maintainer's authoring work is
doc-writing plus small, targeted asset edits — no large fan-out.

## 7. E2 — Deepen review + local enforcement

**Objective:** Raise review precision and add offline enforcement teeth.

**Review depth:**

- **Adversarial verification** (budgeted per §4.3): High-severity or
  low-confidence findings get a second-pass skeptic that tries to refute them;
  a finding survives only if not refuted. Bounds false positives without a
  blanket token multiplier.
- **Severity calibration:** a shared severity rubric across all 11 reviewers
  (what makes a finding Critical vs. Important vs. Minor), grounded in the
  pilot true/false-positive data from E1.
- **Auto-fix suggestions:** where a rule violation has a mechanical fix (missing
  trailer, wrong import boundary, literal secret → Secret Manager reference),
  the reviewer emits a concrete suggested diff, not just a flag.
- **More mined rules:** re-mine divergences the E1 pilots surfaced; add them to
  the relevant `config/standards/` file + reviewer coverage.

**Enforcement — LOCAL HOOKS ONLY (per the user's explicit choice):**

- `pre-commit` config + local git hooks that run offline: secret-scan,
  commit-message lint (Conventional Commits + trailer), and the coverage-bar
  check from `ci-coverage-baseline.md`.
- **NO CI service, NO Git-host hooks, NO remote anything.** Everything runs on
  the developer's machine before the local commit lands.
- Templates land under `templates/<stack>/` (extending the existing per-stack
  CI/pre-commit/secret-scan baselines).

**Exit criteria:** verification pass gated and measured against the E1 token
baseline (no unjustified regression); severity rubric applied across reviewers;
local-hook templates installable per stack; new rules committed.

## 8. E3 — New capabilities

**Objective:** Make the plugin proactive and self-maintaining.

- **`/supy-onboard`:** one command that installs the marketplace, detects the
  stack, runs `supy-baseline` to generate/refresh `CLAUDE.md`, and prints the
  stack-appropriate next steps — the "new repo, day one" entry point.
- **CLAUDE.md drift detection:** a check (hook or skill) that flags when a repo's
  `CLAUDE.md` has drifted from the canonical template + current standards, and
  offers a diff to reconcile.
- **Standards-drift re-mining:** a periodic (human-triggered) skill that
  re-runs the bounded Explore mining (§4.5) against the live repos and proposes
  standards updates — the plugin maintains its own source of truth.
- **Release / changelog + coverage-dashboard skills:** a `supy-release` skill
  that assembles a Conventional-Commits changelog locally, and a coverage
  reporter that renders the `ci-coverage-baseline` bars per repo.

**Exit criteria:** `/supy-onboard` works on a fresh clone of a pilot repo; drift
detection flags a deliberately-drifted `CLAUDE.md`; re-mining produces a
reviewable standards diff within the token budget.

## 9. E4 — Broaden stack coverage (last)

**Objective:** Extend to stacks not yet present in the Supy fleet but likely to
appear, reusing the proven Phase 3–6 authoring pattern (standard + reviewer +
skill(s) + template + ordered detection branch).

- Candidate stacks: React/Next.js, Go, Python services, IaC (Terraform/Pulumi).
- **Only author a stack when a real repo warrants it** — no speculative stacks.
- Each new stack follows the same asset-set contract and the same
  `hooks/detect-stack.sh` ordering discipline (watch for `package.json`-based
  collisions, as with ts-cli vs. ai-agents).

**Exit criteria:** for each warranted stack, a full asset set authored, detection
branch added in the correct order, `plugin-validator` re-run to VALID, and a
pilot (per E1's pattern) run on the first real repo of that stack.

## 10. Decisions locked in

- **Automation = local hooks only** (no CI, no Git host).
- **Pilot repos = one per stack, maintainer-picked** (table in §6), plus a
  recommended second flutter pilot for Profile A.
- **Phase order = E1 → E2 → E3 → E4** (prove before deepen before extend before
  broaden).
- **Token budget is a cross-cutting gate**, with a baseline captured in E1 and
  enforced against thereafter.

## 11. Out of scope (YAGNI)

- Anything requiring a Git host, CI service, or network deployment.
- Speculative new stacks with no live repo (deferred to E4-on-demand).
- Reproducing or handling secret *values* anywhere — only `path:line` citations.

## 12. Next step

On approval of this spec, produce the **E1 implementation plan** via
`superpowers:writing-plans` — the per-stack pilot runbook and results-capture
template are E1's first deliverables. E2–E4 will be sharpened into their own
plans as E1 findings land.
