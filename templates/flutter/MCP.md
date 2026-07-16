# Flutter MCP servers (`.mcp.json`)

`templates/flutter/.mcp.json` is a **drop-in**, not a plugin-global config. The plugin deliberately
does **not** register these MCP servers for every session — most of them are Flutter-only and would
fail to start (or waste a slot) in a backend, frontend, or infra repo. Instead, copy the file into a
Flutter repo that wants them.

## Enable in a Flutter repo

From the target Flutter repo root:

```bash
cp "${CLAUDE_PLUGIN_ROOT}/templates/flutter/.mcp.json" ./.mcp.json
```

Then restart Claude Code (or reconnect MCP) so the servers are picked up. Commit `.mcp.json` if the
whole team should get the servers; add it to `.gitignore` if it's a personal setup.

## What each server provides

| Server | Transport | Requirement | Purpose |
| --- | --- | --- | --- |
| `cortex-kg` | http | none (network) | Supy Cortex knowledge graph — entities, handler contracts, repo guides. |
| `dart` | stdio | Dart SDK on PATH | Dart tooling MCP (`dart mcp-server`) — analyze, format, pub, test. |
| `very-good-cli` | stdio | `very_good_cli` activated | `very_good mcp` — project/feature generation matching Very Good conventions. |
| `railway` | stdio | `npx` (Node) | Railway deploy/infra operations. |
| `ios-simulator` | stdio | `npx` (Node), macOS + Xcode | Drive the iOS Simulator (boot, install, screenshot, UI). |

## Trimming to what a repo needs

Not every Flutter repo needs all five. Delete the entries you don't want after copying:

- **No Railway deploys** → remove `railway`.
- **Non-macOS or no iOS target** → remove `ios-simulator`.
- **Not using Very Good CLI** → remove `very-good-cli`.

`cortex-kg` and `dart` are the two most broadly useful and safe to keep in any Supy Flutter repo.

## Prerequisites

- `dart` server needs the Dart SDK (`command -v dart`). Install via FVM or the Flutter SDK.
- `very-good-cli` server needs the CLI: `dart pub global activate very_good_cli`.
- `railway` and `ios-simulator` shell out to `npx`, so Node.js must be installed.
- No secrets or tokens live in this file — `cortex-kg` authenticates via the network endpoint, and
  the `env` blocks are intentionally empty. Never commit credentials into `.mcp.json`.
