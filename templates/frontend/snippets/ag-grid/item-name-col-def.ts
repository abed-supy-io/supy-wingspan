// Reference snippet — AG Grid column definition factory (angular-conventions rule 21).
//
// One column = one factory function = one file, under a `col-defs/` folder next to
// the grid component. The factory takes a `readonly` args interface and returns a
// typed `ColDef<T>`. Type-only imports use `import type` (rule 23). Headers are
// localized with `$localize`. Behaviour that depends on the row (editable, cell
// editor selection, value formatting) is expressed as callbacks, not hardcoded.

import {
  type ColDef,
  type EditableCallbackParams,
  type ICellEditorParams,
  type ValueFormatterParams,
} from '@ag-grid-community/core';

import { type CatalogItem } from '@supy/catalog';

import { ItemNameCellEditorComponent } from '../cell-editors';

interface ItemNameColDefArgs {
  readonly editable: boolean;
  readonly locale: string;
}

export function ItemNameColDef({ editable, locale }: ItemNameColDefArgs): ColDef<CatalogItem> {
  return {
    colId: 'itemName',
    headerName: $localize`:@@catalog.grid.itemName:Item name`,
    field: 'name',
    flex: 1,
    minWidth: 200,
    valueFormatter: ({ value }: ValueFormatterParams<CatalogItem, string>): string =>
      value ?? $localize`:@@common.notAvailable:N/A`,
    editable: (params: EditableCallbackParams<CatalogItem>): boolean =>
      editable && !params.data?.locked,
    cellEditorSelector: (_params: ICellEditorParams<CatalogItem>) => ({
      component: ItemNameCellEditorComponent,
      params: { locale },
    }),
    comparator: (a: string, b: string): number => a.localeCompare(b, locale),
  };
}
