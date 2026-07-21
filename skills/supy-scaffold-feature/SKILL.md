---
name: supy-scaffold-feature
description: '[frontend] Scaffold a complete Angular NGXS feature library in a supy frontend repo (models, state, service, smart+dumb components, resolver, routes — tagged and wired) using the Plop generator, then fill it in the Supy way. Use when adding a new feature/domain to an angular-nx supy repo.'
---

## Step 0 — Scaffold first, never hand-create

A whole NGXS feature is 13+ files across a fixed directory layout with mandatory `project.json` tags. Hand-creating them drifts from convention and skips the tags that `@nx/enforce-module-boundaries` relies on. **Always generate the skeleton, then fill it in.** This skill drives the Plop `feature` generator shipped with the plugin and then walks the fill-in in dependency order.

Read the governing standards before touching anything:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/frontend/angular-conventions.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/frontend/module-boundaries.md"
```

The companion how-to for the actual code shapes is the **supy-angular-feature** skill — consult it while filling in each file.

## Step 1 — Resolve the repo and confirm the generator is present

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
```

If `git rev-parse` fails, stop and print:

```text
supy-scaffold-feature: not inside a git repository — nothing to scaffold
```

Check that the repo has the feature generator installed:

```bash
ls "$REPO_ROOT/tools/generators/plopfile.js" 2>/dev/null && \
  grep -q '"g:feature"' "$REPO_ROOT/package.json" 2>/dev/null && echo "generator: present"
```

If the generator is **not** present, the repo has not yet adopted the frontend drop-in assets. Offer to install them from the plugin (do not copy silently — show the list and ask first):

```text
supy-scaffold-feature: this repo has no feature generator yet. The plugin ships one under:
  ${CLAUDE_PLUGIN_ROOT}/templates/frontend/tools/generators/

To scaffold features here, copy these into the repo root and wire them up:
  - tools/generators/           (plopfile.js + templates/feature/*.hbs)
  - merge package.scripts.json  (adds the "g:feature" script + plop devDependency)
Also copy the enforcement assets if absent: eslint.config.mjs, .stylelintrc.json,
.editorconfig, .cursor/, .github/workflows/ci.yml, .husky/pre-commit.

Copy them now? [y/N]
```

On `y`, copy the files, run `npm install` (or note it), and continue. On anything else, stop — the generator is a prerequisite.

## Step 2 — Collect inputs

Ask for the two generator inputs (parse from `$ARGUMENTS` in order if present: feature, entity):

```text
supy-scaffold-feature needs two names:
  1. Feature name — plural, kebab-case (e.g. orders)   → becomes @supy/orders, scope:orders
  2. Entity name  — singular, PascalCase (e.g. Order)   → becomes the model/entity type
```

Capture as `FEATURE` and `ENTITY`. Validate:

```bash
echo "$FEATURE" | grep -qE '^[a-z][a-z0-9-]*$'   # kebab-case
echo "$ENTITY"  | grep -qE '^[A-Z][A-Za-z0-9]*$' # PascalCase
```

If either fails, print the format requirement and stop. Confirm no `libs/$FEATURE/` already exists — if it does, stop rather than overwrite.

## Step 3 — Run the generator

```bash
cd "$REPO_ROOT" && npm run g:feature -- --feature "$FEATURE" --entity "$ENTITY"
```

This writes the tagged library under `libs/$FEATURE/`:

- `project.json` (tagged `type:feature`, `scope:$FEATURE`)
- `src/index.ts` (barrel)
- `src/lib/models/$FEATURE.model.ts`
- `src/lib/config/$FEATURE.config.ts`
- `src/lib/store/actions/$FEATURE.actions.ts`
- `src/lib/store/state/$FEATURE.state.ts`
- `src/lib/services/$FEATURE.service.ts`
- `src/lib/resolvers/$FEATURE.resolver.ts`
- `src/lib/components/<entity>-list/…` (smart) + `<entity>-card/…` (dumb)
- `src/lib/$FEATURE.routes.ts`

The generator prints a **NEXT STEPS** block — those three manual wiring steps are Step 6 below.

## Step 4 — Fill in, in dependency order

Fill the generated stubs following **supy-angular-feature**. Work inward-out so each layer compiles against the last:

1. **Models** (`models/$FEATURE.model.ts`) — `*Request`/`*Response` interfaces, all properties `readonly`; references use `SkeletonObjectType`, localized fields use `LocalizedData`.
2. **State** (`store/state/$FEATURE.state.ts` + `store/actions/$FEATURE.actions.ts`) — one state class extending `EntityListState<T>` where it fits; `static @Selector([TOKEN])` methods; deep updates via Immer `produce()`, shallow via `ctx.patchState()`; list-loading actions carry `{ cancelUncompleted: true }`. Action type format `[Feature] ActionName`.
3. **Service + config** (`services/$FEATURE.service.ts` + `config/$FEATURE.config.ts`) — extend `BaseHttpService`, inject a URI `InjectionToken` (never a hardcoded URL); typed `Observable<IQueryResponse<T>>` returns.
4. **Components** — smart list (`inject(Store)`, `selectSignal`, dispatch, OnPush) and dumb card (`input.required()` / `output()`, standalone, OnPush). SCSS uses `--p-*` tokens only.
5. **Routing** (`$FEATURE.routes.ts`) — lazy state via `provideStates([...])` in route `providers`; functional `inject()` guards/resolvers.

## Step 5 — Barrel

Ensure `src/index.ts` re-exports the public surface (routes, state token, models, service, components meant for reuse) and nothing internal.

## Step 6 — Wire the feature into the workspace (the generator's NEXT STEPS)

These three cannot be auto-wired safely — do them by hand:

1. **Path alias** — add to `tsconfig.base.json` `paths`:

   ```jsonc
   "@supy/<feature>": ["libs/<feature>/src/index.ts"]
   ```

2. **Boundary constraint** — append to `eslint.config.mjs` `depConstraints`:

   ```js
   { sourceTag: 'scope:<feature>', onlyDependOnLibsWithTags: ['scope:<feature>', 'scope:shared'] },
   ```

3. **Lazy route** — register in the app routing:

   ```ts
   { path: '<feature>', loadChildren: () => import('@supy/<feature>').then(m => m.<FEATURE>_ROUTES) }
   ```

## Step 7 — Tests

Every component, state, and service gets a co-located `*.spec.ts` that asserts behaviour — a lone `toBeDefined()` does not count. Cover: state reducers (action → expected slice), service HTTP calls (mocked), and smart-component dispatch/selection wiring.

## Step 8 — Verify

```bash
npx nx graph --file=/tmp/graph.json   # confirm the new lib appears, no illegal edges
npx nx lint "$FEATURE" --parallel=3
npx stylelint "libs/$FEATURE/**/*.scss"
npx nx test "$FEATURE"
```

All four must pass before the feature is done. If `nx lint` reports a boundary violation, revisit Step 6.2 (missing/incorrect scope constraint) or the imports (cross-domain access must go through a `scope:shared` lib).

## Degradation paths

- **Not a git repo:** stop (Step 1).
- **Generator absent:** offer to install the drop-in assets; do not scaffold without the generator (Step 1).
- **Standards unreadable:** warn and continue using the inline rules and the supy-angular-feature skill.
- **`libs/<feature>/` already exists:** stop — never overwrite an existing feature.
- **Cortex MCP available:** use `get_entity('<Entity>')` / `get_repo_guide` to pre-fill model fields and service URIs; degrade silently to hand-fill if absent.
