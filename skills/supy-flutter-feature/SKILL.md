---
name: supy-flutter-feature
description: How to write Flutter code in a supy mobile repo the Supy way — Clean Architecture layers, Bloc (never Cubit), go_router context.go, get_it DI, dartz Either/Failure, design tokens. Use whenever writing or editing Dart/Flutter code under lib/ in a flutter supy repo.
---

## When this applies

Any time you write or edit Dart/Flutter code under `lib/` in a Supy mobile repo (Dart 3.11 + Flutter 3.41 + bloc/flutter_bloc + go_router + get_it + dio + dartz + freezed + hive). This skill is the how-to; the enforced rulebook is the governing standard.

## Step 0 — Read the governing standard

Ground every decision in the standards files. Read them before writing code:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/flutter/architecture.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/flutter/flutter-conventions.md"
```

If either is unreadable, print a warning and continue using the rules below as a fallback — never hard-fail.

## The three rules that govern everything

1. **Clean Architecture, dependencies point inward.** Presentation → Domain ← Data. The domain is pure Dart (no `package:flutter`, no Dio, no JSON); presentation never touches `data/`; data implements the domain's interfaces. Cross-feature code lives in `lib/shared/`, primitives in `lib/core/`.
2. **Always `Bloc`, never `Cubit`.** Every feature concern is a `Bloc` with a sealed event contract and a `freezed` (or sealed) state. Repositories and usecases return `Future<Either<Failure, T>>` — the domain **never throws**.
3. **Everything comes from a token or the container.** Navigate with `context.go` and the page's `path` constant (never `pushNamed`/`extra`); resolve dependencies through `get_it` (singletons for services/repos/usecases/datasources, factory for BLoCs); style with design tokens (never `Color(0xFF…)`/`Colors.*`/raw spacing/inline `TextStyle`).

Everything below is the concrete shape these rules take.

## Layers & folders

A feature lives under `lib/features/<feature>/` split into `domain/`, `data/`, `presentation/`. Fill them in dependency order: domain first (entity → repository interface → usecases), then data (model → datasources → repository impl), then presentation (bloc → page → widgets). See `${CLAUDE_PLUGIN_ROOT}/config/standards/flutter/architecture.md` for the full tree.

## Domain

Pure Dart. The entity extends `Equatable`; the repository is an `abstract class` of method signatures returning `Either<Failure, T>`; each usecase extends `UseCase<T, Params>` and does one thing.

```dart
// domain/entities/task.dart
class Task extends Equatable {
  const Task({required this.id, required this.title, required this.isDone});
  final String id;
  final String title;
  final bool isDone;
  @override
  List<Object?> get props => [id, title, isDone];
}

// domain/repositories/task_repository.dart
abstract class TaskRepository {
  Future<Either<Failure, List<Task>>> getTasks();
  Future<Either<Failure, Task>> completeTask(String id);
}

// domain/usecases/get_tasks.dart
class GetTasks extends UseCase<List<Task>, NoParams> {
  GetTasks(this._repository);
  final TaskRepository _repository;
  @override
  Future<Either<Failure, List<Task>>> call(NoParams params) => _repository.getTasks();
}
```

## Data

Models are `freezed` + `json_serializable` DTOs with a `toEntity()` mapper. The repository implementation implements the domain interface, calls its datasources, and maps exceptions to a `Failure` — the domain never sees an exception. Regenerate codegen with `dart run build_runner build --delete-conflicting-outputs`; never hand-edit `*.g.dart`/`*.freezed.dart`.

```dart
// data/repositories/task_repository_impl.dart
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

The fake datasource is selected in DI by `FlavorConfig.instance.useFakeData` — never by commenting code in and out.

## Presentation (BLoC)

One `Bloc` per feature concern. Events are a sealed hierarchy; state is a `freezed` union. The BLoC injects **UseCases** (not repositories), and resolves every `Either` with `fold` — Left → error state, Right → data state.

```dart
sealed class TasksEvent extends Equatable {
  const TasksEvent();
  @override
  List<Object?> get props => [];
}
final class TasksRequested extends TasksEvent { const TasksRequested(); }

@freezed
class TasksState with _$TasksState {
  const factory TasksState.initial() = _Initial;
  const factory TasksState.loading() = _Loading;
  const factory TasksState.loaded(List<Task> tasks) = _Loaded;
  const factory TasksState.error(Failure failure) = _Error;
}

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc({required GetTasks getTasks})
      : _getTasks = getTasks,
        super(const TasksState.initial()) {
    on<TasksRequested>((event, emit) async {
      emit(const TasksState.loading());
      final result = await _getTasks(const NoParams());
      result.fold(
        (failure) => emit(TasksState.error(failure)),
        (tasks) => emit(TasksState.loaded(tasks)),
      );
    });
  }
  final GetTasks _getTasks;
}
```

Provide the BLoC at the owning feature widget with `BlocProvider(create: (_) => sl<TasksBloc>())`. Widgets dispatch events and render state via `BlocBuilder`/`BlocListener` — no business logic in `build()`.

## Navigation (go_router)

Each page exposes `static const path` / `static const name`, is registered once in the router, and is reached with `context.go`. No `pushNamed`/`goNamed`/`push`/`extra`; pass IDs in the path. Auth/role guards live in the router `redirect`.

```dart
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});
  static const path = '/tasks';
  static const name = 'tasks';
  @override
  Widget build(BuildContext context) => const _TasksView();
}

// navigating with an id — hardcoded path, no goNamed / extra
onTap: () => context.go('/tasks/${task.id}'),
```

## Dependency injection (get_it)

Register everything in `lib/app/injection_container.dart`: services, Dio, datasources, repositories, and usecases as `registerLazySingleton`; BLoCs as `registerFactory`. No `riverpod`/`provider`.

```dart
sl
  ..registerLazySingleton<TaskRemoteDatasource>(() => TaskRemoteDatasourceImpl(sl()))
  ..registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(sl()))
  ..registerLazySingleton(() => GetTasks(sl()))
  ..registerFactory(() => TasksBloc(getTasks: sl()));
```

## Networking & caching

Requests go through Dio with the fixed interceptor order `auth → cache → retry → error → logging`. Caching goes through `HiveCacheManager` + `CacheInterceptor` with an explicit policy (`cacheFirst`/`networkFirst`/`staleWhileRevalidate`/`networkOnly`) — never ad-hoc Hive box access from a repository.

## Design system

Colors come from `context.supyColors` (primitives) / `context.colors` (semantic `ColorTokens`); spacing and radius from the spacing scale and `SupyRadius`; typography from `context.textTheme`. Never a `Color(0xFF…)`, `Colors.*`, raw numeric `EdgeInsets`/`EdgeInsets.fromLTRB`, or inline `TextStyle`.

```dart
Container(
  padding: EdgeInsets.all(context.spacing.md),
  decoration: BoxDecoration(color: context.colors.surface, borderRadius: SupyRadius.md),
  child: Text('Prep station', style: context.textTheme.titleMedium),
);
```

## Security & flavors

Tokens live in `flutter_secure_storage`; the auth interceptor attaches the bearer and a `401` triggers the session-expiry flow. Environment values (base URL, fake-data flag, Sentry DSN) come from `FlavorConfig` (dev/staging/production), never hardcoded. Sentry breadcrumbs are sanitized — never log a token or PII.

## Before you finish

- Domain stays pure Dart (no `package:flutter`, Dio, or JSON)?
- `Bloc` with sealed events + `freezed` state — no `Cubit`?
- Repos/usecases return `Either<Failure, T>`, domain never throws, consumer `fold`s both branches?
- Usecase extends `UseCase<T, Params>`, `Params extends Equatable`?
- Navigation is `context.go` + `path` constant — no `pushNamed`/`extra`?
- DI split correct — singletons for services/repos/usecases/datasources, factory for BLoCs?
- No `Color(0xFF…)`/`Colors.*`/raw spacing/inline `TextStyle` — tokens throughout?
- Tests use `mocktail` + `bloc_test`, mock the boundary (not the class under test), ≥80% coverage?

Run the verification suite:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
```

To scaffold a whole new feature (domain → data → presentation → wiring) from bundled stubs, use the **supy-scaffold-flutter-feature** skill instead of hand-creating files. To review a Flutter diff, use the **supy-flutter-reviewer** agent.
