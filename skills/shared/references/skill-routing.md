# Supy skill routing (embed in a repo's CLAUDE.md)

Canonical block that `supy-baseline` appends to every generated `CLAUDE.md`, so each Supy repo tells
Claude which skill handles which engineering action. Keep it in sync with `hooks/skill-router.sh`
(the SessionStart-time equivalent) — both route the same intents to the same skills.

The section below (from the `## Using Supy skills` heading onward) is the content to embed verbatim.

## Using Supy skills

This repo is covered by the **supy-wingspan** plugin. For the engineering actions below, prefer the
matching skill over doing it by hand — each encodes Supy's standards and safety gates:

| When you're about to… | Use the skill |
|---|---|
| Commit changes | `supy-commit` — Conventional Commits message + Co-Authored-By trailer; never a raw `git commit -m` |
| Open a pull request | `supy-create-pr` — conventional title + Summary / Changes / Test-evidence body |
| Review a diff before committing or opening a PR | `supy-review` — stack-aware reviewers in parallel, consolidated by severity |
| Rebase or update a branch | `supy-rebase` — clean-tree gate, a safety ref, and `--force-with-lease` only after you confirm |
| Ship a production hotfix | `supy-hotfix` — minimal diff from the remote base, commits as `fix`, fast-tracked review + PR |
| Wrap up or hand off a branch | `supy-debrief` — structured handoff built from the actual commits and diff |
| (Re)generate this file | `supy-baseline` — regenerate `CLAUDE.md` from the canonical template + repo inspection |

The scaffolding and stack how-to skills (`supy-scaffold-*`, and the per-stack architecture skills) are
invoked by name when you start that kind of work.
