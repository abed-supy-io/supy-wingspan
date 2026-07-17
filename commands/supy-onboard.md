---
description: Onboard or refresh a repo's Supy AI setup — thin wrapper over the supy-baseline skill, plus a CLAUDE.md drift check against the stack's template. Reports section-level drift before offering regeneration.
argument-hint: [optional focus, e.g. "drift only" to skip regeneration]
---

You are running `/supy-onboard` in a Supy repository.

Invoke the `supy-baseline` skill via the Skill mechanism, passing `$ARGUMENTS` through unchanged.

The skill is located at `${CLAUDE_PLUGIN_ROOT}/skills/supy-baseline/SKILL.md`. It:

1. Resolves the repo root via `git rev-parse --show-toplevel` and detects the stack in the same
   order as `${CLAUDE_PLUGIN_ROOT}/hooks/detect-stack.sh`.
2. Selects the stack's Handlebars template (`${CLAUDE_PLUGIN_ROOT}/templates/<stack>/CLAUDE.md.hbs`,
   falling back to `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.hbs`), fills its placeholders from
   Cortex MCP when connected or static inspection otherwise, and appends the stack-scoped
   skill-routing footer.
3. Diffs the generated content against any existing `CLAUDE.md` and asks before overwriting —
   never clobbers silently.
4. Emits the AI-setup checklist (Cortex MCP, `.claude/settings.json`, `CODEOWNERS`, `.claude/`
   directory, `CLAUDE.md`) with fix hints for anything missing.

## Drift check (this command's addition)

Between the skill's Step 2 (template selected) and Step 3 (overwrite gate), summarize
**section-level drift** so the user sees structural divergence before reading the raw diff. If the
repo has no `CLAUDE.md` yet, skip this section — there is nothing to drift from.

Compare the `##` headings of the existing file against the selected template's headings
(placeholders in template headings match anything):

```bash
grep '^## ' "$REPO_ROOT/CLAUDE.md" | sed 's/^## //' | sort > /tmp/supy-onboard-repo-sections
grep '^## ' "$TEMPLATE" | sed 's/^## //; s/{{[a-z_]*}}/*/g' | sort > /tmp/supy-onboard-tpl-sections
```

Report three buckets:

- **Missing sections** — template headings with no counterpart in the repo's `CLAUDE.md`. These
  are the drift that matters: the repo's guidance has fallen behind the canonical layout.
- **Extra sections** — repo headings not in the template. These are usually deliberate,
  repo-specific additions; list them but do not flag them as problems, and note that
  regeneration would drop them unless carried over manually.
- **In sync** — if both lists are empty, print `supy-onboard: CLAUDE.md structure matches the
  <STACK> template — no drift.` and, unless the checklist found gaps, stop before the overwrite
  gate; there is nothing to regenerate.

If `$ARGUMENTS` contains `drift only`, stop after this report — print the drift buckets and the
Step 4 checklist, and do not enter the skill's overwrite gate at all.

When drift exists and regeneration proceeds, remind the user before they answer the skill's
overwrite prompt that **Extra sections** listed above will be lost by a plain overwrite and
should be re-added to the regenerated file if still wanted.

If the working directory is not a git repository, the skill stops early
(`supy-baseline: not inside a git repository — nothing to do`); this command adds nothing on top.

No superpowers dependency. This command has no fallback beyond what the `supy-baseline` skill
itself provides.
