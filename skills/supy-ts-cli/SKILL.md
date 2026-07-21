---
name: supy-ts-cli
description: '[ts-cli] How to write CLI code in the standalone supy-cli repo the Supy way — Clean Architecture (presentation commands → application scripts → infrastructure → domain), commander.js `scripts [run|list|info]`, the IScript/ScriptDetails self-documenting contract, env-layered config, explicit production confirmation before any prod mutation, no secrets in argv/logs, deterministic exit codes, testable use cases, and batched bulk MongoDB operations. Use whenever writing or editing code in the supy-cli repo, or adding a script.'
---

## When this applies

Any time you write or edit code in the standalone `supy-cli` repo (non-Nx Node/TypeScript,
commander.js, direct Mongoose to Supy MongoDB databases) — adding a script, touching a command,
wiring config or a DB connection, or remediating the repo toward Supy baseline. This skill is the
how-to; the enforced rulebook is the governing standard.

A single command here can mutate a **production** database in bulk, so operational safety —
environment layering, explicit production confirmation, and never leaking credentials through argv
or logs — matters as much as architecture. This repo also has **no tests, no CI, and no pre-commit**
today; treat the standard's `## Remediation backlog` as a live map of what still needs closing, but
do not raise backlog items against an unrelated diff.

## Step 0 — Read the governing standard

Ground every decision in the standards files. Read them before writing code:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/ts-cli/architecture.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/secrets-and-config.md"
```

If either is unreadable, print a warning and continue using the rules below as a fallback — never
hard-fail. When the Cortex MCP is connected, prefer it (`get_repo_guide('supy-cli')`,
`trace_implementation`, `search_entities`) as the live source over static docs.

## The rules that govern everything

1. **Dependencies flow inward only:** `presentation → application → infrastructure`, with `domain`
   (interfaces + entities) at the core depending on nothing. A commander command **wires** — it
   parses args, resolves a script, and delegates. **No** `mongoose.connect(...)`, query, or business
   logic in a command action callback. Use the `@domain` / `@application` / `@infrastructure` path
   aliases, not deep relative imports across layers.
2. **Every script is an `IScript` with `ScriptDetails`.** A script implements async
   `execute(context)` and carries a complete `ScriptDetails` block (overview, inputs, databases
   touched, ordered steps, warnings). That metadata is the operator's only preview of what a script
   will do before it runs against a live DB — a stub or missing block is a defect, not a nicety.
3. **Production mutations gate behind an explicit confirmation.** Never let a script write to,
   delete from, or mutate a production database without an interactive confirmation that names the
   target DB and the effect. A `--yes`/non-interactive flag must not silently bypass it; in a
   non-interactive/CI context the script **refuses** rather than assuming yes.
4. **Secrets never live in source, argv, or logs.** Connection strings and DB credentials come from
   layered env (`.env` + `.env.{development,production}`, `MONGO_DB_USER`/`MONGO_DB_PASS`,
   `DEV_*`/`PROD_*` URIs). Never hardcode a URI, accept one as a CLI argument (it leaks into shell
   history / `ps`), or log a connection string. If a secret was ever committed, removing the line is
   not enough: rotate it and purge history.

## Commands (presentation/) — wire, don't compute

The `scripts [run|list|info]` surface stays thin: parse/validate args, resolve the named script,
delegate. New behavior is a new **script**, not a fatter command.

```ts
// presentation/commands/scripts.command.ts — GOOD
program
  .command('scripts')
  .command('run <name>')
  .action(async (name, opts) => {
    const script = registry.resolve(name);              // resolve, don't inline
    const ctx = await buildContext(opts.env);           // infrastructure builds env + DB context
    await runner.run(script, ctx);                      // delegate; runner owns try/catch + exit code
  });
```

```ts
// presentation/commands/replace-skus.command.ts — BAD (four violations)
program
  .command('replace-skus')
  .argument('<mongoUri>')                               // ✗ URI/secret through argv (rule 4)
  .action(async (mongoUri) => {
    const conn = await mongoose.connect(mongoUri);      // ✗ DB access inline in a command (rule 1)
    const all = await conn.model('Product').find();     // ✗ unbounded full-collection load
    for (const p of all) { /* rewrite in place, prod or not */ } // ✗ no prod confirmation (rule 3)
  });
```

## Scripts (application/) — IScript + ScriptDetails

```ts
// application/scripts/replace-catalog-skus.script.ts
export class ReplaceCatalogSkusScript implements IScript {
  readonly details: ScriptDetails = {                    // rule 2: powers `scripts info`
    name: 'replace-catalog-skus',
    overview: 'Replaces deprecated SKU codes across the catalog DB.',
    inputs: [{ name: 'mappingFile', description: 'path to old→new SKU CSV' }],
    databases: ['catalog'],
    steps: ['load mapping', 'batch-update products', 'verify counts'],
    warnings: ['Rewrites product.sku in place — run on staging first.'],
  };

  async execute(ctx: ScriptContext): Promise<void> {
    if (ctx.env === 'production') {
      await ctx.confirmProduction('catalog', 'replace SKU codes in place'); // rule 3
    }
    const repo = ctx.repo('catalog');                    // injected via context, testable (rule 8)
    for (const chunk of batchArray(await repo.listSkus(), 500)) {           // bounded batches (rule 9)
      await repo.bulkReplace(chunk);
    }
  }
}
```

## Config (infrastructure/) — layered env, never literals

Resolve connection details from the env layers through the config module. The environment name — not
a URI — flows through the CLI; the config module maps `development`/`production` to the right
`DEV_*`/`PROD_*` credentials read from `process.env`.

```ts
// infrastructure/config/db.config.ts — resolve by environment, never a literal
const uri = env === 'production' ? process.env.PROD_CATALOG_URI : process.env.DEV_CATALOG_URI;
// user/pass come from MONGO_DB_USER / MONGO_DB_PASS — never inline, never logged
```

## Exit codes & error surfacing

The entrypoint (or the runner it delegates to) wraps execution in try/catch: on failure, print a
chalk error and exit non-zero; on success, exit 0. Never swallow an error so the process exits 0 —
a CI step or chained shell command reads the exit code.

```ts
try {
  await runner.run(script, ctx);
} catch (err) {
  logger.error(chalk.red(err instanceof Error ? err.message : String(err)));
  process.exitCode = 1;                                  // rule 7: non-zero on failure
}
```

## Bulk operations & connections

Process many documents in bounded batches (`batchArray` / a cursor + chunk), not an unbounded
`find()` mapped in memory over a full collection. Reuse the pooled Mongoose connection for the target
DB — never open a connection inside a per-item loop.

## Before you finish

- Commands only parse/validate/resolve/delegate — no Mongoose or business logic inline?
- Every new/changed script implements `IScript` with a complete `ScriptDetails` block?
- Every production mutation gates behind an explicit confirmation and refuses in non-interactive/CI?
- No hardcoded URI/user/password; nothing secret in argv or logs — all from layered env?
- Failure exits non-zero with a surfaced message; success exits 0?
- Bulk work is batched; the pooled connection per DB is reused (no connection per item)?
- New/changed logic is reachable in a unit test with a fake DB context (no module-global connection)?

Run the verification suite (npm-based — this repo is **not** Nx):

```bash
npm run lint        # ESLint 8.56 today — flat ESLint 9 is the migration target
npm run typecheck
npm test            # none yet — add Jest (remediation backlog)
npm run build
```

## Remediation & templates

If the repo is missing the governance assets, copy them from the plugin template as part of
remediation (order: secrets/env → lint alignment → tests + CI → pre-commit):

```bash
ls "${CLAUDE_PLUGIN_ROOT}/templates/ts-cli"
```

- `.env.example` → repo root — required keys with placeholder-only values (`MONGO_DB_USER`,
  `MONGO_DB_PASS`, `DEV_*`/`PROD_*` URIs).
- `eslint.config.mjs` → repo root — flat ESLint 9 migration target (from ESLint 8 `.eslintrc`).
- `.github/workflows/ci.yml` → repo root — the CI the repo lacks (lint → typecheck → test → build).
- `.husky/pre-commit` + `package.scripts.json` — gitleaks secret block, lint-staged, commitlint.
- `CLAUDE.md.hbs` — rendered to the repo root `CLAUDE.md` by the **supy-baseline** skill.

Read `${CLAUDE_PLUGIN_ROOT}/templates/ts-cli/README.md` for the full drop-in guide.

To review a supy-cli diff against these rules, use the **supy-ts-cli-reviewer** agent.

## Degradation paths

**Standards files unreadable:** Warn and continue using the inline rule summaries above.

**Cortex MCP unavailable:** Silently degrade. Context fallback order: Cortex MCP
(`get_repo_guide('supy-cli')`, `trace_implementation`, `search_entities`) → repo `CLAUDE.md` → the
two standards files. Each tier is optional; move to the next if unavailable. Never hard-fail because
Cortex is absent.

**Template dir absent:** Note it and hand-author following `architecture.md`; do not block.
