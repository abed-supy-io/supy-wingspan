---
source: supy-service-inventory/CLAUDE.md, supy-service-inventory/.github/ARCHITECTURE.md, supy-service-inventory/libs/ledger/api/src/ledger.rpc.controller.ts, supy-service-inventory/libs/ledger/api/src/ledger.nats.controller.ts, supy-api/CLAUDE.md
mined_on: 2026-07-15
confidence: high
---

# NATS Event Patterns

Supy services communicate exclusively over NATS. Two distinct transports are used:

- **Request/Reply (RPC)** — synchronous, via `NatsServer`, served by `@MessagePattern` controllers (`*.rpc.controller.ts`)
- **Event-Driven (JetStream)** — async pull consumers, via `JetStreamServer`, served by `@EventPattern` controllers (`*.nats.controller.ts`)

## Rules

1. **RPC subject format**: `<domain>.<entity>.<verb>` — e.g., `ledger.items.stock-movement`, `item.get.one`, `transfer.get.one`. Verb is present-tense (`get`, `create`, `update`, `delete`).
2. **Event subject format**: `<source-domain>.<aggregate>.<event-name>` — e.g., `inventory.transfer.transfer-submitted`, `catalog.retailer-item.base-unit-added`. Event name is kebab-case past-tense.
3. All three segments must be kebab-case; no camelCase or PascalCase in NATS subjects.
4. **`@MessagePattern` controllers** (`*.rpc.controller.ts`) must always be decorated with `@UseFilters(NatsExceptionFilter)`.
5. **`@EventPattern` controllers** (`*.nats.controller.ts`) must always be decorated with `@UseFilters(JetStreamExceptionFilter)`.
6. Payload must be validated via `StrictValidationPipe` — either as `@Payload(StrictValidationPipe) payload: T` (RPC) or `@Payload(new StrictValidationPipe(EventPayload, options)) payload: EventPayload` (event).
7. All RPC handlers must return a typed reply object — never `void` or `any`.
8. Event handlers may return `void`; they must delegate logic to an interactor, not execute it inline.
9. **Cross-service calls** must go through Context Maps (`libs/context-maps/<service>/`) — three layers: `model/` → `proxy/` → `service/`. Direct `ClientAdapter` calls are last resort; add `// TODO: move to context-map`.
10. When the same event subject is consumed by multiple handlers in the same service, use the `{ discriminator: 'unique-id' }` option on `@EventPattern` to disambiguate.
11. Domain events emitted by an aggregate must always use `this.addEvent(new MyEvent(...))` — never emit directly to NATS.
12. Every new domain event class must register its `fullName` discriminator in `apps/api/src/app/domain-events.discriminators.ts`.
13. **Event consumers must be idempotent.** JetStream is at-least-once — the same event can be redelivered, and external webhook bridges add another redelivery source. A handler must produce the same end state on a second delivery: reconcile against a stable key rather than blindly inserting. The mined pattern is query-then-upsert inside a session transaction (`find…` → evaluate (skip / merge / replace) → `upsert…`); a monotonic version / occurred-at check or a dedup key are equivalent. A listener whose logic is a bare `insert`/`create` on redeliverable input is a defect. (Webhook ingress states the HTTP-boundary form of this — see `architecture.md#webhook-ingress-profile` rule W3.)

## Examples

### Good — RPC controller

```typescript
@Controller()
@UseFilters(NatsExceptionFilter)
export class LedgerRpcController {
  @MessagePattern('ledger.items.stock-movement')
  async handle(
    @Payload(StrictValidationPipe) payload: GetStockMovementPayload,
  ): Promise<StockMovementReply> {
    return await this.getStockMovementInteractor.execute(payload);
  }
}
```

### Good — Event controller

```typescript
@Controller()
@UseFilters(JetStreamExceptionFilter)
export class LedgerNatsController {
  @EventPattern('settlements.grn.grn-pushed-to-stock')
  async handleGrnPushedToStock(
    @Payload(new StrictValidationPipe(GrnPushedPayload, options))
    payload: GrnPushedPayload,
  ) {
    await this.grnPushedListener.execute(payload.data);
  }
}
```

### Good — Event with discriminator (multiple consumers of same subject)

```typescript
@EventPattern('inventory.ledger.shipped-out-changed', { discriminator: 'ledger-return-in-sync-nats' })
async handleReturnSync(@Payload(...) payload: ShippedOutChangedPayload) { ... }

@EventPattern('inventory.ledger.shipped-out-changed', { discriminator: 'ledger-grn-sync-nats' })
async handleGrnSync(@Payload(...) payload: ShippedOutChangedPayload) { ... }
```

### Good — Aggregate emitting a domain event

```typescript
export class TransferAggregate extends AggregateRoot<...> {
  submit(input: SubmitInput): void {
    // validate business rules
    this.props.status = TransferStatus.Submitted;
    this.addEvent(new TransferSubmittedEvent({ entity: this, user: input.user }));
    this.addActivities(new TransferSubmittedActivity(this, input.user));
  }
}
```

### Bad

```typescript
// WRONG: no exception filter
@Controller()
export class LedgerRpcController { ... }

// WRONG: business logic in listener
@EventPattern('settlements.grn.grn-pushed-to-stock')
async handle(payload) {
  const grn = await this.grnRepo.findById(payload.id); // ← execute in interactor
  await this.ledgerRepo.applyGrn(grn);
}

// WRONG: raw ClientAdapter instead of context-map
await this.client.catalog.sendAsync('catalog.get.item', { id });
```

## Red flags

- `@MessagePattern` or `@EventPattern` controller missing `@UseFilters(NatsExceptionFilter)` / `@UseFilters(JetStreamExceptionFilter)`.
- Payload not validated through `StrictValidationPipe`.
- NATS subject in camelCase, PascalCase, or with more/fewer than 3 segments.
- Event name not in past-tense.
- Business logic (DB queries, calculations) directly in a NATS controller method.
- Direct `ClientAdapter` call to an external service without a context-map wrapper.
- Domain event emitted without `addEvent()` — i.e., published directly via NATS client.
- Missing discriminator registration in `domain-events.discriminators.ts`.
- Two `@EventPattern` handlers for the same subject without a `discriminator` option.
- An event listener that performs a bare `insert`/`create` on redeliverable input with no idempotency key or query-then-upsert reconciliation (rule 13) — duplicates state on JetStream/webhook redelivery.

## Source

- `supy-service-inventory/CLAUDE.md` — Dual Transport Mode, File Naming, @MessagePattern/EventPattern patterns, Context Maps hierarchy
- `supy-service-inventory/.github/ARCHITECTURE.md` §9 (NATS Subject Conventions), §10 (Domain Events), §8 (Context Maps)
- `supy-service-inventory/libs/ledger/api/src/ledger.rpc.controller.ts` — real RPC handler examples: `ledger.items.stock-movement`, `ledger.items.statement`, `ledger.grns.statement.one`, `ledger.event.check-status`
- `supy-service-inventory/libs/ledger/api/src/ledger.nats.controller.ts` — real event handler examples with discriminators: `settlements.grn.grn-pushed-to-stock`, `inventory.ledger.shipped-out-changed`
- `supy-api/CLAUDE.md` — corroborates same patterns in core domain service
- `supy-mailgun-webhooks` — consumer/handler idempotency (rule 13): the query-then-upsert reconciliation pattern (`findByEmails` → evaluate skip/merge/replace → `upsertManyByEmail` inside a session transaction) at a redelivery-prone ingress boundary; HTTP-boundary form documented in `architecture.md#webhook-ingress-profile` (W3)
