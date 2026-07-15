---
source: supy-service-inventory/CLAUDE.md, supy-service-inventory/.github/ARCHITECTURE.md, supy-api/CLAUDE.md, supy-service-inventory/.github/copilot-instructions.md
mined_on: 2026-07-15
confidence: high
---

# Architecture Standards

Supy backend services follow a Hexagonal / Clean Architecture pattern with Domain-Driven Design (DDD) per bounded context. Every domain service is an Nx monorepo. The canonical live source of truth for architecture data is the Cortex MCP — always prefer it over static docs when connected.

## Rules

1. **Cortex MCP is the live source of truth.** When connected, always call `get_repo_guide('<repo>')`, `trace_implementation('<pattern>')`, `search_entities('<concept>')`, or `search_relationships('<query>')` before relying on static CLAUDE.md guidance. If Cortex is unavailable, fall back to the CLAUDE.md in each repo — which is directional guidance, not exhaustive documentation.
2. **Layer dependency direction is strictly inward**: `api → logic → domain/model ← data`. No layer may import from a layer further out.
3. `api/` must NEVER import `data/` — all persistence is accessed through repository interfaces defined in `domain/model/`.
4. `logic/` must NEVER import `data/` — interactors depend on `I*Repository` interfaces only.
5. `domain/model/` must NEVER import framework packages (`@nestjs/*`, Mongoose, NATS) — it is pure domain.
6. **Cross-domain access must go through Context Maps** (`libs/context-maps/<service>/`). Never import another domain's internal types directly.
7. Every bounded context lives under `libs/<domain>/` and contains sub-layers: `domain/`, `data/`, `logic/`, `api/`, and optionally `commands/` + `queries/` for CQRS.
8. **CQRS split** (`commands/` + `queries/`) is required for complex read/write domains. Domains currently using CQRS: `stock-count`, `recipe`, `wastage`, `transfer`, `productions`. New code in `item` should also use full CQRS structure.
9. All module registrations must be capability-gated via `register({ capability })` using the `BOOTSTRAP_CAPABILITY` enum.
10. **MongoDB / Mongoose conventions**: use `@Schema` + `SchemaFactory.createForClass()`, extend `TimeStampSchema`, always use `InputTransformer` (domain→document) and `OutputTransformer` (document→domain) in the `data/` layer — never map manually. Always use `.lean()` for read queries. Repositories must accept an optional `ClientSession` for transaction support.
11. **Optimistic locking**: check `__v` (Mongoose version key) before writes to detect concurrent modification.
12. **TransactionManager** uses exponential backoff retry (0–350ms cap) for conflict resolution.
13. Always wrap IDs in typed value objects (`new InventoryItemId(str)`, `new RetailerId(str)`). Use `.toObject()` to serialize; never pass raw strings across aggregate boundaries.
14. **Error types**: always use typed errors — `ValidationError` (business rule violations), `NotFoundError` (entity not found), `ConflictError` (concurrent modification / lock conflicts). Never throw generic `Error`.
15. **Import paths**: always use `@supy/<domain>/<sublibrary>` aliases from `tsconfig.base.json`. Never use relative paths across library boundaries.
16. **Import sort order** (ESLint-enforced): side-effect imports → third-party / `@`-scoped packages → internal `@supy/*` aliases → relative imports.
17. Services run in dual transport mode: API mode (`IS_IN_WORKER_MODE=false`) serves `@MessagePattern` RPC via `NatsServer`; Worker mode (`IS_IN_WORKER_MODE=true`) serves `@EventPattern` events via `JetStreamServer`.
18. `nx.json` should have `sync.applyChanges: false` to prevent `nx sync` auto-populating `tsconfig.app.json` references (causes webpack TS6305 failures).

## DDD building blocks

The layer rules above govern *where* code lives; these govern *how* the domain is modelled inside `domain/model/`. The `supy-architecture-reviewer` cites these by anchor (`architecture.md#ddd-building-blocks rule N`).

1. **Aggregate roots own their invariants.** State changes happen only through intention-revealing methods on the aggregate (`transfer.submit()`, not `transfer.state = ...`). A method validates the transition, then mutates through the protected `this.assign('<prop>', <valueObject>)` setter — never by writing `this.props.x = y` from outside or reaching into another aggregate's props.

2. **Aggregates raise events, never persist them.** A state-changing method records what happened with `this.addEvent(new <Thing>Event(this))`; the interactor drains and persists those events atomically with the aggregate. Never call a repository or emit to NATS from inside an aggregate.

3. **Never override `toObject()`** on an aggregate or value object. The base class serialisation is the persistence contract — overriding it silently desynchronises the input/output transformers. Expose read access through getters instead.

4. **Value objects wrap every domain concept** (ids, money, quantities, states). A VO has a private constructor plus static factory methods, is immutable after construction, and validates in the factory. Two VOs are equal by value, not reference.

5. **State machines live in a state value object.** Model the lifecycle as a `<Aggregate>State extends ValueObject<<Aggregate>StateEnum>` whose factories (`createDraft()`, `createSubmitted()`, …) and `isTransientTo` / `canTransitionTo` map define legal transitions. The aggregate asks the state VO whether a transition is legal; it never re-implements the state chart with `if/switch` on a raw enum.

6. **Construct aggregates through factories, never `new` in application code.** `createNew(...)` builds a brand-new aggregate and records the `<Thing>CreatedEvent` (a Created result); `createFromExisting(...)` rehydrates a persisted aggregate with no event (a Loaded result). Interactors and repositories call the factory — they never invoke the aggregate constructor directly.

7. **Domain event names are `<context>.<aggregate>.<past-tense-verb>`** (e.g. `inventory.transfer.transfer-submitted`). Event payloads carry raw primitives only (no VOs, no Mongoose documents), set `metadata.occurredBy`, and every event class is registered as a discriminator in `domain-events.discriminators.ts` or it will not deserialise on the worker side.

## Examples

### Good — layer layout for bounded context `transfer`

```
libs/transfer/
  domain/model/   → TransferAggregate, TransferId, ITransferRepository, TransferSubmittedEvent
  domain/service/ → TransferDomainService (cross-aggregate coordination)
  data/           → TransferSchema, TransferRepository (implements ITransferRepository),
                    TransferInputTransformer, TransferOutputTransformer
  logic/          → CreateTransferInteractor, TransferSubmittedListener
  api/            → TransferRpcController (@MessagePattern), TransferNatsController (@EventPattern),
                    CreateTransferPayload DTO, TransferReply DTO
  commands/       → (full CQRS write side)
  queries/        → (full CQRS read side)
```

### Good — context map for `catalog` service

```
libs/context-maps/catalog/
  model/    → RetailerItemValueObject (translates external data into inventory domain language)
  proxy/    → CatalogProxy (@Injectable NATS client, encapsulates all sendAsync calls)
  service/  → CatalogService (application-level adapter composing proxy calls)
```

### Good — repository interface in domain/model

```typescript
export interface ITransferRepository {
  findById(id: TransferId, session?: ClientSession): Promise<Transfer | null>;
  save(transfer: Transfer, session?: ClientSession): Promise<void>;
}
```

### Good — aggregate method, state VO, and factory (DDD building blocks)

```typescript
// domain/model — state machine lives in the state VO (rule 5)
export class TransferState extends ValueObject<TransferStateEnum> {
  private static readonly isTransientTo: Record<TransferStateEnum, TransferStateEnum[]> = {
    [TransferStateEnum.Draft]: [TransferStateEnum.Submitted],
    [TransferStateEnum.Submitted]: [TransferStateEnum.Approved, TransferStateEnum.Rejected],
    [TransferStateEnum.Approved]: [],
    [TransferStateEnum.Rejected]: [],
  };
  public static createDraft(): TransferState { return new TransferState(TransferStateEnum.Draft); }
  public static createSubmitted(): TransferState { return new TransferState(TransferStateEnum.Submitted); }
  public canTransitionTo(next: TransferStateEnum): boolean {
    return TransferState.isTransientTo[this.value].includes(next);
  }
}

// domain/model — state changes through a method + this.assign, events via this.addEvent (rules 1, 2)
export class Transfer extends AggregateRoot<TransferProps> {
  public submit(): void {
    if (!this.props.state.canTransitionTo(TransferStateEnum.Submitted)) {
      throw new ValidationError('Transfer can only be submitted from draft');
    }
    this.assign('state', TransferState.createSubmitted());
    this.addEvent(new TransferSubmittedEvent(this));
  }
}

// domain/model — factories, not `new`, in application code (rule 6)
export class TransferFactory {
  public static createNew(props: NewTransferProps): Transfer { /* …builds + records TransferCreatedEvent */ }
  public static createFromExisting(props: TransferProps): Transfer { /* …rehydrates, no event */ }
}
```

### Bad

```typescript
// WRONG: mutating aggregate state from outside instead of via a method + this.assign (rule 1)
transfer.props.state = TransferState.createSubmitted();

// WRONG: constructing an aggregate directly instead of through its factory (rule 6)
const transfer = new Transfer({ ...props });

// WRONG: event name not <context>.<aggregate>.<past-tense-verb> (rule 7)
this.addEvent(new TransferSubmittedEvent(this)); // subject "submitTransfer" — must be "inventory.transfer.transfer-submitted"

// WRONG: api layer importing data layer
import { TransferRepository } from '@supy/transfer/data'; // in api controller

// WRONG: importing another domain's internals
import { ItemAggregate } from '@supy/item/domain/model'; // inside ledger domain

// WRONG: raw MongoDB query in controller
await this.transferModel.find({ retailerId }).lean();

// WRONG: relative path across library boundaries
import { ITransferRepository } from '../../../transfer/domain/model/src';
```

## Red flags

- Any layer importing from a layer further out in the dependency chain.
- Direct import of another domain's internal modules (bypassing context maps).
- Framework annotations (`@Injectable`, `@Schema`) in `domain/model/`.
- DTOs defined in `logic/` or `domain/` — they belong in `api/src/lib/exchanges/` or `api/src/lib/dtos/`.
- Missing `InputTransformer` / `OutputTransformer` — manual mapping in repositories.
- Repository methods missing optional `ClientSession` parameter.
- `.find()` without `.lean()` on read queries.
- New API module not capability-gated via `register({ capability })`.
- Missing discriminator registration in `domain-events.discriminators.ts`.
- Aggregate state mutated from outside via `this.props.x = ...` or a public setter instead of an intention-revealing method + `this.assign(...)`.
- An aggregate constructed with `new` in an interactor/repository instead of through `createNew` / `createFromExisting`.
- `toObject()` overridden on an aggregate or value object.
- Lifecycle logic implemented as `if/switch` on a raw enum instead of a state value object with `canTransitionTo` / `isTransientTo`.
- A repository call, NATS emit, or event *persistence* performed inside an aggregate (aggregates only `this.addEvent`).
- Domain event name not `<context>.<aggregate>.<past-tense-verb>`, or an event payload carrying value objects / Mongoose documents instead of raw primitives.
- Cortex MCP available but not consulted for architecture questions (agent relying on potentially stale static docs).

## Source

- `supy-service-inventory/CLAUDE.md` — Architecture, Layer Isolation Rules, NATS Patterns, Data Layer Patterns, Dual Transport Mode, Bootstrap Capabilities, Error Types, Value Objects/IDs, Cortex MCP section
- `supy-service-inventory/.github/ARCHITECTURE.md` §2–§11 — canonical architecture specification with ASCII diagram, layer rules table, CQRS structure, context maps, import path map, MongoDB patterns
- `supy-api/CLAUDE.md` — corroborates same patterns in core domain service; confirms `api → logic → domain ← data` rule
- `supy-service-inventory/.github/copilot-instructions.md` — operator-level conventions reinforcing layer rules and import conventions
- `architecture-starter-kit/docs` + `skills/clean-architecture-ddd`, `skills/domain-review` — the **DDD building blocks** section: aggregate methods + `this.assign` / `this.addEvent`, state-machine-in-VO, `createNew` / `createFromExisting` factories, and domain-event naming
