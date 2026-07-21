# One feature across many repos — zero to merged PRs

A single feature rarely lives in one repo. This walkthrough follows **one feature** —
**"admin force-logout"** (an admin can revoke every active session for a user) — from nothing
to an open PR in **each** repo it touches, with the plugin enforcing the same Supy standards
on every side.

**The feature spans four repos:**

| Repo | Stack | Its slice of the feature |
| --- | --- | --- |
| `supy-backend` | nestjs-nx | The endpoint, session revocation, emits a `user.sessions-revoked` domain event |
| `supy-firebase-functions` | firebase-functions | A trigger that reacts to the event (push a "you were signed out" notification) |
| `supy-frontend` | angular-nx | Admin console button + confirmation dialog that calls the endpoint |
| `supy-retailer` | flutter | Mobile client detects forced logout and clears the session |

> The point: **you install the plugin once.** In each repo it detects the stack, gives you
> that stack's skills, and enforces the same commit/secret/review rules — so the feature lands
> consistently everywhere without anyone copying agent files between repos.

---

## Prerequisite (once per repo) — onboard

In any repo that doesn't yet have a Supy `CLAUDE.md`:

```text
/supy-onboard
```

→ Detects the stack, fills the stack's template, writes `CLAUDE.md`, and reports any missing
AI setup (Cortex MCP, `.claude` settings). Do this once; skip if the repo is already set up.

---

## Repo 1 — `supy-backend` (nestjs-nx)

### Step 1 — plan

```text
/supy-plan add an admin force-logout endpoint that revokes all sessions for a user
            and emits a domain event
```

→ Loads backend standards, reads existing aggregates via Cortex (if connected), and writes a
phased plan to `docs/superpowers/plans/admin-force-logout.md` — domain → interactor →
infrastructure → testing, each task naming its Nx library, plus a **Supy Standards
Alignment** section that declares the new NATS event `user.sessions-revoked` and the expected
commit types.

### Step 2 — build

```text
/supy-build docs/superpowers/plans/admin-force-logout.md
```

→ Executes the plan task-by-task the Supy way: a `revokeAllSessions()` method on the User
aggregate calling `this.addEvent(...)`, an interactor that **persists atomically then
side-effects**, a NATS controller, and tests. Commits each task as it goes.

### Step 3 — review

```text
review my changes before I push
```

→ `/supy-review` detects `nestjs-nx` → dispatches **6 backend reviewers + commit/PR +
secrets** in parallel → consolidates by severity. Fix any `high` findings and re-run until
clean.

### Step 4 — commit anything outstanding

```text
commit this
```

→ `/supy-commit` proposes, e.g.:

```text
feat(auth): add admin force-logout revoking all user sessions
```

Shows it, waits for your OK, commits with the `Co-Authored-By` trailer.

### Step 5 — open the PR

```text
open a PR
```

→ `/supy-create-pr` → conventional title + Summary/Changes/Test-evidence body:

```text
feat(auth): admin force-logout endpoint
```

✅ **Repo 1 PR open.** It emits `user.sessions-revoked` — the contract the next three repos build against.

---

## Repo 2 — `supy-firebase-functions`

### Step 1 — implement the trigger

```text
add a trigger that reacts to user.sessions-revoked and notifies the user
```

→ `supy-firebase-function` skill guides Clean Architecture (index.ts → app interactor → data
repo → frameworks), Awilix DI, a **runtime-enforced auth marker**, typed domain errors, and
an **idempotent** handler (safe to receive the event twice). Secrets come from **Secret
Manager, never literals** — the secrets reviewer would block a hardcoded key.

### Step 2 — review → commit → PR (firebase-functions)

```text
review my changes    → /supy-review dispatches the firebase reviewer + commit/PR + secrets
commit this          → feat(notifications): notify user on forced logout
open a PR
```

✅ **Repo 2 PR open.**

---

## Repo 3 — `supy-frontend` (angular-nx)

### Step 1 — scaffold the UI feature

```text
scaffold a force-logout action in the user-admin feature
```

→ `supy-scaffold-feature` generates the NGXS feature library (models, state, service, smart +
dumb components, resolver, routes — tagged and wired).

### Step 2 — implement

```text
add a "Force logout" button with a confirmation dialog that calls the endpoint
```

→ `supy-angular-feature` guides OnPush components, `inject()`, signal inputs/outputs, NGXS
state with Immer `produce`, and a URI-token service for the API call.

### Step 3 — review → commit → PR

```text
review my changes    → /supy-review dispatches the angular reviewer + commit/PR + secrets
commit this          → feat(user-admin): add force-logout action
open a PR
```

✅ **Repo 3 PR open.**

---

## Repo 4 — `supy-retailer` (flutter)

### Step 1 — scaffold + implement

```text
scaffold a session feature      → supy-scaffold-flutter-feature (domain + data + presentation + tests)
handle a forced-logout response by clearing the session and routing to login
                                → supy-flutter-feature: Clean Architecture, Bloc (never Cubit),
                                  go_router context.go, get_it DI, dartz Either/Failure
```

### Step 2 — review → commit → PR (flutter)

```text
review my changes    → /supy-review dispatches the flutter reviewer + commit/PR + secrets
commit this          → feat(auth): clear session on forced logout
open a PR
```

✅ **Repo 4 PR open.**

---

## What just happened (the payoff)

```text
supy-backend            PR: feat(auth): admin force-logout endpoint            ✅
supy-firebase-functions PR: feat(notifications): notify user on forced logout  ✅
supy-frontend           PR: feat(user-admin): add force-logout action          ✅
supy-retailer           PR: feat(auth): clear session on forced logout         ✅
```

Across four different stacks, **the same plugin**, installed once, gave every repo:

- the **right skills** for its stack (backend never saw Flutter's, and vice-versa),
- the **same review discipline** — the commit/PR and **secrets** reviewers ran on all four,
- **consistent conventional commits** and PR bodies,
- one shared event contract (`user.sessions-revoked`) honored on every side.

No agent files were copied between repos. Nobody forgot to add the secret scanner. That's the
problem this plugin solves.

---

*See also: `docs/SKILLS-IN-A-SESSION.md` (single-skill deep-dives) and `docs/CTO-DEMO.md`
(the 10-minute proof-it-works demo).*
