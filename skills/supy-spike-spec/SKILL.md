---
name: supy-spike-spec
description: '[any] Turn a Jira ticket into a spike/research specification — research questions, options to evaluate, PoC scope, and success criteria — saved to docs/specs/. Use when a ticket needs technical investigation or a proof of concept before implementation can be planned, on any supy-* repo.'
---

## Step 1 — Read project context

Before touching the ticket, ground the spike in how this repo actually works:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
cat "$REPO_ROOT/CLAUDE.md" 2>/dev/null
ls "$REPO_ROOT/docs" 2>/dev/null
```

Read the repo's `CLAUDE.md` (or equivalent context file) and any architecture docs it points to.
Any option evaluated later in this spike must be judged against the repo's existing stack and
conventions — a proposed solution either fits the existing patterns or explicitly justifies
deviating from them. If no `CLAUDE.md` is found, continue without it — this step informs scope,
it does not block the spike.

---

## Step 2 — Resolve the ticket

Accept either form from the user's input:

- Ticket ID: `PROJ-123`
- Full URL: `https://<org>.atlassian.net/browse/PROJ-123`

Extract the ticket ID (`PROJ-123`) for use in the file name, branch name, and template.

---

## Step 3 — Fetch ticket details

**If a Jira MCP server is available:** use its tools to fetch the ticket's summary, description,
and type. Confirm it is actually a spike/research ticket before proceeding — if it reads like a
straightforward implementation ticket, say so and ask whether `supy-spike-spec` is the right skill.

**If no Jira MCP is available (fallback):** ask the user directly for:

```text
supy-spike-spec: no Jira MCP server detected. Please provide:
  1. Summary/title
  2. Description
  3. What triggered the need for this spike
  4. Expected outcome
```

Never fetch or paste raw Jira credentials, API tokens, or auth headers into the spec or the
conversation — only the ticket's content (summary, description, links) belongs there.

---

## Step 4 — Scope the spike

Ask the user to clarify, one topic at a time, whatever the ticket didn't already answer:

1. **Research questions** — What specific questions need to be answered? What unknowns are we
   trying to resolve? What decisions depend on the outcome?
2. **Options to evaluate** — Are there specific solutions/approaches to compare? What criteria
   matter most (performance, maintainability, cost, complexity, security)?
3. **Proof of concept** — Is a PoC needed? What should it demonstrate? What are the success
   criteria?
4. **Constraints** — Time box for the spike? Technical constraints or preferences? Team capacity
   considerations?

Do not invent research questions or options the user hasn't confirmed — a spike spec that asks the
wrong questions wastes the time box it's meant to protect.

---

## Step 5 — Draft the spike specification

Write the draft using the bundled template:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/skills/supy-spike-spec/SPIKE_TEMPLATE.md"
```

The draft should:

- State the research questions to answer, specific and answerable.
- List each option with description, pros, cons, and unknowns still to verify.
- Define weighted evaluation criteria.
- Specify PoC scope, explicit out-of-scope items, and checkbox success criteria (skip this
  section entirely if Step 4 established no PoC is needed).
- Include empty "Findings" / "Recommendations" sections to be filled in during or after the spike
  — do not pre-fill these with guessed answers.
- Use a Mermaid diagram where a flow or decision tree clarifies the options faster than prose.

Keep the PoC scope minimal but sufficient to answer the research questions — a spike that grows
into a full implementation has failed to stay a spike.

---

## Step 6 — Iterate

Present the draft for review. Refine based on feedback until the user approves it. Do not move to
Step 7 without explicit approval.

---

## Step 7 — Save the spec file

Once approved:

```bash
mkdir -p docs/specs
```

Write to `docs/specs/{TICKET_ID}-spike-{short-description}.md`, where `{short-description}` is a
kebab-case summary of the spike (e.g. `docs/specs/PROJ-123-spike-cache-invalidation.md`).

---

## Step 8 — Git workflow

1. Check for an existing branch for this spike: `docs/{TICKET_ID}-spike`.
2. Confirm with the user whether to create it, switch to it, or use the current branch instead —
   never switch branches silently.
3. Stage the new spec file.
4. Hand off to the **supy-commit** skill to craft and confirm the commit message — do not invent a
   commit format here; let `supy-commit` apply the repo's actual commit convention.
5. Once committed, offer to push and open a PR (use **supy-create-pr** if the repo has one, or
   `gh pr create` directly) — only after explicit user confirmation.

---

## Output

- **File:** `docs/specs/{TICKET_ID}-spike-{short-description}.md`
- **Branch:** `docs/{TICKET_ID}-spike`
- **Commit:** produced by `supy-commit`, not hardcoded by this skill

---

## Degradation paths

**Not a git repository:** Step 1's `git rev-parse` fails. Continue without `REPO_ROOT`-relative
context, but warn that branch/commit steps (Step 8) won't be available until inside a repo.

**No `CLAUDE.md` or context docs found:** Note it and continue — ask the user directly for any
architectural constraints the options should respect.

**No Jira MCP server:** Fall back to the direct questions in Step 3. Never fabricate ticket
details.

**User has no PoC in mind:** Skip the Proof of Concept section of the template entirely rather
than leaving a hollow placeholder — a spike can be pure research with no code produced.

**User declines to save, branch, or commit:** Stop at whichever step they decline. The drafted
spec (Step 5/6) is still a valid deliverable printed to the conversation even if never written to
disk.

## Tone

Be focused: keep research questions specific and answerable, and PoC scope minimal but sufficient.
Be practical: consider time constraints, surface dependencies and risks early. Be collaborative:
ask clarifying questions upfront, document assumptions, and leave room for findings to be added
once the spike is actually run.

## Related skills

Once a spike lands on a recommended approach, hand it to the sibling **supy-impl-spec** skill (if
installed) to turn the recommendation into a full implementation specification. Use **supy-commit**
for the commit in Step 8 and **supy-create-pr** for opening the pull request.
