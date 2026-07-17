# supy-wingspan — Examples by repo

A cookbook. For each kind of Supy repo, this shows the **stack line you'll see at
session start** and then concrete *"I want to… → type this"* recipes. Copy the
right-hand side straight into Claude Code.

Two things to remember before you start:

- **Slash commands** are typed with a leading `/` (e.g. `/supy-review`). There are
  only five: `/supy-brainstorm`, `/supy-plan`, `/supy-build`, `/supy-review`,
  `/supy-onboard`.
- **Skills** are *not* slash commands — you ask for them in plain English, e.g.
  *"run the supy-commit skill"* or just *"commit this the Supy way"*. The plugin
  only surfaces a skill in a repo of its stack, so you can't pick the wrong one.

If you're unsure which repo you're in, look at the first line of the session:

```text
supy-wingspan: detected <stack> repo.
```

The `<stack>` there tells you which section below applies.

> New here? Read [USAGE.md](./USAGE.md) first for install and the big picture.
> This file is only examples.

---

## Table of contents

- [Works in every repo](#works-in-every-repo)
- [Backend service — `nestjs-nx`](#backend-service--nestjs-nx) (`supy-service-*`, the BFFs)
- [Frontend — `angular-nx`](#frontend--angular-nx) (`supy-frontend`)
- [Mobile — `flutter`](#mobile--flutter) (`supy-retailer`, `supy-mobile`)
- [Firebase Functions — `firebase-functions`](#firebase-functions--firebase-functions)
- [TypeScript CLI — `ts-cli`](#typescript-cli--ts-cli) (`supy-cli`)
- [AI-agents monorepo — `ai-agents`](#ai-agents-monorepo--ai-agents) (`supy-ai-agents`)
- [Kubernetes config — `k8s-config`](#kubernetes-config--k8s-config)
- [Shared / bare Nx — `nx`](#shared--bare-nx--nx) (`supy-api-common`)
- [Ask the architecture graph — any repo](#ask-the-architecture-graph--any-repo)
- [Full walkthroughs](#full-walkthroughs)

---

## Works in every repo

These recipes don't care about the stack — they run the same in a NestJS service,
an Angular app, or a Flutter project.

| I want to… | Type this |
|---|---|
| Commit my staged changes properly | *"run the supy-commit skill"* — writes a Conventional Commits message + `Co-Authored-By` trailer, asks before committing, never pushes |
| Open a pull request | *"run the supy-create-pr skill"* — builds a conventional title + Summary/Changes/Test-evidence body, pushes via `gh` if available |
| Review my branch before I commit or open a PR | `/supy-review` — detects the stack, runs the matching reviewers in parallel, groups findings High/Medium/Low |
| Review against a specific base branch | `/supy-review origin/release/2026-07` |
| Rebase my branch onto its base safely | *"run the supy-rebase skill"* — takes a safety ref, walks conflicts one commit at a time, no force-push without asking |
| Ship an urgent production fix | *"run the supy-hotfix skill"* — minimal diff, `fix:` commit, fast-tracked review + PR |
| Hand off / write up what I did on this branch | *"run the supy-debrief skill"* — builds a handoff from the real commits + diff |
| Fix a red CI run | *"run the fix-failing-github-actions skill"* — pulls the failing checks, fixes the cause, loops until green |
| Turn a Jira ticket into an implementation spec | *"run the supy-impl-spec skill for PROJ-1234"* → writes `docs/specs/…` |
| Scope a research spike from a ticket | *"run the supy-spike-spec skill for PROJ-1234"* |
| Set up (or refresh) this repo's `CLAUDE.md` | `/supy-onboard` — wraps `supy-baseline` and checks the `CLAUDE.md` for drift vs. the stack template |
| Just check for drift, don't rewrite anything | `/supy-onboard drift only` |
| Go from a rough idea to a design | `/supy-brainstorm add a stock-transfer approval flow` |
| Turn a design into a phased plan | `/supy-plan` |
| Execute a plan task by task (local commits only) | `/supy-build` |

---

## Backend service — `nestjs-nx`

**You'll see:** `supy-wingspan: detected nestjs-nx repo.`
**Repos:** `supy-service-inventory`, `supy-service-ordering`, and the BFFs
(`supy-api-retailer`, `supy-api-mobile`, `supy-api-admin`).
**Reviewers that run:** architecture, NATS events, test-quality, security,
plus commit/PR and secrets.

| I want to… | Type this |
|---|---|
| Understand how to write backend code the Supy way | *"run the supy-clean-architecture skill"* — layer direction, DDD building blocks, CQRS, NATS |
| Start a brand-new bounded context | *"run the supy-scaffold-domain skill"* → the Plop `g:domain` generator, then fill in domain → application → infrastructure |
| Add a NATS RPC request handler | *"run the supy-scaffold-handler skill — an RPC handler for getInventoryItem"* |
| Add a JetStream event consumer | *"run the supy-scaffold-handler skill — a JetStream consumer for order.placed"* |
| Review a service change before PR | `/supy-review` (the 4 backend reviewers + commit/PR + secrets run in parallel) |
| Design a new feature end to end | `/supy-brainstorm add low-stock reordering` → `/supy-plan` → `/supy-build` |
| Check who emits/consumes an event before I touch it | *"use the supy-kg skill — which services consume `order.placed`?"* |
| See a DTO's shape and everyone who uses it | *"use the supy-kg skill — get the DTO usage for CreateOrderDto"* |

**BFF note:** the three BFFs (`supy-api-retailer`, `supy-api-mobile`,
`supy-api-admin`) are also `nestjs-nx`, so everything above applies. When you ask
the graph about client→API or endpoint→NATS chains there, scope to the one BFF —
see [Ask the architecture graph](#ask-the-architecture-graph--any-repo).

---

## Frontend — `angular-nx`

**You'll see:** `supy-wingspan: detected angular-nx repo.`
**Repo:** `supy-frontend`.
**Reviewers that run:** Angular, plus commit/PR and secrets.

| I want to… | Type this |
|---|---|
| Learn the Supy Angular conventions | *"run the supy-angular-feature skill"* — OnPush, `inject()`, signals, NGXS, `--p-*` tokens |
| Scaffold a new NGXS feature library | *"run the supy-scaffold-feature skill"* → the Plop generator, then fill in the state/actions/selectors |
| Turn a Figma flow into tickets | *"run the supy-figma-to-tickets skill"* then paste the Figma URL |
| Review a frontend change | `/supy-review` |
| Plan a new screen from an idea | `/supy-brainstorm add a supplier price-comparison screen` → `/supy-plan` |
| Commit + open the PR | *"run the supy-commit skill"* then *"run the supy-create-pr skill"* |
| Find which BFF endpoint a component calls | *"use the supy-kg skill — trace the client-api-map for supy-api-retailer"* |

---

## Mobile — `flutter`

**You'll see:** `supy-wingspan: detected flutter repo.`
**Repos:** `supy-retailer` and other Flutter apps/packages.
**Reviewers that run:** Flutter, plus commit/PR and secrets.
**Bonus:** a PostToolUse hook auto-formats and analyzes any Dart file you edit.

| I want to… | Type this |
|---|---|
| Learn the Supy Flutter conventions | *"run the supy-flutter-feature skill"* — Clean Arch, BLoC, go_router, get_it, dio, dartz |
| Scaffold a new feature | *"run the supy-scaffold-flutter-feature skill — a `promotions` feature"* → domain + data + presentation + tests |
| Build a Figma screen 1:1 in Flutter | *"run the supy-figma-implement-design skill"* then paste the Figma node URL — maps tokens, adds golden tests |
| Break a Figma flow into tickets | *"run the supy-figma-to-tickets skill"* |
| Write / debug e2e integration tests | *"run the supy-e2e-tests skill"* — runs `integration_test` against the live dev backend |
| Check if the app is ready to release | *"run the supy-app-release-readiness skill"* → per-platform audit + `RELEASE_TODO.md` |
| Bump the Flutter / Dart SDK everywhere | *"run the supy-flutter-upgrade skill"* — pubspecs, `.fvmrc`, workflows, then pub get/format/analyze |
| Audit the whole Dart codebase | *"run the supy-code-assessment skill"* → `CODE_ASSESSMENT.md` |
| Analyze a native iOS/Android app for migration | *"run the supy-analyze-native-codebase skill"* |
| Grade a candidate's Flutter take-home | *"run the supy-interview-feedback skill"* |
| Review a mobile change | `/supy-review` |

---

## Firebase Functions — `firebase-functions`

**You'll see:** `supy-wingspan: detected firebase-functions repo.`
**Repo:** `supy-firebase-functions` (standalone, *not* Nx).
**Reviewers that run:** Firebase Functions, plus commit/PR and secrets.

| I want to… | Type this |
|---|---|
| Learn the Supy Functions conventions | *"run the supy-firebase-function skill"* — index → interactors → repositories → frameworks, Awilix DI, auth markers, Secret Manager |
| Add a new callable / trigger the Supy way | *"run the supy-firebase-function skill — add an `onOrderShipped` Firestore trigger"* |
| Review before PR | `/supy-review` (watch for hardcoded secrets and trigger idempotency) |
| Onboard this repo's `CLAUDE.md` | `/supy-onboard` |

---

## TypeScript CLI — `ts-cli`

**You'll see:** `supy-wingspan: detected ts-cli repo.`
**Repo:** `supy-cli` (commander.js MongoDB scripts runner).
**Reviewers that run:** CLI (architecture + operational safety), plus commit/PR
and secrets.

| I want to… | Type this |
|---|---|
| Learn the Supy CLI conventions | *"run the supy-ts-cli skill"* — Clean Arch, `scripts [run\|list\|info]`, the `IScript`/`ScriptDetails` contract, env-layered config |
| Add a new script the Supy way | *"run the supy-ts-cli skill — add a `backfill-tenant-ids` script"* — thin command, prod-confirm gate, batched bulk ops |
| Review before PR | `/supy-review` (checks: no secrets in argv/logs, explicit prod confirmation, deterministic exit codes) |

---

## AI-agents monorepo — `ai-agents`

**You'll see:** `supy-wingspan: detected ai-agents repo.`
**Repo:** `supy-ai-agents` (polyglot — Node + Python + Cloudflare Workers, MCP
tools, BullMQ, pgvector KG; includes Cortex, Nexus, and friends).
**Reviewers that run:** AI-agents (architecture + operational safety), plus
commit/PR and secrets.

| I want to… | Type this |
|---|---|
| Write / change code the Supy way | *"run the supy-ai-agents skill"* — secret hygiene, auth on exposed MCP tools/routes, env-driven config, idempotent consumers, non-root containers |
| Add a new MCP tool | *"run the supy-ai-agents skill — add an MCP tool that returns tenant usage"* (it'll enforce auth + validation on the entrypoint) |
| Review before PR | `/supy-review` |

> This is the repo that *hosts* Cortex — the knowledge-graph service the `supy-kg`
> skill connects to from every other repo.

---

## Kubernetes config — `k8s-config`

**You'll see:** `supy-wingspan: detected k8s-config repo.` plus a reminder that
**secrets must live in a Secret/external-secret, never in a ConfigMap.**
**Reviewers that run:** secrets + commit/PR only (no stack-specific reviewer).

| I want to… | Type this |
|---|---|
| Scan a manifest change for leaked secrets / bad config split | `/supy-review` — the secrets reviewer is the whole point here |
| Understand the config/secret separation rule | ask to read `config/standards/secrets-and-config.md` |
| Commit + PR a manifest change | *"run the supy-commit skill"* then *"run the supy-create-pr skill"* |

> Never paste a real secret value into the session. If a manifest needs a
> credential, it belongs in a Secret/external-secret reference, not inline.

---

## Shared / bare Nx — `nx`

**You'll see:** `supy-wingspan: detected nx repo.`
**Repos:** shared Nx workspaces with no Angular/Nest marker, e.g. `supy-api-common`.
**Reviewers that run:** commit/PR and secrets only.

| I want to… | Type this |
|---|---|
| Review a change to a shared library | `/supy-review` |
| Commit + PR | *"run the supy-commit skill"* then *"run the supy-create-pr skill"* |
| See who depends on a shared DTO before changing it | *"use the supy-kg skill — find usages of PaginationDto"* |

> Because it's not detected as backend or frontend, you get the two stack-agnostic
> reviewers only. That's expected — a shared lib has no single stack's rules.

---

## Ask the architecture graph — any repo

The `supy-kg` skill connects to **Cortex**, Supy's cross-repo architecture
knowledge graph, through its MCP. Use it whenever a question spans repos or asks
"how does X actually work across the stack." (Cortex must be connected.)

| I want to know… | Type this |
|---|---|
| Which service emits an event | *"use the supy-kg skill — who emits `inventory.adjusted`?"* |
| Who consumes a NATS pattern | *"use the supy-kg skill — who consumes `order.*`?"* |
| A DTO's shape and its consumers | *"use the supy-kg skill — DTO usage for CreateOrderDto"* |
| A NATS handler's contract | *"use the supy-kg skill — handler contract for getInventoryItem"* |
| An event's payload schema | *"use the supy-kg skill — event schema for order.placed"* |
| The full path of a business flow | *"use the supy-kg skill — trace the checkout flow"* |
| A repo overview before diving in | *"use the supy-kg skill — repo guide for supy-service-ordering"* |

**Big-perspective warning:** for `client-api-map` and `endpoint-nats-chains`,
always scope to one BFF, or the result is too large to be accurate:

```text
use the supy-kg skill — client-api-map filtered to supy-api-retailer
```

---

## Full walkthroughs

### A new backend feature, start to finish (in `supy-service-inventory`)

```text
/supy-brainstorm add low-stock automatic reordering        # idea → design
/supy-plan                                                 # design → phased plan
"run the supy-scaffold-domain skill"                       # scaffold the bounded context
/supy-build                                                # implement task by task (local commits)
/supy-review                                               # architecture + NATS + tests + security + secrets
"run the supy-commit skill"                                # conventional commit
"run the supy-create-pr skill"                             # push + open the PR
```

### A Figma screen into the Flutter app (in `supy-retailer`)

```text
"run the supy-figma-implement-design skill"   # then paste the Figma node URL
# edit widgets — the PostToolUse hook auto-formats/analyzes each Dart file you save
"run the supy-e2e-tests skill"                # add/adjust integration tests
/supy-review                                  # Flutter reviewer + commit/PR + secrets
"run the supy-commit skill"
"run the supy-create-pr skill"
```

### An urgent production fix (any repo)

```text
"run the supy-hotfix skill"          # minimal diff from the remote base, fix: commit, review, fast-tracked PR
```

### Onboarding a repo that has no Supy setup yet

```text
/supy-onboard                        # generates CLAUDE.md from the stack template + repo inspection
# review the diff it shows you, then accept
/supy-review                         # confirm the reviewers fire for this stack
```

---

*Missing a recipe? The full component list (all 5 commands, 28 skills, 11
reviewers, 3 hooks) is in [USAGE.md §4](./USAGE.md#4-what-you-get-after-install).*
