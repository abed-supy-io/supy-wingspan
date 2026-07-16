// Reference snippet — AG Grid custom cell renderer (angular-conventions rules 1, 21).
//
// A renderer is a standalone, OnPush component implementing `ICellRendererAngularComp`.
// `agInit`/`refresh` push the incoming params into signals; the template reads the
// signals. No injected domain state — a renderer is a dumb, presentational component
// (rule 6). Return `false` from `refresh` only when the cell must be fully re-created.

import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { type ICellRendererAngularComp } from '@ag-grid-community/angular';
import { type ICellRendererParams } from '@ag-grid-community/core';

import { type CatalogItem } from '@supy/catalog';

type StatusVariant = 'active' | 'archived' | 'draft';

@Component({
  selector: 'app-status-cell-renderer',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<span class="status-pill" [class]="'status-pill--' + variant()">{{ label() }}</span>`,
  styleUrl: './status-cell-renderer.component.scss',
})
export class StatusCellRendererComponent implements ICellRendererAngularComp {
  protected readonly variant = signal<StatusVariant>('draft');
  protected readonly label = signal('');

  agInit(params: ICellRendererParams<CatalogItem, StatusVariant>): void {
    this.render(params);
  }

  refresh(params: ICellRendererParams<CatalogItem, StatusVariant>): boolean {
    this.render(params);

    return true;
  }

  private render(params: ICellRendererParams<CatalogItem, StatusVariant>): void {
    const value = params.value ?? 'draft';
    this.variant.set(value);
    this.label.set(this.toLabel(value));
  }

  private toLabel(variant: StatusVariant): string {
    switch (variant) {
      case 'active':
        return $localize`:@@catalog.status.active:Active`;
      case 'archived':
        return $localize`:@@catalog.status.archived:Archived`;
      default:
        return $localize`:@@catalog.status.draft:Draft`;
    }
  }
}
