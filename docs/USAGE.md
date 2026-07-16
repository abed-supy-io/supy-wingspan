# supy-wingspan — Usage & Deployment Guide

Everything you need to install, use, deploy, and maintain `supy-wingspan` — Supy's
internal Claude Code plugin that makes every `supy-*` repo follow Supy engineering
best practices through AI.

- **What it is:** stack-aware review agents (NestJS backend, Angular frontend,
  Flutter mobile, Firebase Functions, TypeScript CLI, the polyglot AI-agents
  monorepo, and Kubernetes config) plus two stack-agnostic reviewers — commit/PR
  conventions and a secret scanner — that run on every repo; scaffolding & Git
  skills; a consistency-baseline generator; and thin orchestration wrappers over
  the `superpowers` plugin.
- **Status:** local-only, `v0.1.0`. **Not published to any Git host.** It is
  distributed as a **local Claude Code marketplace** — you point Claude Code at
  this directory on disk.

> Prefer reading `docs/PILOT.md` alongside this file. PILOT.md is the validation
> record and the live pilot checklist; this file is the how-to.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Install (deploy locally)](#2-install-deploy-locally)
3. [Verify the install](#3-verify-the-install)
4. [What you get after install](#4-what-you-get-after-install)
5. [Everyday usage](#5-everyday-usage)
6. [The stacks & how detection works](#6-the-stacks--how-detection-works)
7. [Deploying to a team (persist across sessions)](#7-deploying-to-a-team-persist-across-sessions)
8. [Updating the plugin](#8-updating-the-plugin)
9. [Uninstall](#9-uninstall)
10. [Maintaining & extending the plugin](#10-maintaining--extending-the-plugin)
11. [Cutting a release (local-only)](#11-cutting-a-release-local-only)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Prerequisites

- **Claude Code** (CLI, desktop, web, or an IDE extension) — any recent version
  that supports `/plugin` and local marketplaces.
- The plugin lives at `~/Projects/supy-projects/supy-wingspan` on this machine.
  Adjust the paths below if yours differs.
- **Optional but recommended:**
  - The **`superpowers`** plugin. `/supy-brainstorm`, `/supy-plan`, and
    `/supy-build` wrap it. If it's absent, each command degrades to a built-in
    fallback (see [§5](#5-everyday-usage)) — nothing hard-fails.
  - The **Cortex MCP** server. When connected, the review agents and
    `supy-baseline` use it as a live source of Supy architecture. When absent,
    they fall back to the repo's `CLAUDE.md` and the mined standards under
    `config/standards/`.
  - `git` — the review/commit/PR skills operate on a git diff.
  - `gh` (GitHub CLI) — only `supy-create-pr` uses it, and only if you have a
    remote. Not required for the local-only workflow.

No `npm install`, no build step. The plugin is plain Markdown + one shell hook.

---

## 2. Install (deploy locally)

Open a Claude Code session **inside the repo you want to work in** (e.g.
`supy-service-inventory`, or any `supy-*` repo), then run these two slash
commands:

```
/plugin marketplace add ~/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
```

What each does:

- `marketplace add <path>` registers this directory as a local marketplace named
  **`supy`** (the name comes from `.claude-plugin/marketplace.json`). The `~`
  form is portable across machines; a fully-qualified path
  (`/Users/<you>/Projects/supy-projects/supy-wingspan`) also works.
- `install supy-wingspan@supy` installs the plugin. The `@supy` suffix is the
  marketplace name; `supy-wingspan` is the plugin name from
  `.claude-plugin/plugin.json`.

That's the whole deployment. There is nothing to push, publish, or host — the
"deploy" is registering the local directory as a marketplace.

---

## 3. Verify the install

1. **Session-start line.** Open a fresh session in a supy repo. Near the top you
   should see one line from the `detect-stack.sh` SessionStart hook, e.g.:
   ```
   supy-wingspan: detected nestjs-nx repo.
   ```
   (One of `nestjs-nx`, `angular-nx`, `nx`, `flutter`, `firebase-functions`,
   `ts-cli`, `ai-agents`, `k8s-config`, or silent for unknown/mixed.) If the repo
   has no `CLAUDE.md`, it also nudges you to run `supy-baseline`.

2. **Commands are present.** Type `/` and confirm you see `/supy-brainstorm`,
   `/supy-plan`, `/supy-build`, `/supy-review`.

3. **Skills load.** Ask Claude to "run the supy-baseline skill" (or any skill) —
   it should resolve without a "skill not found" error.

If any of these fail, jump to [§12 Troubleshooting](#12-troubleshooting).

---

## 4. What you get after install

**4 slash commands** (typed directly with `/`):

| Command | Purpose |
|---|---|
| `/supy-brainstorm [idea]` | Idea → design. Wraps `superpowers:brainstorming` with Supy stack context; falls back to a one-question-at-a-time clarification. |
| `/supy-plan [feature]` | Design → phased implementation plan. Wraps `superpowers:writing-plans`; fallback writes a domain→application→infrastructure→testing task list to `docs/superpowers/plans/`. |
| `/supy-build [plan]` | Plan → implementation, task by task. Wraps `superpowers:executing-plans` / `subagent-driven-development`; fallback runs the plan with **local-only** commits (never pushes). |
| `/supy-review [base-ref]` | Reviews the current branch diff. Detects the stack and dispatches the matching review subagents in parallel, then consolidates a severity-grouped report. |

**14 skills** (invoked in natural language — *not* slash commands; say e.g.
"run the supy-commit skill"):

| Skill | Stack | Purpose |
|---|---|---|
| `supy-review` | any | The review orchestration behind `/supy-review`. |
| `supy-baseline` | any | Generates/updates the repo's `CLAUDE.md` from the canonical template + repo inspection (+ Cortex). Shows a diff and asks before overwriting. |
| `supy-commit` | any | Proposes a Conventional Commits message grounded in `config/standards/commit-conventions.md`, ending with the `Co-Authored-By` trailer. Confirmation-gated; commit-only, never pushes. |
| `supy-create-pr` | any | Builds a conventional PR title + body. Pushes via `gh` when a remote is available; otherwise prints a ready-to-paste PR. |
| `supy-scaffold-handler` | nestjs-nx | Scaffolds a NestJS NATS handler (RPC or JetStream event) with DTO + test stub. |
| `supy-clean-architecture` | nestjs-nx | How-to for backend Clean/Hexagonal + DDD + CQRS. |
| `supy-scaffold-domain` | nestjs-nx | Scaffolds a full DDD bounded context via the Plop `g:domain` generator. |
| `supy-scaffold-feature` | angular-nx | Scaffolds a complete Angular NGXS feature library via the Plop generator. |
| `supy-angular-feature` | angular-nx | How-to for writing Angular the Supy way (OnPush, `inject()`, NGXS, `--p-*`). |
| `supy-scaffold-flutter-feature` | flutter | Scaffolds a Clean-Architecture feature from bundled `.hbs` stubs (domain + data + presentation + tests). |
| `supy-flutter-feature` | flutter | How-to for writing Flutter the Supy way (Clean Arch, BLoC, go_router, get_it, dio, dartz). |
| `supy-firebase-function` | firebase-functions | How-to for the standalone supy-firebase-functions repo — Clean Architecture (index → interactors → repositories → frameworks), Awilix DI, runtime-enforced auth markers, typed domain errors, idempotent Firestore triggers, secrets from Secret Manager. |
| `supy-ts-cli` | ts-cli | How-to for the standalone supy-cli repo — Clean Architecture, commander.js `scripts [run\|list\|info]`, the `IScript`/`ScriptDetails` contract, env-layered config, explicit prod confirmation, no secrets in argv/logs, deterministic exit codes, batched bulk MongoDB ops. |
| `supy-ai-agents` | ai-agents | Write/change code in the polyglot supy-ai-agents monorepo (Node + Python + Cloudflare Workers, MCP tools, BullMQ, pgvector KG) — secret hygiene, auth on exposed tools, env-driven config, validation + error handling, idempotent consumers, non-root containers. |

**11 review agents** (dispatched internally by `/supy-review`, per detected stack).
Two are stack-agnostic and run on **every** stack: `supy-commit-pr-reviewer`
(commit/PR conventions) and `supy-secrets-reviewer` (committed secrets + config/secret
separation). The rest are stack-specific:
- Backend (`nestjs-nx`) → 6: `supy-architecture-reviewer`, `supy-nats-event-reviewer`,
  `supy-test-quality-reviewer`, `supy-security-reviewer` + commit/PR + secrets.
- Frontend (`angular-nx`) → 3: `supy-angular-reviewer` + commit/PR + secrets.
- Mobile (`flutter`) → 3: `supy-flutter-reviewer` + commit/PR + secrets.
- Firebase Functions (`firebase-functions`) → 3: `supy-firebase-functions-reviewer`
  + commit/PR + secrets.
- CLI (`ts-cli`) → 3: `supy-ts-cli-reviewer` (architecture + operational safety)
  + commit/PR + secrets.
- AI-agents (`ai-agents`) → 3: `supy-ai-agents-reviewer` (architecture + operational
  safety) + commit/PR + secrets.
- K8s config (`k8s-config`) → 2: secrets + commit/PR.
- Any other stack → 2: commit/PR + secrets.

**SessionStart hook:** `hooks/detect-stack.sh` prints the detected-stack line and
never fails the session.

---

## 5. Everyday usage

### The core loop

```
/supy-brainstorm add a stock-transfer approval flow   # idea → design
/supy-plan                                            # design → phased plan
/supy-build                                           # plan → implementation (local commits)
/supy-review                                          # consolidated multi-agent review
"run the supy-commit skill"                           # conventional commit + trailer
```

### Reviewing a change

1. Make your change on a branch and stage/commit it.
2. Run `/supy-review` (no args reviews the whole branch diff vs. the merge-base
   with `origin/main` or `main`; pass a base ref to override).
3. Read the consolidated report — findings grouped into **High / Medium / Low /
   Clean**. On an empty diff the skill stops with *"No changes to review"* and
   dispatches nothing.

### Generating / refreshing CLAUDE.md

Run the `supy-baseline` skill. It inspects the repo (and Cortex if connected),
fills the canonical template for the detected stack, and **shows a diff before
overwriting** an existing `CLAUDE.md` — it never clobbers silently.

### Scaffolding a feature (per stack)

- **Backend domain:** "run the supy-scaffold-domain skill" → Plop `g:domain`.
- **Angular feature:** "run the supy-scaffold-feature skill" → Plop generator.
- **Flutter feature:** "run the supy-scaffold-flutter-feature skill" → bundled
  `.hbs` stubs, manual placeholder substitution (Flutter is not Nx — no Plop/npm).

### Committing & PRs

- `supy-commit` writes a Conventional Commits message ending with:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  ```
  It is **commit-only** and never pushes.
- `supy-create-pr` builds the PR title/body; it pushes via `gh` **only** if a
  remote and `gh` exist, otherwise it prints a paste-ready PR.

### Graceful degradation (no superpowers / no Cortex)

- `/supy-brainstorm` → built-in three-step clarification (purpose → constraints →
  success criteria) mapped onto Supy bounded contexts, with a Risks & Gaps section.
- `/supy-plan` → writes a phased task list to `docs/superpowers/plans/`.
- `/supy-build` → runs the plan with local-only commits.
- Review agents / `supy-baseline` → fall back to `CLAUDE.md` + `config/standards/`.

---

## 6. The stacks & how detection works

`hooks/detect-stack.sh` runs at session start and is also the basis for how
`/supy-review` and `supy-baseline` branch. Detection is **ordered** — the first
matching rule wins — so more specific stacks are tested before generic ones:

| Stack | Detected by (in order) | Gets (beyond the two stack-agnostic reviewers) |
|---|---|---|
| `angular-nx` | `nx.json` + `package.json` with `@angular/core` | Angular reviewer; Angular skills + template |
| `nestjs-nx` | `nx.json` + `package.json` with `@nestjs/core` | 4 backend reviewers; backend skills + template |
| `nx` | `nx.json` alone (no Angular/Nest marker) | — (stack-agnostic reviewers only) |
| `flutter` | **`pubspec.yaml`** (no `package.json`/node) | Flutter reviewer; Flutter skills + template |
| `firebase-functions` | `firebase.json` + a `functions/` dir | Firebase Functions reviewer; `supy-firebase-function` skill + template |
| `ts-cli` | root `package.json` with `commander` + a `bin` entry | CLI reviewer (+ operational safety); `supy-ts-cli` skill + template |
| `ai-agents` | any `package.json` (excl. `node_modules`) depending on `@modelcontextprotocol/sdk` or `@anthropic-ai/claude-agent-sdk` | AI-agents reviewer (+ operational safety); `supy-ai-agents` skill + template |
| `k8s-config` | `kustomization.yaml`, or YAML with `kind: ConfigMap`/`kind: Secret` | — (secrets + commit/PR only) |
| _unknown / mixed_ | anything else | — (stays silent; stack-agnostic reviewers only) |

Ordering invariants: `angular-nx`/`nestjs-nx` are tested before bare `nx`;
`ai-agents` is tested **after** `ts-cli` and **before** `k8s-config`. The
**commit/PR reviewer** and the **secrets reviewer** are stack-agnostic and run on
**every** repo — so even an unknown/mixed repo still gets a secret scan and
commit/PR review. Each repo otherwise gets **only its stack's** agents, skills,
and CLAUDE.md template. Flutter enforcement is `very_good_analysis` + `bloc_lint`
via `analysis_options.yaml` (not ESLint). React/Next.js frontends are
intentionally out of scope for `v0.1.0`.

---

## 7. Deploying to a team (persist across sessions)

The `/plugin` commands above register the marketplace for the **current session**.
To make it stick across sessions and share it with teammates, add the marketplace
to a tracked settings file.

### Per-repo (recommended for a pilot)

In the target repo, add (or merge) a `.claude/settings.json`:

```jsonc
{
  "plugins": {
    "marketplaces": {
      "supy": "~/Projects/supy-projects/supy-wingspan"
    },
    "installed": ["supy-wingspan@supy"]
  }
}
```

Commit it so everyone who clones the repo gets the plugin registered
automatically on session open.

> The exact settings schema can evolve between Claude Code versions. If the keys
> above don't take, run `/plugin` interactively once and check which file Claude
> Code writes to, then mirror that into your tracked settings.

### Per-user (all your repos)

Put the same `plugins` block in your user-level `~/.claude/settings.json` instead
of a repo file.

### Important: the path must exist on each machine

Because this is a **local** marketplace, every teammate must have the
`supy-wingspan` directory at the path you reference. Two options:

1. Everyone clones `supy-wingspan` to the **same relative-to-home path**
   (`~/Projects/supy-projects/supy-wingspan`) and you use the `~` form above.
2. Keep it in a shared location and standardize that path in settings.

There is **no remote marketplace** — that's the local-only constraint. If Supy
later adopts a Git host, publishing becomes: push this repo, then teammates
`marketplace add <git-url>` instead of a local path. Nothing else changes.

---

## 8. Updating the plugin

Since the source is a local directory, "updating" is just changing the files and
refreshing Claude Code's view of the marketplace:

1. Edit the plugin files (or `git pull` if you keep it under version control).
2. In a session, refresh the marketplace:
   ```
   /plugin marketplace update supy
   ```
   (or remove & re-add: `/plugin marketplace remove supy` then
   `/plugin marketplace add ~/Projects/supy-projects/supy-wingspan`).
3. Start a new session so the SessionStart hook and reloaded components take
   effect.

Bump `version` in `.claude-plugin/plugin.json` when you ship a meaningful change.

---

## 9. Uninstall

```
/plugin uninstall supy-wingspan@supy
/plugin marketplace remove supy
```

Then remove the `plugins` block from any tracked `.claude/settings.json` you
added in [§7](#7-deploying-to-a-team-persist-across-sessions). Deleting the
directory on disk also effectively disables it (the marketplace source vanishes).

---

## 10. Maintaining & extending the plugin

### Repository layout

```
supy-wingspan/
├── .claude-plugin/
│   ├── plugin.json         # name, version, description, keywords
│   └── marketplace.json    # marketplace "supy" → this plugin
├── agents/                 # 11 review subagents (Markdown w/ frontmatter)
├── skills/                 # 14 skills, one dir each w/ SKILL.md
├── commands/               # 4 slash-command wrappers over superpowers
├── hooks/
│   ├── hooks.json          # SessionStart → detect-stack.sh
│   └── detect-stack.sh     # stack detection (executable, 9-way ordered)
├── config/standards/       # mined Supy standards (source of truth for agents)
│   ├── *.md                # cross-cutting: commit-conventions, secrets-and-config,
│   │                       #   ci-coverage-baseline + backend (root)
│   ├── backend/            # nestjs-nx module boundaries
│   ├── frontend/           # angular-nx conventions + module boundaries
│   ├── flutter/            # architecture.md + flutter-conventions.md
│   ├── firebase-functions/ # architecture.md (+ remediation backlog)
│   ├── ts-cli/             # architecture.md (+ remediation backlog)
│   └── ai-agents/          # architecture.md (+ remediation backlog)
│                           # (k8s-config has no subdir — governed by root secrets-and-config.md)
├── templates/              # canonical CLAUDE.md templates + generators
│   ├── backend/            # CLAUDE.md.hbs + Plop g:domain generator
│   ├── frontend/           # CLAUDE.md.hbs + Plop feature generator
│   ├── flutter/            # CLAUDE.md.hbs + analysis_options.yaml + .hbs stubs
│   ├── firebase-functions/ # CLAUDE.md.hbs + CI + pre-commit + secret-scan
│   ├── ts-cli/             # CLAUDE.md.hbs + CI + pre-commit + secret-scan
│   ├── ai-agents/          # CLAUDE.md.hbs + CI + pre-commit + secret-scan
│   └── k8s-config/         # CLAUDE.md.hbs + .pre-commit-config.yaml (gitleaks)
├── docs/
│   ├── PILOT.md            # validation record + live pilot checklist
│   └── USAGE.md            # this file
└── README.md
```

### Golden rules when editing

- **Component bodies must use `${CLAUDE_PLUGIN_ROOT}`**, never hardcoded absolute
  paths. Absolute paths are only allowed in human-facing docs (README, docs/*).
- **Standards are the source of truth.** Agents cite `config/standards/*` files by
  H2 anchor (`## Rules`, `## Red flags`, `## Source`, …). When Supy conventions
  change, update the standards file first; the agents follow.
- **Keep counts in sync.** README, `plugin.json`, `config/standards/README.md`,
  `docs/PILOT.md`, and this file (`docs/USAGE.md`) all state agent/skill counts.
  Update them together.
- **Commit convention:** Conventional Commits, `feat:` for features. Every commit
  ends with the trailer
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
  **Local-only: commit, never push.**

### Adding a new stack (the established pattern)

Mirror what backend/frontend/flutter already do:

1. `config/standards/<stack>/` — rulebooks with H2 anchors.
2. `agents/supy-<stack>-reviewer.md` — reviewer citing those rulebooks.
3. `skills/supy-<stack>-feature/` — the how-to skill.
4. `skills/supy-scaffold-<stack>-feature/` — the scaffolder.
5. `templates/<stack>/` — `CLAUDE.md.hbs` + generator/stubs + enforcement config.
6. Wire the stack into `hooks/detect-stack.sh`, `skills/supy-review/SKILL.md`,
   `skills/supy-baseline/SKILL.md`, and `commands/supy-review.md`.
7. Update README, `plugin.json`, `config/standards/README.md`, `docs/PILOT.md`.

### Validate after any change

Run the `plugin-dev:plugin-validator` agent against the tree, and shellcheck the
hook:

```bash
shellcheck hooks/detect-stack.sh
```

Expect: VALID, zero critical errors, `${CLAUDE_PLUGIN_ROOT}` throughout, no empty
template stubs.

---

## 11. Cutting a release (local-only)

There is no remote, so a "release" is a validated local commit:

1. Bump `version` in `.claude-plugin/plugin.json`.
2. Update counts/docs (README, PILOT, standards README) if components changed.
3. Validate (plugin-validator + shellcheck).
4. Commit with a `feat:`/`fix:`/`chore:` message and the required trailer.
   **Do not push.**
5. Teammates pick it up by `git pull` (if shared) + `/plugin marketplace update supy`.

If/when Supy adopts a Git host: push the repo, switch the marketplace source in
teammates' settings from a local path to the Git URL, and tag the release. The
plugin contents don't change.

---

## 12. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No `supy-wingspan: detected …` line at session start | Hook didn't run, or `SessionStart` requires a `matcher` in your runtime | Confirm `hooks/detect-stack.sh` is executable (`chmod +x`); check `hooks/hooks.json`; verify during the live pilot (PILOT.md gap #1) |
| `/supy-*` commands don't appear | Marketplace not added, or install didn't complete | Re-run `/plugin marketplace add …` then `/plugin install supy-wingspan@supy`; start a new session |
| Detected stack is `generic` when it shouldn't be | Repo missing `package.json`/`pubspec.yaml`, or mixed stack | This is intentional safe behavior; you still get the commit/PR reviewer. Run `supy-baseline` to add a `CLAUDE.md`. |
| `/supy-review` says "No changes to review" | Empty diff vs. the base ref | Make/stage a change, or pass an explicit base ref |
| Brainstorm/plan/build behave differently than the docs | `superpowers` plugin absent | Expected — you're on the built-in fallback path. Install `superpowers` for the full flow. |
| Review agents seem to ignore live architecture | Cortex MCP not connected | Expected — agents fall back to `CLAUDE.md` + `config/standards/`. Connect Cortex for live data. |
| `supy-create-pr` won't push | No git remote / no `gh` | Expected under local-only; it prints a paste-ready PR instead |
| Marketplace path not found on a teammate's machine | Local path differs per machine | Standardize the clone path, or use the `~`-relative form (see §7) |

---

*Questions or gaps? See `docs/PILOT.md` for the validation record and the live
pilot checklist, and `config/standards/README.md` for what each rulebook covers
and where it was mined from.*
