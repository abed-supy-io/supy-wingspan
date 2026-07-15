---
source: supy-checklists (Profile A app), supy-mobile (Profile B app), supy-scanner (plugin sub-profile), supy-flutter-packages (melos-packages sub-profile)
mined_on: 2026-07-15
confidence: high
---

# Flutter Architecture — Layers & Boundaries

Supy Flutter apps follow **Clean Architecture**: every feature is split into layers — **presentation → domain ← data** — and dependencies point inward toward the domain. The domain is pure Dart with no Flutter, no `presentation/`, and no `data/` imports; presentation depends on domain only (never on data); data implements the domain's repository interfaces (never the reverse). Cross-cutting primitives (the error/exception types, the `UseCase` base, Dio, cache) live in `lib/core/`; cross-feature UI and models live in `lib/shared/`. There is no Nx and no lint-enforced boundary graph — the boundary is enforced by import discipline and review.

Supy has **two sanctioned app profiles** that share this architecture and diverge on one axis only — how errors cross the data→presentation boundary — plus **two library sub-profiles** (a native plugin and a melos package monorepo) that are not apps and follow a reduced rule set. Read [## Profiles](#profiles) first to identify which one a repo is; the numbered rules below are the **app profile** (A and B) and, where A and B differ, the rule spells out both. Companion coding rules live in [flutter-conventions.md](flutter-conventions.md).

## Profiles

A Flutter repo is exactly one of four shapes. Identify it before applying any rule.

| Profile | What it is | Source repo | Detect by |
|---|---|---|---|
| **A — Either app** | Feature app, functional error handling | `supy-checklists` | `dartz` in `pubspec.yaml` |
| **B — PageState app** | Feature app, exception-based error handling | `supy-mobile` | app repo, `dartz` **absent** |
| **Plugin sub-profile** | Federated native plugin (no app runtime) | `supy-scanner` | `flutter.plugin.platforms` in `pubspec.yaml` |
| **Melos-packages sub-profile** | Monorepo of published packages | `supy-flutter-packages` | `melos.yaml` at repo root |

**Profiles A and B are identical in every architectural rule below except error transport and feature-folder layout.** A repo commits to one profile and applies it consistently — **a repo that uses both `dartz`/`Either` and `PageState`/`throwAppException` for error handling is a red flag** (see Red flags). App-profile rules 1–8 apply to both A and B; where they differ, the rule spells out both. The library sub-profiles do **not** follow rules 1–8 — they have their own rule sets (P1–P6, M1–M5) below.

### App profile — error transport (A vs B)

| | A — Either | B — PageState |
|---|---|---|
| Repo/usecase return | `Future<Either<Failure, T>>` | bare `Future<T>` |
| Data-layer error handling | catch exception → return `Left(Failure)` | catch exception → `throwAppException(e)` (typed `AppException`) |
| Domain on error | never throws; returns `Left` | throws a translated `AppException` |
| Presentation state | `freezed` union (initial/loading/loaded/error) | `PageState<T>` sealed union (init/loading/success/empty/failure) |
| Consumer resolves | `result.fold(onLeft, onRight)` | `state.when(...)` / `whenOrNull` / `maybeWhen`; `isLoading`/`isSuccess` guards |

Coding-rule detail (the sealed `Failure` hierarchy for A; `throwAppException()` + `PageState<T>` for B) is in [flutter-conventions.md](flutter-conventions.md) rules 10–12.

### App profile — feature-folder layout (A vs B)

- **Profile A** — `lib/features/<feature>/{domain,data,presentation}/` (three layers; see rule 1).
- **Profile B** — `lib/features/<feature>/{application,domain,data,presentation,injection}/`: adds `application/` (app-service orchestration / cross-usecase coordination sitting between presentation and domain) and a feature-scoped `injection/<feature>_dependencies.dart` (rather than one central `injection_container.dart`). `domain`/`data`/`presentation` mean the same thing and obey the same dependency direction as Profile A.

### Plugin sub-profile (`supy-scanner`)

A federated native plugin (barcode/document scanner) — a **library, not an app**. App rules 1–8 and the BLoC/go_router/get_it conventions do **not** apply. Its rules:

- **P1. A versioned `MethodChannel` is the single native boundary.** Name it with an explicit version segment (`io.supy.scanner/v1`); a breaking native change bumps the version rather than mutating the existing channel silently. Wrap the channel in one singleton with typed methods — callers never touch `MethodChannel` directly. A platform-interface package defines the contract that the app-facing package and the native implementations both depend on.
- **P2. Nothing `dynamic` crosses the boundary.** Native results marshal into **sealed result types / immutable value objects** (`==`/`hashCode`/`toString`); no raw `Map`/`dynamic` leaks to consumers. No `dynamic` calls, no `runtimeType.toString()`.
- **P3. Streaming uses a per-view `EventChannel`;** a `PlatformView` (`AndroidView`/`UiKitView`) wraps the native camera view; a controller object exposes lifecycle/config (pause/torch/formats).
- **P4. Native work stays off the platform main thread** (Android analyzer thread / iOS background `DispatchQueue`, `VNRequest` off main) and marshals results back to main; hardware lifecycle is bound independently of the widget lifecycle and released on dispose. This **native-bridge hardening** — threading, resource cleanup, and exception translation at the bridge — is the plugin's core review concern.
- **P5. No app-level DI (`get_it`), no BLoC, no go_router.** The plugin exposes a `ChangeNotifier` + streams and lets the *consuming app* wrap them.
- **P6. Coverage gate is 70% lcov (Dart)**; native code has its own tests (Robolectric on the JVM, XCTest on iOS). See [flutter-conventions.md](flutter-conventions.md) rule 21.

### Melos-packages sub-profile (`supy-flutter-packages`)

A **melos monorepo** of independently-published pub.dev packages — a library repo, not an app. App rules 1–8 do not apply. Its rules:

- **M1. Packages are independently releasable with zero inter-package coupling.** A package under `packages/<pkg>/` must not import another package in the same repo; shared concerns get their own package or are duplicated deliberately, not cross-imported.
- **M2. Public API is a barrel export.** `lib/<pkg>.dart` re-exports from `src/*`; everything under `src/` is private-by-convention and not imported directly by consumers.
- **M3. Coverage gate is 85% per package** (higher than the 80% app bar) via `very_good_coverage`. See [flutter-conventions.md](flutter-conventions.md) rule 21.
- **M4. Analysis config is chosen by package nature:** `very_good_analysis` for Flutter-heavy packages, `lints:recommended` for pure-Dart packages. Pick one per package; don't leave a package with no analysis config.
- **M5. CI is per-package with path-based triggers** (a change under `packages/a/` runs only `a`'s jobs); melos is used for bootstrap/`analyze`. Versions live in each `pubspec.yaml`; publishing to pub.dev is deliberate.

## Rules

1. **Every feature is split into layers**, each in its own directory under `lib/features/<feature>/`. **Profile A** uses three (`domain`, `data`, `presentation`); **Profile B** uses five — the same three plus `application/` and a feature-scoped `injection/` (see [## Profiles](#profiles) — feature-folder layout):

   | Layer | Directory | Contains | May import |
   | --- | --- | --- | --- |
   | Presentation | `presentation/` | Pages, Widgets, BLoCs | its own domain/application layer, `shared/presentation`, `core` |
   | Application *(Profile B only)* | `application/` | App services / cross-usecase orchestration | its own domain layer, `core` |
   | Domain | `domain/` | Entities, repository **interfaces**, UseCases | nothing but Dart, `equatable`, `core/error`, `core/usecases` (Profile A also `dartz`) |
   | Data | `data/` | Models (+ mappers), Datasources, repository **implementations** | its own domain layer, `core`, `shared/data` |
   | Injection *(Profile B only)* | `injection/` | `<feature>_dependencies.dart` registrations | the feature's own layers, `core` |

2. **Dependency direction points inward.** Presentation depends on Domain; Data depends on Domain; Domain depends on nothing. Never the reverse. A `domain/` file that imports from `presentation/` or `data/` is a defect; a `presentation/` file that imports from `data/` is a defect (presentation talks to the domain's UseCases, never to a datasource or a model).

3. **The domain layer is pure Dart.** No `package:flutter/*` import, no `BuildContext`, no widgets, no Dio, no Hive, no JSON. A domain entity extends `Equatable` and holds only business fields; a UseCase orchestrates one operation. The repository interface's return type is profile-specific: **Profile A** — an `abstract class` of methods returning `Future<Either<Failure, T>>`; **Profile B** — an `abstract class` of methods returning bare `Future<T>` (errors surface as thrown `AppException`s, not `Left`). If a domain file needs `package:flutter`, the logic is in the wrong layer.

4. **Data implements the domain's interfaces — one repository implementation per domain interface.** `data/repositories/<feature>_repository_impl.dart` implements `domain/repositories/<feature>_repository.dart`, calls its datasources, and translates errors at the boundary — profile-specific: **Profile A** catches exceptions and maps them to `Failure`s returned as `Left`; **Profile B** catches exceptions and re-throws typed `AppException`s via the central `throwAppException(e)` (see [flutter-conventions.md](flutter-conventions.md) rules 10–12). Models (`data/models/`) are `freezed` + `json_serializable` DTOs with a mapper to the domain entity; the domain never sees a model.

5. **Presentation is Pages → Widgets → BLoCs, and reaches the domain only through UseCases.** A BLoC injects UseCases (not repositories, not datasources), one BLoC per feature concern. Pages read/emit through the BLoC; widgets are presentational. Presentation never constructs a repository or a Dio call directly.

6. **`lib/core/` holds cross-cutting primitives; `lib/shared/` holds cross-feature code.** `core/` = the error types in `core/error/` (**Profile A**: the sealed `Failure` hierarchy; **Profile B**: the typed `AppException` hierarchy + `throwAppException`), the `UseCase`/`Params` base (`core/usecases/`), Dio + interceptor chain (`core/network/`), cache managers (`core/cache/`). `shared/` = the design system (`shared/presentation/design_system/`) and any entity/model reused by more than one feature. A feature never imports another feature's `domain/`, `data/`, or `presentation/` directly — shared concepts move to `shared/`.

7. **Dependency injection uses `get_it`; where registrations live is profile-specific.** **Profile A** centralizes all registrations in `lib/app/injection_container.dart`. **Profile B** splits them per feature into `lib/features/<feature>/injection/<feature>_dependencies.dart`, each exposing an init function that a top-level bootstrap calls. Either way: services, Dio, repository implementations, datasources, and UseCases register as `registerLazySingleton`; BLoCs register as `registerFactory` (a fresh instance per feature entry). No feature reaches into `GetIt` from inside the domain layer — resolution happens at the presentation boundary (where the BLoC is provided). See [flutter-conventions.md](flutter-conventions.md) — dependency injection.

8. **Adding a feature `foo`:** (1) create `lib/features/foo/{domain,data,presentation}/` (Profile B also `application/` and `injection/`); (2) fill in dependency order — domain entity + repo interface + usecases, then data model + datasources + repo impl, then presentation bloc + page; (3) register the usecases/repo/datasources (`registerLazySingleton`) and the BLoC (`registerFactory`) — in `injection_container.dart` for Profile A, or in `injection/foo_dependencies.dart` wired into the bootstrap for Profile B; (4) add the page's route to the `go_router` config with its `static const path`. The `supy-scaffold-flutter-feature` skill does steps 1–2 from bundled stubs (Profile A layout) and prints steps 3–4.

## Examples

### Good — per-feature folder layout (Profile A)

The tree below is the **Profile A** (Either) layout. **Profile B** adds `application/` and `injection/` under each feature and drops `dartz`/`Either` (repositories return bare `Future<T>`; presentation wraps `PageState<T>`) — see [## Profiles](#profiles).

```text
lib/
  app/
    injection_container.dart      # get_it registrations (singletons + bloc factories)
    router/app_router.dart        # go_router config
    flavor_config.dart            # dev / staging / production
  core/
    error/failures.dart           # sealed Failure hierarchy
    usecases/usecase.dart         # UseCase<T, Params> + Params base
    network/                      # Dio + interceptor chain
    cache/                        # Hive managers, cache policies
  shared/
    presentation/design_system/   # SupyColors, ColorTokens, spacing, typography
  features/
    tasks/
      domain/
        entities/task.dart                 # extends Equatable, pure Dart
        repositories/task_repository.dart   # abstract, returns Either<Failure, T>
        usecases/get_tasks.dart             # UseCase<List<Task>, GetTasksParams>
      data/
        models/task_model.dart              # freezed + json_serializable + toEntity()
        datasources/
          task_remote_datasource.dart
          fake_task_remote_datasource.dart  # gated by FlavorConfig.useFakeData
        repositories/task_repository_impl.dart  # implements domain interface
      presentation/
        bloc/{tasks_bloc.dart,tasks_event.dart,tasks_state.dart}
        pages/tasks_page.dart               # static const path
        widgets/task_tile.dart
```

### Good — domain repository interface (Profile A: pure Dart, `Either`)

```dart
// features/tasks/domain/repositories/task_repository.dart
abstract class TaskRepository {
  Future<Either<Failure, List<Task>>> getTasks();
  Future<Either<Failure, Task>> completeTask(String id);
}
```

### Good — data implements the domain interface, maps exceptions to failures (Profile A)

```dart
// features/tasks/data/repositories/task_repository_impl.dart
class TaskRepositoryImpl implements TaskRepository {
  const TaskRepositoryImpl(this._remote);
  final TaskRemoteDatasource _remote;

  @override
  Future<Either<Failure, List<Task>>> getTasks() async {
    try {
      final models = await _remote.getTasks();
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Request failed'));
    } on SocketException {
      return const Left(NetworkFailure('No connection'));
    }
  }
}
```

### Good — Profile B equivalent (bare `Future`, `throwAppException`, `PageState`)

Same feature, Profile B. The repository interface returns bare `Future<T>`; the impl re-throws via the central `throwAppException`; presentation exposes a `PageState<T>` instead of an `Either`. Full coding detail is in [flutter-conventions.md](flutter-conventions.md) rules 10–12.

```dart
// features/tasks/domain/repositories/task_repository.dart
abstract class TaskRepository {
  Future<List<Task>> getTasks();          // bare Future — no Either
  Future<Task> completeTask(String id);
}

// features/tasks/data/repositories/task_repository_impl.dart
class TaskRepositoryImpl implements TaskRepository {
  const TaskRepositoryImpl(this._remote);
  final TaskRemoteDatasource _remote;

  @override
  Future<List<Task>> getTasks() async {
    try {
      final models = await _remote.getTasks();
      return models.map((m) => m.toEntity()).toList();
    } catch (e, s) {
      throwAppException(e, s);            // central translation → typed AppException
    }
  }
}
```

### Good — injection wiring (singletons + bloc factory)

Profile A centralizes registrations in `app/injection_container.dart` (shown). Profile B splits the identical registrations into `features/tasks/injection/tasks_dependencies.dart`, wired into a bootstrap.

```dart
// app/injection_container.dart  (Profile A)
sl
  ..registerLazySingleton<TaskRemoteDatasource>(() => TaskRemoteDatasourceImpl(sl()))
  ..registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(sl()))
  ..registerLazySingleton(() => GetTasks(sl()))
  ..registerFactory(() => TasksBloc(getTasks: sl(), completeTask: sl()));
```

## Red flags

These are auto-reject in review — each maps to the fix on its right:

- A `domain/` file importing `package:flutter/*`, `BuildContext`, a widget, Dio, Hive, or JSON → move the logic out; domain is pure Dart.
- A `domain/` file importing from `data/` or `presentation/` → invert the dependency; domain depends on nothing.
- A `presentation/` file importing from `data/` (a model, a datasource, a repository impl) → go through a UseCase; presentation depends on domain only.
- A BLoC injecting a repository or datasource directly instead of UseCases → inject UseCases.
- A repository implementation living in `domain/`, or an interface living in `data/` → interface in `domain/repositories/`, impl in `data/repositories/`.
- A domain entity carrying `fromJson`/`toJson` or `@JsonKey` → that's a model; keep serialization in `data/models/`, entity stays pure.
- One feature importing another feature's `domain/`/`data/`/`presentation/` → promote the shared concept to `lib/shared/`.
- A datasource, repository, or usecase registered as `registerFactory`, or a BLoC registered as `registerLazySingleton` → singletons for services/repos/usecases, factory for BLoCs.
- `GetIt.instance` resolved from inside a domain or data class → resolve at the presentation boundary; pass dependencies through constructors.
- **A repo mixing error-handling profiles** — some methods returning `Future<Either<Failure, T>>` while others return bare `Future<T>` + `throwAppException`, or a `pubspec.yaml` that depends on `dartz` yet a presentation layer built on `PageState<T>` → pick **one** profile for the whole app (see [## Profiles](#profiles)) and apply it consistently.
- **An app-profile rule applied to a library sub-profile** — expecting BLoC/go_router/`get_it`/three-layer features in the `supy-scanner` plugin or a `supy-flutter-packages` melos package → libraries follow the Plugin (P1–P6) or Melos (M1–M5) rules, not app rules 1–8.

## Source

- `supy-checklists` CLAUDE.md — **Profile A**: the Clean Architecture layer split (presentation/domain/data), per-feature folder layout, dependency-direction rules, domain purity, `core/` vs `shared/` placement, the `dartz` `Either<Failure, T>` transport, and the centralized `get_it` DI wiring in `lib/app/injection_container.dart`
- `supy-mobile` — **Profile B**: bare `Future<T>` repositories, central `throwAppException()` → typed `AppException`, `PageState<T>` sealed presentation state, the `{application,domain,data,presentation,injection}` feature layout, and feature-scoped `injection/<feature>_dependencies.dart`
- `supy-scanner` — **Plugin sub-profile**: versioned `MethodChannel` (`io.supy.scanner/v1`) singleton boundary + platform-interface package, sealed result types, per-view `EventChannel` + `PlatformView` + controller, native-bridge hardening (off-main-thread work, resource cleanup, exception translation), `ChangeNotifier` + streams (no BLoC/go_router/get_it)
- `supy-flutter-packages` — **Melos-packages sub-profile**: melos monorepo, zero inter-package coupling, `lib/<pkg>.dart` barrel exports, per-package `very_good_coverage` gate, dual analysis config, per-package path-filtered CI, pub.dev publishing
- Companion coding conventions (BLoC, go_router, Dio, the two error-transport profiles, design tokens) live in [flutter-conventions.md](flutter-conventions.md)
