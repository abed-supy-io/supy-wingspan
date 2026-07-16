# Phase 2 — Synthesis: findings reconciled against current standards

**Date:** 2026-07-15
**Inputs:** 26 `docs/analysis/*.md` reports + current `config/standards/*`.
**Output:** per-group diff of **confirmed** (standard already right — keep), **divergent**
(standard stale/wrong or repos inconsistent — reconcile), **new** (real pattern not yet
codified — add). Each delta names the target asset so Phases 3–5 are mechanical.

Legend: ✅ confirmed · ⚠️ divergent · ➕ new · 🔒 security-blocking

---

## Group A — Backend · NestJS-on-Nx (13 repos)

Standards in scope: `nx-nestjs-patterns.md`, `nats-event-patterns.md`,
`backend/module-boundaries.md`, `architecture.md`, `commit-conventions.md`,
`security-cerbos.md`.

### ✅ Confirmed (keep as-is)

- CQRS + DDD per bounded context; layer isolation api→logic→domain←data — matched in
  `supy-api`, `supy-service-*`, `supy-integration-inventory`.
- `@nx/enforce-module-boundaries` with `type:`/`scope:` tags; domain purity (no nest/mongoose
  imports in domain) — enforced in every backend repo checked.
- Dual transport (NatsServer RPC `*.rpc.controller.ts` vs JetStreamServer `*.nats.controller.ts`),
  `IS_IN_WORKER_MODE` toggle, `this.addEvent()` on aggregates — confirmed.
- NestJS 11 full-decorator-import-path quirk; `nx.json` `sync.applyChanges:false` — confirmed
  present and load-bearing; already in `nx-nestjs-patterns.md`.
- Typed errors only (no `new Error` in domain/logic); typed value-object IDs; optimistic `__v`.
- Commit convention `@supy/commitlint-config/conventional` — every repo. `bug` rejected.

### ⚠️ Divergent (reconcile)

- **`supy-api-common` is a shared-library repo, not an app.** No `apps/*`, no dual transport;
  publishes `@supy/*` libs consumed by the app repos. → Standards must carry a **"shared-lib
  variant"** note: which rules apply (module boundaries, domain purity, typed errors, commits)
  and which don't (transport controllers, `IS_IN_WORKER_MODE`, StrictValidationPipe wiring).
- **`supy-mailgun-webhooks` is a webhook-ingress service** — thin, signature-verified HTTP in,
  events out; lighter CQRS. → reviewer needs a "webhook ingress" profile: signature
  verification stacking, idempotency on redelivery, no business logic in the controller.
- **CI is inconsistent across the 13.** Some have full pipelines, some `passWithNoTests` with no
  coverage gate. → cross-cutting (see Group X).

### ➕ New (codify)

- **Decimal-money helper** — money handled as integer minor units / decimal helper, never JS
  float; recurring across settlements/orders/inventory. New rule in `architecture.md` +
  reviewer red-flag on `number` fields named `price|amount|total|cost`.
- **Distributed-lock / idempotency** on event consumers (redelivery-safe handlers). New rule in
  `nats-event-patterns.md`.
- **Adapter/ACL convention** for third-party integrations (`supy-integration-inventory`:
  Lightspeed/Xero/Tissl behind anti-corruption adapters). New rule in `backend/module-boundaries.md`.
- **Webhook signature-verification stacking** (`supy-mailgun-webhooks`) — verify before parse,
  reject on mismatch. New rule + template.
- **Cerbos policy factory** — services that call Cerbos share a check pattern; worth a helper
  convention linking to `security-cerbos.md`.

---

## Group B — Frontend · Angular-on-Nx (1 repo: `supy-frontend`)

Standards in scope: `frontend/angular-conventions.md`, `frontend/module-boundaries.md`.

### ✅ Confirmed (keep as-is)

- Angular 21 + Nx + NGXS(+Immer) + PrimeNG 21 + AG Grid + Jest + SCSS tokens — matches the repo.
- `OnPush` everywhere; `inject()` in `#private` fields; signal inputs/outputs; `selectSignal`;
  `takeUntilDestroyed`; smart/dumb split — all present and lint-enforced.
- NGXS Immer `produce()` / `patchState()`; `{cancelUncompleted:true}`; `@Selector([TOKEN])`;
  action type `[Feature] ActionName`.
- `BaseHttpService` + URI `InjectionToken` (no hardcoded URLs); functional interceptors with
  intentional chain order; PrimeNG `--p-*` tokens, no `::ng-deep`/hex/raw-px.
- `type:`/`scope:` tags, inward deps, `@supy/*` aliases — module-boundaries doc is accurate.

### ⚠️ Divergent (reconcile)

- The two frontend standards are sourced from the **starter-kit** with an `@app/*`→`@supy/*`
  swap already applied; confirm the live `supy-frontend` alias prefix matches (analysis says
  yes). No rule change — just a verification note in the reviewer.

### ➕ New (codify)

- **AG Grid col-def factories + external `supy-pagination`** wiring to response metadata —
  already in rule 21; reinforce with a template snippet under `templates/frontend/`.
- **`saveToUrl` / URL-synced list state** pattern observed — candidate rule if confirmed as a
  convention (flagged for Phase 3 verification against the repo, not assumed).

> Group B is the **highest-confidence, lowest-churn** group: standards already match. Phase 3
> work here is mostly templates + reviewer reinforcement, not new rules.

---

## Group C — Mobile · Flutter (4 repos)

Standards in scope: `flutter/flutter-conventions.md`, `flutter/architecture.md`.
The current standards encode **one** profile (the `checklist` reference: dartz `Either` +
sealed `Failure` + Hive). Reality is **two app profiles + two library sub-profiles.**

### ✅ Confirmed (keep as-is)

- Bloc-not-Cubit; sealed events + freezed states; get_it DI (registerFactory for blocs,
  registerLazySingleton for the rest); UseCase<T,Params>; Dio interceptor order; design tokens;
  mocktail + bloc_test; flavors + FlavorConfig; flutter_secure_storage; VGA + `bloc_lint`.
- 3-layer presentation→domain←data; domain pure Dart; DI in `injection_container.dart`.

### ⚠️ Divergent (reconcile — the central Group C task)

- **`supy-mobile` (the main app) does NOT use dartz `Either`.** It uses a `PageState<T>` sealed
  union + `throwAppException()` for error flow. The current standard presents `Either` as *the*
  Supy way — it is only `checklist`'s way. → **Split the error-handling rule into two named
  profiles**, both first-class:
  - **Profile A — `Either`/dartz** (source: `checklist`): `Future<Either<Failure,T>>`, sealed
    `Failure` hierarchy.
  - **Profile B — `PageState`/exceptions** (source: `supy-mobile`): `PageState<T>` sealed union,
    `throwAppException()`, typed `AppException`.
  Reviewer picks the profile per repo (detect by dependency: `dartz` present → A; else B).
  Neither is "wrong"; mixing within one repo is the red-flag.

### ➕ New (codify — sub-profiles)

- **`supy-scanner` — federated native plugin sub-profile.** Versioned `MethodChannel`,
  platform-interface package, no app-level DI/bloc rules. New section in `flutter/architecture.md`
  ("plugin package profile") + a reviewer branch.
- **`supy-flutter-packages` — melos monorepo sub-profile.** melos, 6 packages, 85% coverage bar,
  per-package `pubspec`. New section: melos bootstrap/versioning, shared analysis_options,
  per-package publish. Coverage bar here (85%) is higher than the app bar (80%) — note both.

---

## Group D — New/uncovered stacks & infra (9 repos)

### ➕ New stacks worth full asset sets

- **`firebase-functions`** (`supy-firebase-functions`) — Firebase Cloud Functions on Node.
  Recommendation: **remediation-first** new stack (repo needs structure/tests/CI before it's a
  clean template). Asset set: `config/standards/firebase-functions/`, reviewer, how-to +
  scaffold skills, template, `detect-stack.sh` branch (marker: `firebase.json` + `functions/`).
- **`ts-cli`** (`supy-cli`) — TypeScript CLI. Asset set as above (marker: `bin` in package.json +
  a CLI framework dep). Rules: command/subcommand structure, arg parsing, exit codes, no secrets
  in argv/logs, testable command handlers.
- **`ai-agents`** (`supy-ai-agents`) — AI/Cloudflare-Worker monorepo, git submodules, hosts the
  **Cortex MCP** server; BullMQ + pgvector. Asset set (marker: `wrangler.toml` + workers layout).
  Rules: MCP tool contract, worker bindings, queue idempotency, pgvector embedding hygiene, no
  secrets in `wrangler.toml` (use secrets bindings). This repo is also the Cortex host — cross-link
  to the Cortex-optional integration already in the plugin.

### Policy / docs-only (no new stack)

- **`supy-cerbos-policies`** → deepen existing `security-cerbos` (see below — its own delta).
- **`supy-manifest`** → policy-only: codify Datree policy set (req/limits, securityContext, RBAC,
  networkPolicy), document blue-green-vs-Deployment policy, document the known hotfix tag-corruption
  bug as "do not tamper". Pairs with the secrets finding (deployments consume `kind: Secret`).
- **`supy-jsreport-templates`** → infra/policy-only: template repo conventions; no stack automation.
- **`supy-unleash-strategies`** → docs-only: custom Unleash strategy conventions + Docker build.
- **`supy-core`** → empty; skip.

### 🔒 Security-blocking (highest priority of the whole analysis)

- **`supy-configmaps` — committed plaintext secrets** (Twilio, Firebase, Intercom, JSReport,
  Unleash, Referral Hero, Lightspeed, Xero, Tissl, SFTP, SendGrid; paths recorded in the analysis
  file, **values never reproduced** per the org rule). → **New BLOCKING infra/config-secrets
  standard**: (1) all tokens/keys/passwords/webhooks move to `kind: Secret` / external-secrets /
  sealed-secrets / Vault; (2) split `{svc}-{env}-config.yaml` (non-sensitive) + referenced Secret;
  (3) Kustomize bases+overlays to DRY envs; (4) **pre-commit secret-scanning hook that rejects
  commits**; (5) documented ConfigMap-vs-Secret policy; (6) kubeval/kube-linter CI. Directly
  reinforces the org rule against exposed secrets.

### `security-cerbos` reconciliation (stale standard)

The current `security-cerbos.md` describes CEL conditions and derived roles **as if present**.
The actual `supy-cerbos-policies` repo has **none** (empty `derived_roles/`, no CEL, no tests,
coarse all-actions-per-resource, no pre-commit compile). → **Split the standard into
current-state vs target-state** and add the missing rules: derived roles, CEL fine-grained
(`resource.owner == principal.id`), `*_test.yaml` allow/deny suites, pre-commit `cerbos compile`,
documented role→principal binding (OIDC scopes/claims). Codify what IS good: default-deny
everywhere; principal-policy precedence; role-variant naming (`-with-*`/`-with-no-*`).

---

## Group X — Cross-cutting (stack-agnostic, root of `config/standards/`)

Recurring across every group — belongs in stack-agnostic standards, not duplicated per stack:

1. 🔒 **Secrets never committed** — the configmaps finding generalized: a repo-agnostic
   secret-scanning pre-commit + CI gate, and a "secrets live in a secret store" rule. Reinforces
   the standing org constraint. **Highest priority.**
2. ⚠️ **CI is inconsistent** — presence and rigor of pipelines varies widely (full pipelines vs
   `passWithNoTests`, no coverage gate). Codify a baseline CI expectation per stack.
3. ⚠️ **No enforced coverage bar** — `passWithNoTests` is widespread; bars where they exist differ
   (flutter app 80%, flutter packages 85%). Codify a minimum + how it's enforced.
4. ✅ **Commit conventions** — consistent everywhere; already codified. Keep.
5. ➕ **Pre-commit hooks** — where present they're valuable (cerbos compile, lint); make a
   baseline set a stack-agnostic recommendation.

---

## Execution order for Phases 3–5 (by value × blast-radius)

1. **🔒 Group X #1 + Group D secrets** — committed-secrets remediation standard (BLOCKING).
2. **⚠️ Group C profile split** — highest divergence from a shipped standard; two profiles + two
   sub-profiles.
3. **⚠️ + ➕ Group A enrichment** — shared-lib variant, webhook profile, decimal-money,
   idempotency, adapter/ACL; reconcile `security-cerbos`.
4. **➕ Group D new stacks** — firebase-functions (remediation-first), ts-cli, ai-agents.
5. **➕ Group B** — templates + reviewer reinforcement (lowest churn).
6. **⚠️ Group X #2–3 + #5** — CI / coverage / pre-commit baselines.

Every change: local commit only (never push), `${CLAUDE_PLUGIN_ROOT}` in component bodies,
`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer, secrets rule honored.
