---
name: supy-feature-fanout
description: "[any] Plan one cross-repo feature across several open Supy repos from a single prompt. Scans a parent folder for git repos, detects each one's stack, proposes which repos the feature touches (you confirm), then writes a per-repo implementation plan into each affected repo using that repo's Supy standards. Plan-only — it never edits code, commits, or opens PRs. Use when you have multiple supy-* repos checked out under one folder and one feature spans several of them, and you don't want to open each repo and re-explain the feature."
---

## What this does (and does not do)

**Does:** takes one feature description, discovers the Supy repos under a parent folder,
detects each repo's stack, proposes the subset the feature touches, and — after you confirm —
writes a **plan file** into each affected repo, grounded in that repo's stack standards.

**Does not:** edit code, create branches, commit, or open PRs. It stops at plans. To
implement, run `/supy-build <plan>` **inside each repo** afterward (the plan file names its
own path). This boundary is deliberate — one prompt fanning out writes across many repos is
only safe if it stops at reviewable plans.

Use this when several `supy-*` repos are checked out under one folder and a feature spans more
than one of them. For a single repo, use `/supy-plan` instead.

---

## Step 1 — Resolve the workspace root (the parent folder to scan)

The workspace root is the folder that *contains* the sibling repos.

1. If the user named a folder in the prompt, use it.
2. Otherwise default to the **parent of the current repo**:

```bash
CURRENT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
WORKSPACE="${WORKSPACE:-$(dirname "$CURRENT_ROOT")}"
echo "Scanning workspace: $WORKSPACE"
```

If neither is resolvable, stop and ask the user for the folder that holds their repos.

---

## Step 2 — Discover repos and detect each stack

Find every git repo one level under the workspace, then detect its stack using the **canonical
shared procedure** — do not reinvent detection here:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/skills/shared/references/stack-detection.md"
```

For each immediate child directory that contains a `.git`, set `REPO_PATH` to it and run the
detection procedure from that reference (first match wins) to resolve `STACK`. Skip
directories whose `STACK` resolves to `other` unless the user explicitly included them.

Build a table:

```text
REPO                       STACK
supy-backend               nestjs-nx
supy-frontend              angular-nx
supy-retailer              flutter
supy-firebase-functions    firebase-functions
supy-cli                   ts-cli
```

Do not descend more than one level, and never scan inside `node_modules`, `build`, or `.git`.

---

## Step 3 — Propose the affected repos (STOP for confirmation)

From the feature description and each repo's stack + role, decide which repos the feature
**actually touches**, and present the proposal with one line of reasoning per repo:

```text
Feature: <one-line restatement>

Proposed affected repos:
  ✓ supy-backend   (nestjs-nx) — owns the domain; needs the endpoint + emits the event
  ✓ supy-frontend  (angular-nx) — admin UI to trigger it
  ✓ supy-retailer  (flutter)    — client reacts to the event
  ✗ supy-cli       (ts-cli)     — no CLI surface for this feature — skipping

Plan will be written to each ✓ repo. Nothing else is touched. Confirm? (yes / edit the set)
```

**Wait for explicit confirmation.** Let the user add or remove repos before proceeding. Never
plan a repo the user has not confirmed.

---

## Step 4 — Write a per-repo plan into each confirmed repo

For **each** confirmed repo, in turn:

1. Set `REPO_PATH` to that repo and load **that repo's** stack standards — the same set its
   own `/supy-plan` would use. The stack → standards mapping:

   | Stack | Standards to load (under `${CLAUDE_PLUGIN_ROOT}/config/standards/`) |
   | --- | --- |
   | nestjs-nx | `nx-nestjs-patterns.md`, `architecture.md`, `nats-event-patterns.md`, `security-cerbos.md`, `commit-conventions.md` |
   | angular-nx | `frontend/`, `commit-conventions.md` |
   | flutter | `flutter/`, `commit-conventions.md` |
   | firebase-functions | `firebase-functions/`, `commit-conventions.md` |
   | ts-cli | `ts-cli/`, `commit-conventions.md` |
   | ai-agents | `ai-agents/`, `commit-conventions.md` |
   | k8s-config | `secrets-and-config.md`, `commit-conventions.md` |

2. Produce a phased plan for **that repo's slice only**, phrased in that stack's idioms (e.g.
   aggregate/interactor phases for nestjs-nx; NGXS feature phases for angular-nx; Clean
   Architecture + Bloc phases for flutter). Each task names the library/module it touches.

   **Every per-repo plan MUST end in a testing phase — no exceptions.** A slice without tests
   is an incomplete plan. Phrase the testing phase in that stack's tooling and name its
   coverage gate (per `${CLAUDE_PLUGIN_ROOT}/config/standards/ci-coverage-baseline.md`):

   | Stack | Testing phase must specify |
   | --- | --- |
   | nestjs-nx / angular-nx | Jest unit + integration tests (`test --ci --coverage`), mocking at the boundary |
   | flutter (app) | `mocktail` + `bloc_test` + `pumpApp` widget tests (+ goldens for UI) — **≥ 80%** |
   | flutter (melos package) | `very_good_coverage` — **≥ 85% per package** |
   | flutter (plugin) | Dart lcov **≥ 70%** + Robolectric/XCTest native tests |
   | firebase-functions / ts-cli / ai-agents | Jest/pytest on the new code (target-state; add the suite if absent) |

   If a repo has no test suite yet (a remediation-first repo), the testing phase says so and
   scaffolds the minimum suite for this feature's code rather than skipping tests.

3. **Record the cross-repo contract.** If the feature crosses repos via an event, an API, or a
   payload, every plan must name the shared contract identically (e.g. the NATS subject
   `user.sessions-revoked`, or the endpoint path). This is what keeps the slices consistent —
   call the contract out in a top **"Cross-repo contract"** section of every plan.

4. Write the plan to that repo:

```bash
mkdir -p "$REPO_PATH/docs/superpowers/plans"
# write the plan to $REPO_PATH/docs/superpowers/plans/<kebab-feature>.md
```

Use the **same** kebab-case feature slug for the filename in every repo, so the feature is easy
to trace across the workspace.

---

## Step 5 — Print the fan-out summary

End with a map of what was written and the exact next command per repo:

```text
Planned "admin force-logout" across 3 repos:

  supy-backend    docs/superpowers/plans/admin-force-logout.md
  supy-frontend   docs/superpowers/plans/admin-force-logout.md
  supy-retailer   docs/superpowers/plans/admin-force-logout.md

Shared contract: NATS subject `user.sessions-revoked` (backend emits; retailer consumes)

Next — implement each repo in its own session:
  cd supy-backend   && /supy-build docs/superpowers/plans/admin-force-logout.md
  cd supy-frontend  && /supy-build docs/superpowers/plans/admin-force-logout.md
  cd supy-retailer  && /supy-build docs/superpowers/plans/admin-force-logout.md

Then in each repo: review my changes → commit this → open a PR
(/supy-review → /supy-commit → /supy-create-pr)
```

---

## Guardrails

- **Plan-only.** Never edit source, branch, commit, or open a PR from this skill. The only
  files it writes are plan `.md` files under each repo's `docs/superpowers/plans/`.
- **Confirm before writing.** No plan is written until the user confirms the affected set
  (Step 3).
- **One level deep.** Discover repos only in immediate children of the workspace root.
- **Reuse detection.** Always detect stacks via `skills/shared/references/stack-detection.md`
  — never hardcode a second copy of the rules.
- **Consistent contract.** When the feature crosses repos, the shared event/API/payload name
  must appear, identically, in every affected repo's plan.
