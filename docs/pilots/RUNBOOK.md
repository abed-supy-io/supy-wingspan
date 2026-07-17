# supy-wingspan Per-Stack Pilot Runbook

This runbook is the **human-run** procedure that proves supy-wingspan works
end-to-end on one real repo per stack. It generalizes the original
`nestjs-nx` checklist in [`../PILOT.md`](../PILOT.md) to all pilots. Record
each run in a copy of [`RESULTS-TEMPLATE.md`](RESULTS-TEMPLATE.md), then
triage per [`TRIAGE.md`](TRIAGE.md) and tick the tracker in
[`../PILOT.md`](../PILOT.md).

## Ground rules

- **Local-only.** Do a scratch branch and delete it after. **Never push.**
- **Secrets.** If a finding references a secret, cite `path:line` — never
  copy the value into the results file.
- **Representative change.** Make one small, real edit so the branch diff is
  non-empty (`/supy-review` reviews the whole branch diff vs. the merge-base
  with `origin/main`/`main`, not just the last commit).
- **Token capture.** After `/supy-review`, note the approximate tokens and
  turn count for that review (from the session UI) — this is the stack's
  "green" baseline recorded in the tracker.

## Shared steps (every pilot)

1. Open a Claude Code session inside the pilot repo.
2. Enable the plugin:

   ```text
   /plugin marketplace add ~/Projects/supy-projects/supy-wingspan
   /plugin install supy-wingspan@supy
   ```

3. Scroll to session start; confirm the expected SessionStart line (below).
4. Create a scratch branch and make the representative change:

   ```bash
   git checkout -b pilot/supy-wingspan-test
   # make the small edit named in the pilot section, then:
   git add <file>
   ```

5. Run `/supy-review` with no arguments; confirm the expected reviewer set
   dispatches and a consolidated report is emitted.
6. Invoke the `supy-commit` skill; confirm a Conventional-Commits message
   ending with the required trailer, and that nothing is pushed.
7. Capture tokens/turns for the `/supy-review` run.
8. Clean up:

   ```bash
   git checkout main && git branch -D pilot/supy-wingspan-test
   ```

## Pilot 1 — nestjs-nx: supy-service-inventory

- **Expected SessionStart line:** `supy-wingspan: detected nestjs-nx repo.`
- **Expected reviewers (6):** `supy-architecture-reviewer`,
  `supy-nats-event-reviewer`, `supy-test-quality-reviewer`,
  `supy-commit-pr-reviewer`, `supy-security-reviewer`, `supy-secrets-reviewer`
- **Representative change:** add a method stub to an existing interactor, or
  a field to a NATS handler DTO
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.

## Pilot 2 — angular-nx: supy-frontend

- **Expected SessionStart line:** `supy-wingspan: detected angular-nx repo.`
- **Expected reviewers (3):** `supy-angular-reviewer`,
  `supy-commit-pr-reviewer`, `supy-secrets-reviewer`
- **Representative change:** add a `signal` input to a dumb component, or a
  new NGXS action
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.

## Pilot 3 — flutter (Profile B): supy-mobile

- **Expected SessionStart line:** `supy-wingspan: detected flutter repo.`
- **Expected reviewers (3):** `supy-flutter-reviewer`,
  `supy-commit-pr-reviewer`, `supy-secrets-reviewer`
- **Representative change:** add a field to a freezed state or a new BLoC
  event (Profile B: `PageState`/`throwAppException`)
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.

## Pilot 4 — flutter (Profile A): checklist

- **Expected SessionStart line:** `supy-wingspan: detected flutter repo.`
- **Expected reviewers (3):** `supy-flutter-reviewer`,
  `supy-commit-pr-reviewer`, `supy-secrets-reviewer`
- **Representative change:** add a `UseCase` param or a new `Failure`
  subtype (Profile A: `dartz`/`Either`)
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.

## Pilot 5 — firebase-functions: supy-firebase-functions

- **Expected SessionStart line:**
  `supy-wingspan: detected firebase-functions repo (standalone, non-Nx)`
- **Expected reviewers (3):** `supy-firebase-functions-reviewer`,
  `supy-commit-pr-reviewer`, `supy-secrets-reviewer`
- **Representative change:** add a field to a callable's request DTO, or a
  new Firestore trigger stub
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.

## Pilot 6 — ts-cli: supy-cli

- **Expected SessionStart line:**
  `supy-wingspan: detected ts-cli repo (standalone commander.js MongoDB scripts runner)`
- **Expected reviewers (3):** `supy-ts-cli-reviewer`,
  `supy-commit-pr-reviewer`, `supy-secrets-reviewer`
- **Representative change:** add an option to an existing `IScript`, or a
  new script stub
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.

## Pilot 7 — ai-agents: supy-ai-agents

- **Expected SessionStart line:**
  `supy-wingspan: detected ai-agents repo (polyglot MCP/agents monorepo, no root orchestration)`
- **Expected reviewers (3):** `supy-ai-agents-reviewer`,
  `supy-commit-pr-reviewer`, `supy-secrets-reviewer`
- **Representative change:** add a field to an MCP tool input schema, or a
  BullMQ job payload field
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.

## Pilot 8 — k8s-config: supy-configmaps

- **Expected SessionStart line:**
  `supy-wingspan: detected k8s-config repo. Secrets MUST live in a Secret/external-secret`
- **Expected reviewers (2):** `supy-secrets-reviewer`,
  `supy-commit-pr-reviewer`
- **Representative change:** add or edit a **non-secret** ConfigMap key
  (NEVER a real secret value)
- **Report check:** the consolidated report header reads
  `# Supy Review — N issues (H high, M med, L low)` with `## High` /
  `## Medium` / `## Low` / `## Clean` sections.
