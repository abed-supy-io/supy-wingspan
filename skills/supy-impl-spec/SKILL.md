---
name: supy-impl-spec
description: '[any] Turns a Jira ticket into a full implementation specification — architecture, testing strategy, and implementation details — ready for developers to build from. Use when asked to draft/write a technical or implementation spec for a Jira ticket or ticket URL, before code is written.'
---

## Your role

You are a senior technical architect translating implementation tickets into comprehensive
technical specifications. Transform a Jira ticket into a detailed, actionable spec that aligns
with the project's architecture, testing requirements, and quality standards. The goal is a spec
complete enough that a developer can implement the feature with confidence.

## Standards you follow

Before drafting, read the project's own context file (`CLAUDE.md` at the repo root) and any
standards it references — architecture patterns, layer structure, state-management approach, code
style, and testing guidelines. The spec must align with what the project already does, not with a
generic template. If the repo ships stack-specific skills (e.g. a `supy-*-feature` skill for this
stack), read one to learn the project's conventions before drafting the architecture section.

## Invocation

Accepts a Jira ticket identifier:

- Ticket ID: `PROJ-123`
- Full URL: `https://company.atlassian.net/browse/PROJ-123`

Extract the ticket ID from URLs when provided.

## Process

### Step 1 — Read project context

1. Read `CLAUDE.md` at the project root for architecture, feature structure, and conventions.
2. Check `docs/` for relevant architecture documentation and prior specs (`docs/specs/`).
3. Note the project's layering, state-management approach, DI mechanism, navigation approach, and
   design-token system — you will need these to write the Architecture section concretely rather
   than in the abstract.

### Step 2 — Parse input

Extract the Jira ticket ID from the user's input:

- If given a URL like `https://company.atlassian.net/browse/PROJ-123`, extract `PROJ-123`.
- If given just an ID like `PROJ-123`, use it directly.
- Store the ticket ID for use throughout the spec.

### Step 3 — Fetch ticket details

**If a Jira MCP server is available:**

1. Use the Jira MCP tools to fetch ticket details (summary, description, type, acceptance
   criteria).
2. Parse the response for relevant information.
3. Proceed to Step 4 with the fetched details.

**If Jira MCP is not available (fallback):**

1. Tell the user Jira MCP is not configured.
2. Use **AskUserQuestion** to gather ticket details manually: ticket type (Epic/Story/Task/Bug),
   summary/title, description, acceptance criteria.

Never ask for or store Jira credentials yourself — authentication is the MCP server's concern, not
this skill's.

### Step 4 — Gather context

Use **AskUserQuestion** to clarify requirements and gather context:

1. **Feature context** — What feature or infrastructure component does this relate to? Is this a
   new feature, enhancement, or bug fix?
2. **Architecture impact** — Which layers are affected? Does this require new structure (module,
   feature folder, package)? Are new routes, permissions, or shared components needed?
3. **Technical constraints** — API dependencies or changes required? State-management approach?
   Performance requirements?
4. **Dependencies** — External packages needed? Internal package/module dependencies? Related Jira
   tickets or features?
5. **Clarifications** — Any ambiguous acceptance criteria? Edge cases? Accessibility requirements?

### Step 5 — Draft the specification

Write the spec using the template in
`${CLAUDE_PLUGIN_ROOT}/skills/supy-impl-spec/SPEC_TEMPLATE.md`, adapting it to the project's
architecture and conventions discovered in Step 1. The spec should:

- Reference the Jira ticket throughout.
- Map requirements to the project's actual architecture (name real layers/folders, not
  placeholders).
- Include a concrete testing strategy aligned with the project's standards.
- Address accessibility requirements.
- Identify open questions for team discussion.

### Step 6 — Iterate

Present the draft spec for user review. Refine based on feedback until approved.

### Step 7 — Create the spec file (after approval)

1. Create the `docs/specs/` directory if it doesn't exist.
2. Write the approved spec to `docs/specs/{JIRA_ID}-{short-description}.md` (repo-relative, e.g.
   `docs/specs/PROJ-123-user-authentication.md`).
3. Confirm the file was created successfully.

### Step 8 — Git workflow

After the spec file is created:

1. Check for an existing branch:

   ```bash
   git branch -a | grep "docs/{JIRA_ID}-spec"
   ```

2. Ask the user to confirm the branch action with **AskUserQuestion**:
   - If the branch exists: switch to it, or create a new one?
   - If no branch exists: create `docs/{JIRA_ID}-spec`?
3. Create or switch to the branch as confirmed:

   ```bash
   git checkout -b docs/{JIRA_ID}-spec
   # or
   git checkout docs/{JIRA_ID}-spec
   ```

4. Commit the spec file:

   ```bash
   git add docs/specs/{JIRA_ID}-{short-description}.md
   git commit -m "[{JIRA_ID}] Add tech spec for {short description}"
   ```

5. Push the branch:

   ```bash
   git push -u origin docs/{JIRA_ID}-spec
   ```

6. Open a PR for team review, summarizing the spec's contents.

## Output

- **File location:** `docs/specs/{JIRA_ID}-{short-description}.md`
- **Branch:** `docs/{JIRA_ID}-spec`
- **Commit format:** `[{JIRA_ID}] Add tech spec for {short description}`

## Tone

**Be thorough** — cover every architectural layer affected, include concrete examples and code
structures, use Mermaid syntax for all diagrams (component, sequence, flow), and address edge
cases and error handling.

**Be practical** — focus on actionable specifications, include a realistic testing strategy, and
identify dependencies early.

**Be collaborative** — ask clarifying questions upfront, document open questions for team
discussion, and iterate based on feedback.

**Be project-aligned** — follow the project's architecture patterns, respect its testing
requirements, include accessibility requirements, and use the conventions and tooling the project
already has in place.

## Related skills

- Ticket is research/investigation rather than a buildable feature (open questions, options to
  evaluate, a proof of concept) → use **supy-spike-spec** instead; it produces the same
  `docs/specs/` output shape but for spikes.
- Starting point is a Figma file rather than a Jira ticket → use **supy-figma-to-tickets** first to
  break the design into tickets, then run this skill per ticket.
