---
name: supy-scaffold-flutter-feature
description: Scaffold a complete Clean Architecture feature (domain + data + presentation + tests) in a supy Flutter repo from bundled stubs, then fill it in the Supy way and print the manual wiring (get_it registration, go_router route, barrel export). Use when adding a new feature to a flutter supy repo.
---

## Step 0 — Scaffold first, never hand-create

A Clean Architecture feature is ~14 files across three layers (`domain/`, `data/`, `presentation/`) plus tests, in a fixed layout. Hand-creating them drifts from convention and skips the boundaries the reviewer relies on. **Always lay down the skeleton, then fill it in.** Flutter is not Nx — there is no Plop and no lint-enforced boundary graph, so this skill copies bundled `.hbs` stubs (substituting placeholders by hand) and then walks the fill-in in dependency order.

Read the governing standards before touching anything:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/flutter/architecture.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/flutter/flutter-conventions.md"
```

The companion how-to for the actual code shapes is the **supy-flutter-feature** skill — consult it while filling in each file.

## Step 1 — Resolve the repo root

Flutter repos are identified by `pubspec.yaml`, not by git. Find the root:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
test -f "$REPO_ROOT/pubspec.yaml" || { echo "supy-scaffold-flutter-feature: no pubspec.yaml at repo root — not a Flutter repo, nothing to scaffold"; exit 0; }
```

If there is no `pubspec.yaml`, stop — this is not a Flutter repo.

## Step 2 — Collect inputs

Ask for the two names (parse from `$ARGUMENTS` in order if present: feature, entity):

```text
supy-scaffold-flutter-feature needs two names:
  1. Feature name — plural, snake_case (e.g. tasks)   → becomes lib/features/tasks/, TasksBloc, /tasks route
  2. Entity name  — singular, PascalCase (e.g. Task)   → becomes the domain entity type
```

Capture as `FEATURE` (snake_case, plural) and `ENTITY` (PascalCase, singular). Validate:

```bash
echo "$FEATURE" | grep -qE '^[a-z][a-z0-9_]*$'   # snake_case
echo "$ENTITY"  | grep -qE '^[A-Z][A-Za-z0-9]*$' # PascalCase
```

If either fails, print the format requirement and stop. Confirm `lib/features/$FEATURE/` does **not** already exist — if it does, stop rather than overwrite.

Derive the placeholder values used throughout the stubs. The package name comes from `pubspec.yaml` (the stubs use `package:` imports, which `always_use_package_imports` requires):

```bash
PACKAGE=$(grep -E '^name:' "$REPO_ROOT/pubspec.yaml" | head -1 | sed -E 's/^name:[[:space:]]*//')
```

| Placeholder | Meaning | Example |
| --- | --- | --- |
| `{{package}}` | Dart package name (`name:` in `pubspec.yaml`) | `supy_checklists` |
| `{{feature}}` | feature folder + file prefix (snake_case, plural) | `tasks` |
| `{{Feature}}` | class prefix (PascalCase, plural) | `Tasks` |
| `{{entity}}` | entity file name (snake_case, singular) | `task` |
| `{{Entity}}` | entity type (PascalCase, singular) | `Task` |

## Step 3 — Prefer a repo generator, else copy the bundled stubs

If the repo already ships its own generator (`mason` bricks or a `very_good` template), use it — it will match the repo's exact conventions:

```bash
ls "$REPO_ROOT/mason.yaml" 2>/dev/null || ls "$REPO_ROOT"/tool/*feature* 2>/dev/null
grep -q 'very_good_cli\|mason' "$REPO_ROOT/pubspec.yaml" 2>/dev/null && echo "repo generator: present"
```

If a repo generator is present, run it (e.g. `mason make feature -o lib/features` or the repo's documented command) and skip to Step 4.

Otherwise, lay down the skeleton from the plugin's bundled stubs. The stubs live at:

```text
${CLAUDE_PLUGIN_ROOT}/templates/flutter/tools/feature/
```

Create the directory tree and copy each stub to its destination, **renaming `{{feature}}`/`{{entity}}` in the path** and stripping the `.hbs` suffix. The mapping:

| Bundled stub | Destination (under `lib/features/$FEATURE/`) |
| --- | --- |
| `entity.dart.hbs` | `domain/entities/{{entity}}.dart` |
| `repository.dart.hbs` | `domain/repositories/{{feature}}_repository.dart` |
| `usecase.dart.hbs` | `domain/usecases/get_{{feature}}.dart` |
| `model.dart.hbs` | `data/models/{{entity}}_model.dart` |
| `remote_datasource.dart.hbs` | `data/datasources/{{feature}}_remote_datasource.dart` |
| `fake_remote_datasource.dart.hbs` | `data/datasources/fake_{{feature}}_remote_datasource.dart` |
| `repository_impl.dart.hbs` | `data/repositories/{{feature}}_repository_impl.dart` |
| `bloc.dart.hbs` | `presentation/bloc/{{feature}}_bloc.dart` |
| `event.dart.hbs` | `presentation/bloc/{{feature}}_event.dart` |
| `state.dart.hbs` | `presentation/bloc/{{feature}}_state.dart` |
| `page.dart.hbs` | `presentation/pages/{{feature}}_page.dart` |
| `barrel.dart.hbs` | `{{feature}}.dart` (feature barrel) |

Tests go under `test/features/$FEATURE/` (mirroring the `lib/` path):

| Bundled stub | Destination (under `test/features/$FEATURE/`) |
| --- | --- |
| `bloc_test.dart.hbs` | `presentation/bloc/{{feature}}_bloc_test.dart` |
| `repository_impl_test.dart.hbs` | `data/repositories/{{feature}}_repository_impl_test.dart` |

After copying, **substitute the five placeholders** (`{{package}}`, `{{feature}}`, `{{Feature}}`, `{{entity}}`, `{{Entity}}`) throughout every copied file. There is no template engine — do the substitution as an explicit edit pass and confirm no `{{` remains:

```bash
grep -rn '{{' "lib/features/$FEATURE" "test/features/$FEATURE" && echo "!! unsubstituted placeholders remain" || echo "placeholders clean"
```

## Step 4 — Fill in, in dependency order

Fill the stubs following **supy-flutter-feature**. Work inward-out so each layer compiles against the last:

1. **Domain** — `entities/{{entity}}.dart` (extends `Equatable`, pure Dart, business fields only), `repositories/{{feature}}_repository.dart` (abstract, methods return `Future<Either<Failure, T>>`), `usecases/get_{{feature}}.dart` (extends `UseCase<T, Params>`, one operation).
2. **Data** — `models/{{entity}}_model.dart` (`freezed` + `json_serializable`, `toEntity()` mapper), `datasources/` (real + fake, fake gated by `FlavorConfig.instance.useFakeData`), `repositories/{{feature}}_repository_impl.dart` (implements the domain interface, maps exceptions to `Failure`).
3. **Presentation** — `bloc/` (`Bloc` with sealed events + `freezed` state, injects UseCases, `fold`s both branches), `pages/{{feature}}_page.dart` (`static const path`/`name`, provides the BLoC via `BlocProvider(create: (_) => sl<{{Feature}}Bloc>())`).

## Step 5 — Run codegen

The `freezed` model and state need generated files:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Never hand-edit the resulting `*.g.dart` / `*.freezed.dart`.

## Step 6 — Wire the feature (the manual steps a stub cannot do)

These three cannot be auto-wired safely — print them and do them by hand:

1. **DI registration** — in `lib/app/injection_container.dart`, register datasources / repository / usecases as singletons and the BLoC as a factory:

   ```dart
   sl
     ..registerLazySingleton<{{Feature}}RemoteDatasource>(() => {{Feature}}RemoteDatasourceImpl(sl()))
     ..registerLazySingleton<{{Feature}}Repository>(() => {{Feature}}RepositoryImpl(sl()))
     ..registerLazySingleton(() => Get{{Feature}}(sl()))
     ..registerFactory(() => {{Feature}}Bloc(get{{Feature}}: sl()));
   ```

2. **Route** — in the `go_router` config, register the page with its `path` constant:

   ```dart
   GoRoute(path: {{Feature}}Page.path, name: {{Feature}}Page.name, builder: (_, __) => const {{Feature}}Page()),
   ```

3. **Barrel** — ensure `lib/features/$FEATURE/{{feature}}.dart` re-exports the public surface (page, bloc, domain entity/usecases meant for reuse) and nothing internal to `data/`.

## Step 7 — Tests

Both test stubs must assert behaviour — a lone `expect(x, isNotNull)` does not count. Fill:

- `data/repositories/{{feature}}_repository_impl_test.dart` — mock the datasource (`mocktail`); assert success maps to `Right`, and each thrown exception maps to the correct `Failure` via `Left`.
- `presentation/bloc/{{feature}}_bloc_test.dart` — mock the usecase; use `bloc_test` to assert the emitted state sequence for success (`loading → loaded`) and failure (`loading → error`).

## Step 8 — Verify

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
```

All three must pass before the feature is done. If `flutter analyze` reports a layering violation (e.g. a `domain/` file importing `package:flutter`), revisit Step 4 — the logic is in the wrong layer.

## Degradation paths

- **No `pubspec.yaml`:** stop — not a Flutter repo (Step 1).
- **Bundled stubs unreadable:** hand-create the files following **supy-flutter-feature**; keep the same layout and layer boundaries.
- **`lib/features/<feature>/` already exists:** stop — never overwrite an existing feature.
- **Repo generator present:** prefer it over the bundled stubs (Step 3); it matches the repo's exact conventions.
- **Cortex MCP available:** use `get_entity('<Entity>')` / `get_repo_guide` to pre-fill entity fields and datasource URIs; degrade silently to hand-fill if absent.
