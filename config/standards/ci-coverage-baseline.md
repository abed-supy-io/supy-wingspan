---
source: templates/{backend,frontend,firebase-functions,ts-cli,ai-agents,flutter}/.github/workflows/ci.yml, templates/{backend,frontend,firebase-functions,ts-cli,ai-agents}/.husky/pre-commit, templates/k8s-config/.pre-commit-config.yaml, supy-api-common (Jest passWithNoTests shared-library variant), flutter/flutter-conventions.md (per-profile coverage bars)
mined_on: 2026-07-16
confidence: high
---

# CI, Coverage & Pre-commit Baselines

**Stack-agnostic.** This standard defines the *minimum* automated-verification floor every
Supy repo must reach, regardless of stack: what CI must run, the coverage bar and how it is
enforced, and the baseline pre-commit hook set. It sits alongside the two other cross-cutting
standards — [`commit-conventions.md`](commit-conventions.md) and
[`secrets-and-config.md`](secrets-and-config.md) — and complements the per-stack architecture
standards, which own the *content* of the checks (lint rules, boundaries, test design). This
standard owns the *gates*: that the checks exist, run in CI, block on failure, and cannot be
silently bypassed.

**This is a floor, not a ceiling, and it is partly remediation-first.** Three TypeScript
repos (`supy-firebase-functions`, `supy-cli`, `supy-ai-agents`) today have **no tests, no CI,
and no pre-commit** (or only a deploy-scoped secret hook). For those repos the CI/coverage/test
rules below are the **target state** the scaffold moves them toward — they are **not** per-diff
blockers against an unrelated change. The single exception, load-bearing from unit 1 in *every*
repo, is the **blocking secret scan** (rule 6): a repo with no tests still must not be able to
commit a credential.

> **When reviewing, never reproduce a secret value.** If a CI log, coverage report, or hook
> output would echo a token, cite the `path:line` only. See `secrets-and-config.md`.

## Rules

1. **Every repo has CI that runs on `pull_request` and `push` to `main`, with concurrency
   cancellation.** The workflow triggers on both events for `branches: [main]` and sets a
   `concurrency` group keyed on `${{ github.workflow }}-${{ github.ref }}` with
   `cancel-in-progress: true`, so a force-push supersedes its own in-flight run. A repo whose
   default branch can receive a merge with no CN gate is a target-state gap (remediation-first
   repos) or a regression (repos that already have CI).

2. **CI runs the cheapest checks first so failures surface fast.** The canonical order is
   **format-check → lint → typecheck → test (with coverage) → build**. Formatting and lint are
   seconds; a build is minutes — never let a job spend minutes building only to fail on a
   missing semicolon. Nx repos express this with `nx affected -t <target>` (only projects
   touched by the diff); standalone repos run the package scripts directly. Reordering that puts
   a slow check before a fast one is a defect.

3. **Pin the toolchain version per stack; do not float.** The runtime is declared explicitly in
   CI, matching the repo's engines/SDK: **backend (nestjs-nx) Node 20**, **frontend
   (angular-nx) Node 24**, **firebase-functions Node 22** (jobs run with
   `working-directory: functions/`), **ts-cli Node 20**, **ai-agents Node 20 + Python 3.12
   (Poetry)**, **flutter `channel: stable`** via `subosito/flutter-action`. Bumping the version
   is a deliberate, reviewed change — not an implicit `latest`/`lts/*` drift.

4. **Tests run in CI in non-interactive mode with coverage collection on.** Node/TS stacks run
   `test --ci --coverage` (Jest `--ci` disables snapshot writing and watch); Flutter runs
   `flutter test --coverage`; Python runs `pytest` with coverage. Collecting coverage without
   also *gating* on it (rule 5) only produces an ignored artifact.

5. **A coverage floor is enforced as a gate — measured coverage that blocks nothing is not a
   gate.** The known bars are: **Flutter apps ≥ 80%**, **melos packages ≥ 85%** (`very_good_coverage`),
   **Flutter plugin ≥ 70% Dart + native tests** (Robolectric/XCTest). For Node/TS stacks that
   have a test suite, enforce the floor via the runner's own threshold mechanism (Jest
   `coverageThreshold` in config, or an explicit post-test percentage check that `exit 1`s below
   the bar) — the Flutter CI does exactly this with an lcov-parsing step that fails under 80%.
   The floor for the three remediation-first TS repos is **target state**: introduced *with* their
   first real test suite, not retrofitted as a blocker against unrelated diffs.

6. **A blocking secret scan runs in pre-commit from unit 1 — in every repo, tests or not.**
   `gitleaks protect --staged --redact --no-banner` (or the `gitleaks` pre-commit hook for
   config repos) MUST be the **first** hook and MUST exit non-zero on a detection so the commit
   is blocked. A warn-only scanner is non-compliant (`secrets-and-config.md#rules` rule 5). This
   is the one automated gate that is **never** deferred to target state: a repo with zero tests
   and no CI still must not be able to commit a token. Where pre-commit can be bypassed
   (`--no-verify`), also run gitleaks as a CI job for defense in depth (backend/frontend rely on
   Nx-affected jobs; firebase-functions, ts-cli, and ai-agents carry an explicit repo-root
   secret-scan CI job).

7. **Pre-commit mirrors CI's fast checks on the staged/affected set — not the whole repo.**
   After the secret scan, the baseline hook runs `lint-staged` (ESLint + Prettier on staged
   files; Ruff on staged `.py` in polyglot repos) and then the stack's fast correctness gate:
   Nx repos run `nx affected -t lint [typecheck] --uncommitted`; standalone TS repos run the
   package `typecheck` (the compile guarantee the repo ships a `bin` against); Flutter runs
   `dart format --set-exit-if-changed` + `flutter analyze`. The hook must stay fast (staged/
   affected scope only) or engineers will routinely `--no-verify` around it.

8. **Cerbos policies are compiled in CI (and pre-commit) wherever a repo holds them.** A repo
   that carries `cerbos/**` policy YAML runs `cerbos compile` as a gate so an invalid policy
   never merges (`security-cerbos.md`). k8s config/manifest repos additionally validate changed
   manifests with `kube-linter` (pre-commit) and schema-validate in CI (`secrets-and-config.md`
   `#rules` rule 6). Do not add these checks to repos that do not hold the corresponding
   artifacts.

9. **`passWithNoTests` is allowed only where there genuinely are no test files — never to make a
   project that *has* tests pass with zero executed coverage.** The shared-library variant
   (`supy-api-common`, `nx-nestjs-patterns.md` SV-series) legitimately sets Jest
   `passWithNoTests` on flat libs that ship no specs. Using it to green a build whose tests were
   deleted, skipped, or excluded — or to sidestep the coverage floor of rule 5 — is a defect.
   The tell is `passWithNoTests` living next to `*.spec.ts`/`*_test.dart` files that the config
   quietly excludes.

## Examples

**Good — fail-fast CI ordering with an affected graph (backend/frontend shape):**

```yaml
# .github/workflows/ci.yml
on:
  pull_request: { branches: [main] }
  push: { branches: [main] }
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  verify:
    steps:
      - uses: actions/setup-node@v4
        with: { node-version: 20 }           # rule 3: pinned, not lts/*
      - run: npx nx affected -t format:check  # rule 2: cheapest first
      - run: npx nx affected -t lint
      - run: npx nx affected -t typecheck
      - run: npx nx affected -t test --ci --coverage  # rule 4
      - run: npx nx affected -t build         # slowest last
```

**Good — coverage measured *and* gated (Flutter shape):**

```yaml
- run: flutter test --coverage               # rule 4
- name: Enforce coverage floor (>=80%)       # rule 5: the gate
  run: |
    PCT=$(… parse coverage/lcov.info …)
    if [ "${PCT:-0}" -lt 80 ]; then
      echo "::error::Coverage ${PCT}% is below the 80% floor"; exit 1
    fi
```

**Good — secret scan is the first, blocking pre-commit hook (every repo, from unit 1):**

```sh
#!/usr/bin/env sh
# 1. BLOCK committed secrets (secrets-and-config.md#rules rule 5). Non-negotiable, runs first.
gitleaks protect --staged --redact --no-banner
# 2. Lint + format only what's staged (fast).
npx lint-staged
# 3. Fast correctness gate on the affected/changed set.
npx nx affected -t lint typecheck --uncommitted
```

**Bad — coverage collected but nothing gates on it:**

```yaml
- run: npx nx affected -t test --ci --coverage
# …no threshold in jest config, no percentage check. Coverage can fall to 0% and CI stays green.
# Violates rule 5: an ignored artifact is not a gate.
```

**Bad — `passWithNoTests` hiding excluded specs:**

```jsonc
// jest.config.ts
{ "passWithNoTests": true,
  "testPathIgnorePatterns": ["<rootDir>/src/.*\\.spec\\.ts$"] } // specs exist, config skips them
// Violates rule 9: green build, zero executed tests, zero coverage.
```

**Bad — build before lint:**

```yaml
- run: npx nx affected -t build   # minutes
- run: npx nx affected -t lint    # seconds — should have run first (rule 2)
```

## Red flags

- CI workflow missing the `push`/`pull_request` on `main` triggers, or missing the
  `cancel-in-progress` concurrency group → rule 1.
- A `build` (or `test`) step ordered before `lint`/`format`/`typecheck` → rule 2.
- Node/Flutter version given as `lts/*`, `latest`, or omitted (floats across runs) → rule 3.
- `--coverage` collected with no `coverageThreshold`, no lcov floor check, and no failing exit
  below the bar → rule 5.
- **Secret scan absent from pre-commit, or present but warn-only / not the first hook** → rule 6
  (highest severity; the one gate that is never deferred to target state).
- Pre-commit that lints/tests the **whole repo** instead of the staged/affected set (slow enough
  that engineers `--no-verify`) → rule 7.
- `cerbos compile` missing in a repo that holds `cerbos/**` policies; `kube-linter` missing in a
  k8s config repo → rule 8.
- `passWithNoTests: true` sitting next to `*.spec.ts` / `*_test.dart` files that the config
  excludes or ignores → rule 9.

**Not a red flag (remediation-first):** the *absence* of tests, CI, or coverage in
`supy-firebase-functions`, `supy-cli`, or `supy-ai-agents` on a diff that does not touch those
concerns. Those are `## Remediation backlog` items in the respective stack standard, introduced
by the scaffold — not per-diff blockers. The blocking secret scan (rule 6) is the sole exception
and applies to them today.

## Source

Baseline shapes mined verbatim from the per-stack scaffolds in this plugin:
`templates/{backend,frontend,firebase-functions,ts-cli,ai-agents,flutter}/.github/workflows/ci.yml`
(triggers, concurrency, Node/Flutter version pins, check ordering, `--ci --coverage`, the
Flutter lcov ≥80% floor, and the firebase-functions/ts-cli/ai-agents repo-root secret-scan CI
jobs) and `templates/{backend,frontend,firebase-functions,ts-cli,ai-agents}/.husky/pre-commit`
- `templates/k8s-config/.pre-commit-config.yaml` (gitleaks-first ordering, `lint-staged`,
`nx affected --uncommitted`, package `typecheck`, kube-linter). Coverage bars for Flutter come
from `flutter/flutter-conventions.md` (apps ≥80% / melos packages ≥85% / plugin ≥70% Dart +
native). The `passWithNoTests` carve-out is the `supy-api-common` shared-library variant
(`nx-nestjs-patterns.md` SV-series). The remediation-first framing for the three TypeScript
repos matches their `## Remediation backlog` sections in
`firebase-functions/architecture.md`, `ts-cli/architecture.md`, and `ai-agents/architecture.md`.
