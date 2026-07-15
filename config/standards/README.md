# Standards Index

Extracted from real Supy repos on **2026-07-15**. Each file documents rules that the review subagents cite by H2 anchor (`## Rules`, `## DDD building blocks`, `## Examples`, `## Red flags`, `## Source`). Standards are organized by stack: backend files live at the root of this directory (plus [`backend/`](backend/) for module boundaries), frontend files under [`frontend/`](frontend/), and mobile (Flutter) files under [`flutter/`](flutter/).

**Rule: Refresh these files when the mined source repos change** (new commitlint config, refactored NATS conventions, updated Cerbos policies, Angular/NGXS convention changes, Flutter/BLoC convention changes, stack version bumps).

## Backend files (nestjs-nx)

| File | What it covers | Confidence |
|---|---|---|
| [commit-conventions.md](commit-conventions.md) | Allowed commit types, scope rules, subject/body/footer formatting, `fix` vs `bug` correction | high |
| [nats-event-patterns.md](nats-event-patterns.md) | RPC vs event transport, subject naming format, `@MessagePattern` / `@EventPattern` patterns, context-map hierarchy, domain event emission | high |
| [architecture.md](architecture.md) | Layered DDD/Hexagonal architecture, bounded context layout, CQRS structure, context maps, MongoDB/Mongoose conventions, the 7 DDD building-block rules (aggregates, value objects, state VOs, factories, event naming), Cortex MCP usage rule | high |
| [backend/module-boundaries.md](backend/module-boundaries.md) | Nx library `type:`/`scope:` tagging, the inward dependency direction, domain-purity + typed-errors lint rules, `@supy/*` aliases, adding-a-domain wiring | high |
| [security-cerbos.md](security-cerbos.md) | Cerbos resource policy structure, default-deny pattern, role-based access rules, authorization checklist for new handlers | medium |
| [nx-nestjs-patterns.md](nx-nestjs-patterns.md) | Nx monorepo project layout, library structure, generator conventions, NestJS 11 import quirk, TypeScript config, tool versions | high |

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
| [flutter/architecture.md](flutter/architecture.md) | Clean Architecture 3 layers per feature (presentation → domain ← data), the layer dependency rule, `lib/features/` layout, get_it DI (singletons for services/repos/usecases/datasources, factory for BLoCs), `dartz` `Either<Failure, T>` + the sealed `Failure` hierarchy, `UseCase<T, Params>`, repository interface/impl split, hive cache policies | high |
| [flutter/flutter-conventions.md](flutter/flutter-conventions.md) | BLoC (never Cubit) with sealed events + freezed state, go_router `context.go` + `static const path`/`name`, dio interceptor chain (auth → cache → retry → error → logging), freezed/json_serializable codegen, design tokens (`context.supyColors`/`context.textTheme`, spacing scale, `SupyRadius`), flavors via `FlavorConfig`, `flutter_secure_storage` + sanitized Sentry, `mocktail`+`bloc_test`/≥80%/`pumpApp`, Conventional Commits | high |

The `supy-flutter-reviewer` agent and the `supy-flutter-feature` / `supy-scaffold-flutter-feature` skills cite these two files by H2 anchor (e.g. `architecture.md#rules rule 2`, `flutter-conventions.md#red-flags`).

## Mining provenance

| Source repo | What was mined |
|---|---|
| `supy-service-inventory` | commitlint config, CLAUDE.md, ARCHITECTURE.md, copilot-instructions.md, real handler files in `libs/ledger/api/src/`, nx.json, project.json |
| `supy-api` | CLAUDE.md (corroborates patterns in core domain service) |
| `supy-cerbos-policies` | README.md, resource policy YAML files |
| `angular-frontend-starter-kit` | CLAUDE.md, docs/module-boundaries.md, eslint.config.mjs, .stylelintrc.json, tools/generators (Plop feature generator) |
| `architecture-starter-kit` | CLAUDE.md, README.md, docs/module-boundaries.md, eslint.config.mjs (boundary/purity/typed-error rules), skills/clean-architecture-ddd + skills/domain-review, tools/generators (Plop `g:domain` generator) |
| `supy-checklists` (Supy Checklists mobile app) | CLAUDE.md-style spec: Clean Architecture layering, BLoC + freezed conventions, go_router/get_it/dio/dartz patterns, hive cache policies, design tokens, flavors, testing conventions, `analysis_options.yaml` (`very_good_analysis` + `bloc_lint`) |
