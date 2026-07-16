---
name: supy-e2e-tests
description: Write, run, and debug Supy retailer end-to-end (integration_test) tests against the live dev backend on the Android emulator. Flutter/retailer-specific — applies only to the supy-retailer mobile repo, not other Supy Flutter apps. Use when adding e2e coverage, fixing failing e2e tests, or auditing whether created values are actually asserted. Encodes the run command, feature-flag gates, authz-race waiting patterns, finder caveats, and the never-weaken-assertions policy.
---

## When this applies

Any time you add, run, or debug tests under `integration_test/` in the **Supy retailer** Flutter
repo. These are **Flutter `integration_test`** tests (NOT patrol). They run on a booted Android
emulator against the **live `Flavor.dev` backend** with baked-in test credentials. Failures are
usually runtime — stale finders, async-authz races, feature-flag gates, or real intermittent
backend flakiness — not compile errors (`flutter analyze` stays clean). This skill is the how-to
for that harness; for the app-code side (Bloc, repositories, navigation, design tokens) that a
failing e2e test may point back to, use the **supy-flutter-feature** skill.

## Run command (one module at a time)

```bash
fvm flutter test integration_test/e2e_test.dart \
  -d emulator-5554 \
  --dart-define-from-file=env/e2e/.env \
  --dart-define=TEST_TARGET=<module>
```

- Modules: `auth, user, company, channel, inventory, supplier-return, central_kitchen, invoice, grn, order, requisition`.
- **Always run ONE module at a time** to keep failures isolated and runs short.
- Comma-separate for a consolidated run: `TEST_TARGET=auth,user,...,order`.
- **Redact logs** — never let secrets land in a file. Pipe through:

  ```bash
  2>&1 | grep -aviE "bearer|authorization|token|password|otp|eyJ|cookie|secret|traceparent|x-supy-tenant" > /tmp/e2e_<module>.log
  ```

- Authoritative result = the `All tests passed!` / `Some tests failed.` line. `+N -M` is progress.
- **Never print the contents of `env/e2e/.env`.** Never commit it unless explicitly asked.

## Critical patterns (the ones that bite)

### 1. Feature-flag gates — inventory subsystems

ALL inventory subsystems (production, wastage, stock-count, transfer) AND requisition-create
are gated in `AuthorizationBloc` by `UnleashToggle.inventory.isEnabled(context)`, which is
**OFF in live dev**. Without a mock, the drawer/bottom-sheet entries never render and the
test can't even start. Every such test file needs:

```dart
setUp(() {
  sl.allowReassignment = true;
  sl.registerLazySingleton<UnleashService>(
    () => UnleashMockService(
      unleash: sl(),
      mockingMap: {UnleashToggle.inventory.name: true},
    ),
  );
});
```

### 2. Authz-race — wait, don't `pumpAndSettle` once

Buttons gated by `CheckResourceWidget` mount via an **async authz `FutureBuilder`**. They may
not exist when `pumpAndSettle()` returns. Before tapping a permission-gated button:

```dart
await tester.pumpUntilFound(buttonFinder);
await tester.tap(buttonFinder);
```

`pumpUntilFound` and `tapIfVisible` live in `integration_test/test_tools/extensions.dart`.

### 3. The `.first` / `.last` finder caveat

Do NOT pass a chained `.first`/`.last` finder to a poll loop that calls `tester.any()`.
On an empty match, `.first` throws `StateError: No element` on the first poll instead of
returning false — crashing the wait before the widget mounts. `pumpUntilFound` guards this
with a try/catch `_matchesAny` helper, but **prefer the base finder** (e.g.
`find.textContaining('Submit')`) and let the helper handle multiplicity.

### 4. "Found but not hittable" — an overlay is absorbing the pointer

A `tap()` can fail with *"Finder specifies a widget that would not receive pointer events …
derived an Offset that would not hit test on the specified widget"* **even though
`pumpUntilFound` succeeds** — the widget is mounted and found, but a transitioning `Overlay`
sits on top of it. The tell is the hit-test dump in the error: it lists `_RenderTheater`,
`RenderAbsorbPointer`, `RenderAnimatedOpacity`, `RenderIgnorePointer` / `RenderOffstage` layers
above your target. Common cause: a soft-keyboard/text-input overlay left up by a prior
`enterText`, or an in-flight route/snackbar.

This is NOT a "wait longer" problem and NOT a reason to pass `warnIfMissed: false` (that masks
a real obstruction). Fixes, in order of preference:

1. **Drive the controlling object directly** instead of tapping geometry. For a `TabBar`, read
   the controller the screen already owns and `animateTo(index)` —
   `tester.widget<TabBarView>(find.byType(TabBarView)).controller!.animateTo(1)`. This is
   user-equivalent (same controller a tab tap drives) and overlay-independent. A `TabBarView`
   with `NeverScrollableScrollPhysics` *cannot* be swiped, so the controller is the only
   programmatic path.
2. Dismiss the overlay deterministically first (`FocusManager.instance.primaryFocus?.unfocus()`
   for the keyboard) — but verify it actually clears; `pumpAndSettle` alone sometimes doesn't.
3. Only then fall back to tapping the widget.

### 5. Rotating flakiness against the live backend

If the **failing test set changes run-to-run** with the same symptom class (e.g. a GCS
`Connection reset by peer` on an attachment HEAD, or a submit-button race), it's
environmental/timing flakiness. **Harden the shared helper** (`common/*.dart`,
`extensions.dart`) — do NOT play per-test whack-a-mole, and do NOT bump arbitrary timeouts.
Confirm the rotation across at least 3 unchanged runs before investing in helper changes; one
isolated miss per run is consistent with backend jitter, and premature hardening can mask a
future real regression. Track confirmed rotations in `integration_test/COVERAGE_MATRIX.md`
(section "Rotating environmental flakiness").

### 6. `testWidgets(..., skip: …)` takes a `bool`, not a reason string

Unlike `test`'s `skip:` (which accepts a `String` reason), **`testWidgets.skip` is `bool?`**.
Passing a String is a compile error (`The argument type 'String' can't be assigned to the
parameter type 'bool?'`). Put the reason in a doc comment and gate the skip on a `const` bool
that cites the backend issue ID:

```dart
/// Backend-blocked (COVERAGE_MATRIX B7): POST /api/inventory-items/stock-levels 500.
/// Remove once B7 is resolved. (testWidgets.skip is a bool — reason lives here.)
const _stockLevels500Skip = true;

testWidgets('(Counting) Save count', skip: _stockLevels500Skip, (tester) async { … });
```

## New-feature test policy (standing rule — non-negotiable)

**Every new feature ships with tests in the same change.** A feature is not "done" until it is
covered. When you add or modify a feature under `lib/features/<feature>/`, add the matching
tests across the layers it touches — do not defer them to a follow-up:

- **Bloc / state management:** a `bloc_test` per event class asserting the emitted state
  sequence (loading → success/error). Each event is its own class (Bloc, never Cubit), so each
  gets its own test.
- **Data + repository:** repository test mapping the remote/data-source response to the domain
  entity (and the failure path → `Failure`). Mock the data source with `mocktail`.
- **Providers / facades:** unit-test the orchestration logic (e.g. totals providers,
  channel-info add/remove) — pure-Dart where possible.
- **e2e (`integration_test/`):** at least one end-to-end flow for any user-reachable feature,
  obeying the assertion-completeness rule below (assert every created field on the detail view,
  not just a smoke pass). Add a row to `integration_test/COVERAGE_MATRIX.md`.

Scope the depth to the feature's surface: a new screen/flow warrants an e2e test; a new internal
helper warrants unit coverage. If a layer genuinely can't be tested yet (e.g. backend-blocked),
record it as a documented `skip:` citing the issue ID — never silently skip the layer. When in
doubt, add the test. The unit-level conventions above (`mocktail` + `bloc_test`, mock at the
boundary, coverage bar) are the same ones the plugin's Flutter testing standard enforces — see
rule 21 in `${CLAUDE_PLUGIN_ROOT}/config/standards/flutter/flutter-conventions.md`.

## The assertion-completeness rule (non-negotiable)

A test that creates something MUST assert every created field actually persisted — post-submit,
on the detail/summary view. A green test that never checks its written value is a **smoke
pass**, not coverage. When writing or auditing a create flow:

- Confirm the `validate*` helper asserts: date, name, **location**, every line item's
  **name / qty / UOM / unit price / total**, attachments, notes, delivery date.
- Watch for **commented-out validation blocks** — they silently hide gaps. Known offenders are
  tracked in `integration_test/COVERAGE_MATRIX.md` (section "Assertion-completeness audit").

## Test-quality policy

- **NEVER** soften, skip, or weaken an assertion just to make a test pass. Find root cause first
  (follow the `systematic-debugging` skill: investigate before fixing, one hypothesis at a time).
- **App bugs:** if a failing test exposes a real app bug, fix the **app** (`lib/features/...`)
  within Supy conventions (Bloc + explicit events, `context.go`, design tokens — see
  **supy-flutter-feature**) — not the test.
- **Backend-blocked** tests are a **documented `skip:`** citing the backend issue ID (see
  `COVERAGE_MATRIX.md` "Known Backend Issues" B2–B7), never a masked/removed assertion.
  Remember `testWidgets.skip` is a `bool` — see pattern #6 above.
- **Always print the failing endpoint + payload + redacted result** for any backend failure, so
  it can be handed to the backend team.

To review the resulting app-code fix, use the **supy-flutter-reviewer** agent — it covers Clean
Architecture, Bloc, navigation, and design-token conventions, though it does not (yet) review
`integration_test/` harness code itself.

## Structure & conventions

- Orchestration: `integration_test/e2e_test.dart` (`targetList` + `TEST_TARGET`).
- Shared setup / DI reset / cache routes: `integration_test/test_tools/helper.dart`.
- Live login: `integration_test/api_integration/auth.dart` (`loginIntegration`).
- Shared helpers: `integration_test/common/*.dart`, `integration_test/test_tools/extensions.dart`.
- API seeding (create-via-API before UI assertions): `integration_test/api_integration/*.dart`.
- Per-module tests: `integration_test/e2e/<module>/`.
- Reuse existing helpers/extensions before adding new harness code. Add stable `ValueKey`s to
  submit/action buttons rather than relying on text finders where possible.

## Workflow when fixing a failing e2e test

1. Run the single module, capture the redacted log, read the `Some tests failed.` line and
   stack.
2. Triage: **app regression** (fix app) · **stale test** (fix finder/helper) · **flaky/backend**
   (re-run to confirm; harden shared helper or document-skip — never mask).
3. Fix root cause (smallest change, one hypothesis).
4. Re-run the module until green. Then do a consolidated run to catch cross-module ordering
   issues.
5. Keep `fvm flutter analyze integration_test` clean. Update `integration_test/COVERAGE_MATRIX.md`
   if coverage changed.
