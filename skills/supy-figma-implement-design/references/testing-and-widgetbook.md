# Golden tests and Widgetbook use cases

Supporting detail for `supy-figma-implement-design` Steps 7 and 8.

## Golden tests

**Test file location:**

```text
test/src/widgets/
  app_button_golden_test.dart    # Golden tests (separate file from unit tests)
```

**Alchemist golden test pattern:**

```dart
import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  group('AppButton', () {
    // goldenTest registers its own test internally, so the Future is handled.
    // ignore: discarded_futures
    goldenTest(
      'renders correctly',
      fileName: 'app_button',
      tags: ['golden'],
      builder: () => GoldenTestGroup(
        children: [
          GoldenTestScenario(
            name: 'default',
            child: Theme(
              data: AppTheme.light,
              child: const AppButton(label: 'Click me', onPressed: _noop),
            ),
          ),
          GoldenTestScenario(
            name: 'disabled',
            child: Theme(
              data: AppTheme.light,
              child: const AppButton(label: 'Click me'),
            ),
          ),
          GoldenTestScenario(
            name: 'with icon',
            child: Theme(
              data: AppTheme.light,
              child: const AppButton(
                label: 'Click me',
                icon: Icons.arrow_forward,
                onPressed: _noop,
              ),
            ),
          ),
        ],
      ),
    );
  });
}

void _noop() {}
```

**Golden test requirements:**

- Tag golden tests with `tags: ['golden']` for isolated execution. Configure `dart_test.yaml` in the
  package:

```yaml
tags:
  golden:
    description: "Tests that compare golden files."
```

- Cover all meaningful visual states: default, disabled, hover/pressed (if applicable), loading,
  error, empty, with/without optional props.
- Wrap test widgets in a `MaterialApp`/`Theme` with the project's `ThemeData` for consistency.
- Test both light and dark themes where the design supports it.

**Alchemist version compatibility:** use `alchemist: ^0.13.0` or later for Flutter 3.38+ — earlier
versions have Canvas API incompatibilities that cause compilation errors.

**Generate and validate golden files:**

```bash
cd shared/ui_kit
flutter test --tags golden --update-goldens   # generate
flutter test --tags golden                    # validate
```

### Behavioral unit tests

In addition to golden tests, write unit tests for widget behavior:

```dart
testWidgets('calls onPressed when tapped', (tester) async {
  var pressed = false;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: AppButton(
          label: 'Click',
          onPressed: () => pressed = true,
        ),
      ),
    ),
  );

  await tester.tap(find.byType(AppButton));
  await tester.pump();

  expect(pressed, isTrue);
});

testWidgets('does not call onPressed when disabled', (tester) async {
  var pressed = false;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: AppButton(label: 'Click'),  // No onPressed = disabled
      ),
    ),
  );

  await tester.tap(find.byType(AppButton));
  await tester.pump();

  expect(pressed, isFalse);
});
```

Cover: tap behavior, disabled state, loading state, keyboard navigation (if applicable).

## Widgetbook use cases

**Detection (required):** before proceeding, check if the project uses Widgetbook:

1. Look for a `widgetbook/` directory in the project root or `packages/` folder.
2. Search for `widgetbook` or `widgetbook_annotation` in any `pubspec.yaml`.

**If Widgetbook is detected, this step is required — do not skip it.** If not present, skip
straight to Step 9 in the parent skill.

Create use cases for **all visual states** of the widget. Every `GoldenTestScenario` from the golden
tests must have a corresponding Widgetbook `@UseCase`, so the interactive catalog matches the tested
visual contract:

- Default/enabled state
- Disabled state
- Loading state (if applicable)
- Error state (if applicable)
- Empty state (if applicable)
- With/without optional props (e.g. icon, subtitle, trailing action)
- Dark theme variant (if the design supports dark mode)

**Integration steps:**

1. Add the `ui_kit` dependency to widgetbook's `pubspec.yaml`:

   ```yaml
   dependencies:
     ui_kit:
       path: ../shared/ui_kit
   ```

2. Create a use case file in `widgetbook/lib/use_cases/` with a `@UseCase` per visual state:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:ui_kit/ui_kit.dart';
   import 'package:widgetbook_annotation/widgetbook_annotation.dart';

   @UseCase(
     designLink: 'https://figma.com/design/...',
     name: 'Default',
     type: AppButton,
   )
   Widget appButtonDefault(BuildContext context) {
     return Theme(
       data: AppTheme.light,
       child: const AppButton(label: 'Click me', onPressed: _noop),
     );
   }

   @UseCase(
     designLink: 'https://figma.com/design/...',
     name: 'Disabled',
     type: AppButton,
   )
   Widget appButtonDisabled(BuildContext context) {
     return Theme(
       data: AppTheme.light,
       child: const AppButton(label: 'Click me'),
     );
   }

   @UseCase(
     designLink: 'https://figma.com/design/...',
     name: 'With Icon',
     type: AppButton,
   )
   Widget appButtonWithIcon(BuildContext context) {
     return Theme(
       data: AppTheme.light,
       child: const AppButton(
         label: 'Click me',
         icon: Icons.arrow_forward,
         onPressed: _noop,
       ),
     );
   }

   @UseCase(
     designLink: 'https://figma.com/design/...',
     name: 'Dark Theme',
     type: AppButton,
   )
   Widget appButtonDarkTheme(BuildContext context) {
     return Theme(
       data: AppTheme.dark,
       child: const AppButton(label: 'Click me', onPressed: _noop),
     );
   }

   void _noop() {}
   ```

3. Regenerate:

   ```bash
   cd widgetbook && dart run build_runner build --delete-conflicting-outputs
   ```

4. Launch Widgetbook to verify (web is most reliable):

   ```bash
   cd widgetbook && flutter run -d chrome
   ```

Widgetbook complements golden tests: golden tests validate visual correctness automatically, while
Widgetbook provides a comprehensive interactive catalog for designers and developers.
