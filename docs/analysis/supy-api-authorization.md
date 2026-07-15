## supy-api-authorization — NestJS 11 + Fastify on Nx 22.5 (nestjs-nx)

- **Purpose:** RBAC domain service — roles, permissions, policy enforcement via Cerbos; MongoDB-backed; NATS RPC/event handlers.
- **Structure:** `apps/api` + bounded contexts `libs/{authorization,roles,permission-policies}` (CQRS-DDD) + shared `libs/{common,adapters,context-maps,core,domain-events}`.
- **Architecture & patterns:** CQRS + DDD per context: `domain/` (aggregates, VOs, interfaces) → `logic/` (interactors, services, listeners) → `api/` (`@MessagePattern`/`@EventPattern` controllers, DTOs) ← `data/` (repos, Mongoose schemas). Layer isolation enforced; DI by `I*Repository`. Dual transport (API NatsServer RPC / Worker JetStream) via `IS_IN_WORKER_MODE`. Typed errors (`ValidationError`/`NotFoundError`/`ConflictError`/`UnknownError`); MongoDB session transactions with rollback.
- **Tooling:** lint=ESLint 9.39 (Nx, simple-import-sort, stylistic) · format=Prettier 3.6 (@supy/prettier-config) · test=Jest 30 · CI=none (build targets only) · codegen=none · pre-commit=Husky 9 (format + lint-fix) · commits=commitlint conventional; pre-push branch policy `feat|fix|hotfix|…/[a-z0-9-]{1,24}`.
- **Testing:** Jest 30, passWithNoTests; no spec files found (in progress/deleted).
- **Security / secrets / config:** env via `--env-file` + `.env.vault` (encrypted). Cerbos: @cerbos/grpc 0.25 + @cerbos/http 0.26, `CerbosAdminClient`; policies batched (≤10/req), versioned, scope-namespaced (`@scope:reference`); metadata persisted to Mongo + events via outbox.
- **Divergences vs typical Supy nestjs-nx:** none — exemplary; aligns to CLAUDE.md conventions precisely.
- **New patterns worth codifying:** PolicyIdFactory + batched Cerbos sync (DB storage mode); scope-aware policy namespacing; condition-expression DSL mapping (ConditionGroupOperatorEnum → Cerbos MatchExpr); fully-qualified event names `contextName.aggregateName.eventName`.
- **Recommendation:** deepen nestjs-nx — reference bounded context. Consider shared `@supy.api/cerbos-patterns` (policy factory, batching, condition builders).
