# supy-wingspan

Supy's internal Claude Code plugin. Makes every `supy-*` repo follow Supy engineering
best practices through AI: backend-first review agents, scaffolding & Git skills, a
consistency-baseline generator, and thin orchestration wrappers over `superpowers`.

## Status
Local-only, v0.1.0. Not yet published to a Git host.

## Enable locally
From any supy repo (or user settings), add this directory as a local marketplace:
```
/plugin marketplace add ~/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
```
(Exact enablement mechanism is confirmed in Task 10.)

## Components
- `agents/` — review subagents (architecture, NATS events, tests, commit/PR, security)
- `skills/` — supy-review, supy-baseline, supy-commit, supy-create-pr, supy-scaffold-handler
- `commands/` — orchestration wrappers over superpowers
- `hooks/` — stack detection
- `config/standards/` — mined Supy standards (source of truth for the agents)
- `templates/` — canonical CLAUDE.md template
