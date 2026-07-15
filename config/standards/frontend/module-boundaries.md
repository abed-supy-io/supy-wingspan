---
source: angular-frontend-starter-kit/docs/module-boundaries.md, angular-frontend-starter-kit/eslint.config.mjs
mined_on: 2026-07-15
confidence: high
---

# Frontend Module Boundaries — Tags & Wiring

`@nx/enforce-module-boundaries` in `eslint.config.mjs` only works if every library is **tagged** in its `project.json`. Each lib carries one `type:` tag and one `scope:` tag. Dependencies flow inward (outer layers depend on inner) and never across domains except through a `scope:shared` lib. Companion rules for what goes inside a lib live in [angular-conventions.md](angular-conventions.md).

## Rules

1. **Every library is tagged** in `project.json` with exactly one `type:` tag and one `scope:` tag. Untagged libs escape boundary enforcement — treat an untagged lib as a defect.

   | Dimension | Values | Meaning |
   | --- | --- | --- |
   | `type:` | `app`, `feature`, `ui`, `data-access`, `util` | what kind of library |
   | `scope:` | `<domain>` (e.g. `orders`), `shared` | which bounded context |

2. **`type:` meanings:**
   - **`feature`** — a domain library (smart components + its NGXS state/actions/services/models, wired into routes). e.g. `orders`, `inventory`, `items`.
   - **`ui`** — presentational components only (no domain state, no HTTP). e.g. `components`.
   - **`data-access`** — state + services + models with no UI (when you split a feature).
   - **`util`** — framework-light shared utilities, base classes, pipes, directives, tokens. e.g. `common`, `core`, `i18n`, `styles`.
   - **`app`** — the application shells under `apps/` (retailer, admin, supplier).

3. **Dependency direction (layer):** an outer layer may depend on inner layers only.
   - `type:ui` may depend on `type:ui`, `type:util` — **never** `type:data-access` (presentational components stay free of domain data).
   - `type:data-access` may depend on `type:data-access`, `type:util`.
   - `type:util` may depend on `type:util` only.
   - `type:app` / `type:feature` may depend on `feature`, `ui`, `data-access`, `util`.

4. **Domain isolation (scope):** `scope:shared` depends only on `scope:shared`. Each domain (`scope:<domain>`) may depend only on itself and `scope:shared` — **never** on another domain's internals. Cross-domain access goes through a `scope:shared` lib.

5. **Path aliases** live in `tsconfig.base.json` under the `@supy/*` prefix, one entry per lib pointing at its `src/index.ts` barrel. Import across libs through the alias — never a relative path across a library boundary.

6. **Adding a feature `foo`:** (1) the generator writes a tagged `project.json` (`type:feature`, `scope:foo`); (2) add the `@supy/foo` alias to `tsconfig.base.json`; (3) append the scope constraint to `eslint.config.mjs`. Then `nx graph` visualises the dependency graph and `nx lint` enforces it.

## Examples

### Good — tagged `project.json`

```jsonc
// apps/retailer/project.json
{ "name": "retailer",   "tags": ["type:app",     "scope:shared"] }

// libs/orders/project.json   (a domain feature lib)
{ "name": "orders",     "tags": ["type:feature", "scope:orders"] }

// libs/components/project.json
{ "name": "components", "tags": ["type:ui",      "scope:shared"] }

// libs/common/project.json
{ "name": "common",     "tags": ["type:util",    "scope:shared"] }
```

### Good — path aliases (`@supy/*`)

```jsonc
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@supy/common": ["libs/common/src/index.ts"],
      "@supy/core": ["libs/core/src/index.ts"],
      "@supy/components": ["libs/components/src/index.ts"],
      "@supy/orders": ["libs/orders/src/index.ts"],
      "@supy/inventory": ["libs/inventory/src/index.ts"]
    }
  }
}
```

### Good — scope constraint appended per new feature

```js
// eslint.config.mjs — depConstraints
{ sourceTag: 'scope:foo', onlyDependOnLibsWithTags: ['scope:foo', 'scope:shared'] },
```

## Red flags

- A library with no `type:` or no `scope:` tag in `project.json` (escapes boundary enforcement).
- A `type:ui` lib (e.g. `components`) importing a `type:data-access` lib → lint error.
- One domain (`orders`) importing another domain's internals (`inventory`) → lint error; share via a `scope:shared` lib.
- A `type:util` lib (e.g. `common`) importing a `type:feature` lib → lint error (utils can't depend on features).
- A relative import (`../../../orders/...`) crossing a library boundary instead of the `@supy/*` alias.
- A new feature added without its alias in `tsconfig.base.json` or its scope constraint in `eslint.config.mjs`.

## Source

- `angular-frontend-starter-kit/docs/module-boundaries.md` — tag dimensions, `type:` meanings, example tagging, path aliases, adding-a-feature steps, and the explicit `@app/*` → `@supy/*` swap note
- `angular-frontend-starter-kit/eslint.config.mjs` — the `@nx/enforce-module-boundaries` `depConstraints` (layer + scope) this document describes
- Alias note: examples here use the Supy `@supy/*` prefix; the starter kit's own default is `@app/*`.
