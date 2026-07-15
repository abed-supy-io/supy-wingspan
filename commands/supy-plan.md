---
description: Write an implementation plan for a Supy feature or task — wraps superpowers:writing-plans, falls back to a phased task list saved under docs/superpowers/plans/ when superpowers is absent.
argument-hint: <feature or task description>
---

You are running `/supy-plan` in a Supy backend repository.

## Context to apply

Load the Supy standards from `${CLAUDE_PLUGIN_ROOT}/config/standards/` before planning:

- **Stack conventions** — `${CLAUDE_PLUGIN_ROOT}/config/standards/nx-nestjs-patterns.md` and `architecture.md`
- **Event patterns** — `${CLAUDE_PLUGIN_ROOT}/config/standards/nats-event-patterns.md`
- **Commit rules** — `${CLAUDE_PLUGIN_ROOT}/config/standards/commit-conventions.md`
- **Security model** — `${CLAUDE_PLUGIN_ROOT}/config/standards/security-cerbos.md`

If the Cortex MCP server is connected, call `get_repo_guide` and `search_entities` to understand the existing aggregates, events, and module boundaries before producing the plan. Cortex is optional — never fail if absent.

## Planning request

`$ARGUMENTS`

## If `superpowers` plugin is available

Invoke the `superpowers:writing-plans` skill via the Skill mechanism, passing the planning request above. After that skill completes, augment the output with a **"Supy Standards Alignment"** section that:

- Maps each planned task to the affected Nx libraries and bounded contexts.
- Identifies any new NATS events or message patterns the plan introduces and confirms they follow `nats-event-patterns.md`.
- Lists the expected conventional commit types for each phase, per `commit-conventions.md`.
- Notes any Cerbos policy changes required for the proposed feature.

## If `superpowers` plugin is NOT available (fallback)

Produce a phased task list directly. Structure the plan as follows:

```markdown
# Plan: <title derived from $ARGUMENTS>

## Phase 1 — <phase name>
- [ ] Task description (owner hint, relevant Nx lib)

## Phase 2 — <phase name>
- [ ] ...
```

Include at minimum: a domain/model phase, an application/interactor phase, an infrastructure/adapter phase, and a testing phase. Each task must name the Nx library it touches.

Save the plan to `docs/superpowers/plans/<kebab-case-title>.md` in the repository root, creating the directory if it does not exist:

```bash
mkdir -p docs/superpowers/plans
```

Print the path of the saved file after writing it.
