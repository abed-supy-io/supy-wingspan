# Contributing to supy-wingspan

This repo is a Claude Code plugin: agents, skills, slash commands, hooks, standards, and
templates. It ships **no runtime code** — everything is Markdown, JSON, and shell. Contributions
are held to the same bar the plugin enforces on Supy repos.

## Ground rules

- **Conventional Commits.** Every commit follows `config/standards/commit-conventions.md`.
  Releases and the changelog are generated from commit history by release-please, so the type
  and scope matter. Allowed types: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`,
  `refactor`, `revert`, `style`, `test`. The `supy-commit` skill will write a compliant message.
- **No secrets, ever.** This is enforced org-wide and by the `supy-secrets-reviewer`. Never paste
  a token, key, or connection string into an issue, PR, commit, or file.
- **Standards are the source of truth.** The review agents cite `config/standards/`. If you change
  a rule, change the standard first, then the agent/skill that references it.

## Local checks

Run these before opening a PR — CI runs the same two on every PR:

```bash
npx markdownlint-cli2 --config config/custom.markdownlint.jsonc "**/*.md" "!CHANGELOG.md"
npx cspell --config config/cspell.json "**/*.md"
```

Add project-specific words to `config/cspell.json` rather than disabling the check.

## Authoring components

| Component | Location | Notes |
|---|---|---|
| Skill | `skills/<name>/SKILL.md` | Frontmatter needs `name` + `description`. Put long or optional content under `references/` and link to it — keep `SKILL.md` lean. Shared content lives in `skills/shared/references/`. |
| Slash command | `commands/<name>.md` | Thin orchestration; prefer wrapping a skill or `superpowers`. |
| Review agent | `agents/<name>.md` | Must define an Output Contract matching the shape `supy-review` consolidates. |
| Standard | `config/standards/**` | Prose rules the agents cite. |
| Template | `templates/<stack>/**` | Drop-in enforcement config + scaffolding. |
| Hook | `hooks/` | Must degrade silently — never fail a session. |

## Testing a change

Skills, commands, and hooks are only "done" when exercised in a real Claude Code session:

1. Add this checkout as a local marketplace: `/plugin marketplace add ~/Projects/supy-projects/supy-wingspan`
2. Install: `/plugin install supy-wingspan@supy`, then `/reload-plugins`
3. Run the changed component against a repo of the relevant stack and confirm the behaviour.

State the repo/stack you tested against in the PR's test-evidence section.
