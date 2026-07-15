---
source: supy-checklists (Supy Checklists Flutter app) CLAUDE.md
mined_on: 2026-07-15
confidence: high
---

# Flutter Architecture — Layers & Boundaries

Supy Flutter apps follow **Clean Architecture**: every feature is split into three layers — **presentation → domain ← data** — and dependencies point inward toward the domain. The domain is pure Dart with no Flutter, no `presentation/`, and no `data/` imports; presentation depends on domain only (never on data); data implements the domain's repository interfaces (never the reverse). Cross-cutting primitives (the `Failure` hierarchy, the `UseCase` base, Dio, cache) live in `lib/core/`; cross-feature UI and models live in `lib/shared/`. There is no Nx and no lint-enforced boundary graph — the boundary is enforced by import discipline and review. Companion coding rules live in [flutter-conventions.md](flutter-conventions.md).

## Rules

1. **Every feature has exactly three layers**, each in its own directory under `lib/features/<feature>/`:

   | Layer | Directory | Contains | May import |
   | --- | --- | --- | --- |
   | Presentation | `presentation/` | Pages, Widgets, BLoCs | its own domain layer, `shared/presentation`, `core` |
   | Domain | `domain/` | Entities, repository **interfaces**, UseCases | nothing but Dart, `dartz`, `equatable`, `core/error`, `core/usecases` |
   | Data | `data/` | Models (+ mappers), Datasources, repository **implementations** | its own domain layer, `core`, `shared/data` |

2. **Dependency direction points inward.** Presentation depends on Domain; Data depends on Domain; Domain depends on nothing. Never the reverse. A `domain/` file that imports from `presentation/` or `data/` is a defect; a `presentation/` file that imports from `data/` is a defect (presentation talks to the domain's UseCases, never to a datasource or a model).

3. **The domain layer is pure Dart.** No `package:flutter/*` import, no `BuildContext`, no widgets, no Dio, no Hive, no JSON. A domain entity extends `Equatable` and holds only business fields; a repository is an `abstract class` of method signatures returning `Future<Either<Failure, T>>`; a UseCase orchestrates one operation. If a domain file needs `package:flutter`, the logic is in the wrong layer.

4. **Data implements the domain's interfaces — one repository implementation per domain interface.** `data/repositories/<feature>_repository_impl.dart` implements `domain/repositories/<feature>_repository.dart`, calls its datasources, catches exceptions, and maps them to `Failure`s (see [flutter-conventions.md](flutter-conventions.md) — Either & failures). Models (`data/models/`) are `freezed` + `json_serializable` DTOs with a mapper to the domain entity; the domain never sees a model.

5. **Presentation is Pages → Widgets → BLoCs, and reaches the domain only through UseCases.** A BLoC injects UseCases (not repositories, not datasources), one BLoC per feature concern. Pages read/emit through the BLoC; widgets are presentational. Presentation never constructs a repository or a Dio call directly.

6. **`lib/core/` holds cross-cutting primitives; `lib/shared/` holds cross-feature code.** `core/` = the sealed `Failure` hierarchy (`core/error/`), the `UseCase`/`Params` base (`core/usecases/`), Dio + interceptor chain (`core/network/`), cache managers (`core/cache/`). `shared/` = the design system (`shared/presentation/design_system/`) and any entity/model reused by more than one feature. A feature never imports another feature's `domain/`, `data/`, or `presentation/` directly — shared concepts move to `shared/`.

7. **Dependency injection is centralized in `lib/app/injection_container.dart`** using `get_it`. Services, Dio, repository implementations, datasources, and UseCases register as `registerLazySingleton`; BLoCs register as `registerFactory` (a fresh instance per feature entry). No feature reaches into `GetIt` from inside the domain layer — resolution happens at the presentation boundary (where the BLoC is provided). See [flutter-conventions.md](flutter-conventions.md) — dependency injection.

8. **Adding a feature `foo`:** (1) create `lib/features/foo/{domain,data,presentation}/`; (2) fill in dependency order — domain entity + repo interface + usecases, then data model + datasources + repo impl, then presentation bloc + page; (3) register the usecases/repo/datasources (`registerLazySingleton`) and the BLoC (`registerFactory`) in `injection_container.dart`; (4) add the page's route to the `go_router` config with its `static const path`. The `supy-scaffold-flutter-feature` skill does steps 1–2 from bundled stubs and prints steps 3–4.

## Examples

### Good — per-feature folder layout

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

### Good — domain repository interface (pure Dart, `Either`)

```dart
// features/tasks/domain/repositories/task_repository.dart
abstract class TaskRepository {
  Future<Either<Failure, List<Task>>> getTasks();
  Future<Either<Failure, Task>> completeTask(String id);
}
```

### Good — data implements the domain interface, maps exceptions to failures

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

### Good — injection wiring (singletons + bloc factory)

```dart
// app/injection_container.dart
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

## Source

- `supy-checklists` CLAUDE.md — the Clean Architecture layer split (presentation/domain/data), per-feature folder layout, dependency-direction rules, domain purity, `core/` vs `shared/` placement, and the `get_it` DI wiring in `lib/app/injection_container.dart`
- Companion coding conventions (BLoC, go_router, Dio, `Either`/`Failure`, design tokens) live in [flutter-conventions.md](flutter-conventions.md)
