# skills/shared

Cross-skill content that more than one skill needs, kept in one place so it stays consistent.
This directory is **not a skill** — it has no `SKILL.md` and is skipped by
`scripts/validate-skills.sh`.

## Layout

- `references/` — canonical prose or logic a skill reads at runtime (the same way `supy-commit`
  reads `config/standards/commit-conventions.md`). A skill points at a reference with
  `${CLAUDE_PLUGIN_ROOT}/skills/shared/references/<file>` and reads it before acting, rather than
  duplicating the content in its own `SKILL.md`.

## When to add here

Add a shared reference when the same non-trivial logic or explanation would otherwise be copied
into two or more skills — for example stack detection, the diff-range resolution procedure, or a
severity taxonomy. Keep genuinely skill-specific instructions in that skill's own `SKILL.md`.
