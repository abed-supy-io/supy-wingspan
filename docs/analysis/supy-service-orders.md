## supy-service-orders — NestJS 11 + Fastify on Nx 22.6 (nestjs-nx)

- **Purpose:** Orders domain service — PO lifecycle (draft → submit → ship → receive), category orders, requisition groups, GRN settlement integration.
- **Structure:** `apps/api` + bounded contexts `libs/{orders,category-orders,requisitions,order-templates,prediction-baskets,standing-orders}/{domain/model,data,logic,api,contracts,mocks}` + `libs/context-maps/`.
- **Architecture & patterns:** CQRS + DDD aggregates. Dual transport: API (`@MessagePattern`, NatsServer) / Worker (`@EventPattern`, JetStream) via `IS_IN_WORKER_MODE`. Event sourcing via outbox (events persisted on save, JetStream listener syncs). Activities = immutable VOs tracking state transitions (Draft/Submit/Ship/Receive/Post). Layer isolation api → logic → domain ← data; domain framework-agnostic. Redis distributed locks for idempotent event handlers; Mongoose session transactions; optimistic locking `__v`.
- **Tooling:** lint=ESLint 9 (flat: @stylistic, simple-import-sort, Nx boundaries) · format=Prettier (shared) · test=Jest 30 (co-located, mocks via `@supy/{lib}/mocks`) · CI=.github/workflows present · codegen=Nx generators (library-{group,feature-*}) · pre-commit=Husky (commit-msg via commitlint) · commits=@supy/commitlint-config.
- **Testing:** Jest + class-transformer mocks; interactors tested with mocked repos (interface DI); handlers via jest.mock(); no coverage bar.
- **Security / secrets / config:** env via dotenv-cli (`.env{,.local,.me}`) + `@supy.api/env`; Firebase SA key + Firestore in env; Mongo via NATS_* + Mongo URL; authz via `@supy.api/permissions` context map.
- **Divergences vs typical Supy nestjs-nx:** dual transport env-flag; heavy Redis locks in JetStream handlers; extensive context-maps (11+ services).
- **New patterns worth codifying:** dual-transport switchability (formalize env schema + deployment topology); Redis lock idiom (`lockName()`) for JetStream idempotency; Activity VOs as lightweight state-machine history.
- **Recommendation:** deepen nestjs-nx — mature. Formalize outbox/event resilience, codify distributed-lock/JetStream dedup, document Activity state transitions.
