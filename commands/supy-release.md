---
description: Report the release-please state of this plugin repo — pending release PR, unreleased commits since the last tag, and installed-vs-released version — and optionally merge the release PR to ship. Read-only unless explicitly asked to ship.
argument-hint: [optional action, e.g. "ship" to merge the pending release PR after confirmation]
---

You are running `/supy-release` in the supy-wingspan plugin repository. Releases here are fully
automated by **release-please**: merging conventional commits to `main` accumulates into a rolling
release PR, and merging that PR tags the release and bumps `version` in
`.claude-plugin/plugin.json`. Commit types drive the version bump — see
`${CLAUDE_PLUGIN_ROOT}/config/standards/commit-conventions.md`.

## Preconditions (degrade gracefully)

Check each; if one fails, report it plainly and do only what remains possible:

- `gh` not installed or not authenticated (`gh auth status` fails) → skip all PR/release queries;
  still report the local state (steps 1 and 2 below via `git` only) and print the install hint
  (`brew install gh && gh auth login`).
- No GitHub remote (`git remote get-url origin` fails) → local-only report, note that
  release-please cannot run without the GitHub repo.
- Not on a network / API errors → report what succeeded, mark the rest "unavailable", never fail.

## Report (default, read-only)

Gather and present as one short status block:

1. **Current version** — `version` in `.claude-plugin/plugin.json` on the current checkout, and
   on `origin/main` (`git show origin/main:.claude-plugin/plugin.json` after a `git fetch`).
2. **Last release** — most recent tag (`git tag --sort=-v:refname | head -1`) and how many
   commits `origin/main` is ahead of it (`git rev-list <tag>..origin/main --count`).
3. **Pending release PR** — `gh pr list --state open --search "chore(main): release" --json
   number,title,url`. If present, show its title (which contains the next version), URL, and its
   changelog body summary. If absent but unreleased commits exist, say the release PR will appear
   after the next push to `main` (or that the pending commits are all non-releasable types).
4. **Unreleased commits** — `git log <last-tag>..origin/main --oneline`, grouped by conventional
   type, and state the bump they imply (`feat` → minor, `fix` → patch, `BREAKING CHANGE` → major
   pre-1.0 rules per release-please config).
5. **Consumer impact** — remind that installs are pinned snapshots: until the release PR merges,
   `/plugin marketplace update supy` delivers nothing new.

## Ship (only when asked)

If `$ARGUMENTS` contains `ship` or `merge`: show the pending release PR's title, version, and
changelog first, then ask the user to confirm before running `gh pr merge <number> --squash`.
Merging tags the release — this is the outward-facing step, so never do it without the explicit
argument **and** a confirmation. If checks on the PR are failing, stop and report instead of
merging.

Anything else in `$ARGUMENTS` (or nothing) means report-only.
