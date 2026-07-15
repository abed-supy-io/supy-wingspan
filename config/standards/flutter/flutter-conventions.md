---
source: supy-checklists (Supy Checklists Flutter app) CLAUDE.md
mined_on: 2026-07-15
confidence: high
---

# Flutter Conventions

Supy Flutter apps are **Dart 3.11 + Flutter 3.41 + bloc/flutter_bloc + go_router + get_it + dio + dartz + freezed + hive + mocktail/bloc_test**, analysed with **`very_good_analysis` + `bloc_lint`** via `analysis_options.yaml`. These rules govern what goes inside a layer; the layer split, folder layout, and dependency direction live in the companion [architecture.md](architecture.md). There is no ESLint and no Nx — enforcement is `flutter analyze` + `bloc_lint` + review.

## Rules

### State management (BLoC)

1. **Always `Bloc`, never `Cubit`.** Every feature concern is a `Bloc` with an explicit event/state contract. `Cubit` hides the event history and is banned.
2. **Events are a sealed (or `abstract`) class hierarchy**; one event class per user intent. States are `freezed` unions (or a sealed hierarchy) with explicit `initial`/`loading`/`loaded`/`error` shapes — no untyped `bool isLoading` soup.
3. **One BLoC per feature concern.** Register it as a `registerFactory` in `injection_container.dart` and provide it at the owning feature widget via `BlocProvider`. Never make a BLoC a global singleton.
4. **BLoCs hold logic; widgets hold none.** Widgets dispatch events and render state via `BlocBuilder`/`BlocListener`/`context.read`/`context.watch`. No business branching inside `build()`.

### Navigation (go_router)

5. **Navigate with `context.go('/path')` using the page's `path` constant.** Never `pushNamed`, `goNamed`, `push`, or `context.push(...)`, and never pass data via `extra` — pass IDs in the path/query and re-fetch. Named routes and `extra` payloads are banned.
6. **Every page exposes `static const path` and `static const name`** and is registered once in the `go_router` config. Route strings are declared on the page, not scattered at call sites.
7. **Auth and role guards live in the router `redirect`** — not in `initState`, not in widgets. An unauthenticated or under-privileged user is redirected before the page builds.

### Dependency injection (get_it)

8. **One `get_it` container, configured in `lib/app/injection_container.dart`.** Services, Dio, repository implementations, datasources, and UseCases register as `registerLazySingleton`; BLoCs register as `registerFactory`. (Restated from [architecture.md](architecture.md) rule 7 because it is the most-violated rule.)
9. **`get_it` is the only DI mechanism.** No `riverpod`, no `provider` for dependency injection (`flutter_bloc`'s `BlocProvider` is for BLoC lifecycle, not general DI).

### Functional error handling (dartz)

10. **Every repository and usecase method returns `Future<Either<Failure, T>>`.** The domain layer **never throws** and never returns a raw value or a nullable-on-error.
11. **Exceptions are caught in the data layer and mapped to a `Failure`.** The failure type is the sealed hierarchy: `ServerFailure`, `NetworkFailure`, `CacheFailure`, `AuthFailure`, `ValidationFailure`, `UnknownFailure`. No other failure types; no bare `Exception` crossing a layer boundary.
12. **Consumers resolve `Either` explicitly with `fold`** (Left → error state, Right → data state). Never `getOrElse`/`(r as Right).value` to discard the error branch silently.

### UseCases

13. **Every usecase extends the `UseCase<T, Params>` base** and implements `Future<Either<Failure, T>> call(Params params)`. `Params` extends `Equatable`; a parameter-less usecase takes `NoParams`. One operation per usecase.

### Networking (Dio)

14. **The Dio interceptor chain is ordered `auth → cache → retry → error → logging`.** This order is intentional (auth attaches the token before anything else; logging sees the final outcome) — don't reorder or drop links without reason.
15. **The fake remote datasource is gated by `FlavorConfig.instance.useFakeData`.** `FakeChecklistRemoteDatasource` (and any fake) is selected in DI by the flavor flag, never by commenting code in and out.

### Caching (Hive)

16. **Caching goes through `HiveCacheManager` + `CacheInterceptor` with an explicit policy** — one of `cacheFirst`, `networkFirst`, `staleWhileRevalidate`, `networkOnly`. Pick the policy per request; don't read/write Hive boxes ad hoc from a repository.

### Serialization & codegen

17. **Models use `freezed` + `json_serializable` + `json_annotation`.** Regenerate with `dart run build_runner build --delete-conflicting-outputs`. Never hand-edit or hand-write `*.g.dart` / `*.freezed.dart` — they are generated artifacts.

### Design system

18. **Colors come from the design system, never literals.** Use `context.supyColors` (primitives) / `context.colors` (semantic `ColorTokens`). Never `Color(0xFF…)` and never `Colors.*`.
19. **Spacing and radius come from tokens.** Use the spacing scale (`xxs`=2 … `lg`=14 … `giant`=56) and `SupyRadius` — never raw numeric `EdgeInsets`/`SizedBox` values, and never `EdgeInsets.fromLTRB(...)`.
20. **Typography comes from the theme.** Use `context.textTheme` / `SupyTypography` — never construct a `TextStyle(...)` inline.

### Testing

21. **Test with `mocktail` + `bloc_test`, ≥80% coverage.** Mock at the boundary (datasource or repository), **never mock the class under test**. Widget tests use the shared `pumpApp` helper so theme, router, and providers are wired consistently.

### Flavors & security

22. **Three flavors — dev / staging / production — via `main_dev.dart` / `main_stg.dart` / `main_prod.dart` + `FlavorConfig`.** Environment-specific values (base URL, fake-data flag, Sentry DSN) come from `FlavorConfig`, never hardcoded in feature code.
23. **Tokens live in `flutter_secure_storage`.** The auth interceptor attaches the bearer token; a `401` triggers the session-expiry flow (not a silent retry). Sentry breadcrumbs are sanitized — never log tokens, credentials, or PII.

### Commits

24. **Conventional Commits.** Subject line is imperative mood, **≤50 characters**, with **no trailing period**. Body (if any) explains the why.

## Examples

### Good — BLoC with sealed events and freezed state

```dart
// presentation/bloc/tasks_event.dart
sealed class TasksEvent extends Equatable {
  const TasksEvent();
  @override
  List<Object?> get props => [];
}

final class TasksRequested extends TasksEvent {
  const TasksRequested();
}

final class TaskCompleted extends TasksEvent {
  const TaskCompleted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

// presentation/bloc/tasks_state.dart
@freezed
class TasksState with _$TasksState {
  const factory TasksState.initial() = _Initial;
  const factory TasksState.loading() = _Loading;
  const factory TasksState.loaded(List<Task> tasks) = _Loaded;
  const factory TasksState.error(Failure failure) = _Error;
}
```

### Good — usecase on the `UseCase` base, resolved with `fold`

```dart
// core/usecases/usecase.dart
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

abstract class Params extends Equatable {
  const Params();
}

// features/tasks/domain/usecases/get_tasks.dart
class GetTasks extends UseCase<List<Task>, NoParams> {
  GetTasks(this._repository);
  final TaskRepository _repository;

  @override
  Future<Either<Failure, List<Task>>> call(NoParams params) => _repository.getTasks();
}

// in the BLoC event handler
final result = await _getTasks(const NoParams());
result.fold(
  (failure) => emit(TasksState.error(failure)),
  (tasks) => emit(TasksState.loaded(tasks)),
);
```

### Good — page with `static const path` and `context.go`

```dart
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});
  static const path = '/tasks';
  static const name = 'tasks';

  @override
  Widget build(BuildContext context) => const _TasksView();
}

// navigating elsewhere — hardcoded path, no goNamed / extra
onTap: () => context.go(TaskDetailPage.path.replaceFirst(':id', task.id)),
```

### Good — sealed Failure hierarchy

```dart
// core/error/failures.dart
sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure { const ServerFailure(super.message); }
class NetworkFailure extends Failure { const NetworkFailure(super.message); }
class CacheFailure extends Failure { const CacheFailure(super.message); }
class AuthFailure extends Failure { const AuthFailure(super.message); }
class ValidationFailure extends Failure { const ValidationFailure(super.message); }
class UnknownFailure extends Failure { const UnknownFailure(super.message); }
```

### Good — design tokens (colors, spacing, typography from the system)

```dart
Container(
  padding: EdgeInsets.all(context.spacing.md),
  decoration: BoxDecoration(
    color: context.colors.surface,
    borderRadius: SupyRadius.md,
  ),
  child: Text('Prep station', style: context.textTheme.titleMedium),
);
```

### Good — bloc_test with mocked boundary

```dart
class _MockGetTasks extends Mock implements GetTasks {}

blocTest<TasksBloc, TasksState>(
  'emits [loading, loaded] when tasks are fetched',
  setUp: () => when(() => getTasks(const NoParams()))
      .thenAnswer((_) async => Right(tasks)),
  build: () => TasksBloc(getTasks: getTasks),
  act: (bloc) => bloc.add(const TasksRequested()),
  expect: () => [const TasksState.loading(), TasksState.loaded(tasks)],
);
```

## Red flags

These are auto-reject in review — each maps to the fix on its right:

- A `Cubit` → convert to a `Bloc` with explicit sealed events.
- An event or state that isn't a typed class (untyped `bool`/`String` state flags) → sealed event hierarchy + `freezed` state union.
- A BLoC registered as `registerLazySingleton` (or a repo/usecase as `registerFactory`) → factory for BLoCs, singleton for the rest.
- `pushNamed` / `goNamed` / `context.push` / navigation via `extra` → `context.go('/path')` with the page's `path` constant; pass IDs in the path/query.
- A page missing `static const path` / `name`, or a route string written at the call site → declare it on the page.
- An auth/role check in `initState` or a widget → move it to the `go_router` `redirect`.
- `riverpod` / `provider` used for dependency injection → `get_it`.
- A repository or usecase returning a raw value / nullable / throwing → `Future<Either<Failure, T>>`; catch in data, map to a `Failure`.
- A `Failure` type outside the sealed hierarchy, or a bare `Exception` crossing a layer → one of `ServerFailure`/`NetworkFailure`/`CacheFailure`/`AuthFailure`/`ValidationFailure`/`UnknownFailure`.
- `getOrElse` / `(x as Right).value` discarding the Left branch → `fold` both branches explicitly.
- A usecase not extending `UseCase<T, Params>`, or `Params` not extending `Equatable` → use the base + `NoParams`.
- A reordered/missing Dio interceptor → keep the `auth → cache → retry → error → logging` order.
- Fake data toggled by commenting code → gate on `FlavorConfig.instance.useFakeData`.
- Ad-hoc Hive box reads/writes in a repository → go through `HiveCacheManager` + `CacheInterceptor` with an explicit policy.
- Hand-edited `*.g.dart` / `*.freezed.dart` → regenerate with `dart run build_runner build --delete-conflicting-outputs`.
- `Color(0xFF…)` / `Colors.*` → `context.supyColors` / `context.colors`.
- Raw numeric spacing, `EdgeInsets.fromLTRB(...)`, or inline `TextStyle(...)` → spacing tokens / `SupyRadius` / `context.textTheme`.
- Mocking the class under test → mock the datasource/repository boundary only.
- A token, credential, or PII in a log or Sentry breadcrumb → sanitize; secrets live in `flutter_secure_storage`.
- A hardcoded environment value (base URL, DSN) in feature code → read it from `FlavorConfig`.

## Source

- `supy-checklists` CLAUDE.md — the enforced Flutter rulebook: BLoC-not-Cubit state management, `go_router` `context.go` navigation, `get_it` DI split, `dio` interceptor order, `dartz` `Either`/sealed `Failure` handling, `UseCase`/`Params` base, `hive` cache policies, the `SupyColors`/`ColorTokens`/spacing/`SupyRadius`/`SupyTypography` design system, `freezed`/`json_serializable` codegen, `mocktail`/`bloc_test`/`pumpApp` testing, dev/staging/production flavors + `FlavorConfig`, `flutter_secure_storage` + sanitized Sentry, and Conventional Commits
- Analysis is enforced by `very_good_analysis` + `bloc_lint` in `analysis_options.yaml` (shipped in `templates/flutter/`)
- Layer split, folder layout, and dependency direction: [architecture.md](architecture.md)
