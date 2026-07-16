---
name: supy-firebase-function
description: How to write Firebase Functions code in the standalone supy-firebase-functions repo the Supy way — Clean Architecture (index.ts → app interactors → data repositories → frameworks), Awilix DI, runtime-enforced auth markers (@unauthenticated/@internal/@admin/@apiKey), typed domain errors, idempotent Firestore triggers, and secrets from Secret Manager (never literals). Use whenever writing or editing code in the supy-firebase-functions repo, or adding a trigger.
---

## When this applies

Any time you write or edit code in the standalone `supy-firebase-functions` repo (non-Nx
Node/TypeScript on the Firebase Functions runtime, Awilix DI, Cloud Firestore) — adding a callable
or Firestore/PubSub trigger, touching a handler, wiring a repository, or remediating the repo toward
Supy baseline. This skill is the how-to; the enforced rulebook is the governing standard.

This is the **least-governed** TypeScript repo at Supy (TSLint not ESLint, no tests, no CI, no
pre-commit, auth markers unenforced, historically hardcoded credentials). Treat the standard's
`## Remediation backlog` as a live map of what still needs closing — but do not raise backlog items
against an unrelated diff.

## Step 0 — Read the governing standard

Ground every decision in the standards files. Read them before writing code:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/firebase-functions/architecture.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/secrets-and-config.md"
```

If either is unreadable, print a warning and continue using the rules below as a fallback — never
hard-fail. When the Cortex MCP is connected, prefer it (`get_repo_guide('supy-firebase-functions')`,
`trace_implementation`, `search_entities`) as the live source over static docs.

## The rules that govern everything

1. **Dependencies flow inward only:** `frameworks → app → data`-interfaces. `index.ts` wires a
   trigger to an interactor and nothing else — **no** `admin.firestore()`, query, or business logic
   in `index.ts` or a handler body. Firestore access is confined to `data/` repositories.
2. **Resolve, don't `new`.** Interactors, repositories, and data sources come from the **Awilix
   container** (cradle / `container.resolve(...)`), never `new`-ed in application code. Per-request
   and per-environment state comes from a `createScope()` scope, never mutable module globals.
3. **Auth markers must be enforced at runtime.** `@unauthenticated` / `@internal` / `@admin` /
   `@apiKey` are semantic-only until a guard runs. Every marked handler calls the matching guard
   before any logic. An `@admin` handler that never checks the admin claim is an **open endpoint**.
4. **Secrets never live in source.** No API key, token, or credential literal in `server.ts`, a
   handler, or a container registration — read from Firebase Secret Manager / injected env. If a
   secret was ever committed, removing the line is not enough: rotate it and purge history.

## Trigger exports (index.ts) — wire, don't compute

One export per trigger. It resolves an interactor from the container and delegates through the input
mapper. No logic in the export body.

```ts
// index.ts — GOOD
export const setAdminClaim = onCall(async (request) => {
  requireAdmin(request);                               // 1. enforce the @admin marker
  const interactor = container.resolve('setAdminClaimInteractor'); // 2. resolve, don't new
  return interactor.execute(mapCallableInput(request)); // 3. delegate through the mapper
});
```

```ts
// index.ts — BAD (three violations)
// @admin
export const syncOrders = onRequest(async (req, res) => {
  const db = admin.firestore();                        // ✗ Firestore inline in a handler (rule 1)
  const orders = await db.collection('orders').get();  // ✗ business logic in index.ts (rule 1)
  // ✗ marked @admin but never verifies the admin claim (rule 3) — open endpoint
  res.send('ok');
});
```

## Auth guards (frameworks/auth/require-auth.ts)

Call the guard matching the marker at the top of the handler, before any logic:

- `@admin` → `requireAdmin(request)` — checks the `admin` custom claim.
- `@unauthenticated`-excluded → `requireAuth(request)` — any authenticated caller.
- `@apiKey` → `requireApiKey(req)` — expected key from injected env, compared in constant time.
- `@internal` → `await requireInternalOidc(req, { audience })` — verifies the caller's Google OIDC
  service-account identity against an allow-list. An internal/Cloud-Tasks endpoint must verify the
  caller, not just its network origin.

If `require-auth.ts` does not yet exist in the repo, copy it from the template (see the end of this
skill) as part of the auth-enforcement remediation.

## Interactors (app/) and repositories (data/)

Interactors are framework-agnostic use cases: they take a mapped input, orchestrate domain flow, and
call **repository interfaces** — they never touch Firestore directly. Repositories in `data/` hold
all Firestore access.

```ts
// app/set-admin-claim.interactor.ts
export class SetAdminClaimInteractor {
  constructor(private readonly users: IUserRepository) {}  // interface, resolved by Awilix

  async execute(input: SetAdminClaimInput): Promise<void> {
    const user = await this.users.findById(input.uid);
    if (!user) {
      throw ApplicationErrorFactory.notFound('User', input.uid); // typed domain error
    }
    await this.users.grantAdmin(user.id);
  }
}
```

## Typed domain errors

Throw `CustomError` subclasses via `ApplicationErrorFactory` at the boundary and map them to the
correct `HttpsError` code in the framework layer. Never `throw new Error(...)` from a handler or
interactor.

## Firestore trigger idempotency

Firestore/PubSub triggers are delivered **at least once** — the same event can fire twice. A trigger
that writes derived state must reconcile against a stable key (idempotent set/merge, a processed
marker, or a version check), never blind-append.

```ts
// GOOD — idempotent merge keyed by the source document id
await db.doc(`rollups/${event.params.orderId}`).set(rollup, { merge: true });

// BAD — a redelivery double-counts
await db.collection('rollups').add(rollup);
```

## Before you finish

- `index.ts`/handlers contain no Firestore access or business logic — they resolve and delegate?
- Every dependency resolved from the Awilix container, not `new`-ed; env/request state via a scope?
- Every auth-marked handler calls its guard before logic; `@admin` verifies the admin claim?
- No secret literal anywhere — every credential from Secret Manager / injected env?
- Boundary throws are typed `CustomError`s via `ApplicationErrorFactory`, mapped to `HttpsError`?
- Firestore triggers reconcile idempotently against a stable key?
- New/changed logic has a Jest + `firebase-functions-test` spec that asserts the outcome?

Run the verification suite (npm-based — this repo is **not** Nx):

```bash
cd functions
npm run lint        # ESLint — if still TSLint, this is the migration target
npm run typecheck
npm test
npm run build
```

## Remediation & templates

If the repo is missing the enforcement assets, copy them from the plugin template as part of
remediation (order: secrets → auth enforcement → lint → tests + CI):

```bash
ls "${CLAUDE_PLUGIN_ROOT}/templates/firebase-functions"
```

- `functions/src/lib/frameworks/auth/require-auth.ts` — the runtime guards (rule 3).
- `eslint.config.mjs` → `functions/eslint.config.mjs` — TSLint→ESLint migration target.
- `.github/workflows/ci.yml` → repo root — the CI the repo lacks.
- `.husky/pre-commit` + `package.scripts.json` — gitleaks secret block, lint-staged, commitlint.
- `CLAUDE.md.hbs` — rendered to the repo root `CLAUDE.md` by the **supy-baseline** skill.

Read `${CLAUDE_PLUGIN_ROOT}/templates/firebase-functions/README.md` for the full drop-in guide.

To review a firebase-functions diff against these rules, use the **supy-firebase-functions-reviewer**
agent.

## Degradation paths

**Standards files unreadable:** Warn and continue using the inline rule summaries above.

**Cortex MCP unavailable:** Silently degrade. Context fallback order: Cortex MCP
(`get_repo_guide('supy-firebase-functions')`, `trace_implementation`, `search_entities`) → repo
`CLAUDE.md` → the two standards files. Each tier is optional; move to the next if unavailable. Never
hard-fail because Cortex is absent.

**Template dir absent:** Note it and hand-author following `architecture.md`; do not block.
