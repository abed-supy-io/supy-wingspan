---
source: architecture-starter-kit/docs/module-boundaries.md, architecture-starter-kit/eslint.config.mjs
mined_on: 2026-07-15
confidence: high
---

# Backend Module Boundaries — Tags & Wiring

`@nx/enforce-module-boundaries` in `eslint.config.mjs` only works if every library is **tagged** in its `project.json`. Each lib carries one `type:` tag (its architectural layer) and one `scope:` tag (its bounded context). Dependencies flow **inward only** — `api → logic → domain/model ← data` (plus `domain/service`) — and never across domains except through a `scope:shared` lib. This is the mechanical enforcement of the layering rules in [architecture.md](../architecture.md); companion modelling rules for what goes inside each layer live there too.

## Rules

1. **Every library is tagged** in `project.json` with exactly one `type:` tag and one `scope:` tag. Untagged libs escape boundary enforcement — treat an untagged lib as a defect.

   | Dimension | Values | Meaning |
   | --- | --- | --- |
   | `type:` | `api`, `logic`, `domain-model`, `domain-service`, `data`, `context-map`, `util` | which architectural layer |
   | `scope:` | `<domain>` (e.g. `transfer`), `shared` | which bounded context |

2. **`type:` meanings:**
   - **`api`** — transport layer: NATS RPC/event controllers, DTOs, exchanges. The only layer that talks to the outside world.
   - **`logic`** — application layer: interactors/use-cases that orchestrate a change, open transactions, and emit events. Injects domain-model repository *interfaces*, never data implementations.
   - **`domain-model`** — the purest layer: aggregates, entities, value objects, factories, domain events, repository interfaces. Framework-free — no `@nestjs/*`, no Mongoose, no `@nestjs/cqrs`, no `class-validator`/`class-transformer`.
   - **`domain-service`** — stateless domain logic that spans aggregates but still belongs to the domain (no infrastructure). Depends only on `domain-model` and `util`.
   - **`data`** — infrastructure: Mongoose schemas, transformers, repository *implementations* of the domain-model interfaces. Depends on `domain-model` + `util`; **nothing** depends on `data`.
   - **`context-map`** — anti-corruption / translation between bounded contexts. Depends only on `domain-model` + `util`.
   - **`util`** — framework-light shared utilities, base classes, typed errors, tokens. Depends on `util` only.

3. **Dependency direction (layer) — the One Rule, dependencies flow inward:**
   - `type:api` may depend on `logic`, `domain-model`, `domain-service`, `context-map`, `util` — **never** `data`.
   - `type:logic` may depend on `domain-model`, `domain-service`, `context-map`, `util` — **never** `data` or `api`.
   - `type:domain-service` may depend on `domain-model`, `util` only.
   - `type:domain-model` may depend on `util` only — the purest layer.
   - `type:data` may depend on `domain-model`, `util` — **never** `api` or `logic`.
   - `type:context-map` may depend on `domain-model`, `util`.
   - `type:util` may depend on `util` only.

4. **Domain isolation (scope):** `scope:shared` depends only on `scope:shared`. Each domain (`scope:<domain>`) may depend only on itself and `scope:shared` — **never** on another domain's internals. Cross-domain access goes through a `scope:shared` lib or a `context-map`.

5. **Domain purity is lint-enforced.** `domain/model/**` and `domain/service/**` files may not import `@nestjs/*`, `mongoose`, `@nestjs/cqrs`, `class-validator`, or `class-transformer` — an illegal import fails `nx lint`. Move infrastructure concerns to `data/` or `logic/`.

6. **Typed errors only.** `domain/**` and `logic/**` may not `new Error(...)` — use a typed error (`ValidationError`, `NotFoundError`, `ConflictError`). This is a `no-restricted-syntax` lint rule.

7. **Path aliases** live in `tsconfig.base.json` under the `@supy/*` prefix, one entry per lib pointing at its `src/index.ts` barrel (e.g. `@supy/transfer/domain/model`). Import across libs through the alias — never a relative path across a library boundary (`import/no-relative-packages` is an error).

8. **Adding a domain `foo`:** (1) `npm run g:domain foo` writes five tagged `project.json` files (`foo-api` → `type:api`, `foo-logic` → `type:logic`, `foo-domain-model` → `type:domain-model`, `foo-domain-service` → `type:domain-service`, `foo-data` → `type:data`, all `scope:foo`); (2) add the `@supy/foo/*` aliases to `tsconfig.base.json`; (3) append the scope constraint to `eslint.config.mjs`; (4) register the `FooApiModule` in `app.module.ts` and the event discriminators. Then `nx graph` visualises the dependency graph and `nx lint` enforces it.

## Examples

### Good — tagged `project.json` (one domain = five libs)

```jsonc
// libs/transfer/api/project.json
{ "name": "transfer-api",            "tags": ["type:api",            "scope:transfer"] }

// libs/transfer/logic/project.json
{ "name": "transfer-logic",          "tags": ["type:logic",          "scope:transfer"] }

// libs/transfer/domain/model/project.json
{ "name": "transfer-domain-model",   "tags": ["type:domain-model",   "scope:transfer"] }

// libs/transfer/domain/service/project.json
{ "name": "transfer-domain-service", "tags": ["type:domain-service", "scope:transfer"] }

// libs/transfer/data/project.json
{ "name": "transfer-data",           "tags": ["type:data",           "scope:transfer"] }

// libs/common/project.json  (a shared util)
{ "name": "common",                  "tags": ["type:util",           "scope:shared"] }
```

### Good — path aliases (`@supy/*`)

```jsonc
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@supy/common": ["libs/common/src/index.ts"],
      "@supy/transfer/api": ["libs/transfer/api/src/index.ts"],
      "@supy/transfer/logic": ["libs/transfer/logic/src/index.ts"],
      "@supy/transfer/domain/model": ["libs/transfer/domain/model/src/index.ts"],
      "@supy/transfer/domain/service": ["libs/transfer/domain/service/src/index.ts"],
      "@supy/transfer/data": ["libs/transfer/data/src/index.ts"]
    }
  }
}
```

### Good — scope constraint appended per new domain

```js
// eslint.config.mjs — depConstraints
{ sourceTag: 'scope:transfer', onlyDependOnLibsWithTags: ['scope:transfer', 'scope:shared'] },
```

## Red flags

- A library with no `type:` or no `scope:` tag in `project.json` (escapes boundary enforcement).
- `type:api` or `type:logic` importing a `type:data` lib → lint error; inject the repository *interface* from `domain-model` and bind the implementation in a module.
- `type:domain-model` importing `@nestjs/*`, `mongoose`, `@nestjs/cqrs`, `class-validator`, or `class-transformer` → domain-purity lint error.
- `new Error(...)` inside `domain/**` or `logic/**` → typed-errors lint error; use `ValidationError`/`NotFoundError`/`ConflictError`.
- One domain (`transfer`) importing another domain's internals (`ledger`) → lint error; share via a `scope:shared` lib or a `context-map`.
- A relative import (`../../../transfer/domain/model/...`) crossing a library boundary instead of the `@supy/*` alias.
- A new domain added without its aliases in `tsconfig.base.json`, its scope constraint in `eslint.config.mjs`, or its `ApiModule` registered in `app.module.ts`.

## Shared-library variant

Rules 1–8 govern a **bounded-context service repo** (apps + tagged domain libs). One recognized repo does **not** match that shape: `supy-api-common`, the shared-library-only repo that publishes the `@supy.api/*` packages.

- **The untagged-lib defect (rule 1) does not apply to `supy-api-common`.** Its ~30 libraries are a flat, single-purpose namespace with no `type:`/`scope:` tags by design — there are no domains to isolate and no apps to protect, so `@nx/enforce-module-boundaries` is not the enforcement mechanism there. Do **not** flag its libraries as untagged defects.
- **Everything else still holds.** Domain purity (rule 5), typed errors (rule 6), and alias-not-relative imports (rule 7) still apply to any lib in that repo that contains domain logic. Only the tag-based boundary rules (1, 3, 4, and the adding-a-domain wiring in 8) are out of scope there.
- **Cross-context translation still goes through an anti-corruption layer.** In a service repo that is the `type:context-map` lib (rules 2, 4); in `supy-api-common` the equivalent role is played by dedicated integration/adapter libs. Reaching into another context's internals directly is a defect in either shape.

See `nx-nestjs-patterns.md#shared-library-variant-supy-api-common` (SV1–SV6) for the full profile.

## Source

- `architecture-starter-kit/docs/module-boundaries.md` — tag dimensions, `type:` meanings, example tagging, path aliases, adding-a-domain steps, and the explicit `@app/*` → `@supy/*` swap note
- `architecture-starter-kit/eslint.config.mjs` — the `@nx/enforce-module-boundaries` `depConstraints` (7 layer types + scope isolation), the domain-purity `no-restricted-imports` rule, and the typed-errors `no-restricted-syntax` rule this document describes
- Alias note: examples here use the Supy `@supy/*` prefix; the starter kit's own default is `@app/*`.
