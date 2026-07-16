# supy-wingspan Pilot Notes

supy-wingspan is Supy's internal Claude Code plugin. It enforces engineering best practices across every `supy-*` repository through AI: stack-aware review subagents (NestJS backend, Angular frontend, Flutter mobile, Firebase Functions, TypeScript CLI, the polyglot AI-agents monorepo, and Kubernetes config — dispatched by stack) plus two stack-agnostic reviewers (commit/PR conventions and a secret scanner) that run on every repo, a consistency-baseline generator, scaffolding and Git skills, and thin orchestration wrappers over `superpowers`. This document records the P5 (Task 10) pilot and the subsequent multi-stack expansion (Phases 3–6): what was structurally validated, the exact procedure to enable the plugin in a live session, the exercise checklist for confirming the core loop, degradation behaviour, and known gaps.

## Pilot status (2026-07-16)

- ✅ **Structural validation — complete (re-run 2026-07-16 after the multi-stack expansion).** Plugin tree validated at **11 agents / 14 skills / 4 commands / 9-way ordered stack detection**, all components load, verification checks (shellcheck, JSON, frontmatter) pass. See [Validation results](#validation-results).
- ✅ **Graceful degradation — verified by inspection.** Fallback branches confirmed by reading the command/skill sources. See [Graceful degradation](#graceful-degradation).
- ⏳ **Live install + core-loop exercise — pending.** The interactive `/plugin` install and the `/supy-review` + `supy-commit` runs cannot be driven headlessly; they must be run by a human in a real session. Follow the [Pilot exercise checklist](#pilot-exercise-checklist) and record results here. Boxes are unticked until confirmed live.

## Validation results

The `plugin-dev:plugin-validator` was first run against the full plugin tree on 2026-07-15 (after the `flutter` mobile additions), and **re-run on 2026-07-16 after the multi-stack expansion** (Phases 3–6: the `firebase-functions`, `ts-cli`, and `ai-agents` asset sets, the BLOCKING secrets reviewer, the Flutter Profile A/B split, and the cross-cutting CI/coverage baseline). Both runs returned VALID. `shellcheck` was run against `detect-stack.sh` separately and is clean.

Verdict: **VALID** — zero critical errors, zero blocking warnings; the only finding was cosmetic (leftover `.gitkeep` markers in now-populated directories, since removed).

| Component | Result |
|---|---|
| Agents | 11 / 11 valid — backend: `supy-architecture-reviewer`, `supy-nats-event-reviewer`, `supy-test-quality-reviewer`, `supy-security-reviewer`; frontend: `supy-angular-reviewer`; mobile: `supy-flutter-reviewer`; standalone: `supy-firebase-functions-reviewer`, `supy-ts-cli-reviewer`, `supy-ai-agents-reviewer`; stack-agnostic (run on every stack): `supy-commit-pr-reviewer`, `supy-secrets-reviewer` |
| Skills | 14 / 14 valid (`supy-review`, `supy-baseline`, `supy-commit`, `supy-create-pr`, `supy-scaffold-handler`, `supy-clean-architecture`, `supy-scaffold-domain`, `supy-scaffold-feature`, `supy-angular-feature`, `supy-scaffold-flutter-feature`, `supy-flutter-feature`, `supy-firebase-function`, `supy-ts-cli`, `supy-ai-agents`) |
| Commands | 4 / 4 valid — none carry a forbidden `name:` key (`supy-brainstorm`, `supy-plan`, `supy-build`, `supy-review`) |
| `hooks/hooks.json` | Valid |
| `hooks/detect-stack.sh` | Present and executable (`-rwxr-xr-x`); `shellcheck` clean; 9-way ordered detection (angular-nx → nestjs-nx → nx → flutter → firebase-functions → ts-cli → ai-agents → k8s-config → generic) |
| Hardcoded absolute paths | None in component bodies — `${CLAUDE_PLUGIN_ROOT}` used throughout (91 occurrences) |
| Cross-cutting standards | Three at the root of `config/standards/`: `commit-conventions.md`, `secrets-and-config.md` (BLOCKING secret/config separation), `ci-coverage-baseline.md` (coverage bars + pre-commit) — all stack-agnostic |
| Frontend assets | `templates/frontend/` (CLAUDE.md.hbs + Plop generator + enforcement configs) and `config/standards/frontend/` (`angular-conventions.md`, `module-boundaries.md`) present |
| Backend clean-arch assets | `templates/backend/tools/generators/` (Plop `g:domain` generator + templates) and `config/standards/backend/module-boundaries.md` present; the `supy-clean-architecture` how-to and `supy-scaffold-domain` scaffolder cite `architecture.md` (incl. `#ddd-building-blocks`) + `module-boundaries.md` |
| Flutter assets | `templates/flutter/` (CLAUDE.md.hbs + `analysis_options.yaml` + `.editorconfig` + CI workflow + `tools/feature/` bundled `.hbs` stubs) and `config/standards/flutter/` present; standards are split into Profile A (`dartz`/`Either`) vs Profile B (`PageState`/`throwAppException`) with plugin/melos sub-profiles; the `supy-flutter-feature` how-to and `supy-scaffold-flutter-feature` scaffolder cite them by H2 anchor. No `package.json`/`node` — enforcement is `very_good_analysis` + `bloc_lint` |
| Firebase Functions assets | `config/standards/firebase-functions/` rulebook + `templates/firebase-functions/` (CI + pre-commit + secret-scan baselines) present; the `supy-firebase-function` how-to cites them — clean-arch layer direction, Awilix DI, runtime auth markers, typed domain errors, Firestore-trigger idempotency, Secret-Manager-only secrets |
| TypeScript CLI assets | `config/standards/ts-cli/` rulebook + `templates/ts-cli/` (CI + pre-commit + secret-scan baselines) present; the `supy-ts-cli` how-to cites them — clean-arch layers, `IScript`/`ScriptDetails` contract, env-layered config, explicit prod confirmation, no secrets in argv/logs, deterministic exit codes, batched bulk MongoDB ops |
| AI-agents assets | `config/standards/ai-agents/` architecture & operational standard + `templates/ai-agents/` (CI + pre-commit + secret-scan baselines) present; the `supy-ai-agents` how-to cites them — secret hygiene, auth on exposed MCP tools/routes, env-driven config, validation + error handling, idempotent BullMQ consumers, non-root containers |
| K8s-config assets | `templates/k8s-config/` (secret-scan baseline) present; no dedicated `config/standards/` subdir — governed by the root cross-cutting `secrets-and-config.md` and served by the two stack-agnostic reviewers (secrets + commit/PR) |

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
- **Skills (invoked as skills, not slash commands):** `supy-review`, `supy-baseline`, `supy-commit`, `supy-create-pr`; backend: `supy-scaffold-handler`, `supy-clean-architecture`, `supy-scaffold-domain`; frontend: `supy-scaffold-feature`, `supy-angular-feature`; mobile: `supy-scaffold-flutter-feature`, `supy-flutter-feature`; standalone: `supy-firebase-function`, `supy-ts-cli`, `supy-ai-agents`
- Agents: the review subagents dispatched internally by `/supy-review`, by stack — `nestjs-nx` → 6 (architecture, NATS events, test quality, commit/PR, security, secrets); `angular-nx` → 3 (Angular/NGXS, commit/PR, secrets); `flutter` → 3 (Flutter/Clean-Arch, commit/PR, secrets); `firebase-functions` → 3 (Firebase Functions, commit/PR, secrets); `ts-cli` → 3 (CLI + operational-safety, commit/PR, secrets); `ai-agents` → 3 (AI-agents architecture + operational-safety, commit/PR, secrets); `k8s-config` → 2 (secrets, commit/PR); any other stack → 2 (commit/PR, secrets). The commit/PR and secrets reviewers are stack-agnostic and run on every stack.
- SessionStart hook: `detect-stack.sh` runs at session open and prints `supy-wingspan: detected <stack> repo.` (one of `nestjs-nx`, `angular-nx`, `nx`, `flutter`, `firebase-functions`, `ts-cli`, `ai-agents`, `k8s-config`; silent on unknown/mixed stacks)

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

2. **Review agents declare `Grep` and `Glob` as tool identifiers.** All eleven review agents list `tools: Read, Grep, Glob, Bash`. If the runtime does not expose `Grep` or `Glob` as explicit tool identifiers, those entries are silently ignored and the agents still function using `Read` and `Bash`. No action required unless the runtime tool ID list differs and the agents produce degraded results.

## Stacks & remaining live validation

This release covers **seven stacks in one plugin**, each detected and served with its own agents, skills, standards, and CLAUDE.md template:

- **`nestjs-nx`** — NestJS-on-Nx backend with NATS eventing and Cerbos authorization (6 reviewers)
- **`angular-nx`** — Angular-on-Nx frontend with NGXS + PrimeNG (3 reviewers)
- **`flutter`** — Clean Architecture + BLoC mobile, Profile A (`dartz`/`Either`) vs Profile B (`PageState`) with plugin/melos sub-profiles (3 reviewers)
- **`firebase-functions`** — standalone clean-arch Node/TS serverless with Awilix DI + runtime auth markers (3 reviewers)
- **`ts-cli`** — standalone commander.js MongoDB scripts runner with the `IScript`/`ScriptDetails` contract + operational-safety rules (3 reviewers)
- **`ai-agents`** — the polyglot supy-ai-agents monorepo (Node.js + Python + Cloudflare Workers, MCP tools, BullMQ, pgvector KG) with an architecture & operational standard (3 reviewers)
- **`k8s-config`** — Kubernetes/kustomize config, served by the two stack-agnostic reviewers (2 reviewers)

Stack detection (SessionStart hook, `supy-review`, and `supy-baseline`) runs the ordered chain in `hooks/detect-stack.sh` — the order is an invariant, since `ai-agents` and `ts-cli` are both `package.json`-based and would otherwise collide. React/Next.js frontend repositories remain intentionally out of scope for v0.1.0.

All seven stacks were validated **structurally** (see [Validation results](#validation-results)) — every agent, skill, standard, and template loads and passes the validator, and `${CLAUDE_PLUGIN_ROOT}` resolves throughout. What remains is **live** validation: a headed `/plugin install` + core-loop run in a real repo per stack, mirroring the `nestjs-nx` [Pilot exercise checklist](#pilot-exercise-checklist) above. Those live runs cannot be driven headlessly and are still pending for every stack.

The multi-stack expansion proved the stack-branching model scales well past a single Nx/TypeScript shape: detection adds one ordered branch per stack, and the two stack-agnostic reviewers (commit/PR + secrets) and the Git skills apply unchanged everywhere. If a future stack diverges enough that runtime branching becomes unwieldy, the fallback plan (per the design spec's open items, §11) remains an **Approach C split**: separate per-stack plugins or profiles registered under the same `supy` marketplace, each carrying their own standards, agents, and stack-detection hook output.
