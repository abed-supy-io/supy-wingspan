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
- **Status:** published on GitHub at `abed-supy-io/supy-wingspan`; releases are
  automated with **release-please** (see [§11](#11-cutting-a-release)). The
  current version lives in `.claude-plugin/plugin.json`. It is distributed as a
  **Claude Code marketplace** — point Claude Code at the GitHub repo (or a local
  clone while developing the plugin itself).

> Prefer reading `docs/PILOT.md` alongside this file. PILOT.md is the validation
> record and the live pilot checklist; this file is the how-to.
>
> **Want copy-paste recipes per repo?** See [docs/EXAMPLES.md](./EXAMPLES.md) — a
> cookbook of *"I'm in this repo, I want to do X → type this"* examples for every
> stack. Start there if the plugin feels abstract.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Install](#2-install)
3. [Verify the install](#3-verify-the-install)
4. [What you get after install](#4-what-you-get-after-install)
5. [Everyday usage](#5-everyday-usage)
6. [The stacks & how detection works](#6-the-stacks--how-detection-works)
7. [Deploying to a team (persist across sessions)](#7-deploying-to-a-team-persist-across-sessions)
8. [Updating the plugin](#8-updating-the-plugin)
9. [Uninstall](#9-uninstall)
10. [Maintaining & extending the plugin](#10-maintaining--extending-the-plugin)
11. [Cutting a release](#11-cutting-a-release)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Prerequisites

- **Claude Code** (CLI, desktop, web, or an IDE extension) — any recent version
  that supports `/plugin` and local marketplaces.
- The plugin source is `github.com/abed-supy-io/supy-wingspan`. For plugin
  development, a local clone (e.g. `~/Projects/supy-projects/supy-wingspan`)
  works as a marketplace source too — adjust the paths below if yours differs.
- **Optional but recommended:**
  - The **`superpowers`** plugin. `/supy-brainstorm`, `/supy-plan`, and
    `/supy-build` wrap it. If it's absent, each command degrades to a built-in
    fallback (see [§5](#5-everyday-usage)) — nothing hard-fails.
  - The **Cortex MCP** server. When connected, the review agents and
    `supy-baseline` use it as a live source of Supy architecture. When absent,
    they fall back to the repo's `CLAUDE.md` and the mined standards under
    `config/standards/`.
  - `git` — the review/commit/PR skills operate on a git diff.
  - `gh` (GitHub CLI) — used by `supy-create-pr` and
    `fix-failing-github-actions`; both degrade gracefully without it.

No `npm install`, no build step. The plugin is plain Markdown + a few shell hooks.

---

## 2. Install

Open a Claude Code session **inside the repo you want to work in** (e.g.
`supy-service-inventory`, or any `supy-*` repo), then run these two slash
commands:

```text
/plugin marketplace add abed-supy-io/supy-wingspan
/plugin install supy-wingspan@supy
```

What each does:

- `marketplace add abed-supy-io/supy-wingspan` clones the GitHub repo and
  registers it as a marketplace named **`supy`** (the name comes from
  `.claude-plugin/marketplace.json`).
- `install supy-wingspan@supy` installs the plugin as a **pinned snapshot** of
  the marketplace's current version. The `@supy` suffix is the marketplace name;
  `supy-wingspan` is the plugin name from `.claude-plugin/plugin.json`.

**Developing the plugin itself?** Use a local clone as the marketplace source
instead — changes are picked up on marketplace refresh without a release:

```text
/plugin marketplace add ~/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
```

---

## 3. Verify the install

1. **Session-start line.** Open a fresh session in a supy repo. Near the top you
   should see one line from the `detect-stack.sh` SessionStart hook, e.g.:

   ```text
   supy-wingspan: detected nestjs-nx repo.
   ```

   (One of `nestjs-nx`, `angular-nx`, `nx`, `flutter`, `firebase-functions`,
   `ts-cli`, `ai-agents`, `k8s-config`, or silent for unknown/mixed.) If the repo
   has no `CLAUDE.md`, it also nudges you to run `supy-baseline`.

2. **Commands are present.** Type `/` and confirm you see `/supy-brainstorm`,
   `/supy-plan`, `/supy-build`, `/supy-review`, `/supy-onboard`.

3. **Skills load.** Ask Claude to "run the supy-baseline skill" (or any skill) —
   it should resolve without a "skill not found" error.

If any of these fail, jump to [§12 Troubleshooting](#12-troubleshooting).

---

## 4. What you get after install

**6 slash commands** (typed directly with `/`):

| Command | Purpose |
|---|---|
| `/supy-brainstorm [idea]` | Idea → design. Wraps `superpowers:brainstorming` with Supy stack context; falls back to a one-question-at-a-time clarification. |
| `/supy-plan [feature]` | Design → phased implementation plan. Wraps `superpowers:writing-plans`; fallback writes a domain→application→infrastructure→testing task list to `docs/superpowers/plans/`. |
| `/supy-build [plan]` | Plan → implementation, task by task. Wraps `superpowers:executing-plans` / `subagent-driven-development`; fallback runs the plan with **local-only** commits (never pushes). |
| `/supy-review [base-ref]` | Reviews the current branch diff. Detects the stack and dispatches the matching review subagents in parallel, then consolidates a severity-grouped report. |
| `/supy-onboard [focus]` | Onboards or refreshes the repo's Supy AI setup. Wraps `supy-baseline` and adds a section-level `CLAUDE.md` drift check against the stack template; pass `drift only` to report without regenerating. |
| `/supy-release [action]` | Reports the release-please state of this plugin repo — pending release PR, unreleased commits since the last tag, implied version bump, consumer impact. Read-only unless passed `ship`, which merges the release PR after confirmation. Degrades to a local-git-only report without `gh`. |

**28 skills** (invoked in natural language — *not* slash commands; say e.g.
"run the supy-commit skill"). The stack column mirrors
`skills/shared/references/skill-routing.md` — the routing hook only surfaces a
skill in repos of its stack:

| Skill | Stack | Purpose |
|---|---|---|
| `supy-review` | any | The review orchestration behind `/supy-review`. |
| `supy-baseline` | any | Generates/updates the repo's `CLAUDE.md` from the canonical template + repo inspection (+ Cortex). Shows a diff and asks before overwriting. |
| `supy-commit` | any | Proposes a Conventional Commits message grounded in `config/standards/commit-conventions.md`, ending with the `Co-Authored-By` trailer. Confirmation-gated; commit-only, never pushes. |
| `supy-create-pr` | any | Builds a conventional PR title + body. Pushes via `gh` when a remote is available; otherwise prints a ready-to-paste PR. |
| `supy-rebase` | any | Safely rebases the current branch onto its base — safety ref first, conflicts walked one commit at a time, no force-push without confirmation. |
| `supy-hotfix` | any | Drives an urgent production fix end to end — minimal diff, conventional `fix` commit, review, fast-tracked PR. |
| `supy-debrief` | any | Produces a structured handoff/retrospective for the branch from actual commits and diff. |
| `fix-failing-github-actions` | any | Finds failing GitHub Actions checks, fixes the root cause, and loops until every check is green. |
| `supy-impl-spec` | any | Turns a Jira ticket into a full implementation specification before code is written. |
| `supy-spike-spec` | any | Turns a Jira ticket into a spike/research spec — questions, options, PoC scope — saved to `docs/specs/`. |
| `supy-clean-architecture` | nestjs-nx | How-to for backend Clean/Hexagonal + DDD + CQRS. |
| `supy-scaffold-domain` | nestjs-nx | Scaffolds a full DDD bounded context via the Plop `g:domain` generator. |
| `supy-scaffold-handler` | nestjs-nx | Scaffolds a NestJS NATS handler (RPC or JetStream event) with DTO + test stub. |
| `supy-angular-feature` | angular-nx | How-to for writing Angular the Supy way (OnPush, `inject()`, NGXS, `--p-*`). |
| `supy-scaffold-feature` | angular-nx | Scaffolds a complete Angular NGXS feature library via the Plop generator. |
| `supy-figma-to-tickets` | angular-nx, flutter | Turns a Figma file's screens and flows into dependency-ordered GitHub/Jira tickets deep-linked to Dev Mode nodes. |
| `supy-flutter-feature` | flutter | How-to for writing Flutter the Supy way (Clean Arch, BLoC, go_router, get_it, dio, dartz). |
| `supy-scaffold-flutter-feature` | flutter | Scaffolds a Clean-Architecture feature from bundled `.hbs` stubs (domain + data + presentation + tests). |
| `supy-figma-implement-design` | flutter | Translates a Figma design into a production Flutter widget with 1:1 fidelity, mapped onto the theme and validated with golden tests. |
| `supy-e2e-tests` | flutter | Writes, runs, and debugs supy-retailer `integration_test` e2e tests against the live dev backend. |
| `supy-app-release-readiness` | flutter | Audits a Flutter app for release readiness across all detected platforms and synthesizes a release todo list. |
| `supy-flutter-upgrade` | flutter | Bumps Flutter/Dart SDK versions across every `pubspec.yaml`, `.fvmrc`, and workflow, then runs pub get/format/analyze/fix. |
| `supy-code-assessment` | flutter | Whole-project audit of a Flutter codebase against Supy standards; writes `CODE_ASSESSMENT.md`. |
| `supy-analyze-native-codebase` | flutter | Analyzes an iOS/Android native codebase and generates a Flutter migration manifest, PRD, and risk register. |
| `supy-interview-feedback` | flutter | Grades a candidate's Flutter take-home against Supy standards; writes a scored `INTERVIEW_FEEDBACK.md`. |
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
  - commit/PR + secrets.
- CLI (`ts-cli`) → 3: `supy-ts-cli-reviewer` (architecture + operational safety)
  - commit/PR + secrets.
- AI-agents (`ai-agents`) → 3: `supy-ai-agents-reviewer` (architecture + operational
  safety) + commit/PR + secrets.
- K8s config (`k8s-config`) → 2: secrets + commit/PR.
- Any other stack → 2: commit/PR + secrets.

**3 hooks** (wired in `hooks/hooks.json`; none can fail a session):

- **SessionStart** → `detect-stack.sh` prints the detected-stack line (and a
  `supy-baseline` nudge when `CLAUDE.md` is missing).
- **UserPromptSubmit** → `skill-router.sh` suggests the matching `supy-*` skill
  for the prompt, scoped to the detected stack.
- **PostToolUse (Edit|Write)** → `dart-lint-format.sh` formats/analyzes touched
  Dart files in Flutter repos.

---

## 5. Everyday usage

> For concrete, per-repo *"I want to X → type this"* recipes, jump to
> [docs/EXAMPLES.md](./EXAMPLES.md). The rest of this section is the quick tour.

### The core loop

```text
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

  ```text
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
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
| *unknown / mixed* | anything else | — (stays silent; stack-agnostic reviewers only) |

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
      "supy": "abed-supy-io/supy-wingspan"
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

### GitHub source vs. local clone

Because the marketplace source is the GitHub repo, teammates need read access to
`abed-supy-io/supy-wingspan` — nothing has to exist at a particular path on
their machine. Reserve local-path marketplaces (`~/Projects/...`) for developing
the plugin itself; don't commit a machine-specific path into a shared
`.claude/settings.json`.

---

## 8. Updating the plugin

An install is a **pinned snapshot** — pushing commits to GitHub does *not*
change what anyone already has installed. Updates are keyed on the `version` in
`.claude-plugin/plugin.json`, which only release-please bumps. The full path of
a change to a teammate's machine:

1. A `feat:`/`fix:` PR merges to `main`.
2. The rolling **release PR** (opened by release-please) is merged — this tags
   the release and bumps `version` in `.claude-plugin/plugin.json`.
3. On each machine, the marketplace refreshes — either automatically (Claude
   Code refreshes marketplaces periodically) or on demand:

   ```text
   /plugin marketplace update supy
   ```

   Seeing a newer version than the installed one, Claude Code updates the
   plugin.
4. Already-open sessions keep the old snapshot — start a new session (or run
   `/reload-plugins`) to pick up the new components.

So: **no release-PR merge, no update** — merging a feature PR alone leaves every
install where it was.

> Housekeeping: old snapshots accumulate under
> `~/.claude/plugins/cache/supy/supy-wingspan/<version>/`; it's safe to delete
> versions you're no longer on.

---

## 9. Uninstall

```text
/plugin uninstall supy-wingspan@supy
/plugin marketplace remove supy
```

Then remove the `plugins` block from any tracked `.claude/settings.json` you
added in [§7](#7-deploying-to-a-team-persist-across-sessions). Deleting the
directory on disk also effectively disables it (the marketplace source vanishes).

---

## 10. Maintaining & extending the plugin

### Repository layout

```text
supy-wingspan/
├── .claude-plugin/
│   ├── plugin.json         # name, version, description, keywords
│   └── marketplace.json    # marketplace "supy" → this plugin
├── agents/                 # 11 review subagents (Markdown w/ frontmatter)
├── skills/                 # 28 skills, one dir each w/ SKILL.md (+ skills/shared/)
├── commands/               # 6 slash-command wrappers over skills/superpowers
├── hooks/
│   ├── hooks.json          # wires the three hooks below to their events
│   ├── detect-stack.sh     # SessionStart: stack detection (9-way ordered)
│   ├── skill-router.sh     # UserPromptSubmit: stack-scoped skill suggestions
│   └── dart-lint-format.sh # PostToolUse: format/analyze touched Dart files
├── scripts/                # repo validators (xrefs, manifests, skills, agents…) — CI runs these
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
│   ├── pilots/             # pilot runbook, results template, triage protocol
│   ├── EXAMPLES.md         # per-repo copy-paste usage recipes
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
- **Commit convention:** Conventional Commits, `feat:` for features — release-please
  generates releases and the changelog from history, so types matter. Every commit
  ends with the trailer
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

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

Run the same checks CI runs:

```bash
npx markdownlint-cli2 --config config/custom.markdownlint.jsonc "**/*.md" "!CHANGELOG.md"
npx cspell --config config/cspell.json "**/*.md"
shellcheck hooks/*.sh scripts/*.sh templates/*/hooks/* templates/*/scripts/*
for v in scripts/validate-*.sh scripts/test-*.sh scripts/verify-*.sh; do "$v"; done
```

Expect: zero errors, `${CLAUDE_PLUGIN_ROOT}` throughout component bodies, no
empty template stubs. The `plugin-dev:plugin-validator` agent is a good final
sweep before a release.

---

## 11. Cutting a release

Releases are fully automated by **release-please**
(`.github/workflows/release-please.yaml`); nobody bumps a version by hand:

1. Land changes on `main` via PRs with Conventional Commit titles
   (`feat:`/`fix:`/`docs:`/`chore:`).
2. release-please keeps a rolling **release PR** open, accumulating the pending
   changelog. Merging a `feat:` bumps the minor version, a `fix:` the patch
   (pre-1.0 `bump-minor-pre-major` rules).
3. When you want to ship, **merge the release PR**. That tags the release
   (`vX.Y.Z`), updates `CHANGELOG.md`, and syncs `version` in
   `.claude-plugin/plugin.json` (via the config's `extra-files` entry).
4. Installs pick the new version up per [§8](#8-updating-the-plugin).

Manual steps that remain yours: keep component counts in docs in sync when
components change, and make sure CI is green before merging (it blocks the PR
anyway).

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
| `supy-create-pr` won't push | No git remote / no `gh` | Expected — it prints a paste-ready PR instead |
| Installed plugin is behind what's on GitHub | Installs are pinned snapshots; only a release-PR merge bumps the version | Merge the pending release PR, then `/plugin marketplace update supy` and start a new session (see §8) |

---

*Questions or gaps? See `docs/PILOT.md` for the validation record and the live
pilot checklist, and `config/standards/README.md` for what each rulebook covers
and where it was mined from.*
