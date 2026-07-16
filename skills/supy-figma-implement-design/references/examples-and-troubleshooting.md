# Examples and troubleshooting

Supporting detail for `supy-figma-implement-design` — two worked walkthroughs and fixes for common
failure modes.

## Example 1: implementing a button component

User provides: `https://figma.com/design/kL9xQn2VwM8pYrTb4ZcHjF/DesignSystem?node-id=42-15`

**Actions:**

1. Parse URL: `fileKey=kL9xQn2VwM8pYrTb4ZcHjF`, `nodeId=42-15`.
2. Run `get_design_context(fileKey="kL9xQn2VwM8pYrTb4ZcHjF", nodeId="42-15")`.
3. Run `get_screenshot(fileKey="kL9xQn2VwM8pYrTb4ZcHjF", nodeId="42-15")`.
4. Download any icon assets to `packages/design/lib/src/widgets/src/assets/icons/`.
5. Check whether the project already has a button component in the UI package.
6. Map Figma colors to `ColorScheme` (e.g. `colorScheme.primary`, `colorScheme.onPrimary`).
7. Map Figma typography to `TextTheme` (e.g. `textTheme.labelLarge`).
8. Create `AppButton` in
   `packages/design/lib/src/widgets/src/lib/src/widgets/app_button.dart`.
9. Write an Alchemist golden test in
   `packages/design/lib/src/widgets/src/test/src/widgets/app_button_golden_test.dart`.
10. Run `flutter test --tags golden --update-goldens` to generate golden files.
11. **Check for Widgetbook** (`widgetbook/` directory or `widgetbook_annotation` dependency) — if
    present, create use cases for all visual states in `widgetbook/lib/use_cases/app_button.dart`.
12. Compare golden output against the Figma screenshot.
13. Update barrel files and `pubspec.yaml`.

**Result:** `AppButton` widget with golden test validation, integrated with the project theme.

## Example 2: building a card component

User provides: `https://figma.com/design/pR8mNv5KqXzGwY2JtCfL4D/Components?node-id=10-5`

**Actions:**

1. Parse URL, fetch design context and screenshot.
2. Use `get_metadata` to understand the card's internal structure (image, title, subtitle, action
   buttons).
3. Fetch individual child nodes for detailed specs.
4. Download card image assets.
5. Create widget files:
   - `packages/design/lib/src/widgets/src/lib/src/widgets/app_card/app_card.dart` (main widget +
     barrel exports)
   - `.../app_card/app_card_header.dart`
   - `.../app_card/app_card_body.dart`
6. Map spacing to the project's spacing tokens, colors to `ColorScheme`, typography to `TextTheme`.
7. Use `const` constructors and composition of smaller widgets.
8. Write golden tests covering: default state, without image, with long text, dark theme.
9. **Check for Widgetbook** — if present, create use cases for the same states.
10. Validate against the Figma screenshot.

**Result:** composable `AppCard` widget with sub-components, golden tests, and theme integration.

## Common issues and solutions

### Figma output is truncated

Use `get_metadata` for the node structure, then fetch specific child nodes individually with
`get_design_context`.

### Design does not match after implementation

Compare golden test output side-by-side with the Figma screenshot from Step 3. Check spacing
values, color hex codes, and typography specs in the design context data.

### Assets not loading in Flutter

Verify assets are registered in `pubspec.yaml` under the `flutter.assets` key, and that asset paths
are correct relative to the package root. Run `flutter pub get` after adding assets.

### Golden test failures on CI

Golden tests can be platform-sensitive due to font rendering differences. Generate golden files on
the same platform CI runs on (typically Linux). Use Alchemist's CI golden test configuration to
replace text with colored rectangles for cross-platform consistency.

### Project has no existing UI package

Scaffold `packages/design/lib/src/widgets/src/` following
[references/mcp-and-mapping.md](mcp-and-mapping.md#scaffolding-a-new-ui-package). If using Dart
workspaces or Melos, add the package to the root `pubspec.yaml` workspace list, then run
`flutter pub get` from the project root.

### Animations cause flaky golden tests

For widgets with animations (like loading spinners), create a static version for golden tests that
renders the visual state without animation. Use the animated version only in behavioral tests and
Widgetbook. Example:

```dart
// In test file - static version for golden tests
class _StaticLoadingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Render the loading state appearance without animation
    return Container(
      decoration: /* ... same decoration as real button ... */,
      child: CustomPaint(painter: _StaticSpinnerPainter()),
    );
  }
}
```

### Figma uses custom fonts not in the project

Download the font files, place them in
`packages/design/lib/src/widgets/src/assets/fonts/`, and register them in `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: CustomFont
      fonts:
        - asset: assets/fonts/CustomFont-Regular.ttf
        - asset: assets/fonts/CustomFont-Bold.ttf
          weight: 700
```
