## supy-api-retailer — NestJS 11.1 + Fastify 5 on Nx 22.5 (nestjs-nx, BFF)

- **Purpose:** Retailer-facing BFF HTTP gateway; validates/transforms web-app requests, proxies to domain services via NATS.
- **Structure:** `apps/api` + `libs/<domain>/{api,logic,repository,adapter}` (3–4 layer feature libs: grns, customers, invoices, orders, channels, base-items…).
- **Architecture & patterns:** Controller → Interactor (one per use case) → Repository/Adapter → NATS/HTTP. Cerbos RBAC (`@Authorization`, `IResourceProvider`, `GetUserPrincipal`). DTOs with class-validator + Swagger. `@supy.api/errors`. Controllers delegate fully to interactors. `CaptchaGuard` + `CsrfGenerateInterceptor` on anon/login routes.
- **Tooling:** lint=ESLint 9.36 (@nx, @stylistic, simple-import-sort, naming-convention, module-boundaries) · format=Prettier 3.6 (@supy/prettier-config) · test=Jest 30 (co-located) · CI=Nx Cloud + preview.yml · codegen=Nx workspace-generators (library-group, library-feature-api/-controller/-core) · pre-commit=Husky (commit-msg, pre-commit, pre-push, prepare-commit-msg) · commits=commitlint conventional `type[scope]: msg [sc-ID]` (Clubhouse-linked).
- **Testing:** Jest 30 + `Test.createTestingModule`; mock repos; e2e in `tests/e2e` (supertest); co-located transformer specs.
- **Security / secrets / config:** `.env{,.development.local,.production.local}` via `--env-file`; JWT public keys inline; Firebase SA JSON + DATABRICKS_* + FIREBASE_SERVICE_ACCOUNT_KEY in env; CERBOS_URL + AUTHORIZATION_SERVER_URL; `x-api-key`; `.npmrc` skip-worktree.
- **Divergences vs typical Supy nestjs-nx:** adapter layer used more than domain services; explicit endpoint-enum convention; per-endpoint `IResourceProvider` (vs generic RBAC).
- **New patterns worth codifying:** (1) adapter/context-map for NATS wrappers in BFFs; (2) `IResourceProvider` Cerbos resolution per endpoint; (3) `Strict*Pipe` validation naming; (4) `CaptchaGuard`+`CsrfGenerateInterceptor`; (5) feature-lib codegen.
- **Recommendation:** deepen nestjs-nx — mature. Focus: adapter/context-map generator, endpoint-enum validation, pre-push Cerbos policy linting.
