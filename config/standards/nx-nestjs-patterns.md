---
source: supy-service-inventory/CLAUDE.md, supy-service-inventory/.github/ARCHITECTURE.md, supy-service-inventory/nx.json, supy-service-inventory/apps/api/project.json, supy-api/CLAUDE.md, Cortex coding-rules (rule-0007)
mined_on: 2026-07-15
confidence: high
---

# Nx / NestJS Structural Patterns

Supy backend services are Nx monorepos running NestJS 11 on Node.js 24. The canonical project is `supy-service-inventory` (Nx 21.1.2); `supy-api` uses Nx 22.5.3. TypeScript strict mode (`noImplicitAny`) is enforced.

## Rules

1. **Tool versions (verified from package metadata):**
   - NestJS 11.1.14 + Fastify 5.7.4
   - Nx 21.1.2 (`supy-service-inventory`), Nx 22.5.3 (`supy-api`)
   - TypeScript 5.9.2
   - Node.js 24.10.0 (enforced via `.nvmrc` + `check-node-version`)
   - Mongoose 8.23.0
   - Jest 29.7.0 (`supy-service-inventory`), Jest 30 (`supy-api`)
2. **Project layout**: apps under `apps/`, libraries under `libs/<domain>/<layer>/`. Each library has a `project.json` (Nx project config) and `tsconfig.lib.json`.
3. **Application build**: `apps/api` uses `@nx/webpack:webpack` executor with `compiler: tsc` (single compilation unit). This is why `apps/api/tsconfig.app.json` must keep `references: []` — see Nx Sync Note.
4. **`nx.json` must set `sync.applyChanges: false`** to prevent `nx sync` from auto-populating `references` in `apps/api/tsconfig.app.json` (would cause webpack TS6305 failures).
5. **NestJS 11 import path quirk**: use the full decorator import path to avoid module resolution issues:

   ```typescript
   // Correct:
   import { Injectable } from '@nestjs/common/decorators/core/injectable.decorator';
   // Not this (may cause issues in NestJS 11):
   // import { Injectable } from '@nestjs/common';
   ```

6. **Library aliases**: all cross-library imports use `@supy/<domain>/<sublibrary>` aliases defined in `tsconfig.base.json`. Never use relative paths across library boundaries.
7. **New libraries must be created with generators**, not manually: `npm run generate:library-feature-*`.
8. **Module registration** for new API modules: use `register({ capability })` pattern and register in `apps/api/src/app/app.module.ts`.
9. **Where handlers/controllers live**: `libs/<domain>/api/src/*.rpc.controller.ts` (RPC) and `libs/<domain>/api/src/*.nats.controller.ts` (events).
10. **Where DTOs live**: exclusively in `api/src/lib/exchanges/` (request/response exchange types) or `api/src/lib/dtos/` (standalone DTOs). Never in `logic/` or `domain/`.
11. **Where schemas live**: `libs/<domain>/data/src/lib/schemas/` — Mongoose schema definitions using `@Schema` + `SchemaFactory.createForClass()`.
12. **Where repositories live**: `libs/<domain>/data/src/lib/repositories/` — must implement the `I*Repository` interface from `domain/model/`.
13. **Where interactors live**: `libs/<domain>/logic/src/lib/interactors/` — one class per use case.
14. **Where aggregates and value objects live**: `libs/<domain>/domain/model/src/lib/` — pure TypeScript, no framework imports.
15. **Spec files** are co-located with source (`*.spec.ts` next to `*.ts`).
16. **Testing**: use `Test.createTestingModule()` from `@nestjs/testing`; mock repositories from `@supy/{lib}/mocks`; call `jest.resetAllMocks()` in `afterEach`.
17. **Nx parallel default** is 3 (`"parallel": 3` in `nx.json`).
18. **Nx plugin config** (`nx.json`): `@nx/js/typescript`, `@nx/eslint/plugin`, `@nx/webpack/plugin` are registered plugins.
19. **Test coverage for new business logic (Cortex rule-0007, must)**: all new business logic — interactors, listeners, and entity methods with state transitions — must have corresponding `*.spec.ts` files, with coverage especially for state-changing operations, authorization logic, data validation, and cross-service integration points. A spec that exists but only asserts trivially (e.g. `expect(true).toBe(true)` or a lone `toBeDefined()`) does not satisfy this rule — tests must assert the domain outcome.

## Examples

### Good — bounded context library directory layout

```text
libs/transfer/
  api/
    src/lib/
      exchanges/          ← DTOs / exchange types
      transfer.rpc.controller.ts
      transfer.nats.controller.ts
    project.json
    tsconfig.lib.json
  domain/
    model/src/lib/
      transfer.aggregate.ts
      transfer-id.value-object.ts
      i-transfer.repository.ts   ← interface only
      transfer-submitted.event.ts
  data/src/lib/
    schemas/
      transfer.schema.ts
    repositories/
      transfer.repository.ts     ← implements ITransferRepository
    transformers/
      transfer.input.transformer.ts
      transfer.output.transformer.ts
  logic/src/lib/
    interactors/
      create-transfer.interactor.ts
    listeners/
      transfer-submitted.listener.ts
```

### Good — CQRS split layout (e.g., stock-count)

```text
libs/stock-count/
  api/         ← shared module registration
  commands/
    api/       ← @EventPattern command entry points
    application/ ← @CommandHandler classes
    data/      ← write-side repositories
    domain/model/ ← aggregates, command classes
  queries/
    api/       ← @MessagePattern query entry points
    data/      ← read-side DAOs
    use-cases/ ← @Injectable query handlers
  logic/       ← (if interactor pattern coexists)
```

### Good — running affected tasks

```bash
npm run affected:lint && npm run affected:test && npm run affected:build
```

### Good — project.json build target for api app

```json
{
  "targets": {
    "build": {
      "executor": "@nx/webpack:webpack",
      "options": {
        "target": "node",
        "compiler": "tsc"
      }
    }
  }
}
```

### Bad

```typescript
// WRONG: relative path across library boundaries
import { TransferRepository } from '../../../transfer/data/src/lib/repositories';

// WRONG: DTO defined in domain layer
// libs/transfer/domain/model/src/lib/create-transfer.dto.ts ← DTOs don't belong here
```

```bash
# WRONG: nx sync with apply changes (breaks api build)
# nx sync  ← if this auto-populates references in apps/api/tsconfig.app.json, revert
```

## Red flags

- Relative imports across library boundaries (should use `@supy/*` aliases).
- DTO or exchange type defined in `domain/model/` or `logic/` — must be in `api/`.
- Mongoose schema or repository in `domain/model/` layer.
- New library created manually (folders + files) instead of using `generate:library-feature-*` generators.
- `apps/api/tsconfig.app.json` `references` field not empty — indicates `nx sync` was applied (causes TS6305).
- Framework import (`@nestjs/common`) used at root level in NestJS 11 — use full decorator path.
- Test file not co-located with source (`spec` files in a separate `__tests__` directory).
- `jest.resetAllMocks()` missing from `afterEach` in test suites.
- Tautological or assertion-free spec (only `expect(true).toBe(true)` or a lone `toBeDefined()`) — provides no real coverage of the new logic.

## Shared-library variant (supy-api-common)

`supy-api-common` is a **shared-library-only** repo (the `@supy.api/*` packages consumed by every service). It is a deliberate, recognized variant of the layout above — not a violation of it. When reviewing a repo that matches this shape, apply these adjustments instead of the rules above; do not flag the divergences as defects.

- **SV1 — No apps, flat library namespace.** There are no `apps/`. Libraries are ~30 flat, single-purpose packages (`libs/<name>`), not grouped under `libs/<domain>/<layer>/`. The bounded-context layer layout (rules 2, 9–14) does **not** apply here.
- **SV2 — No Nx tags.** Libraries in this repo are intentionally untagged. Do **not** flag missing `type:`/`scope:` tags here (contrast the tagged-service rule in `backend/module-boundaries.md`). See `module-boundaries.md#shared-library-variant`.
- **SV3 — Path alias shape.** Cross-package imports use `@supy.api/<name>` → `libs/<name>/src/index.ts` (barrels `export * from './lib'`), not `@supy/<domain>/<sublibrary>`.
- **SV4 — Independent release + publishing.** Packages are versioned independently via `nx-release`, tagged `@supy.api/{lib}@{version}`, and published to Google Artifact Registry (`.npmrc` kept out of tree via git `skip-worktree`). A change to one lib bumps only that lib.
- **SV5 — Shared archetypes to preserve.** `Identity` base class with a phantom `__type` for type-safe IDs; a custom `BaseError` hierarchy bridged to NestJS via a single `HttpExceptionFilter`; a compression-aware NATS client proxy (LZ4/snappy + serialization + timeouts); transformation decorators (phone/date/JSON). New shared IDs, errors, and NATS wiring should reuse these, not reinvent them.
- **SV6 — `passWithNoTests`.** Jest runs with `passWithNoTests`; a lib with no `*.spec.ts` does not fail CI here. Coverage rule 19 still applies to any lib that contains business logic.

## Source

- `supy-service-inventory/CLAUDE.md` — Stack versions, NestJS 11 import quirk, Nx Sync Note, generator commands, architecture layer layout, testing patterns
- `supy-service-inventory/.github/ARCHITECTURE.md` §1 (repo overview table), §5 (layer table), §6 (CQRS structure), §7 (import path map)
- `supy-service-inventory/nx.json` — `sync.applyChanges: false`, parallel=3, plugin registrations
- `supy-service-inventory/apps/api/project.json` — webpack executor, `compiler: tsc`, sourceRoot
- `supy-api/CLAUDE.md` — corroborates NestJS 11 + Fastify 5, Nx 22.5.3, same library layout conventions
- Cortex `get_coding_rules(category: testing)` rule-0007 (severity: must; source: review-feedback:62-accepted-findings) — test coverage for new business logic + meaningful assertions (rule 19).
- `supy-api-common` — shared-library-only variant: flat untagged libs, `@supy.api/*` barrel aliases, `Identity` phantom-type IDs, `BaseError`→`HttpExceptionFilter`, compression-aware NATS proxy, `nx-release` independent versioning to Google Artifact Registry, Jest `passWithNoTests` (Shared-library variant SV1–SV6).
