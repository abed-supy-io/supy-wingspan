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

```
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

# Generic fallback
[ -z "$STACK" ] && STACK=generic
```

Template generation is supported for **`nestjs-nx`** (backend), **`angular-nx`** (frontend), **`flutter`** (mobile), and **`firebase-functions`** (standalone Firebase Functions backend). For any other stack (`nx`, `generic`) this skill only emits the missing-pieces checklist (Step 4) and skips template generation. In that case print a notice:

```
supy-baseline: stack detected as <STACK>; template generation is only supported for nestjs-nx, angular-nx, flutter, and firebase-functions repos.
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
else
  TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.hbs"
fi
```

Collect each placeholder value from the repo. If Cortex MCP is connected, augment with live data; otherwise fall back to static inspection. Every Cortex call is optional — never hard-fail if Cortex is absent.

Every template shares `repo_name`, `one_line_purpose`, and `stack_versions`. Fill the **Backend placeholders (nestjs-nx)** block for a `nestjs-nx` repo, the **Frontend placeholders (angular-nx)** block for an `angular-nx` repo, the **Flutter placeholders (flutter)** block for a `flutter` repo, or the **Firebase Functions placeholders (firebase-functions)** block for a `firebase-functions` repo. Flutter repos have no `package.json` — every command in the flutter block reads `pubspec.yaml` and the `lib/` tree instead, with no `node`. The `nestjs-nx`, `angular-nx`, and `flutter` blocks additionally fill `key_flows`; the `firebase-functions` template omits `key_flows` and instead carries a **Remediation status** block (see its placeholder block below).

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

---

## Step 3 — Fill the template and compute the diff

Substitute each placeholder in the `$TEMPLATE` selected in Step 2 with the values collected there. Replace every `{{placeholder}}` token (Handlebars-style) with the corresponding value. Every template uses `{{one_line_purpose}}` in two places — both must be filled identically. Fill only the placeholders the selected template actually contains (backend: `bounded_context`, `database`, `aggregates`, `nats_patterns`; frontend: `apps`, `feature_libs`; flutter: `features`, `flavors`; firebase-functions: `bounded_context`, `database`, `lint_status`, `test_status`, `ci_status`, `precommit_status`, `secrets_status`).

Produce the candidate content as an in-memory string called `GENERATED`.

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

```
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

```
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

```
## supy-baseline — AI Setup Checklist for <REPO_NAME>

- [x/☐] Cortex MCP configured         (settings.json / settings.local.json)
- [x/☐] .claude/settings.json present
- [x/☐] CODEOWNERS present             (.github/CODEOWNERS or repo root)
- [x/☐] .claude/ directory present
- [x/☐] CLAUDE.md present
```

Use `[x]` for items that are present/passing and `[☐]` for items that are missing.

If any items are missing, append fix hints:

```
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

```
supy-baseline: template not found at $TEMPLATE — cannot generate CLAUDE.md.
Reporting missing-pieces checklist only.
```

  Then proceed to Step 4 to emit the checklist.
