## supy-service-catalog — NestJS 11 + Fastify on Nx (nestjs-nx)

- **Purpose:** MongoDB-backed catalog service (ck-items, channel-items, retailer-items, price-lists, packagings, UOMs).
- **Structure:** `apps/api` + 12 bounded-context libs under `libs/` + `libs/context-maps/` (inter-service proxies) + `libs/common`.
- **Architecture & patterns:** CQRS + DDD; strict layering api/ (`@MessagePattern` RPC) → logic/ (interactors) → domain/model/ (aggregates, VOs, interfaces) ← data/ (Mongoose repos, transformers). Dual transport `*.rpc.controller.ts` (NatsServer) vs `*.nats.controller.ts` (JetStream) via `IS_IN_WORKER_MODE`. Query-builder via `@supy.api/query` (no raw Mongoose). Outbox via `AggregateRoot.addEvent()` + `addActivities()` audit. Typed errors.
- **Tooling:** lint=ESLint 9 (flat: @stylistic, simple-import-sort, @nx) · format=Prettier 3.6 (@supy/prettier-config) · test=Jest 30 (co-located, mock repos) · CI=none (Nx Cloud present) · codegen=Nx generators (library-group, library-feature-{api,core,logic,data,contracts,mocks}) · pre-commit=Husky 9 · commits=conventional (@supy/commitlint-config).
- **Testing:** Jest 30 + `Test.createTestingModule` + mock repos, co-located; no coverage bar.
- **Security / secrets / config:** env via `@supy.api/env/override`; `IS_IN_WORKER_MODE`/`NATS_SERVER_ENABLED`/`JETSTREAM_SERVER_ENABLED` toggles; `.env.vault` (Doppler); authz via NATS patterns + `SimpleUser` in payloads.
- **Divergences vs typical Supy nestjs-nx:** query layer separate from logic (interactor-only, not command/handler); dual transport env-toggled (not separate deploys); custom workspace generators.
- **New patterns worth codifying:** context-maps (proxy+model+service) avoiding direct ClientAdapter; `@supy.api/query` builder replacing raw Mongoose filters; InputTransformer/OutputTransformer pairs; aggregate event outbox + audit to JetStream.
- **Recommendation:** deepen nestjs-nx — reference for product/domain services; query-builder + context-maps reusable.
