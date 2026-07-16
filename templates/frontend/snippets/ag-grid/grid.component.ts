// Reference snippet — composing col-def factories into a grid (angular-conventions rules 1, 21).
//
// The component holds a `signal<ColDef<T>[]>`, built by a single `buildColumnDefs()`
// method that calls each factory. Rebuild and `.set()` the signal whenever the inputs
// that shape columns change (permissions, locale, edit mode) — never mutate the array
// in place (rule 7). Pagination is external: read request/response metadata off the
// store and hand it to `<supy-pagination>` in the template (see the pagination snippet).

import { ChangeDetectionStrategy, Component, computed, inject, input } from '@angular/core';
import { type ColDef } from '@ag-grid-community/core';
import { Store } from '@ngxs/store';

import { type CatalogItem, CatalogState } from '@supy/catalog';

import { ItemCodeColDef, ItemNameColDef, StatusColDef } from './col-defs';

@Component({
  selector: 'app-catalog-grid',
  templateUrl: './grid.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CatalogGridComponent {
  readonly #store = inject(Store);

  readonly editable = input(false);
  readonly locale = input('en');

  protected readonly rows = this.#store.selectSignal(CatalogState.items);
  protected readonly requestMetadata = this.#store.selectSignal(CatalogState.requestMetadata);
  protected readonly responseMetadata = this.#store.selectSignal(CatalogState.responseMetadata);

  // Rebuilt (never mutated) whenever the inputs that shape columns change.
  protected readonly columnDefs = computed<ColDef<CatalogItem>[]>(() =>
    this.buildColumnDefs(this.editable(), this.locale()),
  );

  private buildColumnDefs(editable: boolean, locale: string): ColDef<CatalogItem>[] {
    return [
      ItemNameColDef({ editable, locale }),
      ItemCodeColDef({ editable }),
      StatusColDef(),
    ];
  }
}
