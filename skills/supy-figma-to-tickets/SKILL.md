---
name: supy-figma-to-tickets
description: '[any] Read a Figma design file via the Figma MCP and turn its screens, components, and flows into dependency-ordered GitHub issues or Jira tickets, each deep-linked back to the Dev Mode node it came from. Confirms scope, ticket breakdown, and labels with the user before creating anything. Use when a Figma design needs to become a set of trackable, developer-ready tickets, in any repo and any stack.'
---

## Step 1 — Resolve the Figma URL and ticket destination

### 1.1 Figma URL

Parse the Figma URL from `$ARGUMENTS` if present, otherwise from the user's request. If none is
found, ask:

> "Please share the Figma file URL in Dev Mode you'd like to break into tickets. It looks like:
> `https://www.figma.com/design/<file_key>/<file_name>&m=dev`"

Do not proceed without a valid Figma URL. From it, extract:

- **File key** — the alphanumeric segment after `/design/` or `/file/`.
- **Node ID** (optional) — if the URL contains `?node-id=`, scope the analysis to that subtree.

If the URL format is unrecognizable, ask the user to double-check it.

### 1.2 Choose the ticket system

Use **AskUserQuestion** to ask where tickets should be created:

1. **GitHub Issues** — requires the `gh` CLI authenticated in the current repo.
2. **Jira** — requires a Jira MCP server configured in the session.

Do not proceed until the user picks one.

### 1.3 Validate the destination

**If GitHub Issues:**

```bash
gh repo view --json nameWithOwner,url --jq '.nameWithOwner + " (" + .url + ")"'
```

If `gh` is not authenticated or no repo is detected, tell the user to install/authenticate `gh`
(`gh auth login`) and run the skill from inside the target repository.

**If Jira:**

Use the Jira MCP to list accessible projects (e.g. a `list_projects`-style tool). If no Jira MCP
server is configured or authentication fails, tell the user to configure and authenticate one per
their MCP server's setup instructions.

Then use **AskUserQuestion** to ask which Jira project to use and which issue type to create (e.g.
Task, Story, Bug). Default to **Task** if the user has no preference.

### 1.4 Confirm scope

Use **AskUserQuestion** to confirm, and ask whether any pages or sections should be included or
excluded:

- **Figma file**: `<file_name>` (`<file_key>`)
- **Destination**: `<owner/repo>` (GitHub) or `<project_key>` (Jira)
- **Scope**: entire file / specific page / specific node

Do not proceed until the user confirms.

## Step 2 — Read the design file

Use whichever Figma MCP tools are available in the current session (commonly `get_design_context`,
`get_metadata`, or `get_figma_data`, depending on which Figma MCP server is configured) to read the
file.

### 2.1 Get the file structure

Fetch the top-level structure at depth 2, enough to see pages and their immediate children
(frames/sections).

### 2.2 Identify work units

Walk the returned node tree and categorize each top-level frame or section:

| Category | Heuristic |
|----------|-----------|
| Screen | Top-level frame on a page, typically device-sized (e.g. 375x812, 1440x900). |
| Component | Node of type `COMPONENT` or `COMPONENT_SET`. |
| Flow | Frames connected by prototype links, or named with a shared prefix (e.g. `Onboarding/Step1`, `Onboarding/Step2`). |
| Shared element | Repeated across multiple screens (nav bars, tab bars, modals). |

### 2.3 Deep-read important nodes

For each identified work unit, fetch only as much additional detail as is needed to write a useful
ticket:

- Layout and dimensions.
- Key text content (headings, labels, button text).
- Component variants and states (default, hover, error, disabled).
- Connections to other frames (prototype links).

Avoid exhaustive property dumps.

## Step 3 — Organize into tickets

### 3.1 Group logically

- **One screen = one ticket**, unless screens are trivially similar (e.g. empty vs. populated
  states of the same list) — combine those.
- **Shared components** that appear across multiple screens get their own ticket, implemented
  first.
- **Flows** (multi-screen sequences like onboarding or checkout) can be a single ticket or split
  per screen — use judgment based on complexity; when in doubt, split.
- **Design system foundations** (colors, typography, spacing tokens) become a single setup ticket
  if they don't already exist in the codebase.

### 3.2 Determine ticket order

Sort tickets by dependency:

1. Design system / shared tokens (if needed).
2. Shared components (bottom-up: atoms before molecules).
3. Individual screens (ordered by flow, not alphabetically).
4. Integration / navigation wiring.

### 3.3 Draft the ticket list

For each ticket, draft:

- **Title** — conventional commit format: `feat: <concise description>`.
- **Figma link** — deep link to the specific node in Dev Mode:
  `https://www.figma.com/design/<file_key>/<file_name>?node-id=<node_id>&m=dev`.
- **Summary** — 2-3 sentences: what this screen/component does, key interactions.
- **Acceptance criteria** — checkboxes covering visible states and behaviors.
- **Design notes** — dimensions, key colors/tokens, component variants, responsive behavior.
- **Dependencies** — which other tickets must land first (reference by title).

## Step 4 — Review with the user

Present the full breakdown as a numbered list:

```text
Proposed tickets (N total):

1. feat: add design tokens and theme setup
   Figma: <link>
   Depends on: —

2. feat: implement bottom navigation bar
   Figma: <link>
   Depends on: #1

3. feat: build home screen
   Figma: <link>
   Depends on: #1, #2
```

Use **AskUserQuestion** to offer:

- **Create all tickets** — proceed to Step 5.
- **Edit the list** — accept changes (merge, split, reorder, remove, rename).
- **Add labels or metadata** — labels (GitHub) or components/epics (Jira) to apply.

Iterate until the user is satisfied.

## Step 5 — Create tickets

### If GitHub Issues

**5.1 Check for existing labels:**

```bash
gh label list --limit 100 --json name --jq '.[].name'
```

Create any requested label that doesn't exist:

```bash
gh label create "<label>" --description "<description>"
```

**5.2 Create issues**, one per approved ticket:

```bash
gh issue create \
  --title "<title>" \
  --body "$(cat <<'EOF'
## Summary

<summary text>

## Figma Design

View in Figma (Dev Mode): <figma_deep_link>

## Acceptance Criteria

- [ ] <criterion 1>
- [ ] <criterion 2>
- [ ] <criterion 3>

## Design Notes

<dimensions, tokens, variants, responsive notes>

## Dependencies

<links to dependency issues or "None">
EOF
)" \
  --label "<label1>,<label2>"
```

Create issues in dependency order so earlier issues exist when later ones reference them. After
each `gh issue create`, capture the issue number from its output and reference it as `#<number>` in
the Dependencies section of any issue that depends on it.

**5.3 Link to a project (optional):** if the repository uses GitHub Projects, offer to add all
issues to a board:

```bash
gh project item-add <project_number> --owner <owner> --url <issue_url>
```

### If Jira

**5.1 Create tickets**, one per approved ticket, via the Jira MCP, with:

- **Project**: the project key confirmed in Step 1.
- **Issue type**: the type confirmed in Step 1 (default: Task).
- **Summary**: the ticket title.
- **Description**, formatted as (wiki markup or ADF, whichever the MCP supports):

```text
h2. Summary

<summary text>

h2. Figma Design

View in Figma (Dev Mode): <figma_deep_link>

h2. Acceptance Criteria

* <criterion 1>
* <criterion 2>
* <criterion 3>

h2. Design Notes

<dimensions, tokens, variants, responsive notes>

h2. Dependencies

<links to dependency tickets or "None">
```

- **Labels / components**: as requested by the user.
- **Epic link**: if the user specified an epic.

Create tickets in dependency order so earlier tickets exist when later ones reference them. After
each ticket is created, capture its key (e.g. `PROJ-123`) from the MCP response, reference it in
the Dependencies section of any ticket that depends on it, and create a "blocked by" link if the
MCP supports it.

**5.2 Link to epic or board (optional):** if the user wants tickets added to an epic or sprint, use
the Jira MCP to link them.

## Step 6 — Summarize and offer next steps

**If GitHub Issues:**

```text
Created N issues in <owner/repo>:

#<num> feat: add design tokens and theme setup
#<num> feat: implement bottom navigation bar
#<num> feat: build home screen
...

Figma source: <original_figma_url>
```

**If Jira:**

```text
Created N tickets in <project_key>:

<PROJ-101> feat: add design tokens and theme setup
<PROJ-102> feat: implement bottom navigation bar
<PROJ-103> feat: build home screen
...

Figma source: <original_figma_url>
```

Use **AskUserQuestion** to offer next steps:

1. **Open tickets in browser** — `gh issue list --state open --json number,title,url` (GitHub) or
   the Jira URLs (Jira).
2. **Add to a project/sprint** — a GitHub Project board, or a Jira sprint via the Jira MCP.
3. **Start building** — pick a ticket and hand it to `/supy-plan` to draft an implementation plan,
   then `/supy-build` to execute it. Once the change is ready, use the **supy-create-pr** skill to
   open the PR back against this ticket.
4. **Done** — end the session.

## Guidelines

- **Always use Dev Mode links.** Append `&m=dev` to every Figma URL so developers land directly in
  Dev Mode with inspect, measurements, and code snippets ready.
- **Link everything.** Every ticket must link to its Figma node — this is the primary value of the
  skill.
- **Right-size tickets.** A single button is too small; an entire app is too big. Target 1-3 days
  of implementation scope per ticket.
- **Include visual context.** Mention key colors, sizes, and states so developers don't need to
  open Figma for basic implementation.
- **Respect existing patterns.** If the codebase already has a design system or theme, reference
  it in the tickets rather than asking developers to recreate tokens.
- **Be concise.** Ticket bodies should be scannable — bullet points and checklists, not paragraphs.

## Important

This skill creates tickets — it does not write code or implementation plans. For implementation,
hand the created ticket to `/supy-plan` (plan) and `/supy-build` (execute), then use
**supy-create-pr** to open the pull request.
