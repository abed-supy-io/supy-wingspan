## supy-api — NestJS 11 + Fastify + Nx + MongoDB (nestjs-nx)

- **Purpose:** Core domain service owning users, locations, channels, customers, settings; NATS request/reply + events; analytics gateway to Databricks. Most widely depended-on service.
- **Structure:** Bounded contexts in `libs/<context>/{domain/model,data,logic,api,common,contracts,mocks}`; single `apps/api`; cross-domain via `libs/context-maps/<service>/`.
- **Architecture & patterns:** CQRS + DDD per context. Input/Output Transformers (domain↔document). Typed value-object IDs. `AggregateRoot.addEvent()` (outbox persisted on save) + `addActivities()` → audit-log JetStream. Interactors depend on `I*Repository`; api→logic→domain isolation enforced. Dual transport: NatsServer RPC (`*.rpc.controller.ts`, `@MessagePattern`) vs JetStreamServer events (`*.nats.controller.ts`, `@EventPattern`) via `IS_IN_WORKER_MODE`.
- **Tooling:** lint=ESLint 9 (@stylistic, simple-import-sort, @typescript-eslint) · format=Prettier 3.6 (@supy/prettier-config) · test=Jest 30 · CI=GitHub Actions (preview.yaml) · codegen=Nx generators (library-group, library-feature-*) · pre-commit=Husky · commits=Conventional (@supy/commitlint-config).
- **Testing:** Jest 30 per project; interactor specs via `Test.createTestingModule` + mocked repos from `@supy/{lib}/mocks`; co-located `.spec.ts`; no explicit coverage bar; placeholder tests present.
- **Security / secrets / config:** `.env{,.local,.development,.production}` via Node runtime args; `@supy.api/env` override; JWT auth (`@supy.api/authentication`); authz in calling services, not core-api.
- **Divergences vs typical Supy nestjs-nx:** none notable — canonical blueprint.
- **New patterns worth codifying:** event discriminator registry (`apps/api/src/app/domain-events.discriminator.ts`); context-map model→proxy→service hierarchy; `StrictValidationPipe` + `StrictJsonQueryPipe` on all handlers; outbox coupled to aggregate persistence; `lean()` on all reads.
- **Recommendation:** deepen nestjs-nx — canonical domain-service blueprint.
