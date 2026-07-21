---
name: supy-angular-feature
description: '[frontend] How to write Angular code in a supy frontend repo the Supy way — OnPush components, inject(), signal inputs/outputs, NGXS state with Immer produce, URI-token services, lazy routes. Use whenever writing or editing Angular code under apps/ or libs/ in an angular-nx supy repo.'
---

## When this applies

Any time you write or edit Angular code under `apps/` or `libs/` in a Supy frontend repo (Angular 21 + Nx + NGXS + PrimeNG 21 + AG Grid). This skill is the how-to; the enforced rulebook is the governing standard.

## Step 0 — Read the governing standard

Ground every decision in the standards file. Read it before writing code:

```bash
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/frontend/angular-conventions.md"
cat "${CLAUDE_PLUGIN_ROOT}/config/standards/frontend/module-boundaries.md"
```

If either is unreadable, print a warning and continue using the rules below as a fallback — never hard-fail.

## The three rules that govern everything

1. **`ChangeDetectionStrategy.OnPush` on every component.** No exceptions — ESLint (`@angular-eslint/prefer-on-push-component-change-detection`) rejects the build otherwise.
2. **Never mutate NGXS state directly.** Deep updates go through Immer `produce()`; shallow updates through `ctx.patchState()`. Direct mutation silently breaks OnPush and selectors.
3. **Dependencies flow inward.** A domain lib (`scope:<domain>`) may depend only on itself and `scope:shared`; cross-domain access goes through a `scope:shared` lib. `@nx/enforce-module-boundaries` fails the lint if you cross a boundary.

Everything below is the concrete shape these rules take. All imports use the Supy `@supy/*` alias.

## Components

Inject with `inject()` into `#private` fields — never constructor injection. New inputs/outputs are signals (`input()`, `input.required()`, `output()`), never `@Input()`/`@Output()`. Consume state via `store.selectSignal(...)`, never the `@Select()` decorator. Split **smart** (container: injects `Store`, dispatches, selects) from **dumb** (presentational: signal inputs/outputs only, zero injected domain state).

### Smart component

```ts
@Component({
  selector: 'app-order-list',
  templateUrl: './order-list.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class OrderListComponent implements OnInit {
  readonly #store = inject(Store);

  protected readonly orders = this.#store.selectSignal(OrdersState.items);
  protected readonly loading = this.#store.selectSignal(OrdersState.loading);

  ngOnInit(): void {
    this.#store.dispatch(new OrdersGetMany());
  }
}
```

### Dumb component

```ts
@Component({
  selector: 'app-order-card',
  standalone: true,
  templateUrl: './order-card.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class OrderCardComponent {
  readonly order = input.required<Order>();
  readonly selected = output<Order>();
}
```

Tear down subscriptions with `takeUntilDestroyed()` (preferred) or `takeUntil(this.destroyed$)` via the `Destroyable` base class.

## State (NGXS)

One state class per feature, extending `EntityListState<T>` where it fits. The state model and all its properties are `readonly`. Selectors are `static` methods decorated with `@Selector([TOKEN])`. List-loading actions carry `{ cancelUncompleted: true }` to drop superseded requests.

```ts
@Action(OrdersGetMany, { cancelUncompleted: true })
getMany(ctx: StateContext<OrdersStateModel>) {
  const { filters, requestMetadata } = ctx.getState();

  return this.ordersService.getMany(filters, requestMetadata).pipe(
    tap(response => {
      ctx.setState(produce(draft => {
        draft.items = response.data;
        draft.responseMetadata = response.metadata;
      }));
    }),
  );
}
```

## Actions

Action type format `[Feature] ActionName`. One action class per operation; payload via a single `readonly` constructor parameter.

```ts
export class OrdersGetDetailed {
  static readonly type = '[Orders] GetDetailed';
  constructor(readonly payload: { id: string; fromCache?: boolean }) {}
}
```

## Services

Domain services extend `BaseHttpService` and inject a **URI InjectionToken** — never a hardcoded URL string. `@Injectable({ providedIn: 'root' })` for singletons. Return typed `Observable<IQueryResponse<T>>` / `Observable<T>`, never `any`.

```ts
@Injectable({ providedIn: 'root' })
export class OrdersService extends BaseHttpService {
  protected readonly http = inject(HttpClient);
  constructor() { super(inject(ORDERS_URI)); }

  getMany(filters: OrderFilters, meta: BaseRequestMetadata): Observable<IQueryResponse<Order>> {
    return this.get<IQueryResponse<Order>>('', this.buildParams(filters, meta));
  }
}

export const ORDERS_URI = new InjectionToken<string>('Orders URI', {
  factory: () => inject(API_BASE_URL) + '/orders',
});
```

## Routing & lazy loading

Feature routes lazy-load their state with `provideStates([...])` in the route `providers` — never eagerly register a feature state at root. Guards/resolvers use functional `inject()` style inside `canMatch` / `resolve`.

```ts
export const ORDER_ROUTES: Routes = [
  {
    path: '',
    component: OrderListComponent,
    canMatch: [() => inject(AuthenticationGuard).canActivate()],
    resolve: { orders: OrdersResolver },
    providers: [provideStates([OrdersState]), OrdersService],
  },
];
```

## Forms

Reactive, strongly typed via `FormBuilder`. No template-driven forms for non-trivial input. Reusable inputs implement `ControlValueAccessor`. Guard submit on `form.invalid`; read values with `getRawValue()`.

## Models & DTOs

All DTO/entity properties `readonly`. Separate `*Request` and `*Response` interfaces. References use `SkeletonObjectType` (`id` + `name`); multi-language fields use `LocalizedData`. `*.model.ts` = API contracts/DTOs; `*.entity.ts` = rich domain entity with methods.

## AG Grid

Column defs are typed factory functions returning `ColDef<T>` (in `col-defs/`). Custom cell renderers are standalone OnPush components implementing `ICellRendererAngularComp`, using signals for value/variant. Pagination is external (`supy-pagination`) wired to response metadata.

## Styling

Use PrimeNG CSS design tokens (`--p-*`) for color, spacing, and radius. No `::ng-deep`, no hardcoded hex colors, no raw `px` for spacing.

```scss
.container {
  padding: var(--p-spacing-md);
  color: var(--p-text-color);
  border: 1px solid var(--p-surface-border);
}
```

## Imports & TypeScript

Import order is auto-fixed by `simple-import-sort`: (1) side-effect → (2) third-party (`@angular/*`, `@ngxs/store`, …) → (3) scoped project (`@supy/*`) → (4) relative (`./…`). `strict: true`; no `any` without a justification comment; `verbatimModuleSyntax` on — use `import type` for type-only imports; unused params prefixed with `_`.

## Before you finish

- Component has `OnPush`? Injected via `inject()` in a `#private` field?
- No `@Input()` / `@Output()` / `@Select()` in new code?
- No direct state mutation — deep updates via `produce()`, shallow via `patchState()`?
- Service uses a URI token, not a hardcoded URL?
- Feature state registered via `provideStates()` in the route, not at root?
- No cross-domain import bypassing a `scope:shared` lib?
- SCSS uses `--p-*` tokens, no `::ng-deep` / hex / raw `px`?
- Specs written and asserting behaviour (not a lone `toBeDefined()`)?

Run the verification suite:

```bash
npx nx affected -t lint --parallel=3
npx stylelint "{apps,libs}/**/*.scss"
npx nx affected -t test --parallel=3
```

To scaffold a whole new feature (models → state → service → components → routing → wiring), use the **supy-scaffold-feature** skill instead of hand-creating files. To review an Angular diff, use the **supy-angular-reviewer** agent.
