# Frontend reference snippets

Copy-paste patterns that encode the two Supy frontend idioms most easily gotten
wrong: **AG Grid column definitions** and **`supy-pagination` wiring**. They are
reference `.ts`/`.html` files, not Plop generators — read them, then mirror the
shape in the feature you are building. Every snippet is mined from and verified
against the live `supy-frontend` repo, and maps to a rule in
[`config/standards/frontend/angular-conventions.md`](../../../config/standards/frontend/angular-conventions.md).

| Snippet | Idiom | Rule |
| --- | --- | --- |
| `ag-grid/item-name-col-def.ts` | Typed column-def **factory function** returning `ColDef<T>`, one file per column, in a `col-defs/` folder. | angular-conventions rule 21 |
| `ag-grid/status-cell-renderer.component.ts` | Standalone **OnPush** custom cell renderer implementing `ICellRendererAngularComp`, signal-backed value/variant. | rules 1, 21 |
| `ag-grid/grid.component.ts` | Composing factories into a `columnDefs` signal via a `buildColumnDefs()` method; external pagination wired to response metadata. | rules 1, 21 |
| `pagination/paginated-list.component.ts` + `.html` | `supy-pagination` bound to NGXS request/response metadata; filter dispatches respecting `saveToUrl`. | rules 21, 24 |

## Why these two

- **AG Grid** — columns are defined as **factory functions** (`ItemNameColDef({...}): ColDef<T>`),
  never inline object literals scattered through the component. Each factory takes a
  `readonly` args interface, lives in its own file under `col-defs/`, and is composed
  in a `buildColumnDefs()` method that feeds a `signal<ColDef<T>[]>`. Type-only imports
  come from `@ag-grid-community/core` with `import type`.
- **`supy-pagination`** — pagination is **external** (the shared `@supy/components`
  `supy-pagination`), driven by NGXS request/response metadata — never AG Grid's
  built-in pager. Filter changes go through `EntityListState` filter actions, and the
  `saveToUrl` flag (rule 24) decides whether the change is persisted to the URL.
