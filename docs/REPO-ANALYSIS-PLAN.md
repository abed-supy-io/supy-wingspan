# supy-wingspan — Full Repo Analysis & Standards-Mining Plan

**Goal:** Analyze *every* Supy repository one by one, extract the real engineering
conventions each one follows, and turn the findings into best-practice assets in
this plugin — `config/standards/*` rulebooks, review agents, how-to & scaffold
skills, CLAUDE.md templates, and stack-detection branches — so every `supy-*` repo
can be held to its stack's standard through AI.

**Scope:** Exhaustive — all 27 code/infra repos under `~/Projects/supy-projects/`
(excludes `supy-wingspan` itself, `docs/`, `worktrees/`).

**Method:** One read-only **Explore** subagent per repo, dispatched in parallel
waves by stack group. Each returns a uniform findings report (fixed template
below). Findings are written to `docs/analysis/<repo>.md`, rolled up per group
into standards edits, then wired + validated + committed locally (**never pushed**).

**Constraints (binding):** local-only — commit, never push. Every commit ends with
`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. Component
bodies use `${CLAUDE_PLUGIN_ROOT}`, never hardcoded absolute paths.

---

## Per-repo findings template

Every Explore agent returns exactly this, ≤45 lines, citing file paths:

```
## <repo> — <confirmed stack>
- Purpose: <one line>
- Structure: <apps/libs or key top-level dirs>
- Architecture & patterns: <layering, DI, state mgmt, error handling, idioms>
- Tooling: lint · format · test · CI · codegen · pre-commit · commits
- Testing: <framework, coverage bar, patterns>
- Security / secrets / config: <env handling, secret storage, authz>
- Divergences vs a typical Supy <stack> repo: <bullets or "none notable">
- New patterns worth codifying: <bullets>
- Recommendation: <deepen stack X | candidate NEW stack Y | infra/policy-only>
```

---

## The repos, grouped by stack

### Group A — Backend · NestJS-on-Nx (13) — *deepen existing `nestjs-nx` stack*
- [x] `supy-api` (core domain)
- [x] `supy-api-admin`
- [x] `supy-api-authorization`
- [x] `supy-api-common` (shared libs — expect divergence)
- [x] `supy-api-mobile`
- [x] `supy-api-retailer`
- [x] `supy-integration-inventory`
- [x] `supy-mailgun-webhooks` (webhook ingress — expect divergence)
- [x] `supy-service-authentication`
- [x] `supy-service-catalog`
- [x] `supy-service-inventory` (already mined — re-verify)
- [x] `supy-service-orders`
- [x] `supy-service-settlements`

### Group B — Frontend · Angular-on-Nx (1) — *deepen existing `angular-nx` stack*
- [x] `supy-frontend`

### Group C — Mobile · Flutter (4) — *deepen existing `flutter` stack*
- [x] `supy-mobile` (main app) — **diverges**: `PageState<T>` sealed union + `throwAppException()` (not dartz Either)
- [x] `supy-scanner` — federated native plugin; versioned MethodChannel; distinct sub-profile
- [x] `checklist` (already mined — re-verify) — canonical flutter reference (Either + sealed failures + hive)
- [x] `supy-flutter-packages.` (melos multi-package monorepo — variant) — melos, 6 pkgs, 85% coverage

### Group D — New/uncovered stacks & infra (9) — *candidate NEW stacks*
- [x] `supy-firebase-functions` (Firebase Cloud Functions, Node) — candidate NEW stack (remediation-first)
- [x] `supy-cli` (TypeScript CLI) — candidate NEW stack (ts-cli)
- [x] `supy-jsreport-templates` (jsreport server + templates) — infra/policy-only
- [x] `supy-unleash-strategies` (Unleash feature-flag strategies, Docker) — docs-only
- [x] `supy-ai-agents` (AI/Cloudflare-Worker monorepo; git submodules) — candidate NEW stack (ai-agents); hosts Cortex MCP
- [x] `supy-cerbos-policies` (Cerbos authz YAML — partially mined) — deepen security-cerbos
- [x] `supy-configmaps` (Kubernetes configmaps YAML) — ⚠️ **BLOCKING: committed plaintext secrets**
- [x] `supy-manifest` (deployment manifests / Helm / GitOps) — policy-only (ArgoCD + Datree)
- [x] `supy-core` (appears empty — likely uninitialized submodule; verify) — **empty; skip**

---

## Phases

- **Phase 0 — Triage** ✅ (done): classify every repo by stack markers, group above.
- **Phase 1 — Analyze (parallel Explore, by wave):** ✅ (done)
  - Wave A → Group A (backend 13) ✅
  - Wave B → Groups B + C (frontend 1 + flutter 4) ✅
  - Wave C → Group D (new/infra 9) ✅
  - Each wave: dispatch, collect reports, write `docs/analysis/<repo>.md`. ✅ 26 files written
    (`supy-core` empty → skipped; all others have durable notes).
- **Phase 2 — Synthesize per group:** ✅ (done) reconciled findings against current
  `config/standards/*`; per-group diff of (confirmed / divergent / new) written to
  `docs/analysis/SYNTHESIS.md`, with a value×blast-radius execution order for Phases 3–5.
- **Phase 3 — Enrich existing stacks:** update backend/frontend/flutter standards,
  reviewers, and how-to skills with the real divergences and new patterns.
- **Phase 4 — New stacks (as warranted):** for each Group D stack worth automating,
  author the full asset set (standard + reviewer + skill(s) + template + detection
  branch in `hooks/detect-stack.sh`).
- **Phase 5 — Cross-cutting:** unify commit conventions, CI, pre-commit, and
  secret/config handling into stack-agnostic standards.
- **Phase 6 — Wire + validate + commit:** update `supy-review`, `supy-baseline`,
  `commands/supy-review.md`, README, `plugin.json`, `config/standards/README.md`,
  `docs/PILOT.md`, `docs/USAGE.md`; run plugin-validator + shellcheck; one local
  `feat:` commit per meaningful unit (never push).

---

## Roll-up mapping (findings → plugin assets)

| Finding type | Lands in |
|---|---|
| Confirmed convention | Reinforce/keep the matching `config/standards/*` rule |
| Divergence / inconsistency | Standard note + a reviewer red-flag; possibly a "prefer X" rule |
| New pattern (existing stack) | New rule in the stack's standard + reviewer coverage |
| New stack | New `config/standards/<stack>/`, `agents/supy-<stack>-reviewer.md`, skill(s), `templates/<stack>/`, detection branch |
| Cross-cutting (CI/commits/secrets) | Stack-agnostic standard (root of `config/standards/`) |

## Progress log

_(updated as waves complete)_
- 2026-07-15: Phase 0 triage complete; plan written; Wave A dispatched.
- 2026-07-15: **Phase 1 complete — 26/27 repos analyzed** (`supy-core` empty → skipped);
  all `docs/analysis/*.md` written. Stack roll-up:
  - **Deepen `nestjs-nx`** (13 repos) — `supy-api-common` is the shared-lib variant.
  - **Deepen `angular-nx`** (1) — `supy-frontend` (Angular 21 + NGXS + PrimeNG).
  - **Deepen `flutter`** (4) — reconcile TWO profiles: `checklist`/Either vs `supy-mobile`/`PageState`;
    add `supy-scanner` plugin sub-profile + `supy-flutter-packages` melos sub-profile.
  - **Candidate NEW stacks:** `firebase-functions` (remediation-first), `ts-cli`, `ai-agents` (MCP/BullMQ/pgvector).
  - **Deepen `security-cerbos`** — add derived roles, CEL, `*_test.yaml`, pre-commit compile.
  - **BLOCKING cross-cutting:** `supy-configmaps` committed plaintext secrets → new infra/config-secrets
    standard (externalize to `kind: Secret`, secret-scanning pre-commit, kubeval CI). Reinforces org secrets rule.
  - **Policy/docs-only:** `supy-manifest` (ArgoCD/Datree), `supy-jsreport-templates`, `supy-unleash-strategies`.
- 2026-07-15: → entering **Phase 2 (Synthesize)**.
- 2026-07-15: **Phase 2 complete** — `docs/analysis/SYNTHESIS.md` written. Per-group deltas:
  - **A (nestjs-nx):** standards largely confirmed; reconcile `supy-api-common` shared-lib
    variant + `supy-mailgun-webhooks` webhook-ingress profile; add decimal-money,
    consumer idempotency, adapter/ACL, webhook signature-stacking, Cerbos policy factory.
  - **B (angular-nx):** highest-confidence match — templates + reviewer reinforcement only.
  - **C (flutter):** central task = split error handling into **Profile A (Either/dartz,
    `checklist`)** vs **Profile B (`PageState`/exceptions, `supy-mobile`)**; add scanner
    plugin + flutter-packages melos sub-profiles.
  - **D:** new stacks firebase-functions (remediation-first) · ts-cli · ai-agents (Cortex host);
    policy/docs-only for manifest/jsreport/unleash; deepen security-cerbos (split current vs
    target; add derived-roles/CEL/tests/pre-commit-compile).
  - **X (cross-cutting):** 🔒 committed-secrets remediation (BLOCKING, top priority);
    CI-baseline + coverage-bar + pre-commit baselines.
  - Execution order set (value×blast-radius): secrets → flutter split → backend enrich +
    cerbos → new stacks → frontend → CI/coverage/pre-commit.
- 2026-07-15: → checkpoint before **Phase 3 (Enrich)** — offer the local `docs:` commit first.
- 2026-07-16: **Phases 3–6 complete — enrich → create → wire → validate.** Executed in the
  value×blast-radius order set in Phase 2. Deliverables (task IDs #17–#23):
  - **🔒 Secrets (BLOCKING, #17):** authored `config/standards/secrets-and-config.md`
    (secret/config separation) + `agents/supy-secrets-reviewer.md` (stack-agnostic, runs on
    every stack); wired into `commands/supy-review.md` dispatch and `detect-stack.sh`
    `k8s-config` branch. Reinforces the org "never commit secrets" rule.
  - **Flutter split (#18):** `config/standards/flutter/` split into **Profile A** (`dartz`/`Either`)
    vs **Profile B** (`PageState`/`throwAppException`), plus scanner-plugin and
    flutter-packages/melos sub-profiles; `supy-flutter-reviewer` + both flutter skills made
    profile-aware.
  - **Backend enrich + cerbos (#19):** added decimal-money, consumer idempotency, adapter/ACL,
    webhook signature-stacking, Cerbos policy-factory rules; reconciled `supy-api-common`
    shared-lib + `supy-mailgun-webhooks` webhook-ingress profiles; deepened security-cerbos
    (derived roles, CEL, `*_test.yaml`, pre-commit compile).
  - **New stacks (#20):** authored full asset sets for **firebase-functions**, **ts-cli**, and
    **ai-agents** — one `config/standards/<stack>/` rulebook, one `agents/supy-<stack>-reviewer.md`,
    one how-to skill (`supy-firebase-function` / `supy-ts-cli` / `supy-ai-agents`), and a
    `templates/<stack>/` baseline each; added ordered detection branches (ts-cli BEFORE
    ai-agents, both `package.json`-based).
  - **Frontend (#21):** `templates/frontend/` + `supy-angular-reviewer` reinforcement (no new
    rules — highest-confidence existing match).
  - **Cross-cutting (#22):** authored `config/standards/ci-coverage-baseline.md` (coverage bars
    ≥80% flutter apps / ≥85% melos pkgs / ≥70% plugin; Node/TS `coverageThreshold`; pre-commit
    baselines) + per-stack CI/pre-commit/secret-scan templates.
  - **Wire-up + validate (#23):** `plugin-dev:plugin-validator` re-run → **VALID** at
    11 agents / 14 skills / 4 commands / 9-way ordered detection; `shellcheck detect-stack.sh`
    clean; removed 5 leftover `.gitkeep` markers (the only finding). Refreshed `README.md`,
    `docs/USAGE.md`, and `docs/PILOT.md` to the current counts (7→11 agents, 11→14 skills,
    3→7 stacks) and this progress log.
  - Final state: **7 stacks, 11 review agents, 14 skills, 4 commands, 9-way stack detection.**
    All validation passing; live per-stack `/plugin install` + core-loop pilots remain the only
    outstanding item (cannot be driven headlessly — see `docs/PILOT.md`).
