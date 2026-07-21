# supy-wingspan

Supy's internal Claude Code plugin. Makes every `supy-*` repo follow Supy engineering
best practices through AI: stack-aware review agents (NestJS backend, Angular frontend,
Flutter mobile, Firebase Functions, TypeScript CLI, the polyglot AI-agents monorepo, and
Kubernetes config), plus two stack-agnostic reviewers — commit/PR conventions and a
secret scanner — that run on every repo. Ships scaffolding, Git, spec-authoring, CI-fixing,
and Flutter delivery skills (Figma-to-code, release readiness, SDK upgrades, code assessment),
a consistency-baseline generator, and thin orchestration wrappers over `superpowers`. Each repo
only surfaces the skills for its own stack, so backend and Flutter devs never see each other's.

## Status

v0.1.1. Published at [`abed-supy-io/supy-wingspan`](https://github.com/abed-supy-io/supy-wingspan) (public).

## Install

From any supy repo (or user settings), add the marketplace and install the plugin.
Run these as **two separate commands** — the second only after the first completes:

```text
/plugin marketplace add abed-supy-io/supy-wingspan
/plugin install supy-wingspan@supy
```

Then run `/reload-plugins` to apply — the commands and skills become available immediately.

Or in one line from the terminal:

```text
claude plugin marketplace add abed-supy-io/supy-wingspan && claude plugin install supy-wingspan@supy
```

<details>
<summary>Install from a local checkout instead</summary>

```text
/plugin marketplace add ~/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
```

</details>

See [`docs/USAGE.md`](docs/USAGE.md) for the full install / usage / deployment
guide, and [`docs/PILOT.md`](docs/PILOT.md) for the validated enablement
procedure, the pilot exercise checklist, and known gaps.

## Usage

The plugin exposes **7 slash commands** and **30 skills**. Commands are typed
directly (`/name`); skills are invoked in natural language ("run the supy-commit
skill") — they are not slash commands.

The skills are grouped below by stack. Every repo gets the **Universal** skills; the
per-stack skills only apply in a repo of that stack — so a backend dev works with the
backend set, a Flutter dev with the Flutter set, and neither is bothered by the other's.
The stack is detected automatically (see the SessionStart hook), and `supy-baseline`
writes only the Universal + this-repo's-stack skills into each repo's `CLAUDE.md`.

### Slash commands

| Command | What it does |
|---|---|
| `/supy-brainstorm [idea]` | Turns a rough idea into a design, wrapping `superpowers:brainstorming` with Supy stack context. Falls back to a built-in one-question-at-a-time clarification (purpose → constraints → success criteria) when `superpowers` is absent. |
| `/supy-plan [feature]` | Produces a phased implementation plan from a feature/task description, wrapping `superpowers:writing-plans`. Fallback writes a domain → application → infrastructure → testing task list to `docs/superpowers/plans/`. |
| `/supy-feature [feature]` | Plans **one feature across several open repos** from a single prompt. Scans the parent folder for git repos, detects each one's stack, proposes which repos the feature touches (you confirm), then writes a per-repo plan into each affected repo under `docs/superpowers/plans/` — each grounded in that repo's standards, all naming the shared cross-repo contract identically. Plan-only: never edits code, branches, commits, or opens PRs. |
| `/supy-build [plan]` | Executes a plan task-by-task, wrapping `superpowers:executing-plans` / `subagent-driven-development`. Fallback runs the plan with **local-only** commits (never pushes). |
| `/supy-onboard [focus]` | Onboards or refreshes a repo's Supy AI setup — a thin wrapper over the `supy-baseline` skill, plus a section-level CLAUDE.md drift check against the stack's template. Reports drift before offering regeneration. |
| `/supy-release [action]` | Reports the release-please state of this plugin repo: pending release PR, unreleased commits since the last tag, the version bump they imply, and consumer impact. Read-only unless passed `ship`, which merges the pending release PR after confirmation. Degrades to a local-git-only report when `gh` is unavailable. |
| `/supy-review [base-ref]` | Reviews the current branch diff. Detects the repo stack and dispatches the matching review subagents in parallel, then consolidates their findings into one severity-grouped report. Dispatch by stack: `nestjs-nx` → 6 (architecture, NATS events, test quality, commit/PR, security, secrets); `angular-nx` → 3 (Angular/NGXS, commit/PR, secrets); `flutter` → 3 (Flutter/Clean-Arch, commit/PR, secrets); `firebase-functions` → 3 (Firebase Functions/Clean-Arch, commit/PR, secrets); `ts-cli` → 3 (CLI/Clean-Arch + operational-safety, commit/PR, secrets); `ai-agents` → 3 (AI-agents architecture + operational-safety, commit/PR, secrets); `k8s-config` → 2 (secrets, commit/PR); any other stack → 2 (commit/PR, secrets). The commit/PR and secrets reviewers are stack-agnostic and run on every stack. Optional arg overrides the diff base (defaults to the merge-base with `origin/main`/`main`, then `HEAD~1`). |

### Skills

#### Universal — every Supy repo

| Skill | What it does |
|---|---|
| `supy-review` | The review orchestration behind `/supy-review` — usable directly as a skill too. Detects the stack and dispatches the matching reviewers. |
| `supy-baseline` | Generates or updates the repo's `CLAUDE.md` from the canonical template + repo inspection (+ Cortex when connected). Writes only the Universal + this-stack skills into the routing footer. Never clobbers an existing file silently — shows a diff and asks first. |
| `supy-commit` | Proposes a Conventional Commits message grounded in `config/standards/commit-conventions.md`, ending with the `Co-Authored-By: Claude Opus 4.8 (1M context)` trailer. Confirmation-gated; commit-only, never pushes. |
| `supy-create-pr` | Builds a conventional PR title + Summary/Changes/Test-evidence/Issue-refs body. Pushes via `gh` when a remote and `gh` are available; otherwise prints a ready-to-paste PR and manual instructions. Runs a Flutter pre-flight (`dart format` + `flutter analyze`) when a `pubspec.yaml` is present. |
| `supy-rebase` | Rebases the current branch onto its base the safe way — resolves the base branch, requires a clean tree, records a `PRE_REBASE_SHA` safety ref, then rebases and resolves conflicts one commit at a time (never `--skip`). Force-pushes with `--force-with-lease` only after you confirm. |
| `supy-hotfix` | Drives a disciplined production hotfix — cuts a `hotfix/<slug>` branch from the remote base, keeps the diff minimal, commits as `fix` (via supy-commit), reviews (via supy-review), fast-tracks the PR (via supy-create-pr), then handles back-merge and release follow-ups. |
| `supy-debrief` | Produces a structured handoff/retrospective for the current branch from the actual commits and diff — context, what changed, why, verification, known gaps, follow-ups — as a ready-to-paste block, and optionally saves it to `docs/debriefs/`. Never auto-commits. |
| `fix-failing-github-actions` | Finds the failing GitHub Actions checks for the branch/PR, pulls the run logs, fixes the root cause, commits + pushes (via supy-commit / supy-create-pr), then re-checks after a short wait — looping until every check is green. |
| `supy-impl-spec` | Turns a Jira/GitHub ticket into a full implementation spec — architecture, testing strategy, implementation details — under `docs/specs/`, ready to build from. |
| `supy-spike-spec` | Turns a ticket into a spike/research spec — research questions, options to evaluate, PoC scope, success criteria — under `docs/specs/`, for work that needs investigation before it can be planned. |
| `supy-feature-fanout` | Behind `/supy-feature`. Plans one feature across several open repos: scans the parent folder, detects each repo's stack, proposes the affected set (you confirm), then writes a per-repo plan (grounded in that repo's standards) into each. Plan-only — never edits code or opens PRs. |

#### Backend — NestJS on Nx (`nestjs-nx`)

| Skill | What it does |
|---|---|
| `supy-clean-architecture` | The how-to for writing backend code the Supy way — Clean/Hexagonal Architecture + DDD + CQRS: aggregates with methods + `this.assign`/`this.addEvent`, value objects with state machines, factories, repository interfaces, interactors that persist atomically then side-effect, NATS controllers. Grounded in `config/standards/architecture.md` + `config/standards/backend/module-boundaries.md`; the companion to `supy-scaffold-domain`. |
| `supy-scaffold-domain` | Scaffolds a complete Clean-Architecture/DDD bounded context via the Plop `g:domain` generator — five tagged libs (api, logic, domain/model, domain/service, data) with aggregate, value objects, state VO, factory, events, repository, schema, transformers, interactor, controller — then walks the fill-in in dependency order and prints the four manual wiring steps. Offers to install the generator if the repo lacks it. |
| `supy-scaffold-handler` | Scaffolds a new NestJS NATS handler (RPC request or JetStream event) with a colocated DTO and test stub, following the mined Nx/NestJS layout. Prefers a repo Nx generator; else copies the nearest existing handler. Confirms planned paths before writing. |

#### Frontend — Angular on Nx (`angular-nx`)

| Skill | What it does |
|---|---|
| `supy-angular-feature` | The how-to for writing Angular the Supy way — OnPush + `inject()` components, signal I/O, NGXS state with Immer `produce()`, URI-token services, lazy routes, `--p-*` styling. Grounded in `config/standards/frontend/`; the companion to `supy-scaffold-feature`. |
| `supy-scaffold-feature` | Scaffolds a complete Angular NGXS feature library via the Plop generator — tagged `project.json`, models, state/actions, URI-token service, smart+dumb components, resolver, lazy routes — then walks the fill-in in dependency order and prints the three manual wiring steps. Offers to install the generator if the repo lacks it. |

#### Flutter / mobile (`flutter`)

| Skill | What it does |
|---|---|
| `supy-flutter-feature` | The how-to for writing Flutter the Supy way — Clean Architecture 3 layers/feature, BLoC (never Cubit) with sealed events + freezed state, go_router with `static const path`/`name`, get_it DI, dio interceptor chain, `dartz` `Either<Failure, T>` + sealed `Failure` hierarchy, `UseCase<T, Params>`, hive cache policies, design tokens, `mocktail`+`bloc_test`. Grounded in `config/standards/flutter/`; the companion to `supy-scaffold-flutter-feature`. |
| `supy-scaffold-flutter-feature` | Scaffolds a complete Clean-Architecture feature (domain + data + presentation + tests) from bundled `.hbs` stubs, then walks the fill-in and prints the three manual wiring steps (get_it registration, go_router route, barrel export). Also creates a brand-new project via `very_good create`. Prefers a repo `mason`/`very_good` generator when present. |
| `supy-figma-implement-design` | Translates a Figma design into a production-ready Flutter widget with 1:1 fidelity via the Figma MCP — maps design tokens onto `ThemeData`/`ColorScheme`/`ThemeExtension`, places the widget in the shared UI package, validates with Alchemist goldens (+ Widgetbook use cases). |
| `supy-figma-to-tickets` | Reads a Figma file via the Figma MCP and turns its screens/flows into dependency-ordered GitHub issues or Jira tickets, each deep-linked to its Dev Mode node. Confirms scope before creating anything. (Also useful in frontend repos.) |
| `supy-e2e-tests` | Writes, runs, and debugs the retailer end-to-end (`integration_test`) suite against the live dev backend on the Android emulator — run command, feature-flag gates, authz-race waits, finder caveats, never-weaken-assertions. (Applies to the supy-retailer repo.) |
| `supy-app-release-readiness` | Audits a Flutter app for release readiness across every detected platform (Android/iOS/web/macOS/Linux/Windows) by launching the six platform readiness agents in parallel, then synthesizes a unified `RELEASE_TODO.md`. |
| `supy-flutter-upgrade` | Bumps Flutter/Dart SDK versions across every `pubspec.yaml`, `.fvmrc`, and Actions workflow, then re-runs pub get / format / analyze / fix and reviews the release notes for breaking changes. |
| `supy-code-assessment` | A structured whole-project audit of a Flutter/Dart codebase against Supy's Flutter standards, written up as `CODE_ASSESSMENT.md` (architectural risks, scalability/testability gaps, refactoring estimate). For a single diff, use `supy-review` instead. |
| `supy-analyze-native-codebase` | Analyzes a native iOS (Swift/Obj-C) and/or Android (Kotlin/Java) codebase to produce a Flutter migration manifest, PRD, risk register, and per-feature reports. |
| `supy-interview-feedback` | Evaluates a candidate's Flutter take-home against Supy's architecture/BLoC/engineering standards and writes a scored `INTERVIEW_FEEDBACK.md` with a hiring recommendation. |

#### Firebase Functions (`firebase-functions`)

| Skill | What it does |
|---|---|
| `supy-firebase-function` | The how-to for writing Firebase Functions code in the standalone supy-firebase-functions repo the Supy way — Clean Architecture (index.ts → app interactors → data repositories → frameworks), Awilix DI, runtime-enforced auth markers (`@unauthenticated`/`@internal`/`@admin`/`@apiKey`), typed domain errors, idempotent Firestore triggers, and secrets from Secret Manager (never literals). |

#### TypeScript CLI (`ts-cli`)

| Skill | What it does |
|---|---|
| `supy-ts-cli` | The how-to for writing CLI code in the standalone supy-cli repo the Supy way — Clean Architecture (presentation commands → application scripts → infrastructure → domain), commander.js `scripts [run\|list\|info]`, the `IScript`/`ScriptDetails` self-documenting contract, env-layered config, explicit production confirmation before any prod mutation, no secrets in argv/logs, deterministic exit codes, testable use cases, and batched bulk MongoDB operations. |

#### AI-agents monorepo (`ai-agents`)

| Skill | What it does |
|---|---|
| `supy-ai-agents` | Write and change code in the polyglot supy-ai-agents monorepo (Cortex/Nexus/Oculus/Gleap/PMS-AI — Node.js + Python + Cloudflare Workers, MCP tools, BullMQ, pgvector KG) so it follows the Supy ai-agents architecture & operational standard — secret hygiene, auth on exposed tools, env-driven config, validation + error handling, idempotent consumers, and non-root containers. |

### SessionStart hook

On session open, `detect-stack.sh` prints one line — e.g. `supy-wingspan: detected
nestjs-nx repo.` — and nudges you to run the `supy-baseline` skill if the repo has
no `CLAUDE.md`. It stays silent on unknown or mixed stacks and never fails the session.

### UserPromptSubmit hook (skill routing)

`skill-router.sh` reads each prompt and, when it recognizes an engineering intent, injects a
one-line nudge to prefer the matching skill over ad-hoc steps. Universal intents (commit, PR,
review, rebase, hotfix, debrief, baseline, failing CI, spec authoring) nudge in every repo.
Stack-specific intents (Figma/design, whole-repo audit, release readiness, Flutter upgrade) only
nudge in a repo of the matching stack — a lightweight `cwd` check gates them — so a backend dev
never sees Flutter suggestions and vice-versa. It is a soft nudge — never blocks the prompt, never
fails the session — and stays completely silent on prompts that match no intent, so ordinary turns
are unaffected. `supy-baseline` embeds the same routing (`## Using Supy skills`), scoped to the
repo's stack, into each generated `CLAUDE.md`, so the guidance persists even without the hook.

### Typical workflow

```text
/supy-brainstorm add a stock-transfer approval flow   # idea → design
/supy-plan                                            # design → phased plan
/supy-build                                           # plan → implementation (local commits)
/supy-review                                          # consolidated multi-agent review
"run the supy-commit skill"                           # conventional commit + trailer
```

### Examples

Worked, step-by-step walkthroughs live under [`docs/`](docs/). Start here:

- **[`docs/SKILLS-IN-A-SESSION.md`](docs/SKILLS-IN-A-SESSION.md)** — how each skill plays
  out in a live session (what you type, what happens), incl. `/supy-plan` and the everyday
  build → review → commit → PR loop.
- **[`docs/CROSS-REPO-FEATURE-WALKTHROUGH.md`](docs/CROSS-REPO-FEATURE-WALKTHROUGH.md)** — one
  feature ("admin force-logout") driven from zero to an open PR in **four** repos
  (backend + firebase-functions + frontend + flutter), one PR each.
- **[`docs/CTO-DEMO.md`](docs/CTO-DEMO.md)** — a 10-minute, copy-paste demo that proves the
  two headline behaviors (auto-detect the stack; surface only that stack's skills) with real
  hook output.

#### Example 1 — one skill in a session (`/supy-plan`)

```text
/supy-plan add an admin force-logout endpoint that revokes all sessions for a user
```

→ loads the backend standards, reads existing aggregates via Cortex (if connected), and
writes a phased plan (domain → interactor → infrastructure → testing, each task naming its Nx
library) to `docs/superpowers/plans/admin-force-logout.md`, with a **Supy Standards
Alignment** section declaring the new NATS event and expected commit types.

#### Example 2 — the everyday loop (any repo)

```text
implement phase 1 of the plan          # you write code the Supy way
review my changes before I commit      # → /supy-review: stack reviewers in parallel
commit this                            # → /supy-commit: feat(auth): add force-logout endpoint …
open a PR                              # → /supy-create-pr: conventional title + evidence body
```

#### Example 3 — the stack filter (why backend never sees Flutter skills)

```text
On the FLUTTER repo:   "implement the figma design"  → nudge: supy-figma-implement-design
On the BACKEND repo:   "implement the figma design"  → (silent)
```

And the `/supy` menu now prefixes each skill with its stack, so it's obvious at a glance:

```text
[flutter]  supy-flutter-feature     How to write Flutter code in a supy mobile repo…
[backend]  supy-clean-architecture  How to write NestJS backend code in a supy service repo…
[any]      supy-commit              Stage-aware conventional commit per Supy commitlint…
```

#### Example 4 — one feature across many open repos (`/supy-feature`)

You have several `supy-*` repos checked out under one folder and a feature that spans several
of them. From any one of them:

```text
/supy-feature add an admin force-logout that revokes all sessions for a user
```

→ scans the parent folder, detects each repo's stack, and **proposes** the affected set:

```text
  ✓ supy-backend   (nestjs-nx) — owns the domain; endpoint + emits user.sessions-revoked
  ✓ supy-frontend  (angular-nx) — admin UI to trigger it
  ✓ supy-retailer  (flutter)    — client reacts to the event
  ✗ supy-cli       (ts-cli)     — no CLI surface — skipping
  Confirm? (yes / edit the set)
```

→ after you confirm, it writes a per-repo plan into each ✓ repo (same feature slug, same
shared contract named identically), then prints the next command per repo:

```text
cd supy-backend  && /supy-build docs/superpowers/plans/admin-force-logout.md
cd supy-frontend && /supy-build docs/superpowers/plans/admin-force-logout.md
cd supy-retailer && /supy-build docs/superpowers/plans/admin-force-logout.md
```

It is **plan-only** — you review each plan, then build/review/commit/PR in each repo.
See the full walkthrough in
[`docs/CROSS-REPO-FEATURE-WALKTHROUGH.md`](docs/CROSS-REPO-FEATURE-WALKTHROUGH.md).

### Cortex MCP (optional)

When the Cortex MCP server is connected, the review agents and `supy-baseline` use it
as a live source of Supy architecture (entities, handler contracts, coding rules).
The repo ships a `.mcp.json` wiring the `cortex-kg` HTTP server, so it connects
automatically where you have access. When it is absent, they degrade gracefully to the
repo's `CLAUDE.md` and the mined standards under `config/standards/` — nothing hard-fails.

## Components

- `agents/` — **17 subagents**: 11 review subagents — backend (architecture, NATS events, tests, security), Angular (frontend), Flutter (mobile), Firebase Functions, TypeScript CLI, AI-agents monorepo, and the two stack-agnostic reviewers (commit/PR conventions + secrets) that run on every stack — plus 6 Flutter release-readiness agents under `agents/app-readiness/` (Android/iOS/web/macOS/Linux/Windows), launched in parallel by `supy-app-release-readiness`
- `skills/` — **30 skills**, grouped by stack (see [Usage](#skills)): 12 Universal (review, baseline, commit, create-pr, rebase, hotfix, debrief, fix-failing-github-actions, impl-spec, spike-spec, feature-fanout, kg), 3 backend, 2 frontend, 10 Flutter/mobile, and one each for firebase-functions, ts-cli, ai-agents. Every repo sees the Universal set plus only its own stack's skills
- `commands/` — orchestration wrappers over superpowers
- `hooks/` — stack detection on session open (nestjs-nx / angular-nx / nx / flutter / firebase-functions / ts-cli / ai-agents / k8s-config / generic) + a UserPromptSubmit skill router that nudges toward the matching workflow skill
- `config/standards/` — mined Supy standards, source of truth for the agents. Three cross-cutting standards at root (`commit-conventions.md`, `secrets-and-config.md`, `ci-coverage-baseline.md`) plus per-stack rulebooks: backend at root + `backend/` for module boundaries, `frontend/`, `flutter/`, `firebase-functions/`, `ts-cli/`, `ai-agents/` (k8s-config has no standards subdir — it's governed by the root `secrets-and-config.md`)
- `templates/` — canonical CLAUDE.md templates + drop-in enforcement config per stack: backend at root (+ Nx generators under `backend/`), `frontend/` (Nx generators + enforcement), `flutter/` (bundled `.hbs` feature stubs + `analysis_options.yaml`), and `firebase-functions/`, `ts-cli/`, `ai-agents/`, `k8s-config/` (CI + pre-commit + secret-scan baselines)
