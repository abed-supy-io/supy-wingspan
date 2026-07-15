## supy-api-mobile — NestJS 11 + Fastify 5 on Nx 22.6 (nestjs-nx, BFF)

- **Purpose:** Mobile-facing BFF gateway; validates/transforms requests, proxies to domain services via NATS.
- **Structure:** `apps/api` + `libs/<feature>/{api,logic,repository}` (three-layer per feature: HTTP controllers, interactors, NATS adapters).
- **Architecture & patterns:** API→Logic→Repository; NATS async RPC via `ClientAdapter` (settlements, orders, core); `StrictValidationPipe`/`StrictParseQueryPipe`; Cerbos authz via `IResourceProvider`; JWT + `@Authentication`/`@Anonymous` decorators.
- **Tooling:** lint=ESLint 9 (flat: import-sort, @stylistic; `max-lines=100`, curly, readonly) · format=Prettier 3.8 (@supy/prettier-config) · test=Jest 30 (co-located specs) · CI=preview.yml · codegen=Nx schematics (library-groups/features/controllers) · pre-commit=commitizen CZ · commits=Conventional `[type](scope): message [sc-123]` (@supy/commitlint-config).
- **Testing:** Jest + `Test.createTestingModule`; mock `ClientAdapter` via jest.fn(); specs co-located.
- **Security / secrets / config:** env via `@supy.api/env` override + `--env-file=.env*`; Cerbos resource authz; CORS + multipart via Fastify plugins; no hardcoded secrets.
- **Divergences vs typical Supy nestjs-nx:** none notable.
- **New patterns worth codifying:** NATS endpoint enums (`[domain].[action].[multiplicity]`); three-layer api/logic/repository split; Resource providers as Cerbos bridge; mobile-optimized DTOs.
- **Recommendation:** deepen nestjs-nx — exemplary BFF; candidate reference template for other BFFs.
