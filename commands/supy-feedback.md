---
description: Capture feedback about Supy engineering standards and open a PR against supy-wingspan. Maps the feedback to the right standard (standards-first), shows the diff, then opens a gh PR with provenance. Pass the feedback as the argument.
argument-hint: [feedback, e.g. "never use Cubit in Flutter, only Bloc"]
---

You are running `/supy-feedback` in a Supy repository.

Invoke the `supy-feedback` skill via the Skill mechanism, passing `$ARGUMENTS`
as the feedback text.

The skill is located at `${CLAUDE_PLUGIN_ROOT}/skills/supy-feedback/SKILL.md`. It:

1. Captures the feedback text (from `$ARGUMENTS` or the recent conversation) plus
   provenance — the current repo name, detected stack, and the triggering example
   if one is in context.
2. Shallow-clones `abed-supy-io/supy-wingspan` into the scratchpad and reads the
   fresh `config/standards/` to map the feedback to a target file, standards-first.
3. Shows you the target file(s) and exact diff, and waits for your approval.
4. On approval, branches, commits (conventional type validated against
   `commit-conventions.md`), pushes, and opens a `gh` PR whose body carries the
   feedback verbatim plus its provenance; then prints the PR URL.

If `gh` is unavailable or the clone/push fails, the skill degrades: it prints the
proposed diff for manual application instead of crashing.

No superpowers dependency. This command has no fallback beyond what the
`supy-feedback` skill itself provides.
