---
name: supy-figma-implement-design
description: '[flutter] Translate a Figma design into a production-ready Flutter widget with 1:1 visual fidelity, using the Figma MCP server. Maps design tokens onto the project''s ThemeData/ColorScheme/ThemeExtension, places the widget in the shared UI package, and validates it with Alchemist golden tests (and Widgetbook use cases, if present). Use when a user provides a Figma URL (or a selected Figma-desktop node) and asks to implement it as Flutter widgets, in a flutter supy repo. Requires a working Figma MCP server connection.'
---

## When this applies

A user supplies a Figma URL (`https://figma.com/design/:fileKey/:fileName?node-id=1-2`) — or, with the
`figma-desktop` MCP, has a node selected in the Figma desktop app — and wants it implemented as
Flutter widgets. This skill is Flutter- and Figma-MCP-specific; for the general how-to on writing
Flutter code the Supy way (layers, BLoC, DI, navigation), see **supy-flutter-feature**. To review the
resulting diff, use the **supy-flutter-reviewer** agent.

**Prerequisite:** a working Figma MCP server connection. If any Figma MCP call fails because the
server isn't connected, pause and walk the user through setup — see
[references/mcp-and-mapping.md](references/mcp-and-mapping.md#step-0--set-up-figma-mcp-if-not-already-configured).

## Standards you follow

Read the governing Flutter standards before implementing, and apply the design-token rules while
building widgets:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/flutter/flutter-conventions.md"
```

- **Colors** — `context.supyColors` (primitives) / `context.colors` (semantic `ColorTokens`). Never
  `Color(0xFF…)` or `Colors.*`.
- **Spacing & radius** — the project's spacing scale and `SupyRadius`. Never raw numeric
  `EdgeInsets`/`SizedBox` values, and never `EdgeInsets.fromLTRB(...)`.
- **Typography** — `context.textTheme` / the project's typography tokens. Never an inline
  `TextStyle(...)`.
- **const, dartdoc, barrels** — `const` constructors wherever possible, `///` dartdoc on every public
  widget API, barrel-file exports for every new directory (see supy-flutter-feature for the general
  code shape).

If the project has no established token system yet, Step 5 (below) covers scaffolding one — treat
that as a fallback, not the default.

## Prerequisites

- Figma MCP server connected and accessible.
- A Figma URL in the form `https://figma.com/design/:fileKey/:fileName?node-id=1-2` — **or**, with
  `figma-desktop`, a node selected directly in the Figma desktop app (no URL/`fileKey` needed).
- Ideally an established design system or shared UI package (not required — Step 5 scaffolds one).

## Default package location

Generated components go in the project's shared UI package, default
`packages/design/lib/src/widgets/src/`. To find the right location: look for an existing UI package
(`ui_kit`, `app_ui`, `design_system`, `ui_components`) under `shared/` or `packages/`; check the
project's context file for a documented location; ask the user if still ambiguous; otherwise fall
back to the default. If no such package exists, scaffold one — see
[references/mcp-and-mapping.md](references/mcp-and-mapping.md#scaffolding-a-new-ui-package) for the
directory layout and Melos/workspace registration.

## Required workflow

Follow these steps in order.

### Step 0–1: Connect and parse the node

Confirm the Figma MCP server is reachable (see Prerequisites), then extract `fileKey` and `nodeId`
from the URL — `fileKey` is the path segment after `/design/`, `nodeId` is the `node-id` query
value (e.g. `42-15`). Full setup instructions per AI tool are in
[references/mcp-and-mapping.md](references/mcp-and-mapping.md#step-0--set-up-figma-mcp-if-not-already-configured).

### Step 2: Fetch design context

```text
get_design_context(fileKey=":fileKey", nodeId="1-2")
```

If the response is too large or truncated: run `get_metadata` for a high-level node map, identify
child nodes, then fetch each with its own `get_design_context` call.

Treat the result as design **intent**, not final code — translate it into idiomatic Flutter, using
the Figma→Flutter concept mapping (Auto Layout → `Column`/`Row`, Fill → `Expanded`, Hug →
`MainAxisSize.min`, etc.) in
[references/mcp-and-mapping.md](references/mcp-and-mapping.md#figma-flutter-concept-mapping).

### Step 3: Capture the visual reference

```text
get_screenshot(fileKey=":fileKey", nodeId="1-2")
```

This screenshot is the source of truth for visual validation in Step 9 — keep it available
throughout implementation.

### Step 4: Download and register assets

Download any assets the MCP server returns. If it gives a `localhost` source URL, use it directly —
never substitute a placeholder or a new icon package. Place SVGs/images/fonts under the target
package's `assets/` tree, register them under `flutter.assets` (and `flutter.fonts` for custom
fonts) in `pubspec.yaml`, and name them `ic_*`/`img_*` in `snake_case`. Full asset-placement layout:
[references/mcp-and-mapping.md](references/mcp-and-mapping.md#asset-placement).

### Step 5: Translate to Flutter widgets

1. **Map design tokens to the theme first.** Prefer the project's existing tokens (`context.colors`,
   `SupyRadius`, `context.textTheme`, spacing scale — see "Standards you follow" above). Only if no
   token system exists yet, scaffold one (`ThemeExtension` for extra colors, an `AppTextStyles`
   class, an `AppSpacing` class) — full scaffolding code in
   [references/design-tokens.md](references/design-tokens.md).
2. **Build the widget tree** from the Figma→Flutter mapping (Step 2): Auto Layout → `Row`/`Column`,
   padding → `Padding` with token `EdgeInsets`, gap → `SizedBox` spacer, fill → `Expanded`/`Flexible`,
   corner radius/shadow → `BorderRadius`/`BoxShadow` in `BoxDecoration`.
3. **Apply widget conventions**: `const` constructors, standalone widget classes over
   widget-returning helper methods, composition over inheritance, `super.key`, named parameters,
   barrel files, `very_good_analysis` clean.
4. **Reuse before creating.** Check the target UI package for an existing matching component
   (button, dialog, loading/error state, app bar, text field, snackbar, tabs, card, accordion,
   banner, search box, icon wrapper, etc.) and extend it with a new variant rather than duplicating.
5. **File organization**: simple widget → single file (`app_button.dart`); complex/composite widget
   → a directory with a main file that also barrel-exports its sub-widgets
   (`app_card/app_card.dart`, `app_card_header.dart`, …). Update the package's top-level barrel.
   Widget classes `PascalCase`, files `snake_case`, shared widgets prefixed `App*` to avoid clashing
   with Flutter built-ins (`AppCard`, not `Card`).

### Step 6: Achieve 1:1 visual parity

Match the Figma design exactly using theme tokens (never hardcoded values). Access via
`Theme.of(context).colorScheme.*` / `.extension<AppColors>()!.*` / `.textTheme.*` (or the project's
own token accessors). When the project's tokens and the Figma spec conflict, prefer project tokens
and adjust spacing/size minimally to match visually. Every widget must support light and dark theme
via `ThemeData` — no conditional brightness checks. Meet WCAG contrast/labels, and add `///` dartdoc
to every public widget API.

### Step 7: Write golden tests

Write an Alchemist golden test for every new widget — it is the visual contract. Cover every
meaningful state (default, disabled, loading, error, empty, with/without optional props, light +
dark theme where applicable), plus behavioral `testWidgets` for tap/disabled/loading/keyboard
behavior. Full test-file pattern, `dart_test.yaml` tagging, and the golden-generation/validation
commands: [references/testing-and-widgetbook.md](references/testing-and-widgetbook.md#golden-tests).

### Step 8: Create Widgetbook use cases (if Widgetbook is present)

**Detection is required before this step**: look for a `widgetbook/` directory, or
`widgetbook`/`widgetbook_annotation` in any `pubspec.yaml`. If absent, skip to Step 9. If present,
this step is required — create a `@UseCase` for **every** `GoldenTestScenario` from Step 7 (default,
disabled, loading, error, empty, with/without optional props, dark theme). Integration steps and
code: [references/testing-and-widgetbook.md](references/testing-and-widgetbook.md#widgetbook-use-cases).

### Step 9: Validate against Figma

Before declaring the implementation done:

1. Run the golden tests to generate golden images.
2. Compare them against the Step 3 screenshot: layout/spacing/alignment, typography, colors (light
   and dark), corner radius, shadows, assets, all interactive states, and accessibility.
3. If anything's off, return to Step 5 or 6, fix, and re-run goldens.
4. Run the full suite:

```bash
cd shared/ui_kit   # or the package resolved in "Default package location"
flutter test
flutter analyze
```

**Acceptance criteria:** all golden tests pass and visually match Figma; `flutter analyze` is clean;
every public API has dartdoc; barrel files are updated; assets are registered in `pubspec.yaml`.

## Examples and troubleshooting

Two worked examples (a button, a composite card) and fixes for common failure modes (truncated
Figma output, visual mismatch after implementation, assets not loading, flaky/CI golden failures,
missing UI package, animated widgets, custom fonts) are in
[references/examples-and-troubleshooting.md](references/examples-and-troubleshooting.md).

## Related

- **supy-flutter-feature** — the general Supy Flutter code shape (Clean Architecture, BLoC, DI,
  navigation, tokens) this skill's output must still follow.
- **supy-flutter-reviewer** — review the resulting diff.
