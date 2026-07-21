---
source: supy-checklists (Profile A app), supy-mobile (Profile B app), supy-scanner (plugin sub-profile), supy-flutter-packages (melos-packages sub-profile)
mined_on: 2026-07-15
confidence: high
---

# Flutter Conventions

Supy Flutter apps are **Dart 3.11 + Flutter 3.41 + bloc/flutter_bloc + go_router + get_it + dio + freezed + hive + mocktail/bloc_test**, analysed with **`very_good_analysis` + `bloc_lint`** via `analysis_options.yaml`. These rules govern what goes inside a layer; the layer split, folder layout, and dependency direction live in the companion [architecture.md](architecture.md). There is no ESLint and no Nx — enforcement is `flutter analyze` + `bloc_lint` + review.

**Error handling differs by profile.** Supy runs two sanctioned app profiles that share every rule below except how errors cross the data→presentation boundary: **Profile A** (source `supy-checklists`) uses `dartz` `Either<Failure, T>`; **Profile B** (source `supy-mobile`) uses bare `Future<T>` + a central `throwAppException()` + `PageState<T>`. **The profile is selected by whether `dartz` is a dependency in `pubspec.yaml`** (present → A, absent → B). Rules 10–12 spell out both variants; a repo commits to one profile and never mixes them. The two library sub-profiles — the `supy-scanner` native plugin and the `supy-flutter-packages` melos monorepo — are not apps and follow their own reduced rule sets; see [architecture.md — Profiles](architecture.md#profiles).

## Rules

### State management (BLoC)

1. **Always `Bloc`, never `Cubit`.** Every feature concern is a `Bloc` with an explicit event/state contract. `Cubit` hides the event history and is banned.
2. **Events are a sealed (or `abstract`) class hierarchy**; one event class per user intent. States are `freezed` unions (or a sealed hierarchy) with explicit `initial`/`loading`/`loaded`/`error` shapes — no untyped `bool isLoading` soup.
3. **One BLoC per feature concern.** Register it as a `registerFactory` in `injection_container.dart` and provide it at the owning feature widget via `BlocProvider`. Never make a BLoC a global singleton.
4. **BLoCs hold logic; widgets hold none.** Widgets dispatch events and render state via `BlocBuilder`/`BlocListener`/`context.read`/`context.watch`. No business branching inside `build()`.

### Navigation (go_router)

5. **Navigate with `context.push('/path')` using the page's `path` constant; reserve `context.go('/path')` for the main shell pages** — the top-level shell/tab destinations (bottom-nav roots). Use `push` when drilling into detail and sub-pages so the back stack is preserved; use `go` only when switching between the main shell destinations. Never `pushNamed`, `goNamed`, or `context.goNamed`, and never pass data via `extra` — pass IDs in the path/query and re-fetch. Named routes and `extra` payloads are banned.
6. **Every page exposes `static const path` and `static const name`** and is registered once in the `go_router` config. Route strings are declared on the page, not scattered at call sites.
7. **Auth and role guards live in the router `redirect`** — not in `initState`, not in widgets. An unauthenticated or under-privileged user is redirected before the page builds.

### Dependency injection (get_it)

8. **One `get_it` container, configured in `lib/app/injection_container.dart`.** Services, Dio, repository implementations, datasources, and UseCases register as `registerLazySingleton`; BLoCs register as `registerFactory`. (Restated from [architecture.md](architecture.md) rule 7 because it is the most-violated rule.)
9. **`get_it` is the only DI mechanism.** No `riverpod`, no `provider` for dependency injection (`flutter_bloc`'s `BlocProvider` is for BLoC lifecycle, not general DI).

### Error handling (profile-specific)

Rules 10–12 have a **Profile A** variant (`dartz`/`Either`) and a **Profile B** variant (bare `Future` + `throwAppException` + `PageState`). Apply the variant matching the repo's profile — detected by `dartz` presence in `pubspec.yaml` (see the intro and [architecture.md — Profiles](architecture.md#profiles)). A single repo uses one variant throughout; mixing the two is a red flag.

10. **Repository/usecase return type.**
    - *Profile A* — every repository and usecase method returns `Future<Either<Failure, T>>`. The domain layer **never throws** and never returns a raw value or a nullable-on-error.
    - *Profile B* — every repository and usecase method returns a **bare `Future<T>`**. Errors are not part of the return type; they surface as thrown typed `AppException`s. The domain still never returns a nullable-on-error to signal failure.
11. **Error translation at the data boundary.**
    - *Profile A* — exceptions are caught in the data layer and mapped to a `Failure`. The failure type is the sealed hierarchy: `ServerFailure`, `NetworkFailure`, `CacheFailure`, `AuthFailure`, `ValidationFailure`, `UnknownFailure`. No other failure types; no bare `Exception` crossing a layer boundary as a raw type.
    - *Profile B* — exceptions are caught in the data layer and re-thrown through the **central `throwAppException(e, stackTrace)`**, which normalizes any error into a typed `AppException` (e.g. `NetworkException`, `ServerException`, `UnauthorizedException`, `ValidationException`, `UnknownException`). Data layers never let a raw `DioException`/`Exception` escape untranslated, and never invent an ad-hoc exception type outside the `AppException` family.
12. **How consumers resolve the outcome.**
    - *Profile A* — resolve `Either` explicitly with `fold` (Left → error state, Right → data state). Never `getOrElse`/`(r as Right).value` to discard the error branch silently.
    - *Profile B* — presentation wraps the result in a `PageState<T>` sealed union (`init` / `loading` / `success` / `empty` / `failure`) and resolves it with `when` / `whenOrNull` / `maybeWhen` (or the `isLoading` / `isSuccess` guards). Never read a `PageState` value without handling the `failure`/`empty` cases; never swallow the thrown `AppException` with an empty `catch`.

### UseCases

13. **Every usecase extends the `UseCase<T, Params>` base** and implements `call(Params params)` — returning `Future<Either<Failure, T>>` in Profile A, or a bare `Future<T>` in Profile B (matching rule 10). `Params` extends `Equatable`; a parameter-less usecase takes `NoParams`. One operation per usecase.

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
20. **Typography comes from the theme.** Use `context.textTheme` / `SupyTypography` — never construct a `TextStyle(...)` inline. Two corollaries: (a) when a needed color, spacing, radius, or typography value has no token, add the token to the design system and use it — never hardcode a literal as a workaround; (b) when the same widget/UI is duplicated across features, extract it into a reusable component in the shared design system (`packages/design` / `shared/presentation/design_system/`) and reuse it — never copy-paste the widget.

### Testing

21. **Test with `mocktail` + `bloc_test`; mock at the boundary (datasource or repository), never mock the class under test.** Widget tests use the shared `pumpApp` helper so theme, router, and providers are wired consistently. The **coverage bar depends on the profile/sub-profile**:
    - *Apps (Profile A and Profile B)* — **≥80%**.
    - *Melos packages (`supy-flutter-packages`)* — **≥85% per package**, enforced by `very_good_coverage` in each package's CI job.
    - *Plugin (`supy-scanner`)* — **≥70% lcov on the Dart side**, plus native tests on both platforms (Robolectric on the JVM, XCTest on iOS). See [architecture.md — Profiles](architecture.md#profiles) rules P6 / M3.

### Flavors & security

22. **Three flavors — dev / staging / production — via `main_dev.dart` / `main_stg.dart` / `main_prod.dart` + `FlavorConfig`.** Environment-specific values (base URL, fake-data flag, Sentry DSN) come from `FlavorConfig`, never hardcoded in feature code.
23. **Tokens live in `flutter_secure_storage`.** The auth interceptor attaches the bearer token; a `401` triggers the session-expiry flow (not a silent retry). Sentry breadcrumbs are sanitized — never log tokens, credentials, or PII.

### Commits

24. **Conventional Commits.** Subject line is imperative mood, **≤50 characters**, with **no trailing period**. Body (if any) explains the why.

### File length

25. **Keep files small and focused — one primary declaration per file.** A widget, page, BLoC, repository, or class file should own a single responsibility; **files stay under ~300 lines** as a soft cap. When a file grows past that, it's a signal to split — extract sub-widgets into their own files under `widgets/`, give each event/state/`Failure`/`AppException` variant its own declaration, and pull unrelated helpers out. Long files hide responsibilities and make review, reuse, and testing harder.

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

### Good — Profile A: usecase on the `UseCase` base, resolved with `fold`

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

### Good — page with `static const path` and `context.push`

```dart
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});
  static const path = '/tasks';
  static const name = 'tasks';

  @override
  Widget build(BuildContext context) => const _TasksView();
}

// drilling into a detail page — push, hardcoded path, no goNamed / extra
onTap: () => context.push(TaskDetailPage.path.replaceFirst(':id', task.id)),
```

### Good — Profile A: sealed Failure hierarchy

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

### Good — Profile A: bloc_test with mocked boundary

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

### Good — Profile B: bare `Future` + `throwAppException` + `PageState`

Same feature under Profile B. Repositories/usecases return bare `Future<T>`; the data layer funnels every error through the central `throwAppException`; presentation exposes a `PageState<T>` and resolves it with `when`.

```dart
// core/error/app_exception.dart — the typed AppException family
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;
}
class NetworkException extends AppException { const NetworkException(super.message); }
class ServerException extends AppException { const ServerException(super.message); }
class UnauthorizedException extends AppException { const UnauthorizedException(super.message); }
class ValidationException extends AppException { const ValidationException(super.message); }
class UnknownException extends AppException { const UnknownException(super.message); }

// core/error/throw_app_exception.dart — the single translation point
Never throwAppException(Object error, [StackTrace? stackTrace]) {
  if (error is AppException) throw error;
  if (error is DioException) {
    throw switch (error.response?.statusCode) {
      401 => const UnauthorizedException('Session expired'),
      422 => const ValidationException('Invalid request'),
      _ => ServerException(error.message ?? 'Request failed'),
    };
  }
  throw UnknownException(error.toString());
}

// features/tasks/data/repositories/task_repository_impl.dart
@override
Future<List<Task>> getTasks() async {
  try {
    final models = await _remote.getTasks();
    return models.map((m) => m.toEntity()).toList();
  } catch (e, s) {
    throwAppException(e, s); // never lets a raw DioException escape
  }
}

// presentation — state is PageState<T>, resolved with when
Future<void> load() async {
  emit(state.copyWith(tasks: const PageState.loading()));
  try {
    final tasks = await _getTasks(const NoParams());
    emit(state.copyWith(
      tasks: tasks.isEmpty ? const PageState.empty() : PageState.success(tasks),
    ));
  } on AppException catch (e) {
    emit(state.copyWith(tasks: PageState.failure(e)));
  }
}

// widget
tasksState.when(
  init: () => const SizedBox.shrink(),
  loading: () => const LoadingView(),
  success: (tasks) => TaskListView(tasks),
  empty: () => const EmptyView(),
  failure: (e) => ErrorView(e.message),
);
```

## Red flags

These are auto-reject in review — each maps to the fix on its right:

- A `Cubit` → convert to a `Bloc` with explicit sealed events.
- An event or state that isn't a typed class (untyped `bool`/`String` state flags) → sealed event hierarchy + `freezed` state union.
- A BLoC registered as `registerLazySingleton` (or a repo/usecase as `registerFactory`) → factory for BLoCs, singleton for the rest.
- `pushNamed` / `goNamed` / navigation via `extra` → `context.push('/path')` (or `context.go` for a main shell/tab destination) with the page's `path` constant; pass IDs in the path/query.
- A page missing `static const path` / `name`, or a route string written at the call site → declare it on the page.
- An auth/role check in `initState` or a widget → move it to the `go_router` `redirect`.
- `riverpod` / `provider` used for dependency injection → `get_it`.
- *(Profile A)* A repository or usecase returning a raw value / nullable / throwing → `Future<Either<Failure, T>>`; catch in data, map to a `Failure`.
- *(Profile A)* A `Failure` type outside the sealed hierarchy, or a bare `Exception` crossing a layer as a raw type → one of `ServerFailure`/`NetworkFailure`/`CacheFailure`/`AuthFailure`/`ValidationFailure`/`UnknownFailure`.
- *(Profile A)* `getOrElse` / `(x as Right).value` discarding the Left branch → `fold` both branches explicitly.
- *(Profile B)* A data-layer `catch` that rethrows a raw `DioException`/`Exception`, or invents an ad-hoc exception type → funnel every error through `throwAppException(e, s)` into the typed `AppException` family.
- *(Profile B)* Presentation reading a `PageState<T>` value without handling `failure`/`empty`, or an empty `catch` swallowing an `AppException` → resolve with `when`/`whenOrNull`/`maybeWhen` and surface the failure state.
- *(Profile B)* A Profile B repo/usecase returning `Future<Either<Failure, T>>` → drop `dartz`; return bare `Future<T>` and translate via `throwAppException`.
- **Mixing profiles in one repo** — `dartz`/`Either` on some paths and `PageState`/`throwAppException` on others, or a `pubspec.yaml` that has `dartz` while presentation is built on `PageState` → commit the whole app to one profile (see [architecture.md — Profiles](architecture.md#profiles)).
- A usecase not extending `UseCase<T, Params>`, or `Params` not extending `Equatable` → use the base + `NoParams`.
- A reordered/missing Dio interceptor → keep the `auth → cache → retry → error → logging` order.
- Fake data toggled by commenting code → gate on `FlavorConfig.instance.useFakeData`.
- Ad-hoc Hive box reads/writes in a repository → go through `HiveCacheManager` + `CacheInterceptor` with an explicit policy.
- Hand-edited `*.g.dart` / `*.freezed.dart` → regenerate with `dart run build_runner build --delete-conflicting-outputs`.
- `Color(0xFF…)` / `Colors.*` → `context.supyColors` / `context.colors`.
- Raw numeric spacing, `EdgeInsets.fromLTRB(...)`, or inline `TextStyle(...)` → spacing tokens / `SupyRadius` / `context.textTheme`.
- A missing design token worked around with a hardcoded literal → add the color/spacing/radius/typography token to the design system and use it.
- The same widget/UI copy-pasted across features → extract a reusable component into the shared design system (`packages/design` / `shared/presentation/design_system/`) and reuse it.
- Mocking the class under test → mock the datasource/repository boundary only.
- A token, credential, or PII in a log or Sentry breadcrumb → sanitize; secrets live in `flutter_secure_storage`.
- A hardcoded environment value (base URL, DSN) in feature code → read it from `FlavorConfig`.
- A single file running well past ~300 lines, or packing multiple widgets/unrelated classes → split by responsibility; extract sub-widgets into `widgets/`, one primary declaration per file.

## Source

- `supy-checklists` CLAUDE.md — the enforced Flutter rulebook and **Profile A** error handling: BLoC-not-Cubit state management, `go_router` `context.push`/`context.go` navigation, `get_it` DI split, `dio` interceptor order, `dartz` `Either`/sealed `Failure` handling, `UseCase`/`Params` base, `hive` cache policies, the `SupyColors`/`ColorTokens`/spacing/`SupyRadius`/`SupyTypography` design system, `freezed`/`json_serializable` codegen, `mocktail`/`bloc_test`/`pumpApp` testing (≥80%), dev/staging/production flavors + `FlavorConfig`, `flutter_secure_storage` + sanitized Sentry, and Conventional Commits
- `supy-mobile` — **Profile B** error handling: bare `Future<T>` repositories/usecases, central `throwAppException()` → typed `AppException`, and the `PageState<T>` sealed presentation union resolved with `when`/`whenOrNull`/`maybeWhen`
- `supy-scanner` — **plugin sub-profile** testing bar: ≥70% lcov (Dart) + Robolectric/XCTest native tests (rule 21); full plugin rules P1–P6 in [architecture.md](architecture.md#profiles)
- `supy-flutter-packages` — **melos-packages sub-profile** testing bar: ≥85% per package via `very_good_coverage` (rule 21); full melos rules M1–M5 in [architecture.md](architecture.md#profiles)
- Analysis is enforced by `very_good_analysis` + `bloc_lint` in `analysis_options.yaml` (shipped in `templates/flutter/`); melos packages may use `lints:recommended` for pure-Dart packages (architecture.md rule M4)
- Layer split, folder layout, dependency direction, and the full profile/sub-profile catalogue: [architecture.md](architecture.md)
