# Using supy-wingspan skills — step by step in a session

Real, in-session walkthroughs of the plugin's skills. Each example shows **what you type**
and **what happens**, step by step. No config to touch — the plugin detects your repo and
surfaces the right skill.

> Two ways a skill gets used:
>
> - **Slash command** — you type it explicitly, e.g. `/supy-plan …`. The `/supy` menu lists
>   every skill; each is now prefixed with its stack, e.g. `[backend]`, `[flutter]`, `[any]`.
> - **Router nudge** — you type a normal request ("commit this") and the plugin suggests the
>   right skill. Stack-specific skills only nudge in a repo of that stack.

---

## Example 1 — `/supy-plan` — plan a feature the Supy way

**Repo:** backend (`nestjs-nx`)

**You type:**

```text
/supy-plan add a force-logout endpoint that revokes all sessions for a user
```

**Step by step, what happens:**

1. **Loads Supy standards into context** — `nx-nestjs-patterns.md`, `architecture.md`,
   `nats-event-patterns.md`, `commit-conventions.md`, `security-cerbos.md`.
2. **Reads your existing code** — if the Cortex MCP server is connected, it calls
   `get_repo_guide` and `search_entities` to learn your current aggregates, events, and
   module boundaries first. (Optional — it never fails if Cortex is absent.)
3. **Produces a phased plan** — at minimum: domain/model → application/interactor →
   infrastructure/adapter → testing. **Every task names the Nx library it touches.**
4. **Adds a "Supy Standards Alignment" section** — maps each task to its bounded context,
   lists new NATS events and confirms they follow the standard, states the expected
   conventional commit type per phase, and flags any Cerbos policy change needed.
5. **Saves the plan** to `docs/superpowers/plans/force-logout-endpoint.md` and prints the path.

**Why it matters:** the plan is already shaped to Supy's architecture — not generic advice.

---

## Example 2 — the everyday loop: build → review → commit → PR

**Repo:** backend. You mostly just talk; the router surfaces the right skill.

### Step 1 — implement

**You type:**

```text
implement phase 1 of the plan
```

You write code following `supy-clean-architecture` conventions (aggregates with methods +
`this.assign`/`this.addEvent`, value objects, factories, interactors that persist atomically
then side-effect). No stack nudges get in your way.

### Step 2 — review

**You type:**

```text
review my changes before I commit
```

→ Router nudge: **"Run supy-review."**
→ `/supy-review` detects `nestjs-nx` and dispatches **6 backend reviewers + commit/PR +
secrets** in parallel, then consolidates findings by severity (high → med → low), each line
prefixed with the reviewer name for traceability.

### Step 3 — commit

**You type:**

```text
commit this
```

→ Router nudge: **"Use supy-commit."**
→ `/supy-commit` reads `commit-conventions.md`, inspects the **staged** diff, and proposes:

```text
feat(auth): add force-logout endpoint revoking all sessions
```

→ It shows the message, waits for your **explicit approval**, then commits with the
`Co-Authored-By` trailer. It will **not** commit without your OK, and rejects non-allowed
types (`bug`, `hotfix`, `wip` → commitlint would reject them anyway).

### Step 4 — open a PR

**You type:**

```text
open a PR
```

→ `/supy-create-pr` builds a conventional title and a **Summary / Changes / Test-evidence**
body from the branch's commits and diff, then opens it via `gh` (or prints a ready-to-paste
title+body if `gh` isn't available).

---

## Example 3 — the stack filter (why a backend dev doesn't see Flutter skills)

Same prompt, two different repos:

**On the FLUTTER repo:**

```text
you: implement the figma design for the login screen
→ nudge: use supy-figma-implement-design (maps tokens onto ThemeData, places the widget in
  the shared UI package, validates with Alchemist golden tests)
```

**On the BACKEND repo:**

```text
you: implement the figma design for the login screen
→ (silent) — no Figma skill is offered to a backend dev
```

And in the `/supy` command menu, the stack prefix makes it obvious at a glance:

```text
[flutter]  supy-flutter-feature     How to write Flutter code in a supy mobile repo…
[backend]  supy-clean-architecture  How to write NestJS backend code in a supy service repo…
[frontend] supy-angular-feature     How to write Angular code in a supy frontend repo…
[any]      supy-commit              Stage-aware conventional commit per Supy commitlint…
```

---

## Example 4 — a Flutter-only session (scaffold → build → release-check)

**Repo:** flutter

### Step 1 — scaffold a feature

```text
you: scaffold a new "orders" feature
→ /supy-scaffold-flutter-feature creates domain + data + presentation + tests from stubs,
  then prints the manual wiring (get_it registration, go_router route, barrel export)
```

### Step 2 — implement from a design

```text
you: implement the figma design for the orders list
→ supy-figma-implement-design builds the widget with 1:1 fidelity + golden tests
```

### Step 3 — check release readiness

```text
you: is the app ready to release to the store
→ supy-app-release-readiness audits each platform (Android/iOS/web/desktop) in parallel
  and produces a RELEASE_TODO.md
```

None of these three nudges would fire on a backend or frontend repo.

---

## Quick reference — which skills fire where

| Skill | Stack tag | Fires when |
| --- | --- | --- |
| supy-commit, supy-create-pr, supy-review, supy-rebase, supy-hotfix, supy-debrief, supy-baseline, fix-failing-github-actions, supy-impl-spec, supy-spike-spec, supy-kg, supy-figma-to-tickets | `[any]` | every repo |
| supy-clean-architecture, supy-scaffold-domain, supy-scaffold-handler | `[backend]` | nestjs-nx |
| supy-angular-feature, supy-scaffold-feature | `[frontend]` | angular-nx |
| supy-flutter-feature, supy-scaffold-flutter-feature, supy-figma-implement-design, supy-app-release-readiness, supy-flutter-upgrade, supy-code-assessment, supy-analyze-native-codebase, supy-e2e-tests, supy-interview-feedback | `[flutter]` | flutter |
| supy-firebase-function | `[firebase]` | firebase-functions |
| supy-ts-cli | `[ts-cli]` | ts-cli |
| supy-ai-agents | `[ai-agents]` | ai-agents |

---

*Bottom line: you rarely call skills by name — you describe what you want, and the plugin
routes you to the Supy-correct way to do it, scoped to the repo you're in.*
