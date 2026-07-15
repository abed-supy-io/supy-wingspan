# supy-wingspan Pilot Notes

supy-wingspan is Supy's internal Claude Code plugin. It enforces engineering best practices across every `supy-*` backend repository through AI: five parallel review subagents, a consistency-baseline generator, scaffolding and Git skills, and thin orchestration wrappers over `superpowers`. This document records the P5 (Task 10) pilot: what was structurally validated, the exact procedure to enable the plugin in a live session, the exercise checklist for confirming the core loop, degradation behaviour, and known gaps.

## Validation results

The `plugin-dev:plugin-validator` was run against the full plugin tree on 2026-07-15.

Verdict: **VALID_WITH_WARNINGS** — zero critical errors.

| Component | Result |
|---|---|
| Agents | 5 / 5 valid (`supy-architecture-reviewer`, `supy-nats-event-reviewer`, `supy-test-quality-reviewer`, `supy-commit-pr-reviewer`, `supy-security-reviewer`) |
| Skills | 5 / 5 valid (`supy-review`, `supy-baseline`, `supy-commit`, `supy-create-pr`, `supy-scaffold-handler`) |
| Commands | 4 / 4 valid — none carry a forbidden `name:` key (`supy-brainstorm`, `supy-plan`, `supy-review-and-commit`, `supy-daily`) |
| `hooks/hooks.json` | Valid |
| `hooks/detect-stack.sh` | Present and executable (`-rwxr-xr-x`) |
| Hardcoded absolute paths | None — `${CLAUDE_PLUGIN_ROOT}` used throughout |

Non-blocking warnings are recorded under [Verify at install / known gaps](#verify-at-install--known-gaps) below.

## Local enablement

The following two commands enable the plugin from inside a Claude Code session opened in the target repository (e.g., `supy-service-inventory`). They are structurally validated — the marketplace `name` is `supy`, the plugin `name` is `supy-wingspan`, and `source` resolves to the repo root — but await live confirmation in an actual session.

```
/plugin marketplace add /Users/abdalqaderalnajjar/Projects/supy-projects/supy-wingspan
/plugin install supy-wingspan@supy
```

Where:
- The path argument to `marketplace add` is the absolute path to the supy-wingspan repo root (or `~/Projects/supy-projects/supy-wingspan` if the shell expands `~`).
- `supy-wingspan@supy` is `<plugin-name>@<marketplace-name>` as defined in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

If the pilot repo tracks its own `.claude/settings.json`, add the marketplace entry there before running the above, so the registration persists across sessions.

After install, the following should be available:
- Commands: `/supy-review`, `/supy-commit`, `/supy-baseline`, `/supy-brainstorm`, `/supy-plan`, `/supy-review-and-commit`, `/supy-daily`
- Agents: the five review subagents (dispatched internally by `/supy-review`)
- SessionStart hook: `detect-stack.sh` runs at session open and prints `supy-wingspan: detected <stack> repo.`

## Pilot exercise checklist

Run the following in `supy-service-inventory` on a scratch branch that contains a small real change. Do not push — local-only. Tick each item after confirming the expected result.

1. - [ ] Open a Claude Code session inside `supy-service-inventory` and run:
   ```
   /plugin marketplace add /Users/abdalqaderalnajjar/Projects/supy-projects/supy-wingspan
   /plugin install supy-wingspan@supy
   ```
   **Expected:** Claude Code reports the plugin installed successfully, no errors.

2. - [ ] Check the session-start output (scroll up to the very beginning of the session).
   **Expected:** A line matching `supy-wingspan: detected nestjs-nx repo.` appears at session open.

3. - [ ] Create a scratch branch and make a small real change (e.g., add a method stub or modify a module file):
   ```bash
   git checkout -b pilot/supy-wingspan-test
   # make a small edit, then stage it
   git add <file>
   ```
   **Expected:** `git diff HEAD~1...HEAD --stat` shows at least one changed file.

4. - [ ] Run `/supy-review` with no arguments.
   **Expected:** Claude dispatches all five review subagents in parallel, waits for results, and emits a consolidated report with the header `# Supy Review — N issues (H high, M med, L low)`, findings grouped into `## High`, `## Medium`, `## Low`, and `## Clean` sections.

5. - [ ] Run `/supy-commit` with no arguments.
   **Expected:** Claude produces a conventional-commit message (type, optional scope, short description) that ends with the trailer:
   ```
   Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
   ```
   Confirm the message is not auto-pushed — the skill is commit-only with no push step.

6. - [ ] Clean up:
   ```bash
   git checkout main
   git branch -D pilot/supy-wingspan-test
   ```
   **Expected:** Branch deleted locally, nothing pushed to remote.

## Graceful degradation

### `/supy-brainstorm` and `/supy-plan` when `superpowers` is absent

Both commands contain an explicit fallback branch that runs without the `superpowers` plugin.

`/supy-brainstorm` fallback (confirmed by reading `commands/supy-brainstorm.md`): when `superpowers:brainstorming` is not available, the command runs a three-step guided clarification, asking one question at a time — Purpose, Constraints, Success criteria — and synthesising a three-to-five-bullet summary mapped onto Supy's bounded contexts and standards. It is self-sufficient: it loads the standards files from `${CLAUDE_PLUGIN_ROOT}/config/standards/` and produces a **"Risks & Gaps"** section without any external dependency.

`/supy-plan` fallback (confirmed by reading `commands/supy-plan.md`): when `superpowers:writing-plans` is not available, the command produces a phased Markdown task list directly, structured as domain → application → infrastructure → testing phases, with each task naming the Nx library it touches. The plan is saved to `docs/superpowers/plans/<kebab-case-title>.md` in the target repository, creating the directory if needed. The fallback is fully self-sufficient.

Both commands degrade gracefully — they still produce useful, Supy-contextualised output when `superpowers` is absent.

### `/supy-review` on an empty diff

Confirmed by reading `skills/supy-review/SKILL.md` (Step 1 of the skill): before dispatching any agent, the skill runs `git diff ${DIFF_BASE}...HEAD --stat`. If the output is empty (no changes) or the working directory is not a git repository, the skill stops immediately and prints:

```
No changes to review — supy-review needs a non-empty diff
```

No agents are dispatched. The behaviour is explicit and deterministic.

## Verify at install / known gaps

The following two non-blocking warnings were recorded by the validator. They do not prevent install but should be verified during the live pilot.

1. **`SessionStart` hook has no `matcher` field.** The `hooks/hooks.json` entry for `SessionStart` does not include a `matcher`. This is correct for session-lifecycle events, but if the target Claude Code runtime requires a `matcher` even for `SessionStart`, the hook entry could be silently skipped. Verify during the live pilot (checklist step 2) that the `detect-stack.sh` message actually fires at session open.

2. **Review agents declare `Grep` and `Glob` as tool identifiers.** The five review agents list `tools: Read, Grep, Glob, Bash`. If the runtime does not expose `Grep` or `Glob` as explicit tool identifiers, those entries are silently ignored and the agents still function using `Read` and `Bash`. No action required unless the runtime tool ID list differs and the agents produce degraded results.

## Next stacks

This pilot covers backend-first repositories: NestJS-on-Nx (`nestjs-nx`) with NATS eventing and Cerbos authorization. Flutter mobile and React/Next.js frontend repositories are intentionally out of scope for v0.1.0.

When those stacks are ready, the plan (per the design spec's open items, §11) is an **Approach C split**: separate per-stack plugins or per-stack profiles registered under the same `supy` marketplace, each carrying their own standards files, agents, and stack-detection hook output. This keeps backend, mobile, and frontend review logic independently versioned and avoids a monolithic plugin that tries to detect and branch across all three stacks at runtime.
