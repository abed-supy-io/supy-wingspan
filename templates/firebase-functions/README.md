# firebase-functions template — governance & remediation drop-in

Drop-in scaffolding for the Supy `supy-firebase-functions` repo (a standalone, non-Nx
Node/TypeScript serverless backend). This repo is the **least-governed TypeScript repo** at Supy:
TSLint instead of ESLint, no tests, no CI, no pre-commit, unenforced auth markers, and hardcoded
credentials in source. These files close those gaps. Enforces
`config/standards/firebase-functions/architecture.md` and `config/standards/secrets-and-config.md`.

> **Never commit a secret value.** These files show *structure* only. Real secrets live in
> Firebase Secret Manager / injected env — never in `server.ts`, a handler, or the DI container.
> If a secret was ever committed, removing the line is not enough — rotate it and purge history
> (`secrets-and-config.md#rules` rule 7).

## What to copy

The repo keeps its Functions package under `functions/`. Paths below are relative to the repo
root unless noted.

- **`.husky/pre-commit`** → repo root. `npx husky init` once. Runs a **blocking** gitleaks secret
  scan (`secrets-and-config.md#rules` rule 5), `lint-staged`, and commit-message linting. A
  warn-only scanner is non-compliant.
- **`.github/workflows/ci.yml`** → repo root. Runs lint → typecheck → test → build on PRs. This is
  the CI the repo currently lacks (remediation backlog).
- **`functions/eslint.config.mjs`** → replaces the deprecated `tslint.json`. Flat ESLint config
  with `@typescript-eslint`. Delete `tslint.json` and the `tslint` devDependency after migrating.
- **`functions/src/lib/frameworks/auth/require-auth.ts`** → the runtime guards that make the
  `@unauthenticated` / `@internal` / `@admin` / `@apiKey` markers actually enforce
  (`architecture.md#rules` rule 4). The markers are currently semantic-only.
- **`package.scripts.json`** → merge into `functions/package.json` (scripts + devDependencies for
  ESLint, Jest, `firebase-functions-test`, Husky, commitlint, gitleaks).
- **`CLAUDE.md.hbs`** → rendered to the repo root `CLAUDE.md` by the `supy-baseline` skill.

## Remediation order (highest value first)

1. **Secrets** — move every hardcoded credential (`server.ts`, DI container) to Secret Manager,
   rotate what was exposed, add `.env.example` with placeholders. Install the gitleaks pre-commit
   hook so it cannot regress.
2. **Auth enforcement** — wire `require-auth.ts` into every handler carrying an auth marker; an
   `@admin` handler that never checks the admin claim is an open endpoint.
3. **Lint** — migrate TSLint → ESLint (`eslint.config.mjs`), fix the fallout, delete `tslint.json`.
4. **Tests + CI** — add Jest + `firebase-functions-test`, cover interactors, turn on `ci.yml`.

## Not included

No Firestore-trigger scaffold generator — triggers are few and domain-specific; hand-author them
following `architecture.md` (one export per trigger, delegate to a container-resolved interactor,
idempotent writes).
