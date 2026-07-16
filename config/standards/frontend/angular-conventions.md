---
source: angular-frontend-starter-kit/CLAUDE.md, angular-frontend-starter-kit/eslint.config.mjs, angular-frontend-starter-kit/.stylelintrc.json, supy-frontend/CLAUDE.md, supy-frontend/libs/common/src/lib/store/state/entity-list.state.ts
mined_on: 2026-07-16
confidence: high
---

# Angular Frontend Conventions

Supy frontend apps are **Angular 21 + Nx + NGXS (+ Immer) + PrimeNG 21 + AG Grid + Jest + SCSS design tokens**. These rules are enforced at multiple layers — editor (Cursor), lint (ESLint + Angular ESLint + `@nx/enforce-module-boundaries`), Stylelint, CI, and review. Module boundaries and tagging live in the companion [module-boundaries.md](module-boundaries.md).

## Rules

### Components

1. **`ChangeDetectionStrategy.OnPush` on every component.** No exceptions — without it, change detection runs everywhere, producing stale views and performance cliffs.
2. **Inject with the `inject()` function — never constructor injection.** Hold injected services in `#private` fields: `readonly #store = inject(Store);`.
3. **New inputs/outputs use signals**: `input()`, `input.required()`, `output()`. Never `@Input()` / `@Output()`.
4. **Consume NGXS state via `store.selectSignal(...)`** — never the `@Select()` decorator.
5. **Tear down subscriptions** with `takeUntilDestroyed()` (preferred) or `takeUntil(this.destroyed$)` via the `Destroyable` base class.
6. **Split smart from dumb components.** Smart (container): injects `Store`, dispatches, selects. Dumb (presentational): signal inputs/outputs only, zero injected domain state.

### State (NGXS)

7. **Never mutate state directly.** Deep updates use Immer `produce()`; shallow updates use `ctx.patchState()`. Never mutate the draft outside `produce()` — direct mutation silently breaks OnPush and selectors.
8. One state class per feature, extending the shared `EntityListState<T>` where it fits. The state model and all model/DTO properties are `readonly`.
9. **List-loading actions use `{ cancelUncompleted: true }`** to drop superseded requests.
10. **Selectors are `static` methods** decorated with `@Selector([TOKEN])`.

### Actions

11. **Action type format `[Feature] ActionName`** (e.g. `'[Orders] GetMany'`). One action class per operation; payload via a single `readonly` constructor parameter.

### Services

12. **Domain services extend `BaseHttpService`** and inject a **URI InjectionToken** (never a hardcoded URL string).
13. `@Injectable({ providedIn: 'root' })` for singletons. Return typed `Observable<IQueryResponse<T>>` / `Observable<T>` — never `any`.

### Routing & lazy loading

14. **Feature routes lazy-load their state with `provideStates([...])` in route `providers`** — never eagerly register a feature state at root.
15. Guards/resolvers use functional `inject()` style inside `canMatch` / `resolve`.

### Forms

16. Reactive, strongly typed via `FormBuilder`. No template-driven forms for non-trivial input. Reusable inputs implement `ControlValueAccessor`. Guard submit on `form.invalid`; read values with `getRawValue()`.

### Data models & DTOs

17. All DTO/entity properties `readonly`. Separate `*Request` and `*Response` interfaces.
18. References use `SkeletonObjectType` (`id` + `name`); multi-language fields use `LocalizedData`. `*.model.ts` = API contracts/DTOs; `*.entity.ts` = rich domain entity with methods.

### HTTP interceptors

19. New interceptors are **functional** (`HttpInterceptorFn`). Chain order is intentional: CSRF → client-version → retailer-context → DI interceptors (auth, error) → fetch. Don't reorder without reason. Errors surface through the snackbar error interceptor; services don't swallow errors.

### Styling

20. **Use PrimeNG CSS design tokens (`--p-*`)** for color, spacing, and radius. **No `::ng-deep`** (deprecated), **no hardcoded hex colors**, **no raw `px` for spacing** — use token scales (`var(--p-spacing-md)`).

### AG Grid

21. Column defs are typed factory functions returning `ColDef<T>` (in `col-defs/`). Custom cell renderers are standalone OnPush components implementing `ICellRendererAngularComp`, using signals for value/variant. Pagination is external (`supy-pagination`) wired to response metadata.

### Imports & TypeScript

22. **Import order** (auto-fixed by `simple-import-sort`): (1) side-effect imports → (2) third-party (`@angular/*`, `@ngxs/store`, …) → (3) scoped project imports (`@supy/*`) → (4) relative (`./…`).
23. `strict: true`. No `any` without a justification comment — prefer generics or `unknown` + narrowing. `verbatimModuleSyntax` on — use `import type` for type-only imports. Unused params prefixed with `_`.

### Filter state & URL sync

24. **Pass `{ saveToUrl: false }` when dispatching filter actions from inside a dialog or drawer.** Filter actions on `EntityListState` (`*PatchFilters`, `*ResetFilters`, `*InitFilters`, …) take an optional `FilterActionsOptions` second argument. `saveToUrl` **defaults to `true`**, which persists the filter state to the URL via `router.navigate()`. `DialogService` closes the active overlay on any `NavigationEnd` event, so dispatching a filter action with the default from within a dialog/drawer **immediately closes it**. Pass `{ saveToUrl: false }` inside any overlay; **omit** the option on main-page filters so state persists in the URL and survives reload/back-forward. `FilterActionsOptions` is defined in `libs/common/src/lib/store/state/entity-list.state.ts`.

## Examples

### Good — smart component (OnPush, `inject()`, `selectSignal`)

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

### Good — NGXS action (Immer `produce`, `cancelUncompleted`)

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

### Good — action class

```ts
export class OrdersGetDetailed {
  static readonly type = '[Orders] GetDetailed';
  constructor(readonly payload: { id: string; fromCache?: boolean }) {}
}
```

### Good — service extends `BaseHttpService` + URI token

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

### Good — lazy route with `provideStates`

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

### Good — SCSS with design tokens

```scss
.container {
  padding: var(--p-spacing-md);
  color: var(--p-text-color);
  border: 1px solid var(--p-surface-border);
}
```

### Good — filter action dispatched from inside a dialog/drawer

```ts
// Inside an overlay: suppress URL sync so DialogService doesn't close it on NavigationEnd.
this.#store.dispatch(
  new GroupedByPslChannelItemsPatchFilters(
    { branchId, pslIds, retailerItemIds },
    { saveToUrl: false },
  ),
);

// On the main page: omit the option so filters persist in the URL.
this.#store.dispatch(new OrdersPatchFilters({ status }));
```

## Red flags

These are auto-reject in review — each maps to the fix on its right:

- Component without `OnPush` → add `changeDetection: ChangeDetectionStrategy.OnPush`.
- Constructor injection → `inject()` in a `#private` field.
- `@Input()` / `@Output()` in new components → `input()` / `input.required()` / `output()`.
- `@Select()` decorator → `store.selectSignal()`.
- Direct state mutation → Immer `produce()` / `ctx.patchState()`.
- Service with a hardcoded URL string → URI InjectionToken + `BaseHttpService`.
- Eager feature-state registration at root → `provideStates()` in route providers.
- `::ng-deep` / hardcoded hex colors / raw `px` spacing → PrimeNG `--p-*` design tokens.
- Cross-domain import of another feature's internals → go through a `scope:shared` lib.
- `any` without a justification comment → proper types (generics / `unknown` + narrowing).
- Subscription without teardown → `takeUntilDestroyed()`.
- Template-driven form for non-trivial input → reactive typed `FormBuilder` form.
- Filter action dispatched from a dialog/drawer without `{ saveToUrl: false }` → the overlay closes on `NavigationEnd`; pass `{ saveToUrl: false }` inside overlays.

## Source

- `angular-frontend-starter-kit/CLAUDE.md` §0–§12 — the enforced frontend rulebook (components, NGXS state/actions, services, routing, forms, models, interceptors, styling, AG Grid, imports/TS, anti-patterns)
- `angular-frontend-starter-kit/eslint.config.mjs` — `@nx/enforce-module-boundaries`, `prefer-on-push-component-change-detection`, `no-restricted-syntax` banning `@Input`/`@Output`/`@Select`, `no-explicit-any`, `consistent-type-imports`, `simple-import-sort` groups, template `prefer-control-flow` / `no-negated-async`
- `angular-frontend-starter-kit/.stylelintrc.json` — `color-no-hex`, `selector-disallowed-list` (`::ng-deep`), `declaration-property-unit-disallowed-list` (no `px` on spacing)
- Alias note: the starter kit ships the `@app/*` path prefix; Supy repos use `@supy/*`. All rules and examples here use `@supy/*` (the swap is applied in the drop-in assets under `templates/frontend/`).
- Rule 24 (`saveToUrl` / URL-synced filter state) is verified against the live `supy-frontend` repo — `CLAUDE.md` §"State Management" documents the `DialogService`/`NavigationEnd` overlay-close mechanism, and `FilterActionsOptions` (default `{ saveToUrl: true }`) is defined in `libs/common/src/lib/store/state/entity-list.state.ts`. Not present in the starter kit; mined from the real codebase.
