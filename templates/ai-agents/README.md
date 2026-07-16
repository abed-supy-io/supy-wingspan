# ai-agents template — governance & remediation drop-in

Drop-in scaffolding for the Supy `supy-ai-agents` monorepo — a **polyglot** AI-agents repo (Node.js +
Python + Cloudflare Workers) with **no root workspace orchestration** and per-team package ownership
(Cortex, Nexus, Oculus, Gleap, PMS-AI). Lint/format, tests, CI, and pre-commit are uneven across
packages today; a blocking secret scan exists only as a native git hook scoped to `deploy/`. These
files converge each package on a common baseline and lock in the load-bearing guarantees an
agent/MCP service needs. Enforces `config/standards/ai-agents/architecture.md` and
`config/standards/secrets-and-config.md`.

> **Never commit a secret value.** These files show *structure* only. Real API keys, OAuth client
> secrets, and connection strings live in env / a secret store (`.env` for Node, `wrangler secret`
> for Workers, injected env in deploy) — never in source, never on `argv`, never in a log. If a
> secret was ever committed, removing the line is not enough — rotate it and purge history
> (`secrets-and-config.md#rules` rule 7).

## What to copy

There is **no root package** — copy per package, into the package root of whichever service you are
bringing up to baseline. Adapt each file to whether that package is Node/TS, Python, or a Worker.

- **`.env.example`** → package root (Node/Python). Superset of the keys used across the repo
  (KG/Postgres URL, Redis URL, model keys, OAuth client id/secret, JWT secret, integration keys) with
  **placeholder-only** values. Keep only the keys the package actually reads; copy to `.env` and fill
  locally; never commit the filled file. Workers use `wrangler secret put <NAME>` instead.
- **`eslint.config.mjs`** → Node/TS package root. Flat ESLint 9 with `@typescript-eslint` and the
  correctness rules an MCP/queue service relies on (no floating promises, no swallowed async).
- **`.husky/pre-commit`** → Node package root. `npx husky init` once, then replace the generated hook.
  Runs a **blocking** gitleaks secret scan (`secrets-and-config.md#rules` rule 5) then `lint-staged`.
  A warn-only scanner is non-compliant. This makes the secret scan uniform, not `deploy/`-only.
- **`.github/workflows/ci.yml`** → repo (or package). A per-package CI **shape** with three jobs —
  `node` (lint → typecheck → test → build), `python` (ruff → mypy → pytest), and a repo-wide
  `secret-scan`. Point the `working-directory` at the package, or convert to a matrix over packages.
- **`Dockerfile`** → package root (services that ship a container). Multi-stage, runtime stage drops
  to a **non-root** UID (architecture.md rule 6).
- **`package.scripts.json`** → merge into the Node package's `package.json` (scripts + lint-staged
  routing for `.ts`/`.js`/`.py` + devDependencies for flat ESLint 9, Husky, commitlint, lint-staged).
- **`CLAUDE.md.hbs`** → rendered to the repo-root `CLAUDE.md` by the `supy-baseline` skill.

## Remediation order (highest value first)

1. **Secrets / env + auth** — confirm every credential comes from env / a secret store; add
   `.env.example` placeholders; install the gitleaks pre-commit so it cannot regress; confirm every
   exposed MCP tool / route on a mutating or data-returning path is auth-guarded.
2. **Lint / format** — add ESLint (Node/TS) + Ruff (Python) consistently per package; fix fallout.
3. **Tests + CI** — add coverage starting with MCP tool contracts and queue-consumer idempotency;
   turn on `ci.yml` per package.
4. **Pre-commit** — wire Husky + commitlint so Conventional Commits and the secret scan are enforced
   locally across every package.

## Not included

No MCP-tool or queue-consumer generator — tools and consumers are numerous and domain-specific;
hand-author each one following `architecture.md` (validate input, auth-guard mutating/data-returning
paths, read config from the singleton, use the shared Redis/BullMQ helper, upsert idempotently, never
log payloads or secrets). No Python `pyproject.toml` / Poetry config — keep the package's existing
Poetry setup and add Ruff/mypy/pytest to it.
