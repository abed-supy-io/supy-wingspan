# Standards Index

Extracted from real Supy repos on **2026-07-15**. Each file documents rules that the review subagents cite by H2 anchor (`## Rules`, `## DDD building blocks`, `## Examples`, `## Red flags`, `## Source`). Standards are organized by stack: backend (nestjs-nx) files live at the root of this directory (plus [`backend/`](backend/) for module boundaries), frontend files under [`frontend/`](frontend/), mobile (Flutter) files under [`flutter/`](flutter/), and the standalone Firebase Functions backend under [`firebase-functions/`](firebase-functions/). Two files at the root are **cross-cutting / stack-agnostic** and govern every repo: `commit-conventions.md` and `secrets-and-config.md` (see the Cross-cutting section below).

**Rule: Refresh these files when the mined source repos change** (new commitlint config, refactored NATS conventions, updated Cerbos policies, Angular/NGXS convention changes, Flutter/BLoC convention changes, stack version bumps).

## Backend files (nestjs-nx)

| File | What it covers | Confidence |
|---|---|---|
| [commit-conventions.md](commit-conventions.md) | Allowed commit types, scope rules, subject/body/footer formatting, `fix` vs `bug` correction | high |
| [nats-event-patterns.md](nats-event-patterns.md) | RPC vs event transport, subject naming format, `@MessagePattern` / `@EventPattern` patterns, context-map hierarchy, domain event emission, **consumer idempotency** (rule 13, query-then-upsert on redeliverable input) | high |
| [architecture.md](architecture.md) | Layered DDD/Hexagonal architecture, bounded context layout, CQRS structure, context maps, MongoDB/Mongoose conventions, the 7 DDD building-block rules (aggregates, value objects, state VOs, factories, event naming), the **webhook-ingress profile** (W1–W5, for external HTTP webhook entry points), Cortex MCP usage rule | high |
| [backend/module-boundaries.md](backend/module-boundaries.md) | Nx library `type:`/`scope:` tagging, the inward dependency direction, domain-purity + typed-errors lint rules, `@supy/*` aliases, adding-a-domain wiring, plus the **shared-library variant** carve-out for `supy-api-common` (untagged flat libs are not a defect there) | high |
| [security-cerbos.md](security-cerbos.md) | Cerbos as-mined **pure static RBAC** (default-deny + role allow-lists, `version: "default"`, no CEL/derived-roles/tests today), principal-policy precedence (admin/superadmin wildcards override resource rules), capabilities as named role variants (`-with-*`), plus a `## Runtime integration` section (PolicyIdFactory, batched admin sync, scope namespacing — verify via Cortex) and a `## Target state` section (CEL/derived-roles/tests are recommendations, **never flagged as defects**) | medium |
| [nx-nestjs-patterns.md](nx-nestjs-patterns.md) | Nx monorepo project layout, library structure, generator conventions, NestJS 11 import quirk, TypeScript config, tool versions, plus the **shared-library variant (SV1–SV6)** for `supy-api-common` (flat untagged libs, `@supy.api/*` barrels, `nx-release` to GAR, `Identity`/`BaseError`/NATS-proxy archetypes) | high |

The `commit-conventions.md` file is stack-agnostic and also governs frontend commits. `backend/module-boundaries.md` lives under [`backend/`](backend/); the `supy-architecture-reviewer` agent and the `supy-clean-architecture` / `supy-scaffold-domain` skills cite both it and `architecture.md` by H2 anchor (e.g. `architecture.md#rules rule 3`, `architecture.md#ddd-building-blocks rule 5`, `module-boundaries.md#red-flags`).

## Frontend files (angular-nx)

| File | What it covers | Confidence |
|---|---|---|
| [frontend/angular-conventions.md](frontend/angular-conventions.md) | Component discipline (OnPush, `inject()`, signal I/O, smart/dumb split), NGXS state/actions (Immer `produce`, `cancelUncompleted`, static selectors), services (`BaseHttpService` + URI token), routing, forms, models/DTOs, styling (`--p-*` tokens), imports/TS | high |
| [frontend/module-boundaries.md](frontend/module-boundaries.md) | Nx library `type:`/`scope:` tagging, dependency direction, domain isolation, `@supy/*` path aliases, adding-a-feature wiring | high |

The `supy-angular-reviewer` agent and the `supy-angular-feature` / `supy-scaffold-feature` skills cite these two files by H2 anchor (e.g. `angular-conventions.md#rules rule 1`, `module-boundaries.md#red-flags`).

## Flutter files (flutter)

| File | What it covers | Confidence |
|---|---|---|
| [flutter/architecture.md](flutter/architecture.md) | Clean Architecture layers per feature (presentation → domain ← data), the layer dependency rule, `lib/features/` layout, get_it DI, the `UseCase<T, Params>` base, repository interface/impl split, hive cache policies — plus the **`## Profiles` section** that splits apps into **Profile A** (`dartz` `Either<Failure, T>` + sealed `Failure` hierarchy + central DI) and **Profile B** (bare `Future<T>` + central `throwAppException` → typed `AppException` + `PageState<T>` + feature-scoped DI), and two **library sub-profiles** — plugin (P1–P6) and melos-packages (M1–M5) | high |
| [flutter/flutter-conventions.md](flutter/flutter-conventions.md) | BLoC (never Cubit) with sealed events + freezed state, go_router `context.go` + `static const path`/`name`, dio interceptor chain (auth → cache → retry → error → logging), freezed/json_serializable codegen, design tokens (`context.supyColors`/`context.textTheme`, spacing scale, `SupyRadius`), flavors via `FlavorConfig`, `flutter_secure_storage` + sanitized Sentry, profile-specific error handling (rules 10–12 carry Profile A + Profile B variants), `mocktail`+`bloc_test` with per-profile coverage bars (apps ≥80%, melos packages ≥85%, plugin ≥70% Dart + native tests), Conventional Commits | high |

The `supy-flutter-reviewer` agent and the `supy-flutter-feature` / `supy-scaffold-flutter-feature` skills cite these two files by H2 anchor (e.g. `architecture.md#rules rule 2`, `flutter-conventions.md#red-flags`).

**Profiles are not stack variants — they are the same stack with two error-transport conventions plus two library shapes.** The reviewer runs a **Step 0** first: `melos.yaml` → melos-packages sub-profile (M1–M5); `flutter.plugin.platforms` in `pubspec.yaml` → plugin sub-profile (P1–P6, no BLoC/go_router/get_it expected); otherwise it is an app, and the `dartz` dependency selects **Profile A** (present) vs **Profile B** (absent). A single app mixing both error-transport profiles is a red flag. The P1–P6 and M1–M5 rules live under `architecture.md#profiles`; findings against them cite that anchor plus the rule tag (e.g. `architecture.md#profiles rule P1`).

## Firebase Functions files (firebase-functions)

The standalone, **non-Nx** Firebase Functions backend (`supy-firebase-functions`) — Node/TypeScript on the Firebase Functions runtime (Node 22), Awilix DI (not NestJS DI), Cloud Firestore, package under `functions/`.

| File | What it covers | Confidence |
|---|---|---|
| [firebase-functions/architecture.md](firebase-functions/architecture.md) | Clean Architecture for Firebase Functions (`index.ts` → app interactors → data repositories → frameworks; dependencies inward), Awilix resolve-don't-`new` + `createScope`, **runtime-enforced auth markers** (`@unauthenticated`/`@internal`/`@admin`/`@apiKey` — a marked handler that never calls its guard is an open endpoint), typed domain errors (`CustomError`→`HttpsError`), **at-least-once Firestore/PubSub trigger idempotency**, secrets from Secret Manager (never literals). Split into per-diff-enforceable `## Rules` (9 numbered) and a repo-wide `## Remediation backlog` (migrations — **not** per-diff blockers unless the diff introduces the defect) | medium |

This is the **least-governed** TypeScript repo at Supy (TSLint not ESLint, no tests, no CI, no pre-commit, unenforced auth markers, historically hardcoded credentials) — the standard is deliberately **remediation-first**. The `supy-firebase-functions-reviewer` agent and the `supy-firebase-function` skill cite `firebase-functions/architecture.md` by H2 anchor (e.g. `architecture.md#rules rule 3`, `architecture.md#red-flags`), and also lean on the cross-cutting `secrets-and-config.md`. The reviewer must **not** raise `## Remediation backlog` items against an unrelated diff. The [`templates/firebase-functions/`](../../templates/firebase-functions/) scaffold supplies the runtime auth guards, an ESLint (TSLint→ESLint migration) config, a CI workflow, a gitleaks/lint-staged/commitlint pre-commit chain, and a stack-specific `CLAUDE.md.hbs`.

## Cross-cutting files (stack-agnostic)

These live at the root of this directory and govern **every** repo regardless of stack.

| File | What it covers | Confidence |
|---|---|---|
| [commit-conventions.md](commit-conventions.md) | Allowed commit types, scope rules, subject/body/footer formatting, `fix` vs `bug` correction (also listed under backend) | high |
| [secrets-and-config.md](secrets-and-config.md) | No committed secrets (BLOCKING); Kubernetes config-vs-Secret separation; externalize to Secret/external-secrets/sealed-secrets/Vault; Kustomize base+overlays; mandatory failing secret-scan pre-commit hook; kubeval/kube-linter CI; rotate-on-exposure; no hardcoded fallbacks/leaks | high |

The `supy-secrets-reviewer` agent cites `secrets-and-config.md` by H2 anchor (e.g. `secrets-and-config.md#rules rule 1`, `secrets-and-config.md#red-flags`). It is dispatched by `supy-review` on **every** stack (like `supy-commit-pr-reviewer`), and additionally defines the `k8s-config` stack (ConfigMap/Secret YAML or a `kustomization.yaml`, no app stack). This standard directly enforces the organization rule that secrets must never be exposed — **never reproduce a secret value; cite path:line only.** The [`templates/k8s-config/`](../../templates/k8s-config/) scaffold provides a ready-to-use blocking secret-scan pre-commit config and a config/secret Kustomize split.

## Mining provenance

| Source repo | What was mined |
|---|---|
| `supy-service-inventory` | commitlint config, CLAUDE.md, ARCHITECTURE.md, copilot-instructions.md, real handler files in `libs/ledger/api/src/`, nx.json, project.json |
| `supy-api` | CLAUDE.md (corroborates patterns in core domain service) |
| `supy-api-common` | shared-library-only repo (`@supy.api/*` packages): ~30 flat untagged libs, barrel aliases, `nx-release` independent versioning to Google Artifact Registry, `Identity` phantom-type IDs, `BaseError`→`HttpExceptionFilter`, compression-aware NATS proxy, transformation decorators, Jest `passWithNoTests` → shared-library variant SV1–SV6 (`nx-nestjs-patterns.md`) + carve-out (`backend/module-boundaries.md`) |
| `supy-mailgun-webhooks` | external HTTP webhook ingress: HMAC-SHA256 signature guard + stacked signature interceptors, no-logic controller republishing to internal `communication.*-email-requested` via outbox, query-then-upsert idempotency, Slack-notifying exception filters, `StrictValidationPipe` + attachment interceptor → webhook-ingress profile W1–W5 (`architecture.md`) + consumer-idempotency rule 13 (`nats-event-patterns.md`) |
| `supy-cerbos-policies` | README.md, `resource_policies/*.yaml`, `principal_policies/{admin,superadmin}.yaml` (wildcard `actions: ["*"]` grants), empty `derived_roles/` (`.gitkeep`), `cerbos-compile-action` CI — as-mined pure static RBAC (no CEL/derived-roles/tests) → `security-cerbos.md` current-state rules + target-state |
| `supy-api-authorization` | Cerbos runtime integration: `PolicyIdFactory`, `CerbosAdminClient` DB storage mode with batched sync (≤10/req), scope namespacing (`@scope:reference`), condition DSL (`ConditionGroupOperatorEnum` → `MatchExpr`), `@cerbos/grpc` + `@cerbos/http` → `security-cerbos.md#runtime-integration` |
| `supy-configmaps` | per-service `{service}-{env}.yaml` ConfigMaps (BLOCKING: committed plaintext secrets — paths recorded, **values never reproduced**); absence of Kustomize / validation / secret-scanning |
| `supy-manifest` | ArgoCD App-of-Apps, `kind: Secret` references, Datree CI validation gate (target-state model for config repos) |
| `angular-frontend-starter-kit` | CLAUDE.md, docs/module-boundaries.md, eslint.config.mjs, .stylelintrc.json, tools/generators (Plop feature generator) |
| `architecture-starter-kit` | CLAUDE.md, README.md, docs/module-boundaries.md, eslint.config.mjs (boundary/purity/typed-error rules), skills/clean-architecture-ddd + skills/domain-review, tools/generators (Plop `g:domain` generator) |
| `supy-checklists` (Supy Checklists mobile app) | **Flutter Profile A (Either):** CLAUDE.md-style spec: Clean Architecture layering, BLoC + freezed conventions, go_router/get_it/dio/dartz patterns, `Either<Failure, T>` + sealed `Failure` hierarchy + `fold`, central `lib/app/injection_container.dart`, hive cache policies, design tokens, flavors, testing conventions, `analysis_options.yaml` (`very_good_analysis` + `bloc_lint`) |
| `supy-mobile` (Supy mobile app) | **Flutter Profile B (PageState):** repos/usecases return bare `Future<T>`; central `throwAppException(e, s)` → typed `AppException` family (`NetworkException`/`ServerException`/`UnauthorizedException`/`ValidationException`/`UnknownException`); `PageState<T>` sealed union (init/loading/success/empty/failure) resolved via `when`/`whenOrNull`/`maybeWhen`; feature folders add `application/` + feature-scoped `injection/<feature>_dependencies.dart` |
| `supy-scanner` (federated Flutter plugin) | **Flutter plugin sub-profile (P1–P6):** versioned `MethodChannel` (`io.supy.scanner/v1`) singleton + `*_platform_interface` package; sealed result types (no `dynamic`); per-view `EventChannel` + `PlatformView` + controller; native work off main thread + bridge hardening; `ChangeNotifier`/streams surface; 70% lcov Dart coverage + Robolectric/XCTest |
| `supy-flutter-packages` (melos monorepo) | **Flutter melos-packages sub-profile (M1–M5):** zero inter-package coupling; barrel exports `lib/<pkg>.dart` → `src/*`; 85% per-package coverage (`very_good_coverage`); dual analysis config (`very_good_analysis` Flutter-heavy / `lints:recommended` pure-Dart); per-package path-filtered CI |
| `supy-firebase-functions` (standalone Firebase Functions backend) | **Firebase Functions (remediation-first):** non-Nx Node/TS on the Functions runtime, package under `functions/`; Clean Architecture (`index.ts`→app→data→frameworks); Awilix DI (`createScope`, resolve-don't-`new`); auth markers `@unauthenticated`/`@internal`/`@admin`/`@apiKey` that must be runtime-enforced by guards; typed `CustomError`→`HttpsError`; at-least-once Firestore/PubSub trigger idempotency; Secret Manager for every credential (historically hardcoded — **paths recorded, values never reproduced**); observed gaps: TSLint (not ESLint), no tests, no CI, no pre-commit → `firebase-functions/architecture.md` `## Rules` (9) + `## Remediation backlog` |
