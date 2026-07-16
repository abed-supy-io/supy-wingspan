# supy-wingspan

Supy's internal Claude Code plugin. Makes every `supy-*` repo follow Supy engineering
best practices through AI: stack-aware review agents (NestJS backend, Angular frontend,
Flutter mobile, Firebase Functions, TypeScript CLI, the polyglot AI-agents monorepo, and
Kubernetes config), plus two stack-agnostic reviewers — commit/PR conventions and a
secret scanner — that run on every repo. Ships scaffolding & Git skills, a
consistency-baseline generator, and thin orchestration wrappers over `superpowers`.

## Status
v0.1.0. Published at [`abed-supy-io/supy-wingspan`](https://github.com/abed-supy-io/supy-wingspan) (public).

## Install
From any supy repo (or user settings), add the marketplace and install the plugin.
Run these as **two separate commands** — the second only after the first completes:
```
/plugin marketplace add abed-supy-io/supy-wingspan
/plugin install supy-wingspan@supy
```

Then run `/reload-plugins` to apply — the commands and skills become available immediately.

Or in one line from the terminal:
```
claude plugin marketplace add abed-supy-io/supy-wingspan && claude plugin install supy-wingspan@supy
```

<details>
<summary>Install from a local checkout instead</summary>

```
/plugin marketplace add ~/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
```
</details>

See [`docs/USAGE.md`](docs/USAGE.md) for the full install / usage / deployment
guide, and [`docs/PILOT.md`](docs/PILOT.md) for the validated enablement
procedure, the pilot exercise checklist, and known gaps.

## Usage

The plugin exposes **4 slash commands** and **14 skills**. Commands are typed
directly (`/name`); skills are invoked in natural language ("run the supy-commit
skill") — they are not slash commands.

### Slash commands

| Command | What it does |
|---|---|
| `/supy-brainstorm [idea]` | Turns a rough idea into a design, wrapping `superpowers:brainstorming` with Supy stack context. Falls back to a built-in one-question-at-a-time clarification (purpose → constraints → success criteria) when `superpowers` is absent. |
| `/supy-plan [feature]` | Produces a phased implementation plan from a feature/task description, wrapping `superpowers:writing-plans`. Fallback writes a domain → application → infrastructure → testing task list to `docs/superpowers/plans/`. |
| `/supy-build [plan]` | Executes a plan task-by-task, wrapping `superpowers:executing-plans` / `subagent-driven-development`. Fallback runs the plan with **local-only** commits (never pushes). |
| `/supy-review [base-ref]` | Reviews the current branch diff. Detects the repo stack and dispatches the matching review subagents in parallel, then consolidates their findings into one severity-grouped report. Dispatch by stack: `nestjs-nx` → 6 (architecture, NATS events, test quality, commit/PR, security, secrets); `angular-nx` → 3 (Angular/NGXS, commit/PR, secrets); `flutter` → 3 (Flutter/Clean-Arch, commit/PR, secrets); `firebase-functions` → 3 (Firebase Functions/Clean-Arch, commit/PR, secrets); `ts-cli` → 3 (CLI/Clean-Arch + operational-safety, commit/PR, secrets); `ai-agents` → 3 (AI-agents architecture + operational-safety, commit/PR, secrets); `k8s-config` → 2 (secrets, commit/PR); any other stack → 2 (commit/PR, secrets). The commit/PR and secrets reviewers are stack-agnostic and run on every stack. Optional arg overrides the diff base (defaults to the merge-base with `origin/main`/`main`, then `HEAD~1`). |

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
| `supy-firebase-function` | (firebase-functions) The how-to for writing Firebase Functions code in the standalone supy-firebase-functions repo the Supy way — Clean Architecture (index.ts → app interactors → data repositories → frameworks), Awilix DI, runtime-enforced auth markers (`@unauthenticated`/`@internal`/`@admin`/`@apiKey`), typed domain errors, idempotent Firestore triggers, and secrets from Secret Manager (never literals). |
| `supy-ts-cli` | (ts-cli) The how-to for writing CLI code in the standalone supy-cli repo the Supy way — Clean Architecture (presentation commands → application scripts → infrastructure → domain), commander.js `scripts [run\|list\|info]`, the `IScript`/`ScriptDetails` self-documenting contract, env-layered config, explicit production confirmation before any prod mutation, no secrets in argv/logs, deterministic exit codes, testable use cases, and batched bulk MongoDB operations. |
| `supy-ai-agents` | (ai-agents) Write and change code in the polyglot supy-ai-agents monorepo (Cortex/Nexus/Oculus/Gleap/PMS-AI — Node.js + Python + Cloudflare Workers, MCP tools, BullMQ, pgvector KG) so it follows the Supy ai-agents architecture & operational standard — secret hygiene, auth on exposed tools, env-driven config, validation + error handling, idempotent consumers, and non-root containers. |

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
- `agents/` — **11 review subagents**: backend (architecture, NATS events, tests, security), Angular (frontend), Flutter (mobile), Firebase Functions, TypeScript CLI, AI-agents monorepo, and the two stack-agnostic reviewers (commit/PR conventions + secrets) that run on every stack
- `skills/` — **14 skills**: supy-review, supy-baseline, supy-commit, supy-create-pr; backend: supy-scaffold-handler, supy-clean-architecture, supy-scaffold-domain; frontend: supy-scaffold-feature, supy-angular-feature; mobile: supy-scaffold-flutter-feature, supy-flutter-feature; standalone: supy-firebase-function, supy-ts-cli, supy-ai-agents
- `commands/` — orchestration wrappers over superpowers
- `hooks/` — stack detection (nestjs-nx / angular-nx / nx / flutter / firebase-functions / ts-cli / ai-agents / k8s-config / generic)
- `config/standards/` — mined Supy standards, source of truth for the agents. Three cross-cutting standards at root (`commit-conventions.md`, `secrets-and-config.md`, `ci-coverage-baseline.md`) plus per-stack rulebooks: backend at root + `backend/` for module boundaries, `frontend/`, `flutter/`, `firebase-functions/`, `ts-cli/`, `ai-agents/` (k8s-config has no standards subdir — it's governed by the root `secrets-and-config.md`)
- `templates/` — canonical CLAUDE.md templates + drop-in enforcement config per stack: backend at root (+ Nx generators under `backend/`), `frontend/` (Nx generators + enforcement), `flutter/` (bundled `.hbs` feature stubs + `analysis_options.yaml`), and `firebase-functions/`, `ts-cli/`, `ai-agents/`, `k8s-config/` (CI + pre-commit + secret-scan baselines)
