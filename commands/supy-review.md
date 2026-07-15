---
description: Review the current Supy diff against Supy standards — thin wrapper over the supy-review skill. Dispatches the reviewers that match the repo's stack. Pass an optional base ref to override the default merge-base detection.
argument-hint: [base-ref, e.g. origin/main or a commit SHA]
---

You are running `/supy-review` in a Supy repository.

Invoke the `supy-review` skill via the Skill mechanism, passing `$ARGUMENTS` as the base ref argument.

The skill is located at `${CLAUDE_PLUGIN_ROOT}/skills/supy-review/SKILL.md`. It:

1. Resolves the diff range using `$ARGUMENTS` as the base ref (or falls back to `git merge-base HEAD origin/main` if no argument is given).
2. Detects the repo's stack and dispatches the matching reviewer agents concurrently:
   - **nestjs-nx** (backend) → five reviewers: architecture, NATS events, test quality, commit/PR hygiene, and security.
   - **angular-nx** (frontend) → two reviewers: Angular/NGXS conventions and commit/PR hygiene.
   - **flutter** (mobile) → two reviewers: Flutter/Clean-Architecture conventions and commit/PR hygiene.
   - **other** → the stack-agnostic commit/PR reviewer only.
3. Consolidates findings into a severity-grouped report (high / medium / low).

If the working directory is not a git repository or the diff is empty, the skill stops early and reports that there is nothing to review.

No superpowers dependency. This command has no fallback beyond what the `supy-review` skill itself provides.
