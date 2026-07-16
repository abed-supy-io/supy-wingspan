# Scaffolding design tokens from Figma (fallback only)

Supporting detail for `supy-figma-implement-design` Step 5. **Prefer the project's existing token
system first** — `context.colors` / `context.supyColors`, `SupyRadius`, `context.textTheme`, and the
project's spacing scale, per `${CLAUDE_PLUGIN_ROOT}/config/standards/flutter/flutter-conventions.md`.
Only scaffold new token classes like the ones below when no such system exists yet.

## Colors

Map Figma color styles to `ColorScheme` properties (`primary`, `secondary`, `surface`, `error`,
etc.). For colors outside the standard `ColorScheme`, add a `ThemeExtension`:

```dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.success, required this.warning});

  final Color? success;
  final Color? warning;

  @override
  ThemeExtension<AppColors> copyWith({Color? success, Color? warning}) {
    return AppColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t),
      warning: Color.lerp(warning, other.warning, t),
    );
  }
}
```

## Typography

Map Figma text styles to `TextTheme` properties (`displayLarge`, `headlineMedium`, `bodyLarge`,
etc.). For custom text styles not in `TextTheme`, add an `AppTextStyles` class:

```dart
abstract class AppTextStyles {
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33,
  );
}
```

## Spacing

Map Figma spacing values to an `AppSpacing` class:

```dart
abstract class AppSpacing {
  static const double spaceUnit = 16;
  static const double xxs = 0.25 * spaceUnit;  // 4
  static const double xs = 0.375 * spaceUnit;   // 6
  static const double sm = 0.5 * spaceUnit;     // 8
  static const double md = 0.75 * spaceUnit;    // 12
  static const double lg = spaceUnit;            // 16
  static const double xl = 1.5 * spaceUnit;     // 24
  static const double xxl = 2 * spaceUnit;      // 32
}
```

## Accessing tokens once mapped

```dart
// Standard colors
Theme.of(context).colorScheme.primary

// Custom colors via ThemeExtension
Theme.of(context).extension<AppColors>()!.success

// Text styles
Theme.of(context).textTheme.bodyLarge
```
