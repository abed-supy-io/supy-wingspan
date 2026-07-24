---
name: supy-review
description: '[any] Review the current Supy diff/PR against Supy standards using the stack-appropriate review subagents in parallel, then consolidate findings by severity. Backend (nestjs-nx) dispatches six reviewers; frontend (angular-nx), mobile (flutter), the standalone Firebase Functions backend (firebase-functions), the standalone commander.js CLI (ts-cli), and the polyglot AI-agents monorepo (ai-agents) dispatch their stack reviewer plus the commit/PR reviewer; Kubernetes config (k8s-config) dispatches the secrets reviewer. The stack-agnostic commit/PR and secrets reviewers run on every stack. Use when about to commit or open a PR on a supy-* repo.'
---

## Step 1 — Resolve the diff range

Determine the diff range using the following logic (in order):

1. If `$ARGUMENTS` names a base ref (e.g., `origin/main`, a commit SHA, or a branch name), use that ref directly as the range base.
2. Otherwise, resolve the merge base against the main branch:

   ```bash
   git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main
   ```

3. If neither yields a valid ref (e.g., not a git repo or no common ancestor), fall back to `HEAD~1`.

Capture the resolved base ref as `DIFF_BASE`. Then verify the diff is non-empty:

```bash
git diff ${DIFF_BASE}...HEAD --stat
```

If the diff is empty (no output), or if the working directory is not a git repository, stop immediately and print:

```text
No changes to review — supy-review needs a non-empty diff
```

Do not proceed to dispatch.

Also capture the absolute repo path:

```bash
REPO_PATH=$(git rev-parse --show-toplevel)
```

---

## Step 2 — Select the reviewer set for the repo's stack

Different stacks have different governing standards, so dispatch only the reviewers that apply. The canonical detection logic and the stack→reviewer-set matrix live in one shared reference (the same source the SessionStart hook follows). Read it now and apply it:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/skills/shared/references/stack-detection.md"
```

From that reference:

1. Run the detection procedure against `REPO_PATH` (in order — first match wins) to resolve `STACK`.
2. Look up `STACK` in the "Stack → reviewer set" table to get the exact set of reviewer agents to dispatch.
3. Honour the "Which reviewers are stack-specific" rule: never dispatch a stack-specific reviewer against a repo of a different stack. `supy-commit-pr-reviewer` and `supy-secrets-reviewer` are stack-agnostic and run on every set.

If the reference is unreadable, fall back to dispatching only the two stack-agnostic reviewers (`supy-commit-pr-reviewer`, `supy-secrets-reviewer`) rather than aborting.

**In a single message, make one Agent tool call per reviewer in the selected set** so they all run in parallel. Do not make them sequentially. Passing both `DIFF_BASE` and `REPO_PATH` into each dispatch prompt is mandatory so all agents review the identical diff rather than each recomputing it independently.

For each Agent call, use this dispatch prompt template (substituting the actual values of `DIFF_BASE` and `REPO_PATH`):

```text
Repo: <REPO_PATH>
Diff range: <DIFF_BASE>...HEAD

Review the diff at the range above against your governing standards.
Use `git diff <DIFF_BASE>...HEAD` to obtain the diff — do not recompute the merge base.
Return findings in the fixed output shape defined in your Output Contract.
```

---

## Step 3 — Collect outputs

Wait for all dispatched agents to complete. Each agent returns a fixed-shape output:

```text
## <reviewer name> — <PASS | ISSUES FOUND>
- **[severity: high|med|low]** <file>:<line> — <problem> → <concrete fix> (rule: <standards anchor>)
```

A clean agent returns only the header line ending in `PASS`, with no bullets.

If an agent errors, times out, or returns output that does not match the fixed shape, treat it as **skipped** — do not let it fail the overall review.

---

## Step 4 — Gated adversarial verification

Before consolidating, run the gated verification protocol defined in the shared reference:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/skills/shared/references/adversarial-verification.md"
```

Apply it to the findings collected in Step 3, once each finding carries its severity:

1. **Gate:** only findings that are **high-severity** (per `config/standards/review-severity.md`)
   or that the reviewer flagged **low-confidence** enter verification. Every other finding
   (confident medium/low) skips straight to Step 5 — this is not a blanket second pass over
   everything, and it must never become one.
2. **Refute:** for each gated finding, run the single skeptic read from the reference — try to
   prove the finding wrong from the diff plus its cited standard anchor. A finding survives
   only if it cannot be refuted; otherwise drop it or fold it into a smaller, accurate finding.
3. **Budget guard:** if token/time budget is under pressure, skip the refutation attempt for a
   gated finding and label it `unverified` instead of blocking the review — never spend a
   blanket multiplier to force verification through. Proceed to Step 5 with whatever findings
   were verified, refuted, or marked `unverified`.

---

## Step 5 — Consolidate into the severity-grouped report

Parse every finding bullet from all dispatched agents' outputs. Classify each bullet by its severity token (`high`, `med`, or `low`). Build the consolidated report in this exact structure:

```markdown
# Supy Review — <N> issues (<H> high, <M> med, <L> low)

## High
- <all high-severity finding lines, each prefixed by reviewer name for traceability>

## Medium
- <all med-severity finding lines>

## Low
- <all low-severity finding lines>

## Clean
- <comma-separated list of reviewer names that returned PASS with no bullets>

## Skipped
- <reviewer names that errored or returned unparseable output, one per line, with a brief reason>
```

Rules for building the report:

- `N` = total count of all parsed finding bullets across all dispatched agents.
- `H`, `M`, `L` = counts per severity level.
- If a severity section has no findings, write the heading but leave the body as `(none)`.
- If no reviewers were skipped, omit the `## Skipped` section entirely.
- If no reviewers returned PASS, write `(none)` under `## Clean`.
- Prefix each finding line with the reviewer name in parentheses for traceability, e.g.:

  ```text
  - (supy-architecture-reviewer) **[severity: high]** libs/ledger/api/src/ledger.rpc.controller.ts:3 — ...
  ```

- Sort findings within each section by file path, then line number, for readability.
- A single failed or skipped reviewer must never cause the whole report to fail — always emit a complete report with whatever findings were successfully collected.

---

## Degradation paths

**Empty diff / not a git repo:** Detected in Step 1. Print the message and stop before dispatching.

**Per-reviewer skip:** If an individual agent errors or returns malformed output, list it under `## Skipped` with a one-line reason (e.g., `supy-nats-event-reviewer — agent error: timeout`). Continue consolidating findings from the remaining agents.

**Verification under budget pressure:** If Step 4's skeptic pass cannot be run for a gated finding (token/time budget), degrade to labelling that finding `unverified` per `${CLAUDE_PLUGIN_ROOT}/skills/shared/references/adversarial-verification.md` — never block the whole review to force verification through.
