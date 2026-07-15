---
name: supy-scaffold-domain
description: Scaffold a complete Clean-Architecture/DDD bounded context in a supy backend repo (five tagged libs — api, logic, domain/model, domain/service, data — with aggregate, value objects, state VO, factory, events, repository, schema, transformers, interactor, controller) using the Plop g:domain generator, then fill it in the Supy way. Use when adding a new domain/bounded-context to a nestjs-nx supy repo.
---

## Step 0 — Scaffold first, never hand-create

A bounded context is 25+ files across five libraries with mandatory `project.json` boundary tags, path aliases, and an ESLint scope constraint. Hand-creating them drifts from convention and skips the tags that `@nx/enforce-module-boundaries` relies on. **Always generate the skeleton, then fill it in.** This skill drives the Plop `domain` generator shipped with the plugin and then walks the fill-in in dependency order.

Read the governing standards before touching anything:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/architecture.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/backend/module-boundaries.md"
```

The companion how-to for the actual code shapes (aggregates, value objects, factories, interactors, controllers) is the **supy-clean-architecture** skill — consult it while filling in each layer. To add a single NATS handler to an *existing* domain, use **supy-scaffold-handler** instead.

## Step 1 — Resolve the repo and confirm the generator is present

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
```

If `git rev-parse` fails, stop and print:

```
supy-scaffold-domain: not inside a git repository — nothing to scaffold
```

Check that the repo has the domain generator installed:

```bash
ls "$REPO_ROOT/tools/generators/plopfile.js" 2>/dev/null && \
  grep -q '"g:domain"' "$REPO_ROOT/package.json" 2>/dev/null && echo "generator: present"
```

If the generator is **not** present, the repo has not yet adopted the backend drop-in assets. Offer to install them from the plugin (do not copy silently — show the list and ask first):

```
supy-scaffold-domain: this repo has no domain generator yet. The plugin ships one under:
  ${CLAUDE_PLUGIN_ROOT}/templates/backend/tools/generators/

To scaffold domains here, copy these into the repo root and wire them up:
  - tools/generators/           (plopfile.js + templates/domain/*.hbs)
  - merge package.scripts.json  (adds the "g:domain" script + plop devDependency)
Also copy the enforcement assets if absent: eslint.config.mjs (the boundary/purity/
typed-error rules), .husky/pre-commit.

Copy them now? [y/N]
```

On `y`, copy the files, run `npm install` (or note it), and continue. On anything else, stop — the generator is a prerequisite.

## Step 2 — Collect the input

Ask for the single generator input (parse from `$ARGUMENTS` if present):

```
supy-scaffold-domain needs one name:
  Domain name — singular, kebab-case (e.g. transfer, stock-count)
    → becomes libs/<name>/, the @supy/<name>/* aliases, and scope:<name>
```

Capture as `DOMAIN`. Validate kebab-case:

```bash
echo "$DOMAIN" | grep -qE '^[a-z][a-z0-9-]*$'
```

If it fails, print the format requirement and stop. Confirm no `libs/$DOMAIN/` already exists — if it does, stop rather than overwrite.

## Step 3 — Run the generator

```bash
cd "$REPO_ROOT" && npm run g:domain "$DOMAIN"
```

This writes five tagged libraries under `libs/$DOMAIN/`:

| Lib | `project.json` tags | Key files |
| --- | --- | --- |
| `domain/model` | `type:domain-model`, `scope:$DOMAIN` | aggregate, `<domain>-id.vo`, `<domain>-state.vo`, created event, factory, repository interface, barrel |
| `domain/service` | `type:domain-service`, `scope:$DOMAIN` | (empty — stateless cross-aggregate logic goes here) |
| `data` | `type:data`, `scope:$DOMAIN` | schema, input/output transformers, repository impl, data module, barrel |
| `logic` | `type:logic`, `scope:$DOMAIN` | `create-<domain>.interactor`, logic module, barrel |
| `api` | `type:api`, `scope:$DOMAIN` | `create-<domain>.payload`, `<domain>.rpc.controller`, api module, barrel |

The generator prints a **NEXT STEPS** block — those four manual wiring steps are Step 5 below.

## Step 4 — Fill in, in dependency order (inward-out)

Fill the generated stubs following **supy-clean-architecture**. Work from the purest layer outward so each layer compiles against the one it depends on:

1. **domain/model** — the aggregate extends `AggregateRoot`; every state change is an intention-revealing method using `this.assign('prop', vo)` + `this.addEvent(...)` (never mutate props externally, never override `toObject()`). Wrap every concept in a value object; put the lifecycle state machine in the state VO (`isTransientTo` / `canTransitionTo`). The factory exposes `createNew` (records the Created event) and `createFromExisting` (no event). Define `I<Domain>Repository` here as an interface. Keep it framework-free — no `@nestjs/*`, Mongoose, `@nestjs/cqrs`, or `class-validator`/`class-transformer` (lint-enforced).
2. **data** — the Mongoose `@Schema`, the `InputTransformer` (domain → doc) and `OutputTransformer` (doc → domain), and the repository implementation that extends the base `Repository` and `implements I<Domain>Repository`. Every method takes an optional `ClientSession`; reads use `.lean()`.
3. **logic** — one interactor per use case, injecting the repository *interface* + `TransactionManager`; order is validate/mutate → persist aggregate+events atomically in `withTransaction` → side-effects after commit. Event listeners delegate to an interactor.
4. **api** — request/reply DTOs in `src/lib/exchanges/` (or `dtos/`); `*.rpc.controller.ts` (`@UseFilters(NatsExceptionFilter)`, `@MessagePattern`, `@Payload(StrictValidationPipe)`) and, for events, `*.nats.controller.ts` (`@UseFilters(JetStreamExceptionFilter)`, `@EventPattern`). The API module exposes `static register({ capability })`.

Ensure each lib's `src/index.ts` barrel re-exports the public surface (aggregate, VOs, factory, repository interface, events for model; repository + module for data; interactors + module for logic; controllers + DTOs + module for api) and nothing internal.

## Step 5 — Wire the domain into the workspace (the generator's NEXT STEPS)

These four cannot be auto-wired safely — do them by hand:

1. **Path aliases** — add one entry per lib to `tsconfig.base.json` `paths`, each pointing at the lib's `src/index.ts`:
   ```jsonc
   "@supy/<domain>/domain/model":   ["libs/<domain>/domain/model/src/index.ts"],
   "@supy/<domain>/domain/service": ["libs/<domain>/domain/service/src/index.ts"],
   "@supy/<domain>/data":           ["libs/<domain>/data/src/index.ts"],
   "@supy/<domain>/logic":          ["libs/<domain>/logic/src/index.ts"],
   "@supy/<domain>/api":            ["libs/<domain>/api/src/index.ts"]
   ```
2. **Scope constraint** — append to `eslint.config.mjs` `depConstraints` so the domain may only depend on itself and shared:
   ```js
   { sourceTag: 'scope:<domain>', onlyDependOnLibsWithTags: ['scope:<domain>', 'scope:shared'] },
   ```
3. **Register the API module** — add `<Domain>ApiModule.register({ capability })` to `apps/api/src/app/app.module.ts`.
4. **Register event discriminators** — add each domain event to `apps/api/src/app/domain-events.discriminators.ts`, or the events will not deserialise on the worker side.

## Step 6 — Tests

Every layer with logic gets a co-located `*.spec.ts` that asserts behaviour — a lone `toBeDefined()` does not count. Cover:

- **domain/model** — pure unit tests of the aggregate methods and the state VO's legal/illegal transitions (no framework, no mocks).
- **logic** — interactor tests with a mocked repository interface; assert the domain method was called and persistence happened inside the transaction.
- **data** — transformer round-trip (domain → doc → domain) preserves value objects.

## Step 7 — Verify

```bash
npx nx graph --file=/tmp/graph.json   # confirm the five libs appear, no illegal edges
npx nx lint "$DOMAIN-domain-model" "$DOMAIN-domain-service" "$DOMAIN-data" "$DOMAIN-logic" "$DOMAIN-api" --parallel=3
npx nx test "$DOMAIN-logic" "$DOMAIN-domain-model"
npx nx affected -t build
```

All must pass before the domain is done. **If `nx lint` reports a module-boundary error, fix the import — never loosen the constraint.** A boundary error means an outer concern leaked inward (inject the repository interface instead of importing `data`) or a domain reached into another domain (go through a `scope:shared` lib or a context-map).

## Degradation paths

- **Not a git repo:** stop (Step 1).
- **Generator absent:** offer to install the drop-in assets; do not scaffold without the generator (Step 1).
- **Standards unreadable:** warn and continue using the inline rules and the supy-clean-architecture skill.
- **`libs/<domain>/` already exists:** stop — never overwrite an existing domain.
- **Cortex MCP available:** use `get_entity('<Domain>')` / `get_repo_guide` / `trace_implementation` to pre-fill aggregate fields, value objects, and event names; degrade silently to hand-fill if absent.
