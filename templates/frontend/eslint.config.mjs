// eslint.config.mjs — flat config (ESLint 9+, Angular ESLint, Nx)
//
// Mechanically enforces the frontend conventions. The module-boundary + OnPush + no-any +
// no-@Select rules are the high-value guardrails: they fail `nx lint`, so they can't reach main.
//
// Required dev deps:
//   @nx/eslint-plugin  angular-eslint  typescript-eslint  eslint
//   eslint-plugin-simple-import-sort

import nx from '@nx/eslint-plugin';
import angular from 'angular-eslint';
import tseslint from 'typescript-eslint';
import simpleImportSort from 'eslint-plugin-simple-import-sort';

export default tseslint.config(
  ...nx.configs['flat/base'],
  ...nx.configs['flat/typescript'],
  ...nx.configs['flat/angular'],

  { ignores: ['**/dist', '**/node_modules', '**/*.config.{js,mjs,cjs}', '**/jest.config.ts'] },

  // ── Module boundaries: dependency direction + domain isolation ───────────
  {
    files: ['**/*.ts'],
    rules: {
      '@nx/enforce-module-boundaries': [
        'error',
        {
          enforceBuildableLibDependency: true,
          allow: [],
          depConstraints: [
            // LAYER (type) — an outer layer may depend on inner layers only.
            { sourceTag: 'type:app', onlyDependOnLibsWithTags: ['type:feature', 'type:ui', 'type:data-access', 'type:util'] },
            { sourceTag: 'type:feature', onlyDependOnLibsWithTags: ['type:feature', 'type:ui', 'type:data-access', 'type:util'] },
            { sourceTag: 'type:ui', onlyDependOnLibsWithTags: ['type:ui', 'type:util'] }, // presentational: no data-access
            { sourceTag: 'type:data-access', onlyDependOnLibsWithTags: ['type:data-access', 'type:util'] },
            { sourceTag: 'type:util', onlyDependOnLibsWithTags: ['type:util'] },

            // SCOPE (domain isolation). Shared libs depend only on shared.
            { sourceTag: 'scope:shared', onlyDependOnLibsWithTags: ['scope:shared'] },
            // The generator appends one of these per new feature, e.g.:
            { sourceTag: 'scope:orders', onlyDependOnLibsWithTags: ['scope:orders', 'scope:shared'] },
          ],
        },
      ],
    },
  },

  // ── Import sorting (auto-fixable) ────────────────────────────────────────
  {
    files: ['**/*.ts'],
    plugins: { 'simple-import-sort': simpleImportSort },
    rules: {
      'simple-import-sort/imports': [
        'error',
        {
          groups: [
            ['^\\u0000'],                 // 1. side-effect imports
            ['^@?\\w'],                   // 2. third-party packages
            ['^@supy(/.*)?$'],             // 3. scoped project imports
            ['^\\.'],                     // 4. relative imports
          ],
        },
      ],
      'simple-import-sort/exports': 'error',
    },
  },

  // ── Angular conventions ──────────────────────────────────────────────────
  {
    files: ['**/*.ts'],
    rules: {
      // OnPush is mandatory.
      '@angular-eslint/prefer-on-push-component-change-detection': 'error',
      // Prefer signal inputs/outputs and selectSignal over the legacy decorators.
      'no-restricted-syntax': [
        'error',
        {
          selector: "Decorator[expression.callee.name=/^(Input|Output)$/]",
          message: 'Use signal APIs: input(), input.required(), output() — not @Input()/@Output().',
        },
        {
          selector: "Decorator[expression.callee.name='Select']",
          message: 'Consume NGXS state with store.selectSignal(...) — not the @Select() decorator.',
        },
      ],
      '@typescript-eslint/no-explicit-any': 'error', // override with an inline justification comment
      '@typescript-eslint/consistent-type-imports': ['error', { prefer: 'type-imports' }],
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      '@typescript-eslint/explicit-function-return-type': 'warn',
    },
  },

  // ── Angular template rules ───────────────────────────────────────────────
  {
    files: ['**/*.html'],
    extends: [...nx.configs['flat/angular-template']],
    rules: {
      '@angular-eslint/template/prefer-control-flow': 'error', // @if/@for over *ngIf/*ngFor
      '@angular-eslint/template/no-negated-async': 'error',
    },
  },

  // ── Relax in tests ───────────────────────────────────────────────────────
  {
    files: ['**/*.spec.ts', '**/*.test.ts', '**/mocks/**/*.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      'no-restricted-syntax': 'off',
    },
  },
);
