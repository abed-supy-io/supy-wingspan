## Summary

<!-- What does this PR change, and why? One or two sentences. -->

## Changes

<!-- Bullet the concrete changes. Group by component: agents / skills / commands / hooks / standards / templates / config / docs. -->

-

## Test evidence

<!-- How did you verify this? For a plugin repo that means, at minimum: -->

- [ ] `markdownlint-cli2 --config config/custom.markdownlint.jsonc "**/*.md"` passes
- [ ] `cspell --config config/cspell.json "**/*.md"` passes
- [ ] Changed skills load and run in a real Claude Code session (name a repo/stack you tested against)
- [ ] Changed hooks were exercised (`hooks/detect-stack.sh` on the relevant stack)
- [ ] Changed components were exercised in a real Claude Code session via a local marketplace
      install (`/plugin marketplace add <path>` → `/plugin install supy-wingspan@supy` →
      `/reload-plugins`)

## Issue refs

<!-- closes #N, relates to #N -->
