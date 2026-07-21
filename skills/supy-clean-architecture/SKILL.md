---
name: supy-clean-architecture
description: '[backend] How to write NestJS backend code in a supy service repo the Supy way — Clean/Hexagonal Architecture + DDD + CQRS: aggregates with methods + this.assign/this.addEvent, value objects with state machines, factories, repository interfaces, interactors that persist atomically then side-effect, NATS controllers. Use whenever writing or editing code under libs/ in a nestjs-nx supy repo.'
---

## When this applies

Any time you write or edit backend code under `libs/` in a Supy service repo (NestJS 11 + Fastify 5 + Nx + Mongoose 8 + NATS, Clean Architecture + DDD + CQRS). Trigger it even for small changes — "add a field", "add an endpoint", "fix this repository" — because the layering and purity rules are easy to violate accidentally. This skill is the how-to; the enforced rulebook is the governing standard.

## Step 0 — Read the governing standard

Ground every decision in the standards files. Read them before writing code:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/architecture.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/backend/module-boundaries.md"
```

If either is unreadable, print a warning and continue using the rules below as a fallback — never hard-fail. When the Cortex MCP is connected, prefer it (`get_repo_guide`, `trace_implementation`, `get_coding_rules`) as the live source over static docs.

## The three rules that govern everything

1. **Dependencies flow inward only:** `api → logic → domain/model ← data` (plus `domain/service`). If a change makes an outer concern (HTTP, Mongoose, NATS) leak into an inner layer, the change is wrong. `@nx/enforce-module-boundaries` fails the lint if you cross a boundary.
2. **`domain/model` and `domain/service` stay pure.** No `@nestjs/*`, no Mongoose, no `@nestjs/cqrs`, no `class-validator`/`class-transformer` — lint-enforced. Infrastructure concerns move to `data/` or `logic/`.
3. **State changes live on the aggregate, persistence lives in a transaction, side-effects fire after commit.** Never mutate an aggregate's props from outside; never `new Error()` in `domain/**` or `logic/**`.

The layer import/forbidden table:

| Layer | May import | Forbidden |
| --- | --- | --- |
| `api/` | `logic`, `domain/model`, `domain/service`, context-maps, `util` | `data` |
| `logic/` | `domain/model`, `domain/service`, context-maps, `util` | `data`, `api` |
| `domain/service/` | `domain/model`, `util` | any framework, `data`, `logic`, `api` |
| `domain/model/` | `util` only | any framework, any other layer |
| `data/` | `domain/model`, `util`, mongoose | `api`, `logic` |

Cross-domain data → always through a **context map** (`libs/context-maps/<service>/`). Everything below is the concrete shape these rules take. All imports use the Supy `@supy/*` alias.

## Interactors (the standard use-case shape)

Inject repository **interfaces**, never implementations. The ordering is load-critical: **validate/mutate → persist atomically → side-effect after commit.** A side-effect inside the transaction can fire even when the transaction later aborts.

```ts
// logic/src/lib/interactors/submit-transfer.interactor.ts
@Injectable()
export class SubmitTransferInteractor {
  constructor(
    private readonly repo: ITransferRepository,        // INTERFACE, not impl
    private readonly txManager: TransactionManager,
    private readonly notifications: NotificationService,
  ) {}

  public async execute(input: SubmitTransferInput): Promise<void> {
    const transfer = await this.repo.getTransfer(new TransferId(input.id));

    if (!transfer) {
      throw new NotFoundError('Transfer', input.id);
    }

    transfer.submit();                                   // 1. domain logic + events

    await this.txManager.withTransaction(async session => {
      await this.repo.save(transfer, session);           // 2. aggregate + events atomic
    });

    await this.notifications.notifySubmission(transfer); // 3. side-effect AFTER commit
  }
}
```

## Aggregates

Every state change is an intention-revealing method on the root: it validates invariants, mutates via `this.assign('prop', vo)`, and emits via `this.addEvent(new XEvent(this))`. Never mutate `props` from outside, never emit events from a handler/controller, never override the base `toObject()`.

```ts
public submit(): void {
  if (!this.props.state.isTransientTo(TransferStateEnum.Submitted)) {
    throw new ValidationError('Transfer cannot be submitted from current state');
  }
  this.assign('state', TransferState.createSubmitted());
  this.addEvent(new TransferSubmittedEvent(this));
}
```

## Value objects (wrap EVERY domain concept)

A raw `string`, `enum`, or `Date[]` standing in for a domain concept is a bug waiting to happen. A VO has a private constructor + static factories, is immutable, and validates at construction. **State-machine transition logic lives in the state VO** (`isTransientTo` / `canTransitionTo`), not spread across the aggregate or handlers.

```ts
export class TransferState extends ValueObject<TransferStateEnum> {
  private constructor(value: TransferStateEnum) { super({ value }); }

  public static createDraft(): TransferState { return new TransferState(TransferStateEnum.Draft); }
  public static createSubmitted(): TransferState { return new TransferState(TransferStateEnum.Submitted); }

  public isTransientTo(to: TransferStateEnum): boolean {
    const t: Record<TransferStateEnum, TransferStateEnum[]> = {
      [TransferStateEnum.Draft]: [TransferStateEnum.Submitted],
      [TransferStateEnum.Submitted]: [TransferStateEnum.Received, TransferStateEnum.Archived],
      [TransferStateEnum.Received]: [TransferStateEnum.Archived],
      [TransferStateEnum.Archived]: [],
    };

    return t[this.props.value].includes(to);
  }

  protected override validate(_: TransferStateEnum): void { /* runs at construction */ }
}
```

IDs are value objects too — `new TransferId(str)`, serialise with `.toObject()`/`.get()` only at boundaries. The compiler then prevents passing a `TransferId` where a `LocationId` is wanted.

## Factories

Two methods, always. Command handlers/interactors use `createNew`; the `OutputTransformer` uses `createFromExisting`. Factories wrap primitives in VOs and call child factories recursively — never `new SomeAggregate(...)` in application code.

```ts
TransferFactory.createNew(dto)          // fresh entity → EntityStateEnum.Created (records CreatedEvent)
TransferFactory.createFromExisting(dto) // hydrated from DB → EntityStateEnum.Loaded (no event)
```

## Repositories

Interface in `domain/model/` (pure). Implementation in `data/`, extends the base `Repository` (which persists aggregate + events atomically — don't hand-roll `save`) and `implements I<Domain>Repository`. Always map through `InputTransformer` (domain → doc) and `OutputTransformer` (doc → domain) — never manual mapping. Every method accepts an optional `ClientSession`; reads use `.lean()`; check `__v` for optimistic locking.

```ts
export interface ITransferRepository {
  getTransfer(id: TransferId, session?: ClientSession): Promise<Transfer | null>;
  save(transfer: Transfer, session?: ClientSession): Promise<void>;
}
```

## Domain events

Name `<context>.<aggregate>.<past-tense-verb>` (`inventory.transfer.transfer-submitted`). Carry **raw primitives only** (no VOs, no documents), set `metadata.occurredBy`, and register a discriminator in `domain-events.discriminators.ts` or the event will not deserialise on the worker side. Persisted in the same transaction as the aggregate.

## Controllers (transport)

Validate + delegate, zero business logic. Apply the exception filter; validate the payload; return response DTOs (never domain objects). DTOs live only in `api/src/lib/{dtos,exchanges}/`.

```ts
@Controller()
@UseFilters(NatsExceptionFilter)
export class TransferRpcController {
  constructor(private readonly interactor: SubmitTransferInteractor) {}

  @MessagePattern('transfer.submit.one')
  public async submit(@Payload(StrictValidationPipe) req: SubmitTransferRequest): Promise<void> {
    return this.interactor.execute(req);
  }
}
```

Services run dual transport: API mode serves `@MessagePattern` RPC via `NatsServer`; Worker mode serves `@EventPattern` events via `JetStreamServer` (`@UseFilters(JetStreamExceptionFilter)`).

## CQRS — only when justified

Use CQRS (`commands/` + `queries/`) only when read and write models genuinely differ (heavy query projections, event-heavy aggregates); otherwise use plain interactors. On the read side, query handlers are `@Injectable()`, inject a **DAO** (not a repository), return projections/DTOs, and never emit events or open transactions.

## Errors & timezone

Throw `ValidationError` (business rule) / `NotFoundError` (entity missing) / `ConflictError` (lock conflict) — never `new Error()`. Store dates UTC; convert to the retailer's `ianaTimeZone` for business logic only.

## Before you finish

- Dependencies flow inward — no `api`/`logic` import of `data`, no framework import in `domain/**`?
- Every state change is an aggregate method using `this.assign(...)`, events only via `this.addEvent(...)`?
- `toObject()` not overridden; aggregate built through a factory, not `new`?
- Every domain concept wrapped in a VO; state-machine logic inside the state VO?
- Interactor injects the repository interface; persists aggregate+events atomically in `withTransaction`; side-effects after commit?
- Repository maps through Input/Output transformers; every method takes optional `ClientSession`; reads use `.lean()`?
- Domain event named `<context>.<aggregate>.<past-tense-verb>`, raw primitives, discriminator registered?
- Typed errors only; no `any` without a justification comment?
- Tests written — domain (pure unit), interactor (mocked repo), transformer (round-trip)?

Run the verification suite:

```bash
npx nx affected -t lint --parallel=3
npx nx affected -t test --parallel=3
npx nx affected -t build
```

To scaffold a whole new bounded context (five tagged libs + wiring) instead of hand-creating files, use the **supy-scaffold-domain** skill. To review a backend diff against these rules, use the **supy-architecture-reviewer** agent.
