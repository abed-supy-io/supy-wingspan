---
description: Brainstorm a feature or problem with Supy context injected — wraps superpowers:brainstorming, falls back to lightweight guided clarification when superpowers is absent.
argument-hint: <topic or question to brainstorm>
---

You are running `/supy-brainstorm` in a Supy backend repository.

## Context to apply

Load and apply the Supy standards from `${CLAUDE_PLUGIN_ROOT}/config/standards/` before brainstorming:

- **Stack conventions** — `${CLAUDE_PLUGIN_ROOT}/config/standards/nx-nestjs-patterns.md` and `architecture.md`
- **Event patterns** — `${CLAUDE_PLUGIN_ROOT}/config/standards/nats-event-patterns.md`
- **Commit rules** — `${CLAUDE_PLUGIN_ROOT}/config/standards/commit-conventions.md`
- **Security model** — `${CLAUDE_PLUGIN_ROOT}/config/standards/security-cerbos.md`

If the Cortex MCP server is connected, query `get_repo_guide` and `list_entities` to understand the current bounded context, aggregates, and event contracts before exploring new ideas. Cortex is optional — if absent, proceed with static inspection.

## Brainstorm topic

`$ARGUMENTS`

## If `superpowers` plugin is available

Invoke the `superpowers:brainstorming` skill via the Skill mechanism, passing the topic above. After that skill completes, apply the Supy-specific lens:

- Validate proposed approaches against Supy stack conventions (`nx-nestjs-patterns.md`, `architecture.md`).
- Flag any proposed event or NATS patterns that deviate from `nats-event-patterns.md`.
- Identify commit or PR scope implications using `commit-conventions.md`.
- Note Cerbos authorization impact if the proposal touches permissions (`security-cerbos.md`).

Present the Supy-specific findings as a section titled **"Supy Fit Assessment"** appended after the superpowers output.

## If `superpowers` plugin is NOT available (fallback)

Run a lightweight structured brainstorm directly, one question at a time:

1. **Purpose** — Ask: "What problem does this solve, and who is the primary beneficiary?" Wait for the answer before continuing.
2. **Constraints** — Ask: "What technical, time, or scope constraints apply?" Wait for the answer.
3. **Success criteria** — Ask: "How will we know this is done and working correctly?" Wait for the answer.

After all three answers are collected, synthesize a short summary (three to five bullets) that maps the idea onto Supy's bounded contexts and stack. Highlight any mismatch with the loaded standards as a **"Risks & Gaps"** list.

Do not skip steps or collapse multiple questions into one message during the fallback path.
