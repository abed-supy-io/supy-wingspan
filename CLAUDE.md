# CLAUDE.md

Guidance for Claude Code when working **in this repository** (developing the plugin itself).
This is not the guidance the plugin gives to other repos — that lives in `agents/`, `skills/`,
and `config/standards/`.

## What this repo is

A Claude Code plugin that packages Supy's engineering standards as review agents, skills, slash
commands, a stack-detection hook, and stack templates. It ships **no runtime code** — only
Markdown, JSON, and shell. Every change is either documentation, configuration, or a small shell
snippet.

## Layout

| Path | Purpose |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest (name, version, component paths). |
| `.claude-plugin/marketplace.json` | Self-contained marketplace definition. |
| `agents/` | Review agents, each with an Output Contract. |
| `skills/` | Skills as `SKILL.md` + optional `references/`, `scripts/`. Shared content in `skills/shared/`. |
| `commands/` | Slash commands — thin orchestration over skills. |
| `hooks/` | Session hooks. `detect-stack.sh` runs on SessionStart. |
| `config/standards/` | The mined standards the agents cite — the source of truth. |
| `config/` | Lint configs: `custom.markdownlint.jsonc`, `cspell.json`. |
| `templates/<stack>/` | Drop-in enforcement config per stack. |
| `docs/` | `USAGE.md` and analysis notes. |

## Working rules

- **Path convention:** skills and hooks reference their own files via `${CLAUDE_PLUGIN_ROOT}`. Never
  hardcode an absolute path.
- **Skills stay lean:** `SKILL.md` holds the decision procedure; push long or optional material into
  `references/` and link to it. Reuse `skills/shared/references/` instead of duplicating.
- **Standards first:** if a rule changes, edit `config/standards/` before the agent or skill that cites it.
- **Hooks must not fail a session:** `detect-stack.sh` and any future hook degrade silently on error.
- **Conventional Commits** (`config/standards/commit-conventions.md`) — releases and the changelog are
  generated from history by release-please. Use the `supy-commit` skill.

## Before committing

Run the same checks CI runs:

```bash
npx markdownlint-cli2 --config config/custom.markdownlint.jsonc "**/*.md" "!CHANGELOG.md"
npx cspell --config config/cspell.json "**/*.md"
```

Add new project words to `config/cspell.json` rather than suppressing the check.

## After changing a skill, command, or hook

It is not done until run in a real session: install this checkout as a local marketplace
(`/plugin marketplace add <path>` → `/plugin install supy-wingspan@supy` → `/reload-plugins`) and
exercise the component against a repo of the relevant stack.
