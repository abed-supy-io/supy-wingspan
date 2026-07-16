---
source: supy-firebase-functions (functions/src/lib/{app,data,frameworks}, use-cases/*, index.ts, server.ts, firebase.json)
mined_on: 2026-07-16
confidence: medium
---

# Firebase Functions (Node 22 / TypeScript) — architecture & remediation

Supy's `supy-firebase-functions` is a **standalone** (non-Nx) serverless backend: Firestore
triggers (auth, orders, companies, products, messages), HTTPS callables, Cloud Tasks, and a
BigQuery sync. It follows the same Clean Architecture spine as the rest of Supy
(`Interactor → Repository → DataSource`) but uses an **Awilix IoC container** for DI instead of
NestJS decorators, and exports one function per trigger from `index.ts`.

It is also the **least-governed TypeScript repo** at Supy: TSLint (deprecated) rather than
ESLint, no tests, no CI, no pre-commit, and hardcoded third-party credentials in source. This
standard therefore separates two concerns:

- **`## Rules`** — the target-state conventions a reviewer enforces on **new or changed** code
  in a diff (clean-architecture direction, runtime-enforced auth, secrets, typed errors). These
  produce per-diff findings.
- **`## Remediation backlog`** — repo-wide migrations (TSLint→ESLint, add tests/CI/pre-commit,
  Secret Manager). These are **not** per-diff blockers unless the diff itself adds the defect;
  they are tracked as remediation, not flagged on every unrelated change.

> **Never reproduce a secret value.** The analysis found hardcoded credentials in `server.ts`
> and the DI container. When reviewing or remediating, cite the **file path and line only** —
> never echo the token/key into a finding, commit, or external tool (organization rule; see
> `secrets-and-config.md`).

## Rules

1. **Layer direction is inward** (`app → data → frameworks`, never the reverse). A use-case
   interactor under `use-cases/<domain>/` depends on a repository *interface*; the concrete
   repository lives in `data/` and talks to a `DataSource`. A trigger/HTTPS handler must not
   query Firestore directly — it resolves an interactor from the container and delegates. Flag a
   Firestore/`admin.firestore()` call or business logic inline in `index.ts` or a handler.
2. **DI through the Awilix container, not `new`.** Interactors, repositories, and data sources
   are registered in the container and resolved by name (`container.resolve('...')` /
   `cradle`). Application code must not `new` a repository or interactor directly. New wiring is
   added to the container registration, not constructed ad hoc.
3. **Env/request state via a scoped container.** Per-request or per-environment values are
   injected through a `container.createScope()` scope, not read from module-level globals inside
   a handler. Flag a handler that reads mutable global config directly instead of resolving it
   from its scope.
4. **Auth markers MUST be enforced at runtime.** The `@unauthenticated` / `@internal` /
   `@admin` / `@apiKey` decorators are currently **semantic-only** — they document intent but do
   not gate execution. Any new callable/HTTPS/Task handler that carries an auth marker must
   actually enforce it (verify the Firebase Auth token / `context.auth`, the admin claim, the
   internal OIDC service-account identity, or the API key) before running logic. A handler
   marked `@admin` that never checks the admin claim is a **high-severity** auth gap.
5. **Cloud Tasks / internal calls authenticate with OIDC service-account identity.** An HTTPS
   endpoint intended for internal (`@internal`) or Task invocation must verify the caller's OIDC
   token / service-account identity — it must not be an open `onRequest` reachable by anyone.
6. **Typed domain errors, thrown through the factory.** Errors are `CustomError` subclasses
   raised via `ApplicationErrorFactory`, mapped to the correct Firebase `HttpsError` code at the
   boundary — never a bare `throw new Error(...)` or an unmapped throw that surfaces as
   `INTERNAL` to the caller.
7. **Secrets come from Secret Manager / injected config, never hardcoded.** A new secret value
   (API key, auth token, service-account JSON, connection string) must be read from Firebase
   Secret Manager (`defineSecret` / `functions.config()` populated out-of-band) or an injected
   env var — never a string literal in `server.ts`, a handler, or the container registration.
   A committed credential is a **high-severity, merge-blocking** finding (pairs with
   `secrets-and-config.md#rules` rule 1). Cite path:line, never the value.
8. **One responsibility per exported trigger.** Each `index.ts` export maps a single trigger
   (`onDocumentWritten`/`onDocumentCreated`/`onCall`/`onRequest`/Task) to exactly one interactor
   entrypoint via the input-mapping plugin (`QueryDocumentSnapshot → Input`). Do not fan a single
   export out into unrelated domains, and do not put mapping/validation logic inside the export
   body — keep it in the mapper.
9. **Firestore triggers must tolerate redelivery.** Cloud Functions Firestore/PubSub triggers
   are at-least-once — the same event can fire twice. A trigger that writes derived state must
   reconcile against a stable key (idempotent set/merge, a processed-marker, or a version check),
   not blind-append. Mirrors the backend consumer-idempotency rule (`nats-event-patterns.md#rules`
   rule 13) for the serverless boundary.

## Examples

### Good — handler delegates to a container-resolved interactor with enforced auth

```typescript
// index.ts — one export, one trigger, no inline logic
export const setAdminClaim = onCall(async (request) => {
  requireAdmin(request.auth);                       // rule 4: runtime auth enforcement
  const interactor = container.resolve('setAdminClaimInteractor'); // rule 2: DI
  return interactor.execute(mapCallableInput(request)); // rule 8: mapper, then delegate
});
```

### Bad — inline Firestore + unenforced @admin + hardcoded secret

```typescript
// WRONG: @admin marker but no claim check; queries Firestore inline; hardcoded key
// @admin
export const syncOrders = onRequest(async (req, res) => {
  const db = admin.firestore();                     // rule 1: no direct Firestore in a handler
  const orders = await db.collection('orders').get();
  await fetch(URL, { headers: { Authorization: '<REDACTED — never commit>' } }); // rule 7
  res.send('ok');
});
```

## Red flags

- Business logic or a direct `admin.firestore()` / Firestore query inside `index.ts` or a
  trigger/HTTPS handler instead of a container-resolved interactor.
- A repository or interactor built with `new` in application code rather than resolved from the
  Awilix container.
- An auth marker (`@admin`/`@internal`/`@apiKey`) on a handler with no matching runtime check —
  the marker is decorative and the endpoint is effectively open.
- An `@internal`/Task endpoint exposed as an unauthenticated `onRequest`.
- A hardcoded secret in `server.ts`, a handler, or the container (highest severity).
- `throw new Error(...)` at the boundary instead of a `CustomError` via `ApplicationErrorFactory`.
- A Firestore trigger that appends/derives state with no idempotency guard on redelivery.

## Remediation backlog

Repo-wide migrations tracked as remediation (surface once at repo level; do **not** flag on
every unrelated diff):

- **TSLint → ESLint.** TSLint is deprecated; migrate to the shared `@supy` ESLint config.
- **Add a test harness.** `firebase-functions-test` is in devDeps but unused; add Jest +
  `firebase-functions-test` and cover interactors.
- **Add CI.** `.github/` is absent; add a workflow running lint + build + test on PRs.
- **Add pre-commit.** No Husky/commitlint; add a blocking secret-scan hook (`secrets-and-config.md`
  rule 5) and Conventional-Commits linting.
- **Move secrets to Secret Manager.** Migrate the hardcoded credentials in `server.ts`/container
  to Firebase Secret Manager and rotate anything ever committed (`secrets-and-config.md` rule 7).
- **Add `.env.example`** listing required keys with placeholder-only values.

## Source

- `supy-firebase-functions/functions/src/lib/{app,data,frameworks}/` — Clean Architecture spine
  (Interactor → Repository → DataSource); Awilix container + scope-per-request env injection.
- `supy-firebase-functions/functions/src/index.ts` — per-trigger exports (Firestore
  onWrite/onCreate/onUpdate, HTTPS onCall/onRequest, Cloud Tasks) + input-mapping plugin.
- `supy-firebase-functions/functions/src/.../server.ts` — per-domain app classes (AuthServer,
  OrdersServer…); **hardcoded credentials recorded by path, values never reproduced.**
- `supy-firebase-functions` tooling: TSLint (deprecated), Prettier (120, single-quote), no
  tests, no CI, no pre-commit, `firebase deploy --only functions` (predeploy lint+build).
- Semantic auth decorators (`@unauthenticated`/`@internal`/`@admin`/`@apiKey`) — currently not
  runtime-enforced; rule 4 requires enforcement on new handlers.
- Organization security rule — secrets must never be exposed; cite path:line only.
