# supy-wingspan

Supy's internal Claude Code plugin. Makes every `supy-*` repo follow Supy engineering
best practices through AI: stack-aware review agents (NestJS backend + Angular
frontend + Flutter mobile), scaffolding & Git skills, a consistency-baseline generator,
and thin orchestration wrappers over `superpowers`.

## Status
Local-only, v0.1.0. Not yet published to a Git host.

## Enable locally
From any supy repo (or user settings), add this directory as a local marketplace:
```
/plugin marketplace add ~/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
```
See [`docs/PILOT.md`](docs/PILOT.md) for the validated enablement procedure, the
pilot exercise checklist, and known gaps.

## Usage

The plugin exposes **4 slash commands** and **11 skills**. Commands are typed
directly (`/name`); skills are invoked in natural language ("run the supy-commit
skill") — they are not slash commands.

### Slash commands

| Command | What it does |
|---|---|
| `/supy-brainstorm [idea]` | Turns a rough idea into a design, wrapping `superpowers:brainstorming` with Supy stack context. Falls back to a built-in one-question-at-a-time clarification (purpose → constraints → success criteria) when `superpowers` is absent. |
| `/supy-plan [feature]` | Produces a phased implementation plan from a feature/task description, wrapping `superpowers:writing-plans`. Fallback writes a domain → application → infrastructure → testing task list to `docs/superpowers/plans/`. |
| `/supy-build [plan]` | Executes a plan task-by-task, wrapping `superpowers:executing-plans` / `subagent-driven-development`. Fallback runs the plan with **local-only** commits (never pushes). |
| `/supy-review [base-ref]` | Reviews the current branch diff. Detects the repo stack and dispatches the matching review subagents in parallel — 5 backend reviewers for `nestjs-nx`, the Angular reviewer + commit/PR reviewer for `angular-nx`, the Flutter reviewer + commit/PR reviewer for `flutter`, the commit/PR reviewer alone otherwise — then consolidates their findings into one severity-grouped report. Optional arg overrides the diff base (defaults to the merge-base with `origin/main`/`main`, then `HEAD~1`). |

### Skills

| Skill | What it does |
|---|---|
| `supy-review` | The review orchestration behind `/supy-review` — usable directly as a skill too. |
| `supy-baseline` | Generates or updates the repo's `CLAUDE.md` from the canonical template + repo inspection (+ Cortex when connected). Never clobbers an existing file silently — shows a diff and asks first. |
| `supy-commit` | Proposes a Conventional Commits message grounded in `config/standards/commit-conventions.md`, ending with the `Co-Authored-By: Claude Opus 4.8 (1M context)` trailer. Confirmation-gated; commit-only, never pushes. |
| `supy-create-pr` | Builds a conventional PR title + Summary/Changes/Test-evidence/Issue-refs body. Pushes via `gh` when a remote and `gh` are available; otherwise prints a ready-to-paste PR and manual instructions. |
| `supy-scaffold-handler` | Scaffolds a new NestJS NATS handler (RPC request or JetStream event) with a colocated DTO and test stub, following the mined Nx/NestJS layout. Prefers a repo Nx generator; else copies the nearest existing handler. Confirms planned paths before writing. |
| `supy-clean-architecture` | (nestjs-nx) The how-to for writing backend code the Supy way — Clean/Hexagonal Architecture + DDD + CQRS: aggregates with methods + `this.assign`/`this.addEvent`, value objects with state machines, factories, repository interfaces, interactors that persist atomically then side-effect, NATS controllers. Grounded in `config/standards/architecture.md` + `config/standards/backend/module-boundaries.md`; the companion to `supy-scaffold-domain`. |
| `supy-scaffold-domain` | (nestjs-nx) Scaffolds a complete Clean-Architecture/DDD bounded context via the Plop `g:domain` generator — five tagged libs (api, logic, domain/model, domain/service, data) with aggregate, value objects, state VO, factory, events, repository, schema, transformers, interactor, controller — then walks the fill-in in dependency order and prints the four manual wiring steps (aliases, scope constraint, `ApiModule` registration, discriminators). Offers to install the generator if the repo lacks it. |
| `supy-scaffold-feature` | (angular-nx) Scaffolds a complete Angular NGXS feature library via the Plop generator — tagged `project.json`, models, state/actions, URI-token service, smart+dumb components, resolver, lazy routes — then walks the fill-in in dependency order and prints the three manual wiring steps (alias, scope constraint, lazy route). Offers to install the generator if the repo lacks it. |
| `supy-angular-feature` | (angular-nx) The how-to for writing Angular the Supy way — OnPush + `inject()` components, signal I/O, NGXS state with Immer `produce()`, URI-token services, lazy routes, `--p-*` styling. Grounded in `config/standards/frontend/`; the companion to `supy-scaffold-feature`. |
| `supy-scaffold-flutter-feature` | (flutter) Scaffolds a complete Clean-Architecture feature (domain + data + presentation + tests) from bundled `.hbs` stubs — entity, repository, usecase, freezed model + datasources, repository impl, BLoC with sealed events + freezed state, page, barrel, and two behaviour tests — then walks the fill-in in dependency order and prints the three manual wiring steps (get_it registration, go_router route, barrel export). Prefers a repo `mason`/`very_good` generator when present. |
| `supy-flutter-feature` | (flutter) The how-to for writing Flutter the Supy way — Clean Architecture 3 layers/feature, BLoC (never Cubit) with sealed events + freezed state, go_router with `static const path`/`name`, get_it DI, dio interceptor chain, `dartz` `Either<Failure, T>` + sealed `Failure` hierarchy, `UseCase<T, Params>`, hive cache policies, design tokens, `mocktail`+`bloc_test`. Grounded in `config/standards/flutter/`; the companion to `supy-scaffold-flutter-feature`. |

### SessionStart hook

On session open, `detect-stack.sh` prints one line — e.g. `supy-wingspan: detected
nestjs-nx repo.` — and nudges you to run the `supy-baseline` skill if the repo has
no `CLAUDE.md`. It stays silent on unknown or mixed stacks and never fails the session.

### Typical workflow

```
/supy-brainstorm add a stock-transfer approval flow   # idea → design
/supy-plan                                            # design → phased plan
/supy-build                                           # plan → implementation (local commits)
/supy-review                                          # consolidated multi-agent review
"run the supy-commit skill"                           # conventional commit + trailer
```

### Cortex MCP (optional)

When the Cortex MCP server is connected, the review agents and `supy-baseline` use it
as a live source of Supy architecture (entities, handler contracts, coding rules).
When it is absent, they degrade gracefully to the repo's `CLAUDE.md` and the mined
standards under `config/standards/` — nothing hard-fails.

## Components
- `agents/` — review subagents: backend (architecture, NATS events, tests, security), Angular (frontend), Flutter (mobile), and the stack-agnostic commit/PR reviewer
- `skills/` — supy-review, supy-baseline, supy-commit, supy-create-pr; backend: supy-scaffold-handler, supy-clean-architecture, supy-scaffold-domain; frontend: supy-scaffold-feature, supy-angular-feature; mobile: supy-scaffold-flutter-feature, supy-flutter-feature
- `commands/` — orchestration wrappers over superpowers
- `hooks/` — stack detection (nestjs-nx / angular-nx / nx / flutter / generic)
- `config/standards/` — mined Supy standards, source of truth for the agents (backend at root + `backend/` for module boundaries, frontend under `frontend/`, flutter under `flutter/`)
- `templates/` — canonical CLAUDE.md templates (backend at root, `frontend/` for angular-nx, `flutter/` for flutter) plus drop-in Nx generators + enforcement config under `backend/` and `frontend/`, and bundled `.hbs` feature stubs + `analysis_options.yaml` under `flutter/`
