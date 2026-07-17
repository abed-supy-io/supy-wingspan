# Review Severity Rubric

Shared grading scale for every `supy-*-reviewer` agent. Each finding carries exactly one
severity — `high`, `med`, or `low` — in the Output Contract form
`**[severity: high|med|low]** <file>:<line> — <problem> → <fix> (rule: <anchor>)`.
Severity grades the **impact of the defect**, not the effort to fix it or how certain the
reviewer feels.

## Rules

1. **high** — merging causes concrete harm: incorrect behavior, data loss or corruption,
   security or secret exposure, broken build/release/deploy, an unguarded external boundary,
   or a violation of a rule the governing standard marks as non-negotiable (MUST / NEVER /
   "non-negotiable"). A high finding blocks the merge until fixed.
2. **med** — the standard is violated in a way that degrades correctness-adjacent qualities:
   maintainability, consistency, testability, or observability, or that plausibly becomes a
   defect under change (missing idempotency on a rarely redelivered path, an untested branch,
   a leaky abstraction). Fix within the same PR unless the author records a justified
   exception.
3. **low** — style, naming, polish, or an improvement the standard recommends but does not
   mandate. May be deferred; never blocks.
4. **Committed secrets are always `high`.** Any secret value in the diff (or reachable
   history) is high regardless of environment, expiry, or "it's only staging" — and the
   finding cites `path:line` only, never the value (`secrets-and-config.md#rules` rule 5/7).
5. **Uncertainty lowers severity, it never raises it.** If the reviewer cannot verify harm
   from the diff plus its context sources, grade one level down and state what evidence would
   confirm the higher grade. Do not inflate to be safe.
6. **One finding, one severity, one rule.** Do not bundle multiple defects into a single
   graded finding; split them so each can be triaged (TP/FP) independently.
7. **Escalate repeats.** The same med-grade violation appearing pervasively across a diff
   (3+ instances of one rule) is reported once as `high` with the instances listed — a
   systematically ignored rule is an architecture problem, not a nit.

## Red flags (reviewer self-check)

- A report where everything is `high` — severity inflation makes triage impossible.
- Grading by effort ("one-line fix → low") instead of impact.
- A `low` used to smuggle in a personal style preference no standard backs.
- A secret finding graded below `high`, or one that echoes the secret value.
