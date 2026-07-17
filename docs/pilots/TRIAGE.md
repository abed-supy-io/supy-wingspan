# Pilot Triage Protocol

Turns each filled [`RESULTS-TEMPLATE.md`](RESULTS-TEMPLATE.md) into concrete
asset fixes and a ticked row in [`../PILOT.md`](../PILOT.md). Local-only;
cite `path:line`, never secret values.

## Inputs

- One filled results file per pilot under `docs/pilots/results/<repo>.md`.

## Per-finding decision

For every row in a pilot's **Findings triage** table:

- **True positive** → the rule fired correctly. Reinforce it: keep the rule,
  and if it was borderline, add a one-line example to the relevant
  `config/standards/*` file so it is unambiguous next time.
- **False positive** → the reviewer over-fired. Fix the reviewer: tighten the
  red-flag wording in `agents/supy-*-reviewer.md`, or scope the underlying
  rule in `config/standards/*` so it no longer matches the safe case.
- **Missed** → a real issue the reviewers did not flag. Mine a new rule into
  the relevant `config/standards/*` file and add coverage to the matching
  `agents/supy-*-reviewer.md`.

Every asset edit is a local `docs:`/`fix:` commit with the required trailer.
Never push.

## Token-baseline gate

Record each pilot's `/supy-review` token/turn cost in the PILOT.md tracker's
**Token baseline** column. If one stack's review is markedly more expensive
than its peers, note it as a candidate for E2's scoped-read / model-tiering
work — deepening review quality in E2 must not regress these baselines
without justification.

## Completion

Tick a tracker row when: detection matched (Detected ✓), the expected
reviewer set ran (Reviewers ✓), every finding is triaged (Findings triaged),
and its asset fixes are committed. Set the row **Status** to ✅. E1 is done
when all eight rows are ✅.
