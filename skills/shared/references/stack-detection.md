# Stack detection (canonical)

The single source of truth for detecting which Supy stack a repository is, and which review agents
apply to it. `supy-review` reads this file at runtime; the SessionStart hook
(`hooks/detect-stack.sh`) implements the same ordering. Keep the two in sync — if the detection
order changes here, change it there too.

## Detection procedure

Given the repo root in `REPO_PATH`, evaluate these conditions **in order** and stop at the first
match. Order matters: Angular-Nx must be tested before NestJS-Nx (both have `nx.json`), and the
narrow single-purpose stacks come before the generic fallbacks.

```bash
if [ -f "$REPO_PATH/nx.json" ] && grep -q '"@angular/core"' "$REPO_PATH/package.json" 2>/dev/null; then
  STACK="angular-nx"
elif [ -f "$REPO_PATH/nx.json" ] && grep -q '"@nestjs/core"' "$REPO_PATH/package.json" 2>/dev/null; then
  STACK="nestjs-nx"
elif [ -f "$REPO_PATH/pubspec.yaml" ]; then
  STACK="flutter"
elif [ -f "$REPO_PATH/firebase.json" ] && [ -d "$REPO_PATH/functions" ]; then
  STACK="firebase-functions"
elif [ -f "$REPO_PATH/package.json" ] && grep -q '"commander"' "$REPO_PATH/package.json" 2>/dev/null && grep -q '"bin"' "$REPO_PATH/package.json" 2>/dev/null; then
  STACK="ts-cli"
elif grep -rlsq --include='package.json' --exclude-dir='node_modules' -e '@modelcontextprotocol/sdk' -e '@anthropic-ai/claude-agent-sdk' "$REPO_PATH" 2>/dev/null; then
  STACK="ai-agents"
elif [ -f "$REPO_PATH/kustomization.yaml" ] || grep -rlsq --include='*.yaml' -e 'kind: ConfigMap' -e 'kind: Secret' "$REPO_PATH" 2>/dev/null; then
  STACK="k8s-config"
else
  STACK="other"
fi
```

## Stack → reviewer set

Dispatch exactly the reviewers listed for the detected stack. The stack-agnostic
`supy-commit-pr-reviewer` and `supy-secrets-reviewer` run on **every** set — a committed secret is a
merge-blocker in any stack, and `supy-secrets-reviewer` self-limits to config/secret/credential
findings and returns `PASS` when a diff has none.

| Stack | Reviewer agents to dispatch |
|---|---|
| `nestjs-nx` | `supy-architecture-reviewer`, `supy-nats-event-reviewer`, `supy-test-quality-reviewer`, `supy-commit-pr-reviewer`, `supy-security-reviewer`, `supy-secrets-reviewer` (six) |
| `angular-nx` | `supy-angular-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` (three) |
| `flutter` | `supy-flutter-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` (three) |
| `firebase-functions` | `supy-firebase-functions-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` (three) |
| `ts-cli` | `supy-ts-cli-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` (three) |
| `ai-agents` | `supy-ai-agents-reviewer`, `supy-commit-pr-reviewer`, `supy-secrets-reviewer` (three) |
| `k8s-config` | `supy-secrets-reviewer`, `supy-commit-pr-reviewer` (two) |
| `other` | `supy-commit-pr-reviewer`, `supy-secrets-reviewer` (two) |

## Which reviewers are stack-specific

Never dispatch a stack-specific reviewer against a repo of a different stack:

- **Backend (`nestjs-nx`):** `supy-architecture-reviewer`, `supy-nats-event-reviewer`,
  `supy-test-quality-reviewer`, `supy-security-reviewer`.
- **Frontend (`angular-nx`):** `supy-angular-reviewer`.
- **Mobile (`flutter`):** `supy-flutter-reviewer`.
- **Standalone Firebase Functions backend (`firebase-functions`):** `supy-firebase-functions-reviewer`.
- **Standalone commander.js CLI (`supy-cli`, `ts-cli`):** `supy-ts-cli-reviewer`.
- **Polyglot AI-agents monorepo (`supy-ai-agents`, `ai-agents`):** `supy-ai-agents-reviewer`.
- **Stack-agnostic (every stack):** `supy-commit-pr-reviewer`, `supy-secrets-reviewer`.
