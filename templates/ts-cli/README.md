# ts-cli template — governance & remediation drop-in

Drop-in scaffolding for the Supy `supy-cli` repo (a standalone, non-Nx commander.js MongoDB scripts
runner, shipped as an npm bin). The repo has **no tests, no CI, and no pre-commit** today, and runs
on ESLint 8. These files close those gaps and lock in the operational-safety guarantees a
production-mutating CLI needs. Enforces `config/standards/ts-cli/architecture.md` and
`config/standards/secrets-and-config.md`.

> **Never commit a secret value.** These files show *structure* only. Real connection strings and
> credentials live in layered env (`.env` + `.env.{development,production}`) — never in source, never
> as a CLI argument, never in a log. If a secret was ever committed, removing the line is not enough —
> rotate it and purge history (`secrets-and-config.md#rules` rule 7).

## What to copy

The repo is a single package at the root (no `functions/` subdir). Paths below are relative to the
repo root.

- **`.env.example`** → repo root. Required keys with placeholder-only values (`MONGO_DB_USER`,
  `MONGO_DB_PASS`, `DEV_*`/`PROD_*` URIs). Copy to `.env` / `.env.{development,production}` and fill
  locally; never commit the filled files.
- **`eslint.config.mjs`** → repo root. Flat ESLint 9 config with `@typescript-eslint`, matching the
  existing Prettier conventions (100 cols, single quotes). Delete `.eslintrc(.js|.json)` and bump the
  `eslint` devDependency to `^9` after migrating.
- **`.husky/pre-commit`** → repo root. `npx husky init` once, then replace the generated hook. Runs a
  **blocking** gitleaks secret scan (`secrets-and-config.md#rules` rule 5), `lint-staged`, and a
  typecheck. A warn-only scanner is non-compliant.
- **`.github/workflows/ci.yml`** → repo root. Runs lint → typecheck → test → build on PRs, plus a
  repo-wide gitleaks scan. This is the CI the repo currently lacks.
- **`package.scripts.json`** → merge into the repo-root `package.json` (scripts + devDependencies for
  flat ESLint 9, Jest, Husky, commitlint, lint-staged). Keeps the npm-bin build
  (`scripts/copy-shebang.js`) and Prettier (100 cols).
- **`CLAUDE.md.hbs`** → rendered to the repo root `CLAUDE.md` by the `supy-baseline` skill.

## Remediation order (highest value first)

1. **Secrets / env** — confirm every connection string and credential comes from layered env; add
   `.env.example` with placeholders; install the gitleaks pre-commit hook so it cannot regress. Audit
   for any URI/credential passed as a CLI argument or written to a log.
2. **Lint** — migrate ESLint 8 (`.eslintrc`) → flat ESLint 9 (`eslint.config.mjs`), fix the fallout,
   delete the old config.
3. **Tests + CI** — add Jest, cover the application-layer scripts with a fake DB context, turn on
   `ci.yml`.
4. **Pre-commit** — wire Husky + commitlint so Conventional Commits and the secret scan are enforced
   locally.

## Not included

No script generator — scripts are numerous and domain-specific; hand-author each one following
`architecture.md` (implement `IScript` with a complete `ScriptDetails` block, delegate from a thin
command, gate production mutations behind an explicit confirmation, batch bulk writes).
