# How to use supy-wingspan — the everyday guide

A practical playbook for using the plugin day to day: building a feature, fixing a bug,
shipping a hotfix, or working a feature that spans several repos. You rarely call things by
name — you describe what you want, and the plugin routes you to the Supy-correct way to do it,
scoped to the repo you're in.

---

## The one thing to understand first

The plugin **detects your repo's stack** and gives you two kinds of help:

- **Slash commands** — you type them (`/supy-plan`, `/supy-review`). The `/supy` menu lists
  every skill, each prefixed with its stack: `[backend]`, `[flutter]`, `[frontend]`,
  `[firebase]`, `[ts-cli]`, `[ai-agents]`, or `[any]`.
- **Nudges** — you type a normal request ("commit this", "fix the failing CI") and the plugin
  suggests the right skill. Stack-specific skills only nudge inside a repo of that stack, so a
  backend dev never sees Flutter suggestions and vice-versa.

You don't configure anything per repo. Install once; it figures out where it is.

---

## First time in a repo — onboard (once)

If the repo has no Supy `CLAUDE.md` yet, the SessionStart line will tell you. Run:

```text
/supy-onboard
```

→ detects the stack, writes a `CLAUDE.md` from the stack's template, and reports any missing
AI setup. Do this once per repo.

---

## Workflow 1 — build a new feature

The core loop. Works in any repo; the plugin swaps in your stack's skills automatically.

| Step | You type | What happens |
| --- | --- | --- |
| 1. Shape the idea | `/supy-brainstorm add a stock-transfer approval flow` | Turns a rough idea into a design (purpose → constraints → success criteria). |
| 2. Plan | `/supy-plan` | Phased plan (domain → application → infrastructure → testing), each task naming its library, saved under `docs/superpowers/plans/`. |
| 3. Build | `/supy-build docs/superpowers/plans/<plan>.md` | Executes the plan task-by-task the Supy way, committing locally as it goes. |
| 4. Review | `review my changes before I commit` | `/supy-review` dispatches your stack's reviewers in parallel, consolidated by severity. Fix `high` findings, re-run. |
| 5. Commit | `commit this` | `/supy-commit` proposes a Conventional Commits message, waits for your OK, adds the trailer. |
| 6. PR | `open a PR` | `/supy-create-pr` builds a conventional title + Summary/Changes/Test-evidence body. |

You can also just write code yourself and jump in at step 4 — review → commit → PR works
standalone.

### Scaffolding shortcuts (optional)

If you're adding a whole new module, scaffold it first, then fill it in:

- **Backend:** `scaffold a new "invoicing" domain` → `supy-scaffold-domain`
- **Frontend:** `scaffold a "reports" feature` → `supy-scaffold-feature`
- **Flutter:** `scaffold an "orders" feature` → `supy-scaffold-flutter-feature`
- **Backend NATS:** `scaffold a handler for order.created` → `supy-scaffold-handler`

---

## Workflow 2 — fix a bug

Smaller loop — usually no plan needed.

```text
1. (write the fix, or describe it and let the skill guide you)
2. review my changes       → /supy-review — catches regressions, secrets, convention breaks
3. commit this             → /supy-commit proposes:  fix(<scope>): <what you fixed>
4. open a PR               → /supy-create-pr
```

The commit type matters: bug fixes are `fix(...)`, **not** `bug(...)` — commitlint rejects the
latter. The skill picks the right type for you.

---

## Workflow 3 — ship an urgent production hotfix

When something is broken in prod and needs a targeted fix now:

```text
ship a hotfix for <the production issue>
```

→ `supy-hotfix` drives the whole thing with hotfix discipline:

1. cuts `hotfix/<slug>` from the **up-to-date remote base**,
2. keeps the diff **minimal** (no scope creep),
3. commits as `fix` (via `supy-commit`),
4. runs the review (via `supy-review`),
5. fast-tracks the PR (via `supy-create-pr`),
6. handles the back-merge and release follow-ups.

---

## Workflow 4 — one feature across several open repos

You have several `supy-*` repos checked out under one folder and a feature that touches more
than one of them (e.g. backend emits an event, mobile reacts to it). From any one of them:

```text
/supy-feature add an admin force-logout that revokes all sessions for a user
```

→ scans the parent folder, detects each repo's stack, and **proposes** which repos the feature
touches — with a reason per repo — and waits for you to confirm:

```text
  ✓ supy-backend   (nestjs-nx) — owns the domain; endpoint + emits user.sessions-revoked
  ✓ supy-frontend  (angular-nx) — admin UI to trigger it
  ✓ supy-retailer  (flutter)    — client reacts to the event
  ✗ supy-cli       (ts-cli)     — no CLI surface — skipping
  Confirm? (yes / edit the set)
```

→ after you confirm, it writes a **plan into each affected repo** (grounded in that repo's
standards, all naming the shared contract identically), then prints the next command per repo.
It is **plan-only** — you then run the normal build → review → commit → PR loop **in each
repo**. Full walkthrough: [`CROSS-REPO-FEATURE-WALKTHROUGH.md`](CROSS-REPO-FEATURE-WALKTHROUGH.md).

---

## Workflow 5 — keep a branch current / fix red CI

```text
rebase onto main           → supy-rebase — safety ref, one-commit-at-a-time conflicts,
                             --force-with-lease only after you confirm
fix the failing CI         → fix-failing-github-actions — pulls the run logs, fixes the root
                             cause, commits + pushes, loops until every check is green
```

---

## Workflow 6 — specs, handoffs, and audits

| You want to… | Type / run | Skill |
| --- | --- | --- |
| Turn a ticket into an implementation spec | `write an impl spec for JIRA-123` | `supy-impl-spec` |
| Time-box an investigation | `write a spike spec for <question>` | `supy-spike-spec` |
| Hand off / wrap up a branch | `debrief this branch` | `supy-debrief` |
| Break a Figma flow into tickets | `turn this figma into tickets` | `supy-figma-to-tickets` |

Flutter-only audits: `assess the codebase` (`supy-code-assessment`), `is the app ready to
release` (`supy-app-release-readiness`), `upgrade Flutter` (`supy-flutter-upgrade`).

---

## Cheat sheet

```text
New feature      /supy-brainstorm → /supy-plan → /supy-build → review → commit → PR
Bug fix          (fix) → review my changes → commit this → open a PR
Hotfix           ship a hotfix for <issue>
Cross-repo       /supy-feature <feature>   (plans each repo; you build each)
Rebase           rebase onto main
Red CI           fix the failing CI
Onboard a repo   /supy-onboard
Review anytime   review my changes   (or /supy-review)
Commit anytime   commit this         (never hand-write git commit -m)
```

---

## Two rules that always hold

1. **Let the skills do commits and PRs.** `supy-commit` and `supy-create-pr` enforce
   Conventional Commits and add the `Co-Authored-By` trailer — don't hand-roll
   `git commit -m` or `gh pr create`.
2. **Review before you push.** `supy-review` runs the secrets reviewer on every stack, so a
   committed credential is caught before it leaves your machine.

*See also: [`SKILLS-IN-A-SESSION.md`](SKILLS-IN-A-SESSION.md) for per-skill session
transcripts, and the [README](../README.md) for the full skill catalog.*
