---
name: supy-coverage-report
description: '[any] Render coverage bars for a Supy repo against its ci-coverage-baseline floor. Detects the stack, finds the coverage artifact (lcov.info or Jest coverage-summary.json), compares to the floor from config/standards/ci-coverage-baseline.md, and prints a labelled PASS/FAIL bar per package. Use when you want a quick visual of whether a repo meets its coverage gate, or to assemble a fleet coverage snapshot. Read-only — never writes files or echoes secrets.'
---

You render a **coverage snapshot** for the current Supy repo: one bar per
package, each compared to the coverage floor codified in
`config/standards/ci-coverage-baseline.md`. This is read-only and offline — you
never run the repo's tests, write files, or push anything. If a coverage
artifact is missing, you say how to produce it and stop.

## Step 1 — Detect the stack and its floor

Prefer the stack named in the SessionStart hook line if one is in context.
Otherwise apply the canonical order in
`skills/shared/references/stack-detection.md`. Map the stack to the
`render-coverage.sh` `--stack` value:

- Flutter app → `flutter-app` (floor 80%)
- Flutter melos packages → `flutter-melos` (floor 85%)
- Flutter plugin → `flutter-plugin` (floor 70%)
- Node/TS stacks (nestjs-nx, angular-nx, firebase-functions, ts-cli,
  ai-agents) → pass an explicit `--floor` read from the repo's own
  `coverageThreshold` / lcov gate, per `config/standards/ci-coverage-baseline.md`.

## Step 2 — Find the coverage artifact

Look, in order, for the artifact the repo's own CI produces:

```bash
# Flutter / lcov-based
ls coverage/lcov.info 2>/dev/null
# Jest json-summary reporter
ls coverage/coverage-summary.json 2>/dev/null
```

For a melos monorepo, look for a `coverage/lcov.info` per package under
`packages/*/coverage/lcov.info`.

If no artifact exists, degrade gracefully — do not fabricate numbers:

```text
supy-coverage-report: no coverage artifact found.
Produce one first, e.g.:  flutter test --coverage   (or)   nx test <proj> --coverage
Then re-run this skill.
```

Stop there.

## Step 3 — Render the bars

Call the bundled renderer once per package. Never re-implement the maths here —
the script is the single source of the bar logic and is TDD-tested.

```bash
SCRIPT="${CLAUDE_PLUGIN_ROOT}/skills/supy-coverage-report/scripts/render-coverage.sh"
# Flutter app example:
bash "$SCRIPT" --label "$(basename "$PWD")" --stack flutter-app --lcov coverage/lcov.info
# melos: one call per package
for f in packages/*/coverage/lcov.info; do
  bash "$SCRIPT" --label "$(basename "$(dirname "$(dirname "$f")")")" --stack flutter-melos --lcov "$f"
done
```

For Jest `coverage-summary.json`, read `.total.lines.pct` (rounded to an
integer) and pass it via `--pct` with an explicit `--floor`:

```bash
PCT="$(jq -r '.total.lines.pct | floor' coverage/coverage-summary.json)"
bash "$SCRIPT" --label "$(basename "$PWD")" --floor 80 --pct "$PCT"
```

Print the collected bars as the result. A non-zero exit from the script for a
package means that package is **below floor** — surface it as a FAIL bar, do
not treat it as an error to abort on.

## Step 4 — Never leak secrets

Coverage artifacts do not contain credentials, but if you ever surface a file
path or snippet alongside the bars, cite `path:line` only — never a secret
value. This skill writes nothing and pushes nothing.

## Error handling summary

| Condition | Behavior |
|---|---|
| No coverage artifact | Print how to produce one; stop. No fabricated numbers. |
| A package is below floor | Render its FAIL bar; continue with the others; do not abort. |
| Stack undetected | Ask the user for the floor, or pass an explicit `--floor`. |
| `jq` unavailable (Jest path) | Say so and ask the user for the line-coverage %; render with `--pct`. |
