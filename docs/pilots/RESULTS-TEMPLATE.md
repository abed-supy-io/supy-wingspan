# Pilot Result — <pilot repo>

Copy this file to `docs/pilots/results/<repo>.md` and fill it in during the
run. **Never paste a secret value** — cite `path:line` only.

## Run metadata

- Pilot repo: `<repo>`
- Stack (+ profile): `<stack>`
- Date: `<YYYY-MM-DD>`
- Operator: `<name>`
- Plugin commit: `<supy-wingspan short SHA at time of run>`

## Install

- Install succeeded (Y/N): ``
- Errors (if any): ``

## Detection

- SessionStart line observed (verbatim): ``
- Matches expected (Y/N): ``

## Review dispatch

- Reviewers that ran: ``
- Matches expected set (Y/N): ``
- Review report header: ``

## Findings triage

Verdict is one of: TP (true positive), FP (false positive), MISSED (a real
issue the reviewers did not flag).

| # | Severity | file:line | Reviewer | Verdict | Note (no secret values) |
|---|---|---|---|---|---|
|   |          |           |          |         |                         |

## Token baseline

- Approx tokens (in / out) for the `/supy-review` turn: ``
- Turns: ``
- Notes (was this unexpectedly expensive vs. other stacks?): ``

## Commit

- supy-commit message (redact any secret): ``
- Trailer present (Y/N): ``
- Pushed (must be N): ``

## Asset-fix actions

Action is one of: reinforce rule · tighten reviewer red-flag · scope rule ·
mine new rule · none.

| Finding | Action | Target file | Status |
|---|---|---|---|
|         |        |             |        |

## Sign-off

- Pilot passed (Y/N): ``
- Notes: ``
