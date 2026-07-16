---
description: Execute an implementation plan task-by-task with Supy standards enforced — wraps superpowers:executing-plans and superpowers:subagent-driven-development, falls back to sequential task execution with commits when superpowers is absent.
argument-hint: <path to plan file, e.g. docs/superpowers/plans/my-feature.md>
---

You are running `/supy-build` in a Supy backend repository.

## Context to apply

Load the Supy standards from `${CLAUDE_PLUGIN_ROOT}/config/standards/` before executing:

- **Stack conventions** — `${CLAUDE_PLUGIN_ROOT}/config/standards/nx-nestjs-patterns.md` and `architecture.md`
- **Event patterns** — `${CLAUDE_PLUGIN_ROOT}/config/standards/nats-event-patterns.md`
- **Commit rules** — `${CLAUDE_PLUGIN_ROOT}/config/standards/commit-conventions.md`
- **Security model** — `${CLAUDE_PLUGIN_ROOT}/config/standards/security-cerbos.md`

If the Cortex MCP server is connected, query relevant entities and handler contracts before editing each Nx library. Cortex is optional — never fail if absent.

## Plan to execute

`$ARGUMENTS`

If `$ARGUMENTS` is empty or does not resolve to a readable file, stop immediately and print:

```text
supy-build: no plan file provided — pass a path, e.g. /supy-build docs/superpowers/plans/my-feature.md
```

## If `superpowers` plugin is available

Invoke the `superpowers:executing-plans` skill via the Skill mechanism, passing the plan path above. If the plan contains independent tasks across multiple Nx libraries, also invoke `superpowers:subagent-driven-development` to execute them concurrently. After the superpowers skill(s) complete, enforce the Supy standards layer:

- Each commit produced must follow `commit-conventions.md` (type, scope, body). Reject or amend any commit that does not comply.
- New or modified event schemas must conform to `nats-event-patterns.md` — verify before committing.
- Modules and files must follow `nx-nestjs-patterns.md` structural rules (domain / application / infrastructure layering).
- Cerbos policy files must be updated if the implementation introduces new resources or actions (`security-cerbos.md`).

## If `superpowers` plugin is NOT available (fallback)

Execute the plan manually, task by task, in phase order:

1. Read the plan file at the path given in `$ARGUMENTS`.
2. For each unchecked task (`- [ ]`), implement it against the Supy standards above.
3. After completing each task, run the affected Nx lint and test targets:

   ```bash
   npx nx affected --target=lint --base=HEAD~1
   npx nx affected --target=test --base=HEAD~1
   ```

4. Commit using a conventional commit message matching `commit-conventions.md`. Stage only the files for the current task. Commit locally — do NOT push.
5. Mark the task as done in the plan file (`- [x]`) and commit the plan update together with the implementation, or as a separate follow-up commit if the implementation commit is already clean.

Repeat until all tasks are checked. Print a summary of tasks completed, commits made, and any tasks skipped with reasons.

Do NOT push to the remote under the fallback path. Local commits only.
