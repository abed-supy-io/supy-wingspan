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

## Fixture scorecard triage

The [fixture scorecard](../PILOT.md#fixture-scorecard) in `PILOT.md` scores each reviewer's
recall/precision against its golden fixtures (`evals/run-review-eval.sh`) and, once run, the three
[flagship live-proof runs](../PILOT.md#live-proof-runs-flagship). Once those runs have populated the
scorecard, triage every fixture outcome the same way a pilot finding is triaged above — but the fix
target is the fixture-owning reviewer/standard, not a one-off pilot repo:

- **False positive** (the reviewer fired on a fixture's safe case) → **tighten the reviewer.**
  Narrow the red-flag wording in the matching `agents/supy-*-reviewer.md`, or scope the underlying
  rule in `config/standards/*` so it no longer matches the safe case. Do not touch the fixture —
  it is the regression test proving the false positive is gone.
- **Missed** (a fixture's planted issue was not flagged) → **standards-first.** Mine the rule into
  the relevant `config/standards/*` file *before* touching the reviewer — the standard is the
  source of truth the agent cites, per this repo's `CLAUDE.md`. Only after the standard states the
  rule, add matching coverage to the reviewer's `agents/supy-*-reviewer.md`.
- **Confirmed true positive** → leave as-is. The fixture already regression-locks it; no asset
  change needed.

**Regression rule:** no reviewer or standards change made in this loop may flip any other fixture
from passing to failing. Re-run `bash evals/run-review-eval.sh <dimension>` for every dimension
touched (not just the one being fixed) before committing the fix, and confirm every previously-green
fixture in that dimension is still green.

The resulting list of asset fixes (one row per FP tightened or rule mined) is **R2's input** — R2
consumes it as the starting backlog for deepening reviewer coverage. Do not fabricate entries in
this list; it is populated only from real scorecard/live-run outcomes, never estimated.

## Completion

Tick a tracker row when: detection matched (Detected ✓), the expected
reviewer set ran (Reviewers ✓), every finding is triaged (Findings triaged),
and its asset fixes are committed. Set the row **Status** to ✅. E1 is done
when all eight rows are ✅.
