# vgv-wingspan comparison & adopted improvements

A structured look at [Very Good Ventures' `vgv-wingspan`](https://github.com/VeryGoodOpenSource)
plugin against `supy-wingspan`, and a record of which of its practices we adopted, which we
adapted, and which we deliberately skipped.

`vgv-wingspan` is a mature, public, single-stack (Flutter/Dart) Claude Code plugin.
`supy-wingspan` is a younger, private-then-public, **multi-stack** plugin (seven Supy stacks +
two stack-agnostic reviewers). The differences below follow from that: much of what VGV does for
one stack we have to generalise across seven.

## What vgv-wingspan does that we learned from

| Practice | vgv-wingspan | supy-wingspan (before) | Status |
|---|---|---|---|
| **Self-CI** — the plugin lints/checks itself | GitHub Actions on push + PR | none | ✅ Adopted |
| **Governance files** — CONTRIBUTING / SECURITY / CODE_OF_CONDUCT | present | none | ✅ Adopted |
| **Release automation** | release-please | manual version bump | ✅ Adopted |
| **Shared references** — content read by more than one component | factored out | stack detection duplicated (hook + `supy-review`) | ✅ Adopted |
| **Git-workflow skills** — hotfix / debrief / rebase | present | none | ✅ Adopted |
| **In-repo `CLAUDE.md`** guiding work on the plugin itself | present | none | ✅ Adopted |
| Single-stack simplicity | one stack | seven stacks | ➖ N/A (our scope is wider by design) |

## What we adopted, and how it landed here

### 1. Self-CI (`.github/workflows/ci.yaml`)

Three jobs on push-to-`main` and every PR: **markdownlint** (`config/custom.markdownlint.jsonc`),
**cspell** (`config/cspell.json`), and a **skills validator** (`scripts/validate-skills.sh`, which
asserts every `skills/*/SKILL.md` has valid frontmatter and that the directory name matches the
frontmatter `name:`). `permissions: contents: read`, concurrency cancels superseded runs.

The markdownlint config was tuned to house style rather than stock defaults — `MD041` (no forced
H1), `MD029` (mixed ordered-list numbering), and `MD024: siblings_only` are relaxed because they
fight the way these docs are written; genuine readability rules stay on. This let CI land green on
the existing tree instead of flagging hundreds of pre-existing, stylistic-only violations.

### 2. Governance files

- `CONTRIBUTING.md` — ground rules (Conventional Commits, no secrets, standards-first), the local
  checks CI mirrors, an authoring-components table, and how to test a change in a real session.
- `SECURITY.md` — scope (shell in hooks/skills, the secret-hygiene guarantee), private reporting,
  and the rotate-then-scrub procedure for a leaked credential.
- `CODE_OF_CONDUCT.md` — a short professional-and-direct standard with enforcement contact.
- `CLAUDE.md` (root) — guidance for Claude when working **in** this repo (distinct from the
  guidance the plugin emits to other repos).

### 3. release-please automation

`release-please-config.json` + `.release-please-manifest.json` + a `release-please.yaml` workflow.
Release type `simple`; an `extra-files` JSON updater keeps `.claude-plugin/plugin.json` `$.version`
in lockstep with the tagged release, so the manifest version is never hand-edited.

### 4. Shared references refactor

Stack detection was duplicated between `hooks/detect-stack.sh` and `supy-review`'s Step 2. It now
lives once in `skills/shared/references/stack-detection.md` (detection order + the stack→reviewer
matrix). `supy-review` reads it at runtime — mirroring the repo's existing pattern of skills reading
their governing file (`supy-commit` reads `commit-conventions.md`) — and falls back to the two
stack-agnostic reviewers if the reference is unreadable. `skills/shared/` is documented as
**not a skill** and is skipped by the validator.

### 5. Git-workflow skills

- `supy-rebase` — safe rebase onto a resolved base: clean-tree gate, `PRE_REBASE_SHA` safety ref,
  conflict resolution one commit at a time (never `--skip`), `--force-with-lease` only on confirm.
  Ships `scripts/detect-base-branch.sh` (override → `origin/HEAD` → `git remote show` →
  main/master/develop → fallback), reused by `supy-debrief`.
- `supy-hotfix` — disciplined production hotfix: minimal diff, cut `hotfix/<slug>` from the remote
  base, commit as **`fix`** (not `hotfix` — that type is rejected by commitlint), review, fast-track
  PR, then back-merge and release follow-ups.
- `supy-debrief` — structured branch handoff/retrospective from the actual commits and diff, honest
  about verification, never auto-commits, optionally saved to `docs/debriefs/`.

## What we deliberately did not copy

- **Dart/Flutter-specific tooling** (e.g. `very_good` analysis in CI) — we are multi-stack; per-stack
  enforcement belongs in `templates/<stack>/`, not in the plugin's own CI.
- **A heavyweight single-stack assumption** — our review dispatch is stack-detected precisely so one
  plugin serves seven stacks; we did not narrow that to match VGV's single-stack shape.

## Shipped after the analysis

- **`.mcp.json` for the Cortex MCP endpoint.** VGV ships MCP wiring; we use Cortex as an optional
  live source for review agents and `supy-baseline`. Now committed at the repo root, wiring the
  `cortex-kg` HTTP server at `https://cortex.ai.supy.io/mcp/sse`. Only the endpoint URL is
  committed — no token or credential lives in the file.
