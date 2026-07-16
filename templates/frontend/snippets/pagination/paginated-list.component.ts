// Reference snippet — external `supy-pagination` wiring (angular-conventions rules 21, 24).
//
// Pagination is the shared `supy-pagination` from `@supy/components`, NOT AG Grid's
// built-in pager. It is driven entirely by NGXS request/response metadata:
//   - `[pageIndex]`        ← requestMetadata().page
//   - `[previousDisabled]` ← page === 0
//   - `[nextDisabled]`     ← (page + 1) * limit >= responseMetadata().total
//   - `(indexChange)`      → dispatch the list action for the new page
//
// Filter changes go through `EntityListState` filter actions. `saveToUrl` (rule 24)
// decides whether the change is persisted to the URL:
//   - MAIN PAGE  → omit the option (default true) so filters survive reload/back-forward.
//   - IN OVERLAY → pass `{ saveToUrl: false }` or `DialogService` closes the dialog/drawer
//                  on the resulting `NavigationEnd`.

import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { Store } from '@ngxs/store';

import {
  CatalogGetMany,
  CatalogPatchFilters,
  CatalogSetPage,
  CatalogState,
  type CatalogFilters,
} from '@supy/catalog';

@Component({
  selector: 'app-catalog-list',
  templateUrl: './paginated-list.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CatalogListComponent {
  readonly #store = inject(Store);

  // Exposed to the template as a single `selectors` object for terse bindings.
  protected readonly selectors = {
    rows: this.#store.selectSignal(CatalogState.items),
    requestMetadata: this.#store.selectSignal(CatalogState.requestMetadata),
    responseMetadata: this.#store.selectSignal(CatalogState.responseMetadata),
  };

  protected onPageChange(page: number): void {
    this.#store.dispatch(new CatalogSetPage({ page }));
    this.#store.dispatch(new CatalogGetMany());
  }

  // Main-page filter change — omit the option so the filter persists in the URL.
  protected onFilterChange(filters: Partial<CatalogFilters>): void {
    this.#store.dispatch(new CatalogPatchFilters(filters));
  }

  // Same action dispatched from inside a dialog/drawer — suppress URL sync so the
  // overlay is not closed by DialogService on the resulting NavigationEnd.
  protected onFilterChangeInOverlay(filters: Partial<CatalogFilters>): void {
    this.#store.dispatch(new CatalogPatchFilters(filters, { saveToUrl: false }));
  }
}
