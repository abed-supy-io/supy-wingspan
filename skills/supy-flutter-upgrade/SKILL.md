---
name: supy-flutter-upgrade
description: '[flutter] Bumps Flutter and Dart SDK versions across every pubspec.yaml, .fvmrc, and GitHub Actions workflow in a Supy Flutter repo, then runs pub get, format, analyze, and fix, and checks the target release''s notes for breaking changes. Flutter-specific. Use when upgrading Flutter/Dart versions, or when the user asks to "upgrade Flutter" or "update the Flutter version".'
---

## When this applies

Any time you bump the Flutter/Dart SDK version in a Supy Flutter repo (app or melos-packages monorepo) — updating `pubspec.yaml` constraints, `.fvmrc`, and CI workflow `flutter-version` pins, then re-validating the repo still formats, analyzes, and lints clean. This is a mechanical, repo-wide version bump, not an architecture change; it does not touch the layer/BLoC/DI rules that [supy-flutter-feature](../supy-flutter-feature/SKILL.md) and [supy-flutter-reviewer](../../agents/supy-flutter-reviewer.md) enforce — but the format/analyze step in Step 7 below runs the same `very_good_analysis` + `bloc_lint` gate described in `flutter-conventions.md`, so a version bump can surface newly-flagged lints that need fixing before it lands.

All paths below are **relative to the target (consuming) repo**, not this plugin — `pubspec.yaml`, `.fvmrc`, and `.github/workflows/` live in the repo being upgraded.

## Step 1 — Detect the current version

1. Get the installed Flutter version: `flutter --version`.
2. Find every `pubspec.yaml` in the repo, including nested packages (e.g. under `packages/` in a melos monorepo) — do not assume a fixed package list, discover them:

   ```bash
   find . -name pubspec.yaml -not -path "*/build/*"
   ```

3. Check for a `.fvmrc` at the repo root.
4. Read each `pubspec.yaml` and extract current constraints under `environment:`:
   - `flutter:` (e.g. `^3.38.0`)
   - `sdk:` (e.g. `^3.10.0`)
5. If `.fvmrc` exists, read its `flutter` field (e.g. `"flutter": "3.19.0"`).
6. Report the versions found across all files before changing anything.

## Step 2 — Get the target version

- Use the version the user specified.
- Otherwise, ask: "What Flutter version do you want to upgrade to?"
- Validate it's semver (`X.Y.Z` or `X.Y.Z-pre.N`).

## Step 3 — Determine the matching Dart SDK version

Fetch `https://docs.flutter.dev/install/archive` and read off the Dart SDK version paired with the target Flutter version.

## Step 4 — Update pubspec.yaml files

For each `pubspec.yaml` found in Step 1:

1. **Flutter constraint** — in the `environment:` section, update `flutter:`, preserving the existing operator (`^`, `>=`, …): `flutter: ^3.38.0` → `flutter: ^3.41.0`.
2. **Dart SDK constraint** — update `sdk:` to the version from Step 3, same operator: `sdk: ^3.10.0` → `sdk: ^3.11.0`.
3. If a file has no `environment:` section, add one; if `environment:` exists but is missing `flutter:` or `sdk:`, add the missing field. Default to caret (`^`) constraints unless the file already uses a different operator.
4. Edit each file with exact string matching — don't reformat surrounding YAML.

## Step 5 — Update .fvmrc (if present)

1. Read the file's JSON.
2. Update `"flutter": "{oldVersion}"` → `"flutter": "{targetVersion}"` (exact version string, not a constraint — `.fvmrc` never uses `^`/`>=`). Add the field if missing.
3. Preserve every other field and the file's formatting.

## Step 6 — Update GitHub Actions workflows

1. Find workflow files: `.github/workflows/*.yaml` (and `.yml`).
2. In each, if a `flutter-version:` line is present, update it: `flutter-version: 3.38.2` → `flutter-version: 3.41.0`.
3. If `.github/workflows_config.json` exists, update its `flutterVersion` field the same way.

## Step 7 — pub get, then format / analyze / fix

Run for **every** package root found in Step 1 (start from the repo root, then each nested package):

```bash
# in each directory containing a pubspec.yaml
flutter pub get   # Flutter packages
dart pub get      # Dart-only packages

dart format .
flutter analyze                                        # Flutter packages
dart analyze --fatal-infos --fatal-warnings lib test    # Dart-only packages
dart fix --apply
```

If the repo is a melos monorepo (`melos.yaml` at the root), run `melos bootstrap` instead of per-package `pub get`, and prefer `melos exec -- dart format .` / `melos run analyze` if those scripts are defined — check `melos.yaml` for the actual script names before assuming.

**Error handling:** if any command fails, report the error and keep going — don't abort the whole upgrade over one package's failure. Collect every failure for the summary in Step 9.

## Step 8 — Fetch and review release notes for breaking changes

1. Fetch `https://docs.flutter.dev/release/release-notes/release-notes-{targetVersion}` (e.g. `release-notes-3.41.0`). If that exact URL 404s, try the `X.Y` form or browse the current release-notes index.
2. In the notes, find "Breaking changes", "Deprecations", or "Migration guide" sections and extract concrete API changes.
3. For each breaking change, search the repo for usages of the affected API — pay particular attention to `flutter_bloc`, `go_router`, `sentry_flutter`, `get_it`, and `mocktail`, since those are load-bearing across every Supy Flutter repo.
4. Where the release notes describe a straightforward mechanical replacement, apply it. Only change what's explicitly documented — don't speculatively "fix" adjacent code.
5. For anything needing human judgment, list it under "manual follow-up" in the summary, with file paths and a link to the relevant migration guide.

## Step 9 — Summary report

Report:

1. **Files updated** — every `pubspec.yaml`, `.fvmrc` if touched, every workflow file, `workflows_config.json` if touched.
2. **Version changes** — old Flutter → new Flutter, old Dart SDK → new Dart SDK.
3. **Issues found** — format/analyze/fix failures, with which package they came from.
4. **Breaking changes** — auto-fixed vs. flagged for manual review, with file locations.
5. **Next steps** — run the app and smoke-test; `pub get`/`melos bootstrap` has already run in Step 7, so a fresh install isn't needed before testing.

## Notes

- **Preserve constraint operators** (`^`, `>=`, …) already in the file; don't silently rewrite a repo's convention.
- **GitHub workflows may pin an exact version** (`3.38.2`) while `pubspec.yaml` uses a constraint (`^3.38.0`) — update both, in their own idiom.
- **`.fvmrc` always uses an exact version string**, never a constraint.
- If release notes for the target version aren't published yet, continue the upgrade and flag that breaking-change review needs to happen manually once they are.

## Before you finish

- Every `pubspec.yaml` found in Step 1 updated — none skipped?
- `.fvmrc` (if present) and CI workflow pins match the new target version?
- `pub get`/`melos bootstrap`, `dart format`, `analyze`, and `dart fix --apply` all run per package, with failures called out rather than silently swallowed?
- Release notes checked for breaking changes touching `flutter_bloc`, `go_router`, `sentry_flutter`, `get_it`, or `mocktail`?
- Summary lists exactly what changed and what still needs a human?

This skill only bumps versions and clears the resulting lint/format noise. If the analyzer surfaces a real architecture or convention violation while you're in there, don't fix it inline — hand it to [supy-flutter-reviewer](../../agents/supy-flutter-reviewer.md), and use [supy-commit](../supy-commit/SKILL.md) to land the version bump as its own Conventional Commit.
