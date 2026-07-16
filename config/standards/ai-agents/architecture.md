---
source: supy-ai-agents (polyglot AI-agents monorepo — Cortex, Nexus, Oculus, Gleap, PMS-AI, +submodule)
mined_on: 2026-07-16
confidence: low
---

# Supy AI-Agents Architecture & Operational Standard

`supy-ai-agents` is a **polyglot AI-agents monorepo**: independent packages
(Node.js + Python + Cloudflare Workers) with **no root workspace
orchestration** and per-team ownership. Cortex is a Claude Agent SDK + MCP
server (19 tools over SSE/HTTP) backed by Express + BullMQ (Redis) and a
PostgreSQL + pgvector knowledge graph fed by a repo-clone → extract → inject
pipeline; Nexus is Python (Poetry + FastAPI + MCP); Oculus is a Turbo/npm
TS workspace; Gleap is a Cloudflare Pages app. Several packages expose MCP
tools or HTTP endpoints, run background jobs, and hold OAuth/JWT secrets — so
the load-bearing concerns here are **secret hygiene, auth on every exposed
tool/endpoint, input validation, idempotent job processing, and non-root
containers**, applied per-package because there is no shared root to enforce
them.

This file has two distinct parts:

- **`## Rules`** — the enforceable, per-diff checklist. A reviewer flags a
  diff only when a *changed line* violates one of these.
- **`## Remediation backlog`** — repo-wide gaps (uneven lint/format, thin
  test coverage, inconsistent CI, non-uniform pre-commit) that predate this
  standard. These are tracked for planned migration and surfaced once at the
  repo level; they are **not** per-diff blockers unless the diff itself
  introduces or worsens the defect.

> **Never reproduce a secret value.** When a finding involves a credential,
> token, API key, OAuth client secret, or connection string, cite it as
> `path:line` and describe the class of secret only. Never copy the value
> into a review comment, commit message, log line, or file. This is an
> organization security rule and overrides any instinct to be "helpful" by
> showing the offending string.

## Rules

1. **Secrets come from the environment or a secret store — never from
   literals, `argv`, or logs.** New keys are documented in `.env.example`
   (Node) / equivalent template, or declared as `wrangler secret` /
   deployment-injected env (Workers) — with **placeholder values only**. A
   real credential, token, API key, OAuth client secret, or connection
   string committed to the repo is **high severity and merge-blocking**
   (this pairs with `secrets-and-config.md#rules` rule 1). Never log a
   secret-bearing value.

2. **Every MCP tool/resource that exposes data or mutates state sits behind
   authentication** (OAuth 2.1 / JWT / Bearer, per the package's existing
   scheme, e.g. `cortex/oauth-server.js`). A read-only or engineer-scoped
   token must not reach a write/mutating tool. A new exposed tool or route
   with no auth guard on a mutating or data-returning path is a finding.

3. **Configuration is read through the package's env-driven config
   singleton, not scattered `process.env` / `os.environ` reads.** New code
   that reaches directly into the environment in handler/business logic,
   bypassing the established config module, is a finding.

4. **Every external entrypoint validates its input and handles its errors.**
   MCP tools, HTTP routes, and queue consumers must validate the payload,
   wrap work in `try`/`catch` with the package's custom logger, and respect
   the rate-limit guards already in place. A swallowed error (empty catch,
   caught-and-ignored), an unvalidated payload, or a removed rate-limit guard
   is a finding.

5. **Redis / BullMQ connections use the shared cluster config with fallback,
   not ad-hoc connection literals.** New code that constructs its own Redis
   client with inline host/port/credentials instead of the package's cluster
   config helper is a finding.

6. **Containers run as a non-root user.** A new or edited Dockerfile that
   runs as root (no `USER` directive dropping to the non-root UID, e.g.
   `1001`) for the runtime stage is a finding.

7. **Commits follow Conventional Commits** (`feat`, `fix`, `docs`, `chore`,
   `refactor`); versioning is manual semver per package. This is enforced by
   `supy-commit-pr-reviewer`; noted here so the stack's convention is
   explicit.

8. **Each package is self-contained.** With no root workspace to guard
   boundaries, a package must not reach into a sibling package via deep
   relative imports (`../../<other-package>/...`). Cross-package use goes
   through a published/packaged interface, not a reach-through path.

9. **Queue consumers are idempotent and never leak payload contents.**
   Because BullMQ jobs can redeliver, a consumer must key its writes
   deterministically (upsert on a stable key, not blind insert) so a
   redelivered job does not duplicate or corrupt state. Consumers in the
   repo-clone → extract → inject KG pipeline must never log secret-bearing
   payloads or raw cloned-repo content.

## Examples

**Good — secret from env via the config singleton, auth-guarded MCP tool
(rules 1, 2, 3):**

```ts
import { config } from '../config';           // rule 3: single env-driven source
import { requireScope } from '../auth';        // rule 2: auth guard

// rule 2: mutating tool requires a write scope; engineer read tokens can't reach it
server.tool('inject_entity', injectSchema, requireScope('kg:write'), async (input) => {
  // rule 4: payload already validated by injectSchema; wrap in try/catch + logger
  try {
    const client = getRedis();                 // rule 5: shared cluster config, not a literal
    await upsertEntity(config.pgUrl, input.key, input.body); // rule 9: deterministic upsert key
    return { ok: true };
  } catch (err) {
    logger.error('inject_entity failed', { key: input.key, err: err.message }); // rule 9: no payload body/secret
    throw err;                                 // rule 4: never swallow
  }
});
```

**Bad — hardcoded secret, no auth, ad-hoc Redis, swallowed error (rules 1, 2,
4, 5):**

```ts
// ✗ rule 1: connection string with embedded credential committed in source
const pg = new Client('postgres://kg_user:S3cr3t@10.0.0.4:5432/kg');
// ✗ rule 5: ad-hoc Redis literal instead of the cluster config helper
const redis = new Redis({ host: '10.0.0.9', port: 6379 });

// ✗ rule 2: mutating MCP tool with no auth guard
server.tool('inject_entity', async (input) => {
  try {
    await pg.query('INSERT INTO entity ...', [input.key, input.body]); // ✗ rule 9: blind insert, not idempotent
  } catch {
    // ✗ rule 4: error swallowed — a failed inject looks like success
  }
});
```

**Good — non-root container (rule 6):**

```dockerfile
FROM node:20-slim
WORKDIR /app
COPY --chown=node:node . .
RUN groupadd -g 1001 app && useradd -u 1001 -g app app
USER app                                       # rule 6: runtime drops from root
CMD ["node", "server.js"]
```

## Red flags

- A connection string, `Bearer` token, `sk-`/`pk-`-style key, OAuth client
  secret, or webhook URL literal appearing in a `.js`/`.ts`/`.py`/`.toml`
  source or a committed `.env` (not `.env.example`). **Cite `path:line`,
  never the value.**
- A new `server.tool(...)` / route handler on a mutating or data-returning
  path with no auth middleware/scope check.
- `process.env.X` / `os.environ[...]` read inside handler or business logic
  instead of the config module.
- `new Redis({ host: ... })` / inline BullMQ connection options instead of
  the shared cluster helper.
- `catch {}` / `except: pass` / a caught error that is neither rethrown nor
  logged on an external entrypoint.
- A queue consumer doing an unconditional `INSERT` (no upsert / dedupe key),
  or logging `job.data` / cloned-repo file contents verbatim.
- A Dockerfile whose final stage has no `USER` dropping to a non-root UID.
- `../../<sibling-package>/` import crossing a package boundary.

## Remediation backlog

Repo-wide gaps tracked as remediation (surface once at repo level; do **not**
flag on every unrelated diff):

- **Uneven lint/format.** Standardize linting (ESLint for Node/TS, Ruff for
  Python) and formatting (Prettier / Black) across packages; several packages
  have partial or no config.
- **Thin test coverage.** Cortex has ~4 `node --test` tests, Nexus has
  pytest, Oculus runs Turbo, PMS-AI has none. Raise baseline coverage,
  starting with MCP tool contracts and queue-consumer idempotency.
- **Inconsistent CI.** Per-package CI is uneven; converge on a shared
  polyglot CI shape (lint + typecheck/mypy + test + build) per package.
- **Non-uniform pre-commit.** A blocking `gitleaks` pre-commit exists only as
  a native git hook scoped to `deploy/`; make a blocking secret-scan
  pre-commit uniform across all packages.
- **Undocumented deploy paths.** The polyglot deploy story (podman →
  Artifact Registry → ArgoCD; Gleap `wrangler pages deploy`; Nexus K8s Jobs)
  is tribal knowledge; document per package.

## Source

- Mined from `docs/analysis/supy-ai-agents.md` (Supy repo analysis,
  confidence `low` — the analysis is a high-level survey, not a line-level
  audit; rules are conservative and per-diff, and stack-specific claims should
  be reconfirmed against the live repo or Cortex before hard-blocking).
- Cross-references `secrets-and-config.md` (the stack-agnostic secrets rules;
  rule 1 here pairs with `secrets-and-config.md#rules` rule 1).
- Organization security rule — secrets must never be exposed; cite
  `path:line` only.
