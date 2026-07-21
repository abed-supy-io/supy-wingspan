---
description: Plan one cross-repo feature across several open Supy repos from a single prompt — scans a parent folder, detects each repo's stack, proposes the affected repos (you confirm), then writes a per-repo plan into each. Plan-only; never edits code or opens PRs.
argument-hint: <feature description> [in <folder>]
---

You are running `/supy-feature` — a cross-repo feature planner for a Supy workspace where
several `supy-*` repos are checked out side by side under one parent folder.

## Request

`$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and ask the user for the feature description (and, optionally,
the workspace folder to scan).

## What to do

Invoke the `supy-feature-fanout` skill via the Skill mechanism, passing the feature
description through unchanged. The skill is at
`${CLAUDE_PLUGIN_ROOT}/skills/supy-feature-fanout/SKILL.md`. It:

1. Resolves the **workspace root** — a folder the user names, else the parent of the current repo.
2. Discovers the git repos one level under it and detects each one's stack using the canonical
   `${CLAUDE_PLUGIN_ROOT}/skills/shared/references/stack-detection.md`.
3. **Proposes which repos the feature touches, with reasoning, and waits for your confirmation.**
4. Writes a per-repo implementation plan (grounded in each repo's stack standards) into each
   confirmed repo under `docs/superpowers/plans/<feature>.md`, naming the shared cross-repo
   contract identically in every plan.
5. Prints a fan-out summary with the exact `/supy-build` command to run in each repo.

## Boundary

This command is **plan-only**. It never edits source, branches, commits, or opens PRs. After
the plans are written, implement each repo in its own session with `/supy-build`, then
`/supy-review` → `/supy-commit` → `/supy-create-pr`.
