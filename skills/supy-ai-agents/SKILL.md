---
name: supy-ai-agents
description: Write and change code in the polyglot supy-ai-agents monorepo (Cortex/Nexus/Oculus/Gleap/PMS-AI — Node.js + Python + Cloudflare Workers, MCP tools, BullMQ, pgvector KG) so it follows the Supy ai-agents architecture & operational standard. Use when adding an MCP tool, HTTP route, or queue consumer; touching config/secrets; wiring Redis/BullMQ; or writing a Dockerfile in an ai-agents repo. Enforces secret hygiene, auth on exposed tools, env-driven config, validation + error handling, idempotent consumers, and non-root containers.
---

## When this applies

Use this skill when you are working inside `supy-ai-agents` (or a package of
it — Cortex, Nexus, Oculus, Gleap, PMS-AI) and you are: adding or changing an
**MCP tool/resource**, an **HTTP route**, or a **BullMQ queue consumer**;
touching **config or secrets**; wiring **Redis/BullMQ**; or writing/editing a
**Dockerfile**. It is polyglot — the same rules apply whether the file is
Node/TypeScript, a Cloudflare Worker, or Python.

## Step 0 — Read the governing standard

Do not work from memory. Read the standard (and the shared secrets rules)
first:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/ai-agents/architecture.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/secrets-and-config.md"
```

If Cortex MCP is available, also ground yourself in the live repo
(`get_repo_guide('supy-ai-agents')`, `get_coding_rules`,
`trace_implementation`) to find the actual config singleton, auth scheme, and
Redis cluster helper for the package you are editing. If Cortex is
unavailable, fall back to the repo's `CLAUDE.md` / per-package `CLAUDE.md`,
then the standard. Never hard-fail because Cortex is absent.

## The rules that govern everything

1. Secrets from env / secret store — never literals, `argv`, or logs. New
   keys → `.env.example` / `wrangler secret` **placeholders only**. A
   committed real secret is merge-blocking.
2. Every exposed MCP tool/resource or route on a mutating/data-returning path
   is behind auth (OAuth 2.1 / JWT / Bearer). Read tokens never reach write
   tools.
3. Config through the env-driven config singleton, not scattered
   `process.env` / `os.environ`.
4. Every external entrypoint validates input + `try`/`catch` with the custom
   logger + keeps rate-limit guards. No swallowed errors.
5. Redis/BullMQ via the shared cluster config with fallback, not ad-hoc
   connection literals.
6. Containers run as a non-root user.
7. Conventional Commits (`feat`/`fix`/`docs`/`chore`/`refactor`); manual
   semver.
8. Each package is self-contained — no `../../<sibling-package>/`
   reach-through imports.
9. Queue consumers are idempotent (deterministic upsert keys) and never log
   secret-bearing payloads or cloned-repo content.

## Writing an MCP tool or HTTP route

**GOOD** — auth-guarded, config from the singleton, validated, logged, no
secret leak:

```ts
import { config } from '../config';            // rule 3
import { requireScope } from '../auth';         // rule 2

server.tool('inject_entity', injectSchema, requireScope('kg:write'), async (input) => {
  try {                                          // rule 4
    await upsertEntity(config.pgUrl, input.key, input.body); // rule 9: upsert on stable key
    return { ok: true };
  } catch (err) {
    logger.error('inject_entity failed', { key: input.key, err: err.message }); // rule 9: no body/secret
    throw err;                                   // rule 4: never swallow
  }
});
```

**BAD**:

```ts
const pg = new Client('postgres://kg_user:S3cr3t@10.0.0.4:5432/kg'); // ✗ rule 1: committed credential
server.tool('inject_entity', async (input) => {  // ✗ rule 2: no auth guard
  try {
    await pg.query('INSERT INTO entity ...', [input.key]); // ✗ rule 9: blind insert
  } catch {}                                      // ✗ rule 4: swallowed error
});
```

## Wiring Redis / BullMQ

**GOOD** — shared cluster helper:

```ts
import { getRedis } from '../redis';  // rule 5: cluster config + fallback
const connection = getRedis();
const queue = new Queue('extract', { connection });
```

**BAD**:

```ts
const connection = new Redis({ host: '10.0.0.9', port: 6379 }); // ✗ rule 5: ad-hoc literal
```

## Config and secrets

**GOOD** — read through the config module; new keys documented as
placeholders only:

```ts
// config.ts centralises env access (rule 3)
export const config = {
  pgUrl: requireEnv('KG_DATABASE_URL'),
  openRouterKey: requireEnv('OPENROUTER_KEY'),
};
```

```dotenv
# .env.example — PLACEHOLDER VALUES ONLY, never a real secret (rule 1)
KG_DATABASE_URL=postgres://user:password@localhost:5432/kg
OPENROUTER_KEY=
```

**BAD**: reading `process.env.OPENROUTER_KEY` directly in a handler (✗ rule
3), or committing the real key to `.env` (✗ rule 1).

## Containers

**GOOD** — runtime drops to a non-root UID (rule 6):

```dockerfile
FROM node:20-slim
WORKDIR /app
COPY --chown=node:node . .
RUN groupadd -g 1001 app && useradd -u 1001 -g app app
USER app
CMD ["node", "server.js"]
```

**BAD**: a final stage with no `USER` directive (✗ rule 6, runs as root).

## Before you finish

Checklist for the diff you are about to commit:

- [ ] No credential/token/API-key/OAuth-secret/connection-string literal in
      any changed source or committed `.env` — cite `path:line`, never the
      value (rule 1).
- [ ] Every new/changed mutating or data-returning MCP tool/route has an auth
      guard/scope check (rule 2).
- [ ] Config read through the config singleton, not raw `process.env` /
      `os.environ` (rule 3).
- [ ] Every external entrypoint validates input, `try`/`catch` + logger, keeps
      rate-limit guards; no `catch {}` / `except: pass` (rule 4).
- [ ] Redis/BullMQ via the shared cluster helper (rule 5).
- [ ] Any new/edited Dockerfile drops to a non-root UID (rule 6).
- [ ] No `../../<sibling-package>/` reach-through imports (rule 8).
- [ ] Queue consumers upsert on a deterministic key and never log payloads /
      cloned-repo content (rule 9).

Run the verification the affected package supports (they differ — this is a
remediation-backlog item, so run what exists, don't assume a uniform suite):

```bash
# Node/TS package (e.g. Cortex, Oculus)
npm run lint 2>/dev/null; npm run typecheck 2>/dev/null; npm test 2>/dev/null; npm run build 2>/dev/null
# Python package (e.g. Nexus)
ruff check . 2>/dev/null; mypy . 2>/dev/null; pytest 2>/dev/null
# Cloudflare Worker (e.g. Gleap): validate the wrangler build/deploy dry-run per its README
```

## Remediation & templates

Governance drop-ins (blocking secret-scan pre-commit, polyglot CI, ESLint,
`.env.example`, non-root Dockerfile snippet, merge-in scripts):

```bash
ls "${CLAUDE_PLUGIN_ROOT}/templates/ai-agents"
```

These close the `## Remediation backlog` gaps (uneven lint/format, thin
coverage, inconsistent CI, non-uniform pre-commit). Copy per package; adapt to
whether the package is Node, Python, or a Worker. Never add a real secret to
any template.

## Degradation paths

- **Standards file unreadable:** apply the nine rules from *The rules that
  govern everything* above and note that the full standard could not be read.
- **Cortex unavailable:** fall back to repo `CLAUDE.md` / per-package
  `CLAUDE.md`, then the static standard. Do not block on Cortex.
- **Template dir absent:** proceed with the rules; note that governance
  drop-ins were not available and recommend running `supy-baseline`.
