# supy-wingspan Pilot Notes

supy-wingspan is Supy's internal Claude Code plugin. It enforces engineering best practices across every `supy-*` repository through AI: stack-aware review subagents (NestJS backend + Angular frontend + Flutter mobile, dispatched by stack), a consistency-baseline generator, scaffolding and Git skills, and thin orchestration wrappers over `superpowers`. This document records the P5 (Task 10) pilot: what was structurally validated, the exact procedure to enable the plugin in a live session, the exercise checklist for confirming the core loop, degradation behaviour, and known gaps.

## Pilot status (2026-07-15)

- ✅ **Structural validation — complete.** Plugin tree validated, all components load, verification checks (shellcheck, JSON, frontmatter) pass. See [Validation results](#validation-results).
- ✅ **Graceful degradation — verified by inspection.** Fallback branches confirmed by reading the command/skill sources. See [Graceful degradation](#graceful-degradation).
- ⏳ **Live install + core-loop exercise — pending.** The interactive `/plugin` install and the `/supy-review` + `supy-commit` runs cannot be driven headlessly; they must be run by a human in a real session. Follow the [Pilot exercise checklist](#pilot-exercise-checklist) and record results here. Boxes are unticked until confirmed live.

## Validation results

The `plugin-dev:plugin-validator` was run against the full plugin tree on 2026-07-15 (re-run after the `flutter` mobile additions). `shellcheck` was run against `detect-stack.sh` separately.

Verdict: **VALID** — zero critical errors, zero blocking warnings.

| Component | Result |
|---|---|
| Agents | 7 / 7 valid — backend: `supy-architecture-reviewer`, `supy-nats-event-reviewer`, `supy-test-quality-reviewer`, `supy-security-reviewer`; frontend: `supy-angular-reviewer`; mobile: `supy-flutter-reviewer`; stack-agnostic: `supy-commit-pr-reviewer` |
| Skills | 11 / 11 valid (`supy-review`, `supy-baseline`, `supy-commit`, `supy-create-pr`, `supy-scaffold-handler`, `supy-clean-architecture`, `supy-scaffold-domain`, `supy-scaffold-feature`, `supy-angular-feature`, `supy-scaffold-flutter-feature`, `supy-flutter-feature`) |
| Commands | 4 / 4 valid — none carry a forbidden `name:` key (`supy-brainstorm`, `supy-plan`, `supy-build`, `supy-review`) |
| `hooks/hooks.json` | Valid |
| `hooks/detect-stack.sh` | Present and executable (`-rwxr-xr-x`); `shellcheck` clean |
| Hardcoded absolute paths | None in component bodies — `${CLAUDE_PLUGIN_ROOT}` used throughout |
| Frontend assets | `templates/frontend/` (CLAUDE.md.hbs + Plop generator + enforcement configs) and `config/standards/frontend/` (`angular-conventions.md`, `module-boundaries.md`) present |
| Backend clean-arch assets | `templates/backend/tools/generators/` (Plop `g:domain` generator + templates) and `config/standards/backend/module-boundaries.md` present; the `supy-clean-architecture` how-to and `supy-scaffold-domain` scaffolder cite `architecture.md` (incl. `#ddd-building-blocks`) + `module-boundaries.md` |
| Flutter assets | `templates/flutter/` (CLAUDE.md.hbs + `analysis_options.yaml` + `.editorconfig` + CI workflow + `tools/feature/` bundled `.hbs` stubs) and `config/standards/flutter/` (`architecture.md`, `flutter-conventions.md`) present; the `supy-flutter-feature` how-to and `supy-scaffold-flutter-feature` scaffolder cite both by H2 anchor. No `package.json`/`node` — enforcement is `very_good_analysis` + `bloc_lint` |

Runtime items to confirm during the live pilot are recorded under [Verify at install / known gaps](#verify-at-install--known-gaps) below.

## Local enablement

The following two commands enable the plugin from inside a Claude Code session opened in the target repository (e.g., `supy-service-inventory`). They are structurally validated — the marketplace `name` is `supy`, the plugin `name` is `supy-wingspan`, and `source` resolves to the repo root — but await live confirmation in an actual session.

```
/plugin marketplace add ~/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
```

Where:
- The path argument to `marketplace add` is the supy-wingspan repo root. The `~` form above is portable across machines; a fully-qualified absolute path (e.g. `/Users/<you>/Projects/supy-projects/supy-wingspan`) works too if `~` is not expanded.
- `supy-wingspan@supy` is `<plugin-name>@<marketplace-name>` as defined in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

If the pilot repo tracks its own `.claude/settings.json`, add the marketplace entry there before running the above, so the registration persists across sessions.

After install, the following should be available:
- **Commands (slash):** `/supy-brainstorm`, `/supy-plan`, `/supy-build`, `/supy-review`
- **Skills (invoked as skills, not slash commands):** `supy-review`, `supy-baseline`, `supy-commit`, `supy-create-pr`; backend: `supy-scaffold-handler`, `supy-clean-architecture`, `supy-scaffold-domain`; frontend: `supy-scaffold-feature`, `supy-angular-feature`; mobile: `supy-scaffold-flutter-feature`, `supy-flutter-feature`
- Agents: the review subagents dispatched internally by `/supy-review` — 5 backend reviewers for `nestjs-nx`, the Angular reviewer + commit/PR reviewer for `angular-nx`, the Flutter reviewer + commit/PR reviewer for `flutter`, the stack-agnostic commit/PR reviewer otherwise
- SessionStart hook: `detect-stack.sh` runs at session open and prints `supy-wingspan: detected <stack> repo.` (one of `nestjs-nx`, `angular-nx`, `nx`, `flutter`, `generic`)

## Pilot exercise checklist

Run the following in `supy-service-inventory` on a scratch branch that contains a small real change. Do not push — local-only. Tick each item after confirming the expected result.

1. - [ ] Open a Claude Code session inside `supy-service-inventory` and run:
   ```
   /plugin marketplace add ~/Projects/supy-projects/supy-wingspan
   /plugin install supy-wingspan@supy
   ```
   **Expected:** Claude Code reports the plugin installed successfully, no errors.

2. - [ ] Check the session-start output (scroll up to the very beginning of the session).
   **Expected:** A line matching `supy-wingspan: detected nestjs-nx repo.` appears at session open.

3. - [ ] Create a scratch branch and make a small real change (e.g., add a method stub or modify a module file):
   ```bash
   git checkout -b pilot/supy-wingspan-test
   # make a small edit, then stage it
   git add <file>
   ```
   **Expected:** `git diff $(git merge-base HEAD origin/main || git merge-base HEAD main)...HEAD --stat` shows at least one changed file. (Note: `/supy-review` reviews the whole branch diff vs. the merge-base with `origin/main` or `main`, not just the last commit.)

4. - [ ] Run `/supy-review` with no arguments.
   **Expected:** Claude dispatches all five review subagents in parallel, waits for results, and emits a consolidated report with the header `# Supy Review — N issues (H high, M med, L low)`, findings grouped into `## High`, `## Medium`, `## Low`, and `## Clean` sections.

5. - [ ] Invoke the `supy-commit` skill (ask Claude to prepare the commit; it is a skill, not a `/`-command — e.g. "run the supy-commit skill").
   **Expected:** Claude produces a conventional-commit message (type, optional scope, short description) that ends with the trailer:
   ```
   Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
   ```
   Confirm the message is not auto-pushed — the skill is commit-only with no push step.

6. - [ ] Clean up:
   ```bash
   git checkout main
   git branch -D pilot/supy-wingspan-test
   ```
   **Expected:** Branch deleted locally, nothing pushed to remote.

## Graceful degradation

### `/supy-brainstorm` and `/supy-plan` when `superpowers` is absent

Both commands contain an explicit fallback branch that runs without the `superpowers` plugin.

`/supy-brainstorm` fallback (confirmed by reading `commands/supy-brainstorm.md`): when `superpowers:brainstorming` is not available, the command runs a three-step guided clarification, asking one question at a time — Purpose, Constraints, Success criteria — and synthesising a three-to-five-bullet summary mapped onto Supy's bounded contexts and standards. It is self-sufficient: it loads the standards files from `${CLAUDE_PLUGIN_ROOT}/config/standards/` and produces a **"Risks & Gaps"** section without any external dependency.

`/supy-plan` fallback (confirmed by reading `commands/supy-plan.md`): when `superpowers:writing-plans` is not available, the command produces a phased Markdown task list directly, structured as domain → application → infrastructure → testing phases, with each task naming the Nx library it touches. The plan is saved to `docs/superpowers/plans/<kebab-case-title>.md` in the target repository, creating the directory if needed. The fallback is fully self-sufficient.

Both commands degrade gracefully — they still produce useful, Supy-contextualised output when `superpowers` is absent.

### `/supy-review` on an empty diff

Confirmed by reading `skills/supy-review/SKILL.md` (Step 1 of the skill): before dispatching any agent, the skill runs `git diff ${DIFF_BASE}...HEAD --stat`. If the output is empty (no changes) or the working directory is not a git repository, the skill stops immediately and prints:

```
No changes to review — supy-review needs a non-empty diff
```

No agents are dispatched. The behaviour is explicit and deterministic.

## Verify at install / known gaps

The following two non-blocking warnings were recorded by the validator. They do not prevent install but should be verified during the live pilot.

1. **`SessionStart` hook has no `matcher` field.** The `hooks/hooks.json` entry for `SessionStart` does not include a `matcher`. This is correct for session-lifecycle events, but if the target Claude Code runtime requires a `matcher` even for `SessionStart`, the hook entry could be silently skipped. Verify during the live pilot (checklist step 2) that the `detect-stack.sh` message actually fires at session open.

2. **Review agents declare `Grep` and `Glob` as tool identifiers.** All seven review agents list `tools: Read, Grep, Glob, Bash`. If the runtime does not expose `Grep` or `Glob` as explicit tool identifiers, those entries are silently ignored and the agents still function using `Read` and `Bash`. No action required unless the runtime tool ID list differs and the agents produce degraded results.

## Next stacks

This release covers three stacks in one plugin: NestJS-on-Nx (`nestjs-nx`) with NATS eventing and Cerbos authorization, Angular-on-Nx (`angular-nx`) with NGXS + PrimeNG, and Flutter (`flutter`) with Clean Architecture + BLoC. Stack detection (SessionStart hook, `supy-review`, and `supy-baseline`) branches on the repo's `package.json` for the two Nx stacks and on `pubspec.yaml` for Flutter, so each repo gets only its stack's agents, skills, and CLAUDE.md template. React/Next.js frontend repositories remain intentionally out of scope for v0.1.0.

The `angular-nx` and `flutter` support was validated structurally alongside the backend. For `flutter`: the `supy-flutter-reviewer` agent, the `supy-scaffold-flutter-feature`/`supy-flutter-feature` skills, the `templates/flutter/` CLAUDE.md template + bundled `.hbs` feature stubs + `analysis_options.yaml`, and the `config/standards/flutter/` rulebooks all load and pass verification. Flutter is not Nx: it has no `package.json`, no Plop, and no npm/node — the scaffolder copies bundled `.hbs` stubs with manual placeholder substitution, and enforcement is `very_good_analysis` + `bloc_lint` via `analysis_options.yaml`. A live `angular-nx` pilot and a live `flutter` pilot in real Supy repos — mirroring the backend checklist below — are still pending.

Bringing Flutter into this plugin (rather than a separate one) proved the stack-branching model scales past Nx/TypeScript: detection simply adds a `pubspec.yaml` branch, and the shared commit/PR reviewer and Git skills apply unchanged. If a future stack diverges enough that runtime branching becomes unwieldy, the fallback plan (per the design spec's open items, §11) remains an **Approach C split**: separate per-stack plugins or profiles registered under the same `supy` marketplace, each carrying their own standards, agents, and stack-detection hook output.
