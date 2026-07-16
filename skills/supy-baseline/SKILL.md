---
name: supy-baseline
description: Generate or refresh the canonical Supy CLAUDE.md and report missing AI setup (Cortex MCP, .claude settings) for the current supy repo. Use when a repo lacks standardized AI configuration.
---

## Step 1 — Resolve repo root and stack

Identify the repo root and name:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
```

If `git rev-parse` fails (not a git repo), stop immediately and print:

```text
supy-baseline: not inside a git repository — nothing to do
```

Detect the stack by inspecting the root. Nx repos are disambiguated by their framework dependency:

```bash
if [ -f "$REPO_ROOT/nx.json" ] && [ -f "$REPO_ROOT/package.json" ]; then
  if grep -q '"@angular/core"' "$REPO_ROOT/package.json"; then
    STACK=angular-nx
  elif grep -q '"@nestjs/core"' "$REPO_ROOT/package.json"; then
    STACK=nestjs-nx
  else
    STACK=nx
  fi
fi

# Flutter (fallback)
[ -f "$REPO_ROOT/pubspec.yaml" ] && STACK=flutter

# Standalone Firebase Functions backend (non-Nx): firebase.json + a functions/ package.
# Checked after flutter, before the generic fallback — mirrors detect-stack.sh / supy-review order.
[ -z "$STACK" ] && [ -f "$REPO_ROOT/firebase.json" ] && [ -d "$REPO_ROOT/functions" ] && STACK=firebase-functions

# Standalone TypeScript CLI (non-Nx): package.json declaring a `bin` and depending on commander.
# Checked after firebase-functions, before ai-agents — mirrors detect-stack.sh / supy-review order.
[ -z "$STACK" ] && [ -f "$REPO_ROOT/package.json" ] \
  && grep -q '"commander"' "$REPO_ROOT/package.json" 2>/dev/null \
  && grep -q '"bin"' "$REPO_ROOT/package.json" 2>/dev/null && STACK=ts-cli

# Polyglot AI-agents monorepo (non-Nx, no root orchestration): a package.json anywhere in the tree
# depends on the MCP SDK or the Claude Agent SDK. Checked after ts-cli (ts-cli inspects only the ROOT
# package.json, and this repo has no root orchestration to misgrab) and before the generic fallback —
# mirrors detect-stack.sh / supy-review order.
[ -z "$STACK" ] \
  && grep -rlsq --include='package.json' --exclude-dir='node_modules' \
       -e '@modelcontextprotocol/sdk' -e '@anthropic-ai/claude-agent-sdk' "$REPO_ROOT" 2>/dev/null \
  && STACK=ai-agents

# Generic fallback
[ -z "$STACK" ] && STACK=generic
```

Template generation is supported for **`nestjs-nx`** (backend), **`angular-nx`** (frontend), **`flutter`** (mobile), **`firebase-functions`** (standalone Firebase Functions backend), **`ts-cli`** (standalone commander.js CLI), and **`ai-agents`** (polyglot MCP/agents monorepo). For any other stack (`nx`, `generic`) this skill only emits the missing-pieces checklist (Step 4) and skips template generation. In that case print a notice:

```text
supy-baseline: stack detected as <STACK>; template generation is only supported for nestjs-nx, angular-nx, flutter, firebase-functions, ts-cli, and ai-agents repos.
Reporting missing AI-setup pieces only.
```

---

## Step 2 — Gather template inputs

Select the Handlebars template for the detected stack:

```bash
if [ "$STACK" = "angular-nx" ]; then
  TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/frontend/CLAUDE.md.hbs"
elif [ "$STACK" = "flutter" ]; then
  TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/flutter/CLAUDE.md.hbs"
elif [ "$STACK" = "firebase-functions" ]; then
  TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/firebase-functions/CLAUDE.md.hbs"
elif [ "$STACK" = "ts-cli" ]; then
  TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/ts-cli/CLAUDE.md.hbs"
elif [ "$STACK" = "ai-agents" ]; then
  TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/ai-agents/CLAUDE.md.hbs"
else
  TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.hbs"
fi
```

Collect each placeholder value from the repo. If Cortex MCP is connected, augment with live data; otherwise fall back to static inspection. Every Cortex call is optional — never hard-fail if Cortex is absent.

Every template shares `repo_name`, `one_line_purpose`, and `stack_versions`. Fill the **Backend placeholders (nestjs-nx)** block for a `nestjs-nx` repo, the **Frontend placeholders (angular-nx)** block for an `angular-nx` repo, the **Flutter placeholders (flutter)** block for a `flutter` repo, the **Firebase Functions placeholders (firebase-functions)** block for a `firebase-functions` repo, the **ts-cli placeholders (ts-cli)** block for a `ts-cli` repo, or the **ai-agents placeholders (ai-agents)** block for an `ai-agents` repo. Flutter repos have no `package.json` — every command in the flutter block reads `pubspec.yaml` and the `lib/` tree instead, with no `node`. The `nestjs-nx`, `angular-nx`, and `flutter` blocks additionally fill `key_flows`; the `firebase-functions`, `ts-cli`, and `ai-agents` templates omit `key_flows` and instead carry a **Remediation status** block (see their placeholder blocks below).

### Shared placeholders

#### `repo_name`

```bash
echo "$REPO_NAME"
```

#### `one_line_purpose`

1. If Cortex is connected, call `get_repo_guide('$REPO_NAME')` and extract the `description` or `summary` field.
2. Fallback: read the first non-heading, non-blank line of the existing `CLAUDE.md` (if present), or read the `description` field in `package.json`. If neither exists, use `"<purpose — fill me in>"`.

### Backend placeholders (nestjs-nx)

#### `bounded_context`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `boundedContext` field.
2. Fallback: use the first directory under `libs/` as a rough proxy (`ls libs/ | head -1`). If unclear, use `"<bounded-context>"`.

#### `database`

Inspect `package.json` dependencies for `mongoose` or `@nestjs/mongoose`; if found, emit `MongoDB`. Otherwise emit `"<database>"`.

```bash
grep -q '"mongoose"' "$REPO_ROOT/package.json" && DB=MongoDB || DB="<database>"
```

#### `aggregates`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `aggregates` list.
2. Fallback: grep for aggregate root class names:

```bash
grep -r "extends.*Aggregate\|AggregateRoot" "$REPO_ROOT/libs" --include="*.ts" -l \
  | xargs grep -h "^export class" 2>/dev/null \
  | sed 's/export class //' | sed 's/ .*//' | sort -u | head -10 | paste -sd ', '
```

If nothing found, emit `"<aggregates>"`.

#### `nats_patterns`

1. Cortex (if connected): `trace_implementation` or `search_relationships` for the repo.
2. Fallback: grep for `@MessagePattern` and `@EventPattern` subjects:

```bash
grep -r "@MessagePattern\|@EventPattern" "$REPO_ROOT/libs" --include="*.ts" -h \
  | grep -oP "(?<=['\"])[^'\"]+(?=['\"])" | sort -u | head -10 | paste -sd ', '
```

If nothing found, emit `"<nats-patterns>"`.

#### `key_flows`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `flows` or `keyFlows`.
2. Fallback: list interactor class names:

```bash
grep -r "Interactor\b" "$REPO_ROOT/libs" --include="*.ts" -l \
  | xargs grep -h "^export class" 2>/dev/null \
  | sed 's/export class //' | sed 's/Interactor.*//' | sort -u | head -8 | paste -sd ', '
```

If nothing found, emit `"<key-flows>"`.

#### `stack_versions`

Read from `package.json`:

```bash
node -e "
  const p=require('$REPO_ROOT/package.json');
  const all={...p.dependencies,...p.devDependencies};
  console.log('| Package | Version |');
  console.log('|---------|---------|');
  ['@nestjs/core','@nestjs/microservices','typescript','@nx/workspace','mongoose'].forEach(k=>{
    if(all[k]) console.log('| '+k+' | '+all[k]+' |');
  });
"
```

### Frontend placeholders (angular-nx)

#### `apps`

The application shells under `apps/` (e.g. retailer, admin, supplier):

```bash
ls "$REPO_ROOT/apps" 2>/dev/null | paste -sd ', '
```

If nothing found, emit `"<apps>"`.

#### `feature_libs`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → feature list.
2. Fallback: list libs tagged `type:feature` (fall back to the bare `libs/` listing if no tags resolve):

```bash
grep -rl '"type:feature"' "$REPO_ROOT/libs" --include="project.json" 2>/dev/null \
  | sed "s#$REPO_ROOT/libs/##;s#/project.json##" | sort -u | head -12 | paste -sd ', '
```

If nothing found, emit `"<feature-libs>"`.

#### `key_flows`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `flows` or `keyFlows`.
2. Fallback: list the top-level route paths declared in the app shells:

```bash
grep -rh "path:" "$REPO_ROOT/apps" --include="*.routes.ts" 2>/dev/null \
  | grep -oE "path: *'[^']+'" | sed "s/path: *'//;s/'//" | grep -v '^$' | sort -u | head -8 | paste -sd ', '
```

If nothing found, emit `"<key-flows>"`.

#### `stack_versions`

Read from `package.json`:

```bash
node -e "
  const p=require('$REPO_ROOT/package.json');
  const all={...p.dependencies,...p.devDependencies};
  console.log('| Package | Version |');
  console.log('|---------|---------|');
  ['@angular/core','@ngxs/store','primeng','ag-grid-angular','nx','typescript'].forEach(k=>{
    if(all[k]) console.log('| '+k+' | '+all[k]+' |');
  });
"
```

### Flutter placeholders (flutter)

Flutter repos have no `package.json` or `node`. Read `pubspec.yaml` and the `lib/` tree.

#### `features`

The feature modules under `lib/features/`:

```bash
ls "$REPO_ROOT/lib/features" 2>/dev/null | paste -sd ', '
```

If nothing found, emit `"<features>"`.

#### `flavors`

The build flavors, taken from the flavored entrypoints (`lib/main_<flavor>.dart`, the very_good_cli convention):

```bash
ls "$REPO_ROOT/lib"/main_*.dart 2>/dev/null \
  | sed -E 's#.*/main_##;s#\.dart##' | sort -u | paste -sd ', '
```

If no flavored entrypoints exist, fall back to `dev, staging, production`.

#### `key_flows`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `flows` or `keyFlows`.
2. Fallback: list the route path constants declared on pages:

```bash
grep -rh "static const path" "$REPO_ROOT/lib" --include="*.dart" 2>/dev/null \
  | grep -oE "'/[^']*'" | tr -d "'" | sort -u | head -8 | paste -sd ', '
```

If nothing found, emit `"<key-flows>"`.

#### `stack_versions`

Read from `pubspec.yaml` (no `node`). Emit a markdown table of the key dependencies:

```bash
{
  echo '| Package | Version |'
  echo '|---------|---------|'
  for pkg in flutter_bloc go_router get_it dio dartz freezed_annotation hive very_good_analysis; do
    ver=$(grep -E "^  $pkg:" "$REPO_ROOT/pubspec.yaml" | head -1 | sed -E "s/^  $pkg:[[:space:]]*//")
    [ -n "$ver" ] && echo "| $pkg | $ver |"
  done
}
```

If `pubspec.yaml` is unreadable, emit `"<stack-versions>"`.

### Firebase Functions placeholders (firebase-functions)

Standalone (non-Nx) repo — the Functions package lives under `functions/`, dependency injection is Awilix, and the database is Cloud Firestore. Every command reads `functions/package.json` and the `functions/src/` tree.

#### `bounded_context`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `boundedContext` field.
2. Fallback: use the repo name minus a leading `supy-` as a rough proxy, or `"<bounded-context>"` if unclear.

#### `database`

Firestore is the standing default for this stack — emit `Cloud Firestore`. (The template already prints "Cloud Firestore" alongside; keep them consistent.)

#### `stack_versions`

Read from `functions/package.json`:

```bash
node -e "
  const p=require('$REPO_ROOT/functions/package.json');
  const all={...p.dependencies,...p.devDependencies};
  console.log('| Package | Version |');
  console.log('|---------|---------|');
  ['firebase-functions','firebase-admin','awilix','typescript','eslint'].forEach(k=>{
    if(all[k]) console.log('| '+k+' | '+all[k]+' |');
  });
"
```

If `functions/package.json` is unreadable, emit `"<stack-versions>"`.

#### Remediation-status placeholders

This template carries a **Remediation status** block instead of `key_flows`. Set each status from a static probe of the repo — this repo is being brought up to Supy baseline, so most start as gaps. Report factually; never overstate. If a probe is inconclusive, emit `unknown — verify`.

```bash
# lint_status: ESLint present vs still TSLint
{ [ -f "$REPO_ROOT/functions/eslint.config.mjs" ] || [ -f "$REPO_ROOT/functions/.eslintrc.js" ]; } \
  && LINT="ESLint configured" || LINT="gap — still TSLint / no ESLint config"

# test_status: any Jest spec present
grep -rlsq --include='*.spec.ts' --include='*.test.ts' . "$REPO_ROOT/functions/src" 2>/dev/null \
  && TEST="specs present" || TEST="gap — no Jest specs found"

# ci_status: a CI workflow present
{ [ -f "$REPO_ROOT/.github/workflows/ci.yml" ] || ls "$REPO_ROOT/.github/workflows/"*.yml >/dev/null 2>&1; } \
  && CI="workflow present" || CI="gap — no CI workflow"

# precommit_status: Husky hook present
[ -f "$REPO_ROOT/functions/.husky/pre-commit" ] || [ -f "$REPO_ROOT/.husky/pre-commit" ] \
  && PRECOMMIT="pre-commit hook present" || PRECOMMIT="gap — no pre-commit hook"

# secrets_status: NEVER inspect or echo any secret value — only note that a manual audit is required.
SECRETS="gap — audit for hardcoded credentials, migrate to Secret Manager"
```

Map `LINT → {{lint_status}}`, `TEST → {{test_status}}`, `CI → {{ci_status}}`, `PRECOMMIT → {{precommit_status}}`, `SECRETS → {{secrets_status}}`. **Never** print a secret value into any placeholder — the secrets probe deliberately reports only that an audit is needed, never a matched string.

The floor these `ci_status` / `test_status` / `precommit_status` gaps are measured against is the cross-cutting standard `${CLAUDE_PLUGIN_ROOT}/config/standards/ci-coverage-baseline.md` (CI triggers + fail-fast ordering, coverage floor enforced as a gate, gitleaks-first pre-commit from unit 1). For the remediation-first repos (firebase-functions, ts-cli, ai-agents) these are **target-state** gaps the scaffold closes — report them, but the only always-on item is the blocking secret scan. Point fix hints at that standard rather than re-describing the baseline inline.

### ts-cli placeholders (ts-cli)

Standalone (non-Nx) commander.js MongoDB scripts runner — a single package at the repo root (no `functions/` subdir), talking to MongoDB via Mongoose. Every command reads the repo-root `package.json` and the `src/` tree. Like `firebase-functions`, this template carries a **Remediation status** block instead of `key_flows`.

#### `databases`

The MongoDB databases the CLI targets. Prefer the layered-env key names, never a connection string.

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → database targets.
2. Fallback: derive the target names from the `*_URI` env keys in `.env.example` (never read `.env`, and never echo a value):

```bash
grep -oE '^(DEV|PROD)_[A-Z0-9]+_URI' "$REPO_ROOT/.env.example" 2>/dev/null \
  | sed -E 's/^(DEV|PROD)_//;s/_URI$//' | tr 'A-Z' 'a-z' | sort -u | paste -sd ', '
```

If nothing found, emit `"<databases>"`.

#### `stack_versions`

Read from the repo-root `package.json`:

```bash
node -e "
  const p=require('$REPO_ROOT/package.json');
  const all={...p.dependencies,...p.devDependencies};
  console.log('| Package | Version |');
  console.log('|---------|---------|');
  ['commander','mongoose','inquirer','chalk','typescript','eslint'].forEach(k=>{
    if(all[k]) console.log('| '+k+' | '+all[k]+' |');
  });
"
```

If `package.json` is unreadable, emit `"<stack-versions>"`.

#### Remediation-status placeholders

Set each status from a static probe of the repo root (no `functions/` subdir). Report factually; never overstate. If a probe is inconclusive, emit `unknown — verify`.

```bash
# lint_status: flat ESLint 9 present vs still ESLint 8 (.eslintrc)
[ -f "$REPO_ROOT/eslint.config.mjs" ] \
  && LINT="flat ESLint 9 configured" || LINT="gap — still ESLint 8 (.eslintrc) / no flat config"

# test_status: any Jest spec present
grep -rlsq --include='*.spec.ts' --include='*.test.ts' . "$REPO_ROOT/src" 2>/dev/null \
  && TEST="specs present" || TEST="gap — no Jest specs found"

# ci_status: a CI workflow present
{ [ -f "$REPO_ROOT/.github/workflows/ci.yml" ] || ls "$REPO_ROOT/.github/workflows/"*.yml >/dev/null 2>&1; } \
  && CI="workflow present" || CI="gap — no CI workflow"

# precommit_status: Husky hook present
[ -f "$REPO_ROOT/.husky/pre-commit" ] \
  && PRECOMMIT="pre-commit hook present" || PRECOMMIT="gap — no pre-commit hook"

# secrets_status: NEVER inspect or echo any secret value — only note that a manual audit is required.
SECRETS="gap — audit for hardcoded URIs/credentials, confirm none in argv or logs, migrate to layered env"
```

Map `LINT → {{lint_status}}`, `TEST → {{test_status}}`, `CI → {{ci_status}}`, `PRECOMMIT → {{precommit_status}}`, `SECRETS → {{secrets_status}}`. **Never** print a secret value into any placeholder.

### ai-agents placeholders (ai-agents)

Polyglot AI-agents monorepo (non-Nx, **no root orchestration**) — Node.js, Python, and Cloudflare Workers packages that are each self-contained, with per-team ownership. There is no root `package.json`, so every probe scans the tree (excluding `node_modules`). Like `firebase-functions` and `ts-cli`, this template carries a **Remediation status** block instead of `key_flows`, and it uses `{{packages}}` in place of a single `{{database}}`/`{{databases}}`.

#### `packages`

The independent packages that make up the monorepo (e.g. cortex, nexus, oculus, gleap, pms-ai).

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → package/module list.
2. Fallback: list the directories that carry a package manifest one level down, excluding `node_modules` and dotfolders:

```bash
{
  find "$REPO_ROOT" -maxdepth 3 \( -name package.json -o -name pyproject.toml -o -name wrangler.toml \) \
    -not -path '*/node_modules/*' 2>/dev/null \
    | sed -E "s#^$REPO_ROOT/##;s#/(package\.json|pyproject\.toml|wrangler\.toml)\$##" \
    | grep -v '^\.' | awk -F/ '{print $1}' | sort -u | paste -sd ', '
}
```

If nothing found, emit `"<packages>"`.

#### `stack_versions`

Polyglot — there is no single manifest. Emit a best-effort table of the runtimes/frameworks found across packages. Never fail if a manifest is missing; skip what is absent.

```bash
{
  echo '| Component | Detected |'
  echo '|-----------|----------|'
  grep -rlsq --include='package.json' --exclude-dir='node_modules' -e '@modelcontextprotocol/sdk' "$REPO_ROOT" 2>/dev/null \
    && echo '| MCP SDK (@modelcontextprotocol/sdk) | present |'
  grep -rlsq --include='package.json' --exclude-dir='node_modules' -e '@anthropic-ai/claude-agent-sdk' "$REPO_ROOT" 2>/dev/null \
    && echo '| Claude Agent SDK | present |'
  grep -rlsq --include='package.json' --exclude-dir='node_modules' -e '"express"' "$REPO_ROOT" 2>/dev/null \
    && echo '| Express | present |'
  grep -rlsq --include='package.json' --exclude-dir='node_modules' -e '"bullmq"' "$REPO_ROOT" 2>/dev/null \
    && echo '| BullMQ (Redis) | present |'
  grep -rlsq --include='*.toml' -e 'fastapi' "$REPO_ROOT" 2>/dev/null \
    && echo '| FastAPI (Python) | present |'
  { [ -f "$REPO_ROOT/wrangler.toml" ] || grep -rlsq --include='wrangler.toml' -e '' "$REPO_ROOT" 2>/dev/null; } \
    && echo '| Cloudflare Workers (wrangler) | present |'
}
```

If the table has no rows, emit `"<stack-versions>"`.

#### Remediation-status placeholders

Set each status from a static probe of the whole tree (no root orchestration — probes are recursive and exclude `node_modules`). Report factually; never overstate. If a probe is inconclusive, emit `unknown — verify`.

```bash
# lint_status: a flat ESLint 9 config and/or Python Ruff config present anywhere
{ grep -rlsq --include='eslint.config.mjs' --include='eslint.config.js' --exclude-dir='node_modules' -e '' "$REPO_ROOT" 2>/dev/null \
  || grep -rlsq --include='ruff.toml' --include='pyproject.toml' --exclude-dir='node_modules' -e 'ruff' "$REPO_ROOT" 2>/dev/null; } \
  && LINT="lint config present (ESLint/Ruff)" || LINT="gap — no shared ESLint/Ruff config across packages"

# test_status: any test present across the polyglot tree (node --test / vitest / jest specs or pytest)
{ grep -rlsq --include='*.test.ts' --include='*.test.js' --include='*.spec.ts' --exclude-dir='node_modules' -e '' "$REPO_ROOT" 2>/dev/null \
  || grep -rlsq --include='test_*.py' --include='*_test.py' --exclude-dir='node_modules' -e '' "$REPO_ROOT" 2>/dev/null; } \
  && TEST="tests present" || TEST="gap — few/no tests found"

# ci_status: a CI workflow present
{ [ -f "$REPO_ROOT/.github/workflows/ci.yml" ] || ls "$REPO_ROOT/.github/workflows/"*.yml >/dev/null 2>&1; } \
  && CI="workflow present" || CI="gap — no CI workflow"

# precommit_status: a Husky/pre-commit hook present anywhere
{ [ -f "$REPO_ROOT/.husky/pre-commit" ] || grep -rlsq --include='pre-commit' --exclude-dir='node_modules' -e '' "$REPO_ROOT/.husky" 2>/dev/null; } \
  && PRECOMMIT="pre-commit hook present" || PRECOMMIT="gap — no pre-commit hook / no uniform secret scan"

# secrets_status: NEVER inspect or echo any secret value — only note that a manual audit is required.
SECRETS="gap — audit for hardcoded API keys/tokens/OAuth secrets across packages, migrate to env / wrangler secrets"
```

Map `LINT → {{lint_status}}`, `TEST → {{test_status}}`, `CI → {{ci_status}}`, `PRECOMMIT → {{precommit_status}}`, `SECRETS → {{secrets_status}}`. **Never** print a secret value into any placeholder — the secrets probe deliberately reports only that an audit is needed, never a matched string.

---

## Step 3 — Fill the template and compute the diff

Substitute each placeholder in the `$TEMPLATE` selected in Step 2 with the values collected there. Replace every `{{placeholder}}` token (Handlebars-style) with the corresponding value. Every template uses `{{one_line_purpose}}` in two places — both must be filled identically. Fill only the placeholders the selected template actually contains (backend: `bounded_context`, `database`, `aggregates`, `nats_patterns`; frontend: `apps`, `feature_libs`; flutter: `features`, `flavors`; firebase-functions: `bounded_context`, `database`, `lint_status`, `test_status`, `ci_status`, `precommit_status`, `secrets_status`; ts-cli: `databases`, `lint_status`, `test_status`, `ci_status`, `precommit_status`, `secrets_status`; ai-agents: `packages`, `lint_status`, `test_status`, `ci_status`, `precommit_status`, `secrets_status`).

Produce the candidate content as an in-memory string called `GENERATED`.

### Append the skill-routing footer (stack-scoped)

So the generated `CLAUDE.md` tells Claude which skill handles which engineering action **in this
repo** — and only the skills relevant to *this* repo's stack — append a stack-scoped slice of the
canonical routing block. A backend dev's `CLAUDE.md` must not list Flutter skills, and vice-versa.

`skills/shared/references/skill-routing.md` is structured as one **Universal** table (always applies)
followed by per-stack blocks fenced with `<!-- STACK:<id> -->` / `<!-- /STACK:<id> -->` markers.
Append the universal part plus **only** the block whose id equals the `$STACK` detected in Step 2,
with the marker comment lines stripped:

```bash
ROUTING="${CLAUDE_PLUGIN_ROOT}/skills/shared/references/skill-routing.md"
if [ -r "$ROUTING" ]; then
  # Universal part: from the heading up to (but not including) the first stack marker.
  sed -n '/^## Using Supy skills/,/^<!-- STACK:/p' "$ROUTING" | sed '$d'
  # This repo's stack block only (markers removed). Nothing emitted for nx/generic/k8s-config.
  sed -n "/^<!-- STACK:${STACK} -->\$/,/^<!-- \/STACK:${STACK} -->\$/p" "$ROUTING" \
    | sed '1d;$d'
fi
```

Append that combined output to `GENERATED`, separated by a blank line. If the reference is missing or
unreadable, skip this append rather than failing — the rest of the generated file is still valid.
Stacks without a block (`nx`, `generic`, `k8s-config`) get the universal table only. Keep the routing
file's intents in sync with `hooks/skill-router.sh`.

### Overwrite gate

Check whether `CLAUDE.md` already exists in the repo root:

```bash
[ -f "$REPO_ROOT/CLAUDE.md" ] && EXISTING=true || EXISTING=false
```

**If `EXISTING=true`:**

1. Write `GENERATED` to a temp file (`/tmp/supy-baseline-generated.md`).
2. Show the diff between the existing file and the generated content:

```bash
diff --unified "$REPO_ROOT/CLAUDE.md" /tmp/supy-baseline-generated.md
```

3. **Ask the user** before proceeding:

```text
supy-baseline: CLAUDE.md already exists at <REPO_ROOT>/CLAUDE.md.
The diff above shows what would change.
Overwrite? [y/N]
```

- If the user answers `y` or `yes` (case-insensitive): proceed to write.
- Any other answer (or no answer): stop and print `supy-baseline: skipped — existing CLAUDE.md preserved`.
- Never clobber silently under any circumstance.

**If `EXISTING=false`:**

Write `GENERATED` directly to `$REPO_ROOT/CLAUDE.md`.

Print a confirmation:

```text
supy-baseline: wrote CLAUDE.md → <REPO_ROOT>/CLAUDE.md
```

---

## Step 4 — Report missing AI-setup pieces

Run each check against `$REPO_ROOT` regardless of whether a `CLAUDE.md` was written (the checklist is always emitted).

### Checklist items

**1. Cortex MCP not configured**

Check whether Cortex MCP is wired up in the repo-level settings. Cortex may be configured in `.claude/settings.json`, `.claude/settings.local.json`, or the workspace-level `settings.local.json` at the repo root.

```bash
grep -rl "cortex\|Cortex" \
  "$REPO_ROOT/.claude/settings.json" \
  "$REPO_ROOT/.claude/settings.local.json" \
  "$REPO_ROOT/settings.local.json" \
  2>/dev/null | grep -q . && CORTEX_CONFIGURED=true || CORTEX_CONFIGURED=false
```

If `CORTEX_CONFIGURED=false`, flag as missing.

**2. `.claude/settings.json` absent**

```bash
[ -f "$REPO_ROOT/.claude/settings.json" ] && SETTINGS_OK=true || SETTINGS_OK=false
```

**3. No `CODEOWNERS`**

```bash
( [ -f "$REPO_ROOT/CODEOWNERS" ] || [ -f "$REPO_ROOT/.github/CODEOWNERS" ] ) \
  && CODEOWNERS_OK=true || CODEOWNERS_OK=false
```

**4. No `.claude/` directory at all**

```bash
[ -d "$REPO_ROOT/.claude" ] && CLAUDE_DIR_OK=true || CLAUDE_DIR_OK=false
```

**5. `CLAUDE.md` absent (after generation attempt)**

```bash
[ -f "$REPO_ROOT/CLAUDE.md" ] && CLAUDE_MD_OK=true || CLAUDE_MD_OK=false
```

### Emit the checklist

Print the report in this format:

```text
## supy-baseline — AI Setup Checklist for <REPO_NAME>

- [x/☐] Cortex MCP configured         (settings.json / settings.local.json)
- [x/☐] .claude/settings.json present
- [x/☐] CODEOWNERS present             (.github/CODEOWNERS or repo root)
- [x/☐] .claude/ directory present
- [x/☐] CLAUDE.md present
```

Use `[x]` for items that are present/passing and `[☐]` for items that are missing.

If any items are missing, append fix hints:

```text
### Fix hints

- **Cortex MCP**: add the Cortex MCP server block to .claude/settings.json — see ${CLAUDE_PLUGIN_ROOT}/config/standards/architecture.md for the required structure.
- **.claude/settings.json**: create the file with at minimum {"mcpServers": {}}.
- **CODEOWNERS**: add .github/CODEOWNERS listing team reviewers for the repo.
- **.claude/ directory**: run `mkdir -p .claude` in the repo root.
- **CLAUDE.md**: re-run supy-baseline to generate it.
```

Only emit hints for items that are actually missing.

---

## Degradation paths

- **Cortex unavailable** (not connected, unauthenticated, or any MCP error): silently fall back to static inspection for every placeholder. Never print an error for missing Cortex — it is optional. The checklist item "Cortex MCP configured" reports its absence independently.
- **`package.json` unreadable**: use `"<stack-versions>"` for the `stack_versions` placeholder and continue.
- **No lib files found** (empty or non-standard repo): use the `"<placeholder>"` default for every value that could not be resolved (`"<aggregates>"`, `"<feature-libs>"`, etc.) and continue.
- **Template file absent** (the `$TEMPLATE` selected in Step 2 not found): stop generation and print:

```text
supy-baseline: template not found at $TEMPLATE — cannot generate CLAUDE.md.
Reporting missing-pieces checklist only.
```

  Then proceed to Step 4 to emit the checklist.
