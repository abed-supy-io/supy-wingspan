## supy-service-authentication — NestJS-on-Nx microservice (nestjs-nx)

- **Purpose:** Authentication service — OTP, SSO, API keys, domain verification, token lifecycle (OIDC, refresh tokens).
- **Structure:** `apps/api` + `libs/{authentication,api-key,user,connector,domain-verification,organization,queue-board,retailer,common}`.
- **Architecture & patterns:** clean layering api/controllers → logic/interactors → contracts → data/repositories; NATS `@MessagePattern` RPC; `StrictValidationPipe`; DI via `@Inject` port tokens; domain events (`UserSyncedEvent`, `UserDeletedEvent`); error handling via `@supy.api/errors` + `NatsExceptionFilter`.
- **Tooling:** lint=ESLint flat (TS strict + @stylistic + import-sort) · format=Prettier (80 cols, trailing commas, single quotes) · test=Jest (@nx/jest) · CI=GitHub Actions (`nx run-many lint test build typecheck`) · codegen=@nx/js/typescript, @nx/rspack · pre-commit=Husky (branch `type/slug` ≤24 chars; commitlint @supy/commitlint-config) · commits=conventional.
- **Testing:** Jest with mocked services; passWithNoTests; coverage → `{projectRoot}/coverage`; ci config codeCoverage=true.
- **Security / secrets / config:** `LogtoTokenService` (OIDC subject tokens M2M + custom refresh tokens, 14-day TTL store, revoke-on-reissue); OTP over NATS payloads; env via `--env-file` (`.env{,.development,.production,.*.local}`) + `@supy.api/env`.
- **Divergences vs typical Supy nestjs-nx:** none notable.
- **New patterns worth codifying:** LogtoTokenService token lifecycle (subject → access + custom refresh → revoke on reissue); `OidcClientType` enum (Web/Mobile) for audience differentiation; port abstractions (`ILogtoOidcPort`, `IRefreshTokenStore`) for multi-provider support.
- **Recommendation:** deepen nestjs-nx — solid; document token-lifecycle reference for other services.
