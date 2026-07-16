# Supy skill routing (embed in a repo's CLAUDE.md)

Canonical block that `supy-baseline` appends to every generated `CLAUDE.md`, so each Supy repo tells
Claude which skill handles which engineering action. Keep it in sync with `hooks/skill-router.sh`
(the prompt-time equivalent) — both route the same intents to the same skills.

`supy-baseline` embeds **two** parts: the universal table (always), plus the **one** stack block that
matches the repo's detected stack. The stack blocks are delimited by `<!-- STACK:<id> -->` markers so
the generator can select exactly one. Everything from the `## Using Supy skills` heading down is the
embeddable content; the per-stack `<!-- STACK -->` comment markers are stripped on embed.

## Using Supy skills

This repo is covered by the **supy-wingspan** plugin. For the engineering actions below, prefer the
matching skill over doing it by hand — each encodes Supy's standards and safety gates.

**Universal — these apply in every Supy repo:**

| When you're about to… | Use the skill |
|---|---|
| Commit changes | `supy-commit` — Conventional Commits message + Co-Authored-By trailer; never a raw `git commit -m` |
| Open a pull request | `supy-create-pr` — conventional title + Summary / Changes / Test-evidence body |
| Review a diff before committing or opening a PR | `supy-review` — stack-aware reviewers in parallel, consolidated by severity |
| Rebase or update a branch | `supy-rebase` — clean-tree gate, a safety ref, and `--force-with-lease` only after you confirm |
| Ship a production hotfix | `supy-hotfix` — minimal diff from the remote base, commits as `fix`, fast-tracked review + PR |
| Wrap up or hand off a branch | `supy-debrief` — structured handoff built from the actual commits and diff |
| Fix a failing CI / GitHub Actions run | `fix-failing-github-actions` — pulls the run logs, fixes the root cause, loops until green |
| Turn a ticket into an implementation spec | `supy-impl-spec` — structured impl spec under `docs/specs/` |
| Scope a time-boxed spike | `supy-spike-spec` — investigation spec with questions, timebox, and exit criteria |
| (Re)generate this file | `supy-baseline` — regenerate `CLAUDE.md` from the canonical template + repo inspection |

<!-- STACK:nestjs-nx -->
**Backend (NestJS on Nx) — for this repo's stack:**

| When you're about to… | Use the skill |
|---|---|
| Write backend code (aggregates, VOs, interactors, CQRS, NATS) the Supy way | `supy-clean-architecture` — the backend how-to, grounded in the mined standards |
| Scaffold a new bounded context / domain | `supy-scaffold-domain` — the `g:domain` generator, then fill-in in dependency order |
| Add a NATS handler (RPC request or JetStream event) | `supy-scaffold-handler` — colocated DTO + test stub |
<!-- /STACK:nestjs-nx -->

<!-- STACK:angular-nx -->
**Frontend (Angular on Nx) — for this repo's stack:**

| When you're about to… | Use the skill |
|---|---|
| Write Angular code (OnPush + `inject()`, signals, NGXS) the Supy way | `supy-angular-feature` — the frontend how-to |
| Scaffold a new Angular NGXS feature library | `supy-scaffold-feature` — the Plop generator, then fill-in in dependency order |
| Break a Figma flow into tickets | `supy-figma-to-tickets` — GitHub/Jira issues from a Figma design |
<!-- /STACK:angular-nx -->

<!-- STACK:flutter -->
**Flutter / mobile — for this repo's stack:**

| When you're about to… | Use the skill |
|---|---|
| Write Flutter code (Clean Arch, BLoC, go_router, get_it) the Supy way | `supy-flutter-feature` — the Flutter how-to |
| Scaffold a new feature (or a whole new project) | `supy-scaffold-flutter-feature` — bundled stubs + `very_good create` for new projects |
| Build a Figma design into Flutter | `supy-figma-implement-design` — tokens, Widgetbook, goldens |
| Break a Figma flow into tickets | `supy-figma-to-tickets` — GitHub/Jira issues from a Figma design |
| Write integration / e2e tests | `supy-e2e-tests` — the Supy patterns, never-weaken-assertions |
| Check release readiness | `supy-app-release-readiness` — per-platform audit → `RELEASE_TODO.md` |
| Bump the Flutter / Dart SDK | `supy-flutter-upgrade` — pubspec / `.fvmrc` / workflows across every package |
| Audit the whole Dart/Flutter codebase | `supy-code-assessment` — project-wide audit → `CODE_ASSESSMENT.md` |
| Audit the native (Android / iOS) layers | `supy-analyze-native-codebase` — native migration/analysis |
| Evaluate a Flutter candidate's take-home | `supy-interview-feedback` — scored rubric → `INTERVIEW_FEEDBACK.md` |
<!-- /STACK:flutter -->

<!-- STACK:firebase-functions -->
**Firebase Functions — for this repo's stack:**

| When you're about to… | Use the skill |
|---|---|
| Write Firebase Functions code the Supy way | `supy-firebase-function` — Clean Arch, Awilix DI, auth markers, Secret Manager |
<!-- /STACK:firebase-functions -->

<!-- STACK:ts-cli -->
**TypeScript CLI — for this repo's stack:**

| When you're about to… | Use the skill |
|---|---|
| Write CLI code the Supy way | `supy-ts-cli` — Clean Arch, commander.js, `IScript` contract, prod-confirm gates |
<!-- /STACK:ts-cli -->

<!-- STACK:ai-agents -->
**AI-agents monorepo — for this repo's stack:**

| When you're about to… | Use the skill |
|---|---|
| Write / change code in the polyglot AI-agents monorepo the Supy way | `supy-ai-agents` — architecture + operational standard (secrets, auth, idempotency) |
<!-- /STACK:ai-agents -->

Scaffolding and how-to skills are also invoked by name whenever you start that kind of work.
