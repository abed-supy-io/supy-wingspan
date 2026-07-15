---
name: supy-scaffold-handler
description: Scaffold a new NestJS NATS message/event handler in a supy backend repo following Supy Nx/NestJS conventions (handler + DTO + test). Use when adding a new NATS pattern to a service.
---

## Step 1 — Read the governing standards

Read both standards files so all subsequent decisions are grounded in them:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/nats-event-patterns.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/nx-nestjs-patterns.md"
```

Internalize every rule before proceeding. Key rules that govern this scaffold:

**From `nats-event-patterns.md`:**
- Rule 1: RPC subject format is `<domain>.<entity>.<verb>` (verb present-tense, e.g. `ledger.items.stock-movement`). The controller file is `*.rpc.controller.ts` and must be decorated with `@UseFilters(NatsExceptionFilter)`.
- Rule 2: Event subject format is `<source-domain>.<aggregate>.<event-name>` (event-name kebab-case past-tense, e.g. `inventory.transfer.transfer-submitted`). The controller file is `*.nats.controller.ts` and must be decorated with `@UseFilters(JetStreamExceptionFilter)`.
- Rule 3: All three subject segments must be kebab-case — no camelCase or PascalCase.
- Rule 6: Payload must be validated via `StrictValidationPipe`.
- Rule 7: RPC handlers must return a typed reply object — never `void` or `any`.
- Rule 8: Event handlers delegate all logic to an interactor (or listener); no business logic inline.
- Rule 10: If the same event subject is consumed by multiple handlers in the same service, add a `{ discriminator: 'unique-id' }` option on `@EventPattern`.

**From `nx-nestjs-patterns.md`:**
- Rule 9: Handler/controller files live at `libs/<domain>/api/src/*.rpc.controller.ts` (RPC) and `libs/<domain>/api/src/*.nats.controller.ts` (events).
- Rule 10: DTOs live exclusively in `api/src/lib/exchanges/` (exchange types) or `api/src/lib/dtos/` (standalone DTOs). Never in `logic/` or `domain/`.
- Rule 15: Spec files are co-located with source (`*.spec.ts` next to `*.ts`).
- Rule 16: Tests use `Test.createTestingModule()` from `@nestjs/testing`; call `jest.resetAllMocks()` in `afterEach`.
- Rule 19 (Cortex rule-0007, must): All new business logic must have `*.spec.ts` files. Specs must assert the domain outcome — a lone `toBeDefined()` does not satisfy this rule.

If either standards file is unreadable, print a warning and continue using the rules stated above as a fallback — do not abort.

## Step 2 — Collect scaffolding inputs

Resolve the repo root:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
```

If `git rev-parse` fails (not a git repo), stop and print:

```
supy-scaffold-handler: not inside a git repository — nothing to scaffold
```

Ask the user for the three required inputs. If `$ARGUMENTS` was passed, parse them from it in order (pattern, project, type); otherwise prompt interactively:

```
supy-scaffold-handler needs three pieces of information:

1. NATS subject pattern — e.g. "ledger.items.get-one" (RPC) or "inventory.transfer.transfer-submitted" (event)
2. Target Nx project name — e.g. "ledger-api" (run `nx show projects` if unsure)
3. Handler type — enter "request" (NATS request/reply via @MessagePattern) or "event" (JetStream via @EventPattern)
```

Capture the answers as `NATS_PATTERN`, `NX_PROJECT`, and `HANDLER_TYPE`.

### Validate the NATS pattern

Check that `NATS_PATTERN` contains exactly three dot-separated kebab-case segments:

```bash
echo "$NATS_PATTERN" | grep -qP '^[a-z][a-z0-9-]*\.[a-z][a-z0-9-]*\.[a-z][a-z0-9-]*$'
```

If validation fails, stop and print:

```
supy-scaffold-handler: invalid NATS pattern "<NATS_PATTERN>".
  RPC format:   <domain>.<entity>.<verb>       e.g. ledger.items.get-one
  Event format: <source-domain>.<aggregate>.<past-tense-event>  e.g. inventory.transfer.transfer-submitted
All three segments must be lowercase kebab-case.
```

For `HANDLER_TYPE=event`, also check that the third segment looks like a past-tense verb (ends in `-ed`, `-d`, or a recognised past form). If it does not, print a **warning** (not a stop):

```
supy-scaffold-handler: warning — event subject third segment "<segment>" does not appear to be past-tense (rule 2 in nats-event-patterns.md). Proceed? [y/N]
```

Abort unless the user confirms.

### Derive the domain name

Extract the first segment of `NATS_PATTERN` as the domain anchor:

```bash
DOMAIN=$(echo "$NATS_PATTERN" | cut -d. -f1)
```

## Step 3 — Locate the target library and resolve file paths

### Find the Nx library root

Look up the Nx project's root directory. Prefer reading `project.json` via the Nx CLI; fall back to filesystem search:

```bash
# Preferred: Nx CLI
LIB_ROOT=$(nx show project "$NX_PROJECT" --json 2>/dev/null | grep '"root"' | head -1 | grep -oP '(?<=": ")[^"]+')

# Fallback: find project.json
if [ -z "$LIB_ROOT" ]; then
  LIB_ROOT=$(find "$REPO_ROOT" -name project.json -not -path "*/node_modules/*" \
    | xargs grep -l "\"name\":\s*\"$NX_PROJECT\"" 2>/dev/null \
    | head -1 | xargs dirname)
fi
```

If `LIB_ROOT` is still empty, stop and print:

```
supy-scaffold-handler: could not locate Nx project "<NX_PROJECT>".
Run `nx show projects` in the repo to list all projects and re-run with the correct name.
```

### Resolve controller, DTO, and spec paths

Derive the controller and DTO naming base from the NATS pattern:

```bash
# e.g. "ledger.items.get-one" → base "ledger-items-get-one", domain "ledger"
PATTERN_BASE=$(echo "$NATS_PATTERN" | tr '.' '-')
DOMAIN_BASE=$(echo "$NATS_PATTERN" | cut -d. -f1)
```

Set file paths according to `nx-nestjs-patterns.md` rules 9, 10, and 15.

First, probe whether the library uses the `src/lib/` layout (produced by `@nx/nest:library`) or the flat `src/` layout, and set `API_SRC` accordingly so that controller, DTO, and spec are truly co-located:

```bash
# Probe for src/lib/ layout (common output of @nx/nest:library)
if [ -d "$REPO_ROOT/$LIB_ROOT/src/lib" ]; then
  API_SRC="$REPO_ROOT/$LIB_ROOT/src/lib"
else
  API_SRC="$REPO_ROOT/$LIB_ROOT/src"
fi

if [ "$HANDLER_TYPE" = "request" ]; then
  CONTROLLER_FILE="$API_SRC/${DOMAIN_BASE}.rpc.controller.ts"
  CONTROLLER_SPEC="$API_SRC/${DOMAIN_BASE}.rpc.controller.spec.ts"
else
  CONTROLLER_FILE="$API_SRC/${DOMAIN_BASE}.nats.controller.ts"
  CONTROLLER_SPEC="$API_SRC/${DOMAIN_BASE}.nats.controller.spec.ts"
fi

# DTOs go in exchanges/ (exchange types) per rule 10 — derived from API_SRC
DTO_DIR="$API_SRC/exchanges"
DTO_FILE="$DTO_DIR/${PATTERN_BASE}.dto.ts"
```

If the controller file already exists it will be **appended to** (a new method added), not replaced. If it does not exist it will be created. Note this distinction in the plan shown to the user.

## Step 4 — Check for an existing Nx generator

Before falling back to copy-from-template, check whether the repo defines or installs a generator that can scaffold handlers:

```bash
# Check nx.json and installed plugins for handler/controller generators
cat "$REPO_ROOT/nx.json" 2>/dev/null | grep -i "generator\|plugin" | head -20

# List any locally installed generator collections
ls "$REPO_ROOT/tools/generators" 2>/dev/null
find "$REPO_ROOT/libs" -maxdepth 3 -type d -name "generators" 2>/dev/null

# Check for @nx/nest or @nestjs-nx generators
cat "$REPO_ROOT/package.json" | grep -i "\"@nx/nest\|nestjs-nx\|@nrwl/nest"
```

If a matching generator is found (e.g. `nx g @nx/nest:controller`, `nx g @nx/nest:resource`, or a local `nx g <workspace>:handler`), prefer it:

```bash
nx g <generator> --project="$NX_PROJECT" --name="$DOMAIN_BASE" --dry-run
```

Review the dry-run output to confirm the generated paths match the file locations derived in Step 3. If they do, use the generator (without `--dry-run`) for the controller and any boilerplate it produces. Supplement with the DTO and spec files from Step 6 as needed.

If no suitable generator is found, proceed to the copy-from-template path in Step 5.

## Step 5 — Resolve the scaffold template

If no Nx generator was used, find the nearest existing handler of the same type in `$REPO_ROOT` to use as a template:

```bash
if [ "$HANDLER_TYPE" = "request" ]; then
  TEMPLATE_SRC=$(find "$REPO_ROOT/libs" -name "*.rpc.controller.ts" \
    -not -path "*/node_modules/*" -not -name "*.spec.ts" | head -1)
else
  TEMPLATE_SRC=$(find "$REPO_ROOT/libs" -name "*.nats.controller.ts" \
    -not -path "*/node_modules/*" -not -name "*.spec.ts" | head -1)
fi
```

If no template is found, use the inline stub in Step 6 directly.

If Cortex MCP is available, augment the template with live contract information for the pattern:

```
Cortex: get_handler_contract("<NATS_PATTERN>")
Cortex: get_entity("<DOMAIN>")
```

Use the Cortex output to pre-fill method names, payload type names, and return types. If Cortex is unavailable, derive names by converting the pattern to PascalCase (e.g. `ledger.items.get-one` → `GetOnePayload`, `GetOneReply`).

## Step 6 — Build the planned file content

Generate the file content in memory. Do not write any files yet.

### Controller method to add / create

For `HANDLER_TYPE=request`, generate:

```typescript
// In ${DOMAIN_BASE}.rpc.controller.ts
import { Controller, UseFilters } from '@nestjs/common/decorators';
import { MessagePattern, Payload } from '@nestjs/microservices';
import { NatsExceptionFilter } from '@supy/common/filters';  // adjust alias to repo
import { StrictValidationPipe } from '@supy/common/pipes';   // adjust alias to repo
import { <PayloadClass> } from './exchanges/<PATTERN_BASE>.dto';
import { <ReplyClass> } from './exchanges/<PATTERN_BASE>.dto';

@Controller()
@UseFilters(NatsExceptionFilter)
export class <DomainPascal>RpcController {
  @MessagePattern('<NATS_PATTERN>')
  async handle<MethodName>(
    @Payload(StrictValidationPipe) payload: <PayloadClass>,
  ): Promise<<ReplyClass>> {
    return await this.<interactorName>.execute(payload);
  }
}
```

For `HANDLER_TYPE=event`, generate:

```typescript
// In ${DOMAIN_BASE}.nats.controller.ts
import { Controller, UseFilters } from '@nestjs/common/decorators';
import { EventPattern, Payload } from '@nestjs/microservices';
import { JetStreamExceptionFilter } from '@supy/common/filters';  // adjust alias to repo
import { StrictValidationPipe } from '@supy/common/pipes';        // adjust alias to repo
import { <PayloadClass>, options } from './exchanges/<PATTERN_BASE>.dto';

@Controller()
@UseFilters(JetStreamExceptionFilter)
export class <DomainPascal>NatsController {
  @EventPattern('<NATS_PATTERN>')
  async handle<MethodName>(
    @Payload(new StrictValidationPipe(<PayloadClass>, options))
    payload: <PayloadClass>,
  ): Promise<void> {
    await this.<listenerName>.execute(payload.data);
  }
}
```

Replace placeholder names (`<PayloadClass>`, `<ReplyClass>`, `<DomainPascal>`, `<MethodName>`, `<interactorName>`, `<listenerName>`) using the pattern and Cortex data resolved in Step 5. Derive PascalCase names from the NATS pattern by converting each kebab segment.

### DTO file

Generate a DTO stub at `$DTO_FILE`:

```typescript
// <PATTERN_BASE>.dto.ts
import { IsString } from 'class-validator';

export class <PayloadClass> {
  // TODO: add validated fields matching the NATS payload contract
  @IsString()
  readonly id: string;
}

// RPC only — remove for event handlers
export class <ReplyClass> {
  // TODO: add reply fields
}
```

### Spec file (co-located, mandatory per rule 19)

Generate a spec stub at `$CONTROLLER_SPEC`. The spec must assert the handler wiring — a lone `toBeDefined()` does not satisfy rule 19:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { <ControllerClass> } from './<DOMAIN_BASE>.<type>.controller';

describe('<ControllerClass>', () => {
  let controller: <ControllerClass>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [<ControllerClass>],
      providers: [
        // TODO: provide mocked interactor/listener from @supy/<domain>/mocks
      ],
    }).compile();

    controller = module.get<<ControllerClass>>(<ControllerClass>);
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should delegate to the interactor/listener on valid payload', async () => {
    // TODO: arrange mock, act by calling controller.handle<MethodName>(...), assert delegated call
    // Example: expect(mockInteractor.execute).toHaveBeenCalledWith(expect.objectContaining({ id: '1' }));
  });
});
```

## Step 7 — Show the plan and get confirmation

Before writing any file, print the full plan:

```
supy-scaffold-handler: planned changes for pattern "<NATS_PATTERN>"

  Handler type : <request|event>
  Nx project   : <NX_PROJECT>
  Scaffold via : <"Nx generator: nx g <generator>" | "copy-from-template: <TEMPLATE_SRC>" | "inline stub">

  Files to create or modify:
    [create|append]  <CONTROLLER_FILE>
    [create]         <DTO_FILE>
    [create]         <CONTROLLER_SPEC>

  NB: If the controller file already exists, a new handler method will be appended to the class.
      A discriminator option may be needed if the same subject is already handled — check rule 10
      in nats-event-patterns.md.

Proceed with scaffold? [y/N]
```

- If the user answers `y` or `yes` (case-insensitive): proceed to Step 8.
- Any other answer: stop and print:

```
supy-scaffold-handler: aborted — no files were written.
```

Never write files silently under any circumstance.

## Step 8 — Write the files

Write or update the files as planned:

1. **Controller** — if the controller file does not exist, create it with the full class scaffold. If it already exists, append only the new handler method inside the existing class (do not clobber the file).
2. **DTO** — create `$DTO_FILE` (and `$DTO_DIR` if it does not exist).
3. **Spec** — create `$CONTROLLER_SPEC`.

After writing, print:

```
supy-scaffold-handler: scaffold complete.

  Written:
    <path to each file, one per line>

  Next steps:
    1. Fill in the DTO fields in <DTO_FILE> to match the actual NATS payload contract.
    2. Replace the TODO comment in the spec with a real assertion of the delegated call.
    3. Register the interactor/listener in the module (apps/api/src/app/app.module.ts).
    4. If this is a new domain event, register its discriminator in
       apps/api/src/app/domain-events.discriminators.ts (rule 12 in nats-event-patterns.md).
    5. Run: npm run affected:lint && npm run affected:test
```

## Degradation paths

**Not a git repo:** Detected in Step 2. Print the message and stop.

**Invalid NATS pattern:** Detected in Step 2. Print the validation message and stop.

**Nx project not found:** Detected in Step 3. Print the message and stop.

**Standards files unreadable:** Warn and continue using the inline rule summaries in Step 1.

**Nx generator dry-run fails or produces wrong paths:** Fall back to the copy-from-template path in Step 5. Print a notice:

```
supy-scaffold-handler: Nx generator dry-run failed or produced unexpected paths — falling back to template-copy scaffold.
```

**No existing controller of matching type found:** Skip template copy and use the inline stub content in Step 6 directly.

**Cortex MCP unavailable:** Silently degrade to static name derivation. Never hard-fail because Cortex is absent. Context fallback order: Cortex MCP (`get_handler_contract`, `get_entity`, `get_repo_guide`) → repo `CLAUDE.md` → the two standards files. Each tier is optional; move to the next if unavailable.

**User declines confirmation:** Detected in Step 7. Print the abort message and stop. Never write files without explicit approval.
