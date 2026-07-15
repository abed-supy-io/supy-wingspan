## supy-api-admin — NestJS-on-Nx backend (nestjs-nx)

- **Purpose:** Admin API for the Supy platform; modular backend serving admin UIs and integrations.
- **Structure:** ~33 feature libs (users, retailers, suppliers, orders, channels…) each split api/core/logic/repository; single `apps/api`; shared `libs/common`.
- **Architecture & patterns:** Layered controller → interactor → adapter/repository; NestJS DI; NATS microservices (`ClientAdapter.core.sendAsync`); Cerbos gRPC authz; JWT + JWKS (passport-jwt, jwks-rsa); error handling via `@supy.api/nest` HttpExceptionFilter; request/response resource DTOs; WebSocket server.
- **Tooling:** lint=ESLint 9.36 (flat: @nx, @stylistic, simple-import-sort) · format=Prettier (shared) · test=Jest (@nx/jest; `ci` config enables codeCoverage) · CI=GitHub Actions (per-PR preview deploy) · codegen=Nx generators (@supy/tools: library-group, library-feature-api/-controller/-core) · pre-commit=Husky (format + lint-fix staged) · commits=commitlint (@supy/commitlint-config/conventional).
- **Testing:** Jest + NestJS Test module; specs mostly placeholder (`expect(interactor).toBeDefined()`); coverage configured in CI mode but no enforced threshold.
- **Security / secrets / config:** runtime env (HTTP_*, REDIS_HOST_URL, CERBOS_URL, WEBSOCKET_*, API_VERSION, OPENAPI_PATH); `.env.local`/`.env.me` uncommitted; Google Artifact Registry login script; JWT+JWKS auth; Cerbos PDP authz.
- **Divergences vs typical Supy nestjs-nx:** none notable.
- **New patterns worth codifying:** library generators enforce scaffold layers; gap = no enforced test-coverage target, no CLAUDE.md/ADR.
- **Recommendation:** deepen nestjs-nx — mature baseline. Codify: (1) coverage thresholds, (2) CLAUDE.md, (3) OpenAPI schema check in CI.
