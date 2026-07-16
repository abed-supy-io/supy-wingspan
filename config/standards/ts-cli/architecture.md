---
source: supy-cli (src/{domain,application,infrastructure,presentation}, scripts/copy-shebang.js, .env.{development,production})
mined_on: 2026-07-16
confidence: medium
---

# TypeScript CLI (commander.js) — architecture & operational safety

Supy's `supy-cli` is a **standalone** (non-Nx) command-line tool: a MongoDB scripts runner that
performs bulk operations across Supy databases (catalog, inventory, core, orders, settlements,
audit) — replacements, syncs, exports. It follows the same Clean Architecture spine as the rest of
Supy (`domain → application → infrastructure → presentation`) but is built on **commander.js**
rather than NestJS, talks to Mongo through **Mongoose** directly (not the shared DB lib), and ships
as an **npm bin** (shebang injected by `scripts/copy-shebang.js`).

Because a single command can mutate a **production** database in bulk, this standard treats
**operational safety** as a first-class concern alongside architecture: environment layering,
explicit production confirmation, and never leaking credentials through argv or logs.

This standard, like the Firebase Functions one, separates two concerns:

- **`## Rules`** — the target-state conventions a reviewer enforces on **new or changed** code in a
  diff (layering, `IScript`/`ScriptDetails` contract, env config, prod confirmation, no secrets in
  argv/logs, exit codes, testable use cases). These produce per-diff findings.
- **`## Remediation backlog`** — repo-wide gaps (no tests, no CI, no pre-commit, ESLint 8→9). These
  are **not** per-diff blockers unless the diff itself adds the defect; they are tracked as
  remediation, not flagged on every unrelated change.

> **Never reproduce a secret value.** Connection strings and DB credentials come from env
> (`MONGO_DB_USER`/`MONGO_DB_PASS`, `DEV_*`/`PROD_*` URIs). When reviewing or remediating, cite the
> **file path and line only** — never echo a URI, user, or password into a finding, commit, or
> external tool (organization rule; see `secrets-and-config.md`).

## Rules

1. **Layer direction is inward** (`presentation → application → infrastructure`, `domain` at the
   core). `domain/` holds interfaces + entities and depends on nothing; `application/` holds use
   cases + script implementations; `infrastructure/` holds config, DB clients, logging, and UI;
   `presentation/` holds the commander commands. A command must not open a Mongoose connection or
   run a query inline — it resolves/constructs a use case (script) and delegates. Flag DB access or
   business logic in a command action callback. Respect the path aliases (`@domain`, `@application`,
   `@infrastructure`) rather than deep relative imports across layers.
2. **Every script implements `IScript` and exposes `ScriptDetails`.** A script is a class/object
   with an async `execute(context)` and a `ScriptDetails` metadata block (overview, inputs, databases
   touched, ordered steps, warnings) that powers `supy-cli scripts info <name>` / `--info`. A new
   script without complete `ScriptDetails` is a finding — the metadata is the operator's only preview
   of what the script will do before it runs against a live database.
3. **Commands are thin; commander wiring stays declarative.** The `scripts [run|list|info]` command
   surface parses and validates arguments, resolves the named script, and delegates to its
   `execute`. No domain logic, no DB calls, no `console.log`-driven control flow in the action
   callback. New behavior is added as a script (application layer), not by fattening a command.
4. **Config comes from layered env, never literals.** Connection details are read from `.env` +
   `.env.{development,production}` through the infrastructure config module — never a hardcoded URI,
   user, or password in a script, command, or config default. `DEV_*` / `PROD_*` URI pairs and
   `MONGO_DB_USER` / `MONGO_DB_PASS` are resolved by environment. A committed credential is a
   **high-severity, merge-blocking** finding (pairs with `secrets-and-config.md#rules` rule 1). Cite
   path:line, never the value.
5. **Production mutations MUST gate behind an explicit confirmation.** Any script that writes to,
   deletes from, or otherwise mutates a **production** database must require an explicit interactive
   confirmation (inquirer prompt naming the target DB and the effect) before it proceeds, and must
   surface a chalk-highlighted production warning. A destructive production path that runs without
   confirmation — or that a `--yes`/non-interactive flag can bypass silently — is a **high-severity**
   operational-safety gap. In a non-interactive/CI context the script must **refuse** a production
   mutation rather than assume yes.
6. **Secrets never travel through argv or logs.** A credential, token, or connection string must not
   be accepted as a CLI argument (it leaks into shell history and `ps` output), echoed to stdout/
   logs, or written to an error message. Credentials come from env only; log the **database name and
   operation**, never the URI or password. A secret in argv or a log line is **high severity**. Cite
   path:line, never the value.
7. **Deterministic exit codes and surfaced errors.** The CLI entrypoint wraps execution in
   try/catch: a script that fails exits **non-zero** (`process.exitCode = 1` / `process.exit(1)`) with
   a clear chalk error message; success exits 0. An error must never be swallowed so the process
   exits 0 on failure — a CI step or chained shell command depends on the exit code. Per-script input
   validation runs before any DB work.
8. **Use cases are unit-testable, decoupled from commander and the live DB.** Business logic lives in
   the application-layer script/use case and takes its DB client/repository via the passed `context`
   (or constructor), so it can be tested with a fake — not by reaching for a module-global Mongoose
   connection. Keep command callbacks thin so the logic they trigger is reachable in a unit test
   without spawning the CLI. (The repo has **no tests today** — see the backlog; new scripts should
   be written test-ready even before the harness lands.)
9. **Bulk operations batch; connections pool per database.** A script that reads or writes many
   documents processes them in bounded batches (`batchArray` / cursor + chunk) rather than loading or
   writing an entire collection at once, and reuses the pooled Mongoose connection for the target DB
   rather than opening a connection per document. Flag an unbounded `find()` → in-memory map over a
   full collection, or a connection opened inside a per-item loop.

## Examples

### Good — a script with ScriptDetails, prod confirmation, env config, batching

```typescript
// application/scripts/replace-catalog-skus.script.ts
export class ReplaceCatalogSkusScript implements IScript {
  readonly details: ScriptDetails = {                    // rule 2: self-documenting metadata
    name: 'replace-catalog-skus',
    overview: 'Replaces deprecated SKU codes across the catalog DB.',
    inputs: [{ name: 'mappingFile', description: 'path to old→new SKU CSV' }],
    databases: ['catalog'],
    steps: ['load mapping', 'batch-update products', 'verify counts'],
    warnings: ['Rewrites product.sku in place — run on staging first.'],
  };

  async execute(ctx: ScriptContext): Promise<void> {
    if (ctx.env === 'production') {
      await ctx.confirmProduction('catalog', 'replace SKU codes in place'); // rule 5
    }
    const repo = ctx.repo('catalog');                    // rule 1/8: injected, not module-global
    for (const chunk of batchArray(await repo.listSkus(), 500)) {           // rule 9: bounded batches
      await repo.bulkReplace(chunk);
    }
  }
}
```

### Bad — inline DB in the command, no ScriptDetails, prod without confirmation, secret in argv

```typescript
// WRONG: presentation layer talks to Mongo directly; no metadata; no prod guard; URI from argv
program
  .command('replace-skus')
  .argument('<mongoUri>')                                // rule 6: secret/URI through argv
  .action(async (mongoUri) => {
    const conn = await mongoose.connect(mongoUri);       // rule 1: DB access inline in a command
    const all = await conn.model('Product').find();      // rule 9: unbounded full-collection load
    for (const p of all) { /* rewrite in place, prod or not */ } // rule 5: no confirmation
    // rule 7: throws bubble up with no exit-code contract
  });
```

## Red flags

- A `mongoose.connect(...)` / query inside a commander action callback instead of a resolved
  application-layer script.
- A new script with no `ScriptDetails` (or a stub one) — nothing shows under `scripts info`.
- A hardcoded connection string, DB user, or password anywhere in source (highest severity).
- A credential or URI accepted as a CLI argument, or a connection string / password written to a log.
- A production write/delete path with no interactive confirmation, or one a flag can silently bypass;
  a script that proceeds against production in a non-interactive/CI context.
- A failure path that lets the process exit 0 (swallowed error, missing non-zero exit code).
- An unbounded `find()` mapped in memory over a full collection, or a connection opened per item.
- Business logic reachable only by spawning the CLI (untestable), or deep cross-layer relative
  imports that bypass the `@domain`/`@application`/`@infrastructure` aliases.

## Remediation backlog

Repo-wide gaps tracked as remediation (surface once at repo level; do **not** flag on every
unrelated diff):

- **Add a test harness.** No tests today; add Jest and cover the application-layer scripts with a
  fake DB context (rule 8 makes this reachable).
- **Add CI.** No workflow; add one running lint → typecheck → test → build on PRs.
- **Add pre-commit.** No Husky/commitlint; add a blocking gitleaks secret scan
  (`secrets-and-config.md` rule 5), lint-staged, and Conventional-Commits linting.
- **Align ESLint.** Migrate ESLint 8.56 (`.eslintrc`) → flat ESLint 9 (`eslint.config.mjs`) with the
  shared `@supy` config; keep Prettier (100 cols).
- **Add `.env.example`** listing required keys (`MONGO_DB_USER`, `MONGO_DB_PASS`, `DEV_*`/`PROD_*`
  URIs) with placeholder-only values.

## Source

- `supy-cli/src/domain/` — `IScript`, `ScriptDetails`, entities (interfaces at the core, no deps).
- `supy-cli/src/application/` — use cases + 50+ script implementations (`execute(context)`).
- `supy-cli/src/infrastructure/` — env config (`.env` + `.env.{development,production}`), Mongoose
  connection pooling per DB, logging, chalk + inquirer UX (production warnings/prompts).
- `supy-cli/src/presentation/` — commander commands (`scripts [run|list|info]`); try/catch at entry.
- `supy-cli/scripts/copy-shebang.js` — npm bin distribution (shebang injection).
- `supy-cli` tooling: ESLint 8.56 (`@typescript-eslint`), Prettier 3.1 (100 cols), **no tests, no CI,
  no pre-commit**, conventional commits not enforced.
- Credentials via env (`MONGO_DB_USER`/`MONGO_DB_PASS`, `DEV_*`/`PROD_*` URIs); `.env` layering;
  **production requires an explicit confirmation prompt**; no secrets in VCS.
- Organization security rule — secrets must never be exposed; cite path:line only.
