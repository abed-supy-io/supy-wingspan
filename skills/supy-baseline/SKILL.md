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

Detect the stack by inspecting the root:

```bash
# NestJS/Nx backend
[ -f "$REPO_ROOT/nx.json" ] && [ -f "$REPO_ROOT/package.json" ] && STACK=nestjs-nx

# Flutter (fallback)
[ -f "$REPO_ROOT/pubspec.yaml" ] && STACK=flutter

# Generic fallback
[ -z "$STACK" ] && STACK=generic
```

For a `generic` or `flutter` stack this skill currently only emits the missing-pieces checklist (Step 4) and skips template generation. Print a notice:

```
supy-baseline: stack detected as <STACK>; template generation is only supported for nestjs-nx repos.
Reporting missing AI-setup pieces only.
```

---

## Step 2 — Gather template inputs (nestjs-nx only)

Read the Handlebars template from the plugin:

```bash
TEMPLATE="${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.hbs"
```

Collect each placeholder value from the repo. If Cortex MCP is connected, augment with live data; otherwise fall back to static inspection. Every Cortex call is optional — never hard-fail if Cortex is absent.

### `repo_name`

```bash
echo "$REPO_NAME"
```

### `one_line_purpose`

1. If Cortex is connected, call `get_repo_guide('$REPO_NAME')` and extract the `description` or `summary` field.
2. Fallback: read the first non-heading, non-blank line of the existing `CLAUDE.md` (if present), or read the `description` field in `package.json`. If neither exists, use `"<purpose — fill me in>"`.

### `bounded_context`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `boundedContext` field.
2. Fallback: infer from the directory name under `libs/` that contains the most source files (`ls libs/ | head -1`). If unclear, use `"<bounded-context>"`.

### `database`

Inspect `package.json` dependencies for `mongoose` or `@nestjs/mongoose`; if found, emit `MongoDB`. Otherwise emit `"<database>"`.

```bash
grep -q '"mongoose"' "$REPO_ROOT/package.json" && DB=MongoDB || DB="<database>"
```

### `aggregates`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `aggregates` list.
2. Fallback: grep for aggregate root class names:

```bash
grep -r "extends.*Aggregate\|AggregateRoot" "$REPO_ROOT/libs" --include="*.ts" -l \
  | xargs grep -h "^export class" 2>/dev/null \
  | sed 's/export class //' | sed 's/ .*//' | sort -u | head -10 | paste -sd ', '
```

If nothing found, emit `"<aggregates>"`.

### `nats_patterns`

1. Cortex (if connected): `trace_implementation` or `search_relationships` for the repo.
2. Fallback: grep for `@MessagePattern` and `@EventPattern` subjects:

```bash
grep -r "@MessagePattern\|@EventPattern" "$REPO_ROOT/libs" --include="*.ts" -h \
  | grep -oP "(?<=['\"])[^'\"]+(?=['\"])" | sort -u | head -10 | paste -sd ', '
```

If nothing found, emit `"<nats-patterns>"`.

### `key_flows`

1. Cortex (if connected): `get_repo_guide('$REPO_NAME')` → `flows` or `keyFlows`.
2. Fallback: list interactor class names:

```bash
grep -r "Interactor\b" "$REPO_ROOT/libs" --include="*.ts" -l \
  | xargs grep -h "^export class" 2>/dev/null \
  | sed 's/export class //' | sed 's/Interactor.*//' | sort -u | head -8 | paste -sd ', '
```

If nothing found, emit `"<key-flows>"`.

### `stack_versions`

Read from `package.json`:

```bash
node -e "
  const p=require('$REPO_ROOT/package.json');
  const all={...p.dependencies,...p.devDependencies};
  const v=k=>all[k]||'n/a';
  console.log('| Package | Version |');
  console.log('|---------|---------|');
  ['@nestjs/core','@nestjs/microservices','typescript','@nx/workspace','mongoose'].forEach(k=>{
    if(all[k]) console.log('| '+k+' | '+all[k]+' |');
  });
"
```

---

## Step 3 — Fill the template and compute the diff

Substitute each placeholder in `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.hbs` with the values collected in Step 2. Replace every `{{placeholder}}` token (Handlebars-style) with the corresponding value. The template uses `{{one_line_purpose}}` in two places — both must be filled identically.

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
- **No lib files found** (empty or non-standard repo): use `"<aggregates>"`, `"<nats-patterns>"`, `"<key-flows>"` as placeholder values and continue.
- **Template file absent** (`${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.hbs` not found): stop generation and print:

```
supy-baseline: template not found at ${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.hbs — cannot generate CLAUDE.md.
Reporting missing-pieces checklist only.
```

  Then proceed to Step 4 to emit the checklist.
