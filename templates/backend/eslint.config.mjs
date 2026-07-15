// eslint.config.mjs — flat config (ESLint 9+)
//
// Enforces the architecture mechanically. The dependency-direction rules below are the
// single most valuable guardrail in this repo: an illegal import fails `nx lint`, so it
// can never reach main. Tag every library in its project.json (see TAGS section below).
//
// Required dev deps:
//   @nx/eslint-plugin  @typescript-eslint/eslint-plugin  @typescript-eslint/parser
//   eslint-plugin-import  eslint

import nx from '@nx/eslint-plugin';
import tseslint from 'typescript-eslint';
import importPlugin from 'eslint-plugin-import';

export default tseslint.config(
  // ── Base ────────────────────────────────────────────────────────────────
  ...nx.configs['flat/base'],
  ...nx.configs['flat/typescript'],

  {
    ignores: ['**/dist', '**/node_modules', '**/*.config.{js,mjs,cjs}', '**/jest.config.ts'],
  },

  // ── Module boundaries: the dependency-direction guardrail ────────────────
  {
    files: ['**/*.ts'],
    rules: {
      '@nx/enforce-module-boundaries': [
        'error',
        {
          enforceBuildableLibDependency: true,
          allow: [],
          depConstraints: [
            // ---- LAYER constraints (the core rule: dependencies flow inward) ----
            {
              sourceTag: 'type:api',
              onlyDependOnLibsWithTags: [
                'type:logic',
                'type:domain-model',
                'type:domain-service',
                'type:context-map',
                'type:util',
              ],
            },
            {
              sourceTag: 'type:logic',
              onlyDependOnLibsWithTags: [
                'type:domain-model',
                'type:domain-service',
                'type:context-map',
                'type:util',
              ],
            },
            {
              sourceTag: 'type:domain-service',
              onlyDependOnLibsWithTags: ['type:domain-model', 'type:util'],
            },
            {
              // The purest layer. domain/model depends on nothing but shared utils.
              sourceTag: 'type:domain-model',
              onlyDependOnLibsWithTags: ['type:util'],
            },
            {
              sourceTag: 'type:data',
              onlyDependOnLibsWithTags: ['type:domain-model', 'type:util'],
            },
            {
              sourceTag: 'type:context-map',
              onlyDependOnLibsWithTags: ['type:domain-model', 'type:util'],
            },
            {
              sourceTag: 'type:util',
              onlyDependOnLibsWithTags: ['type:util'],
            },

            // ---- SCOPE constraints (domain isolation) ----
            // Shared libs (common, context-maps) may only depend on shared libs.
            {
              sourceTag: 'scope:shared',
              onlyDependOnLibsWithTags: ['scope:shared'],
            },
            // Each domain may depend on itself + shared. The generator appends one of
            // these per new domain. Example for the "transfer" domain:
            {
              sourceTag: 'scope:transfer',
              onlyDependOnLibsWithTags: ['scope:transfer', 'scope:shared'],
            },
          ],
        },
      ],
    },
  },

  // ── Import ordering (auto-fixable) ───────────────────────────────────────
  {
    files: ['**/*.ts'],
    plugins: { import: importPlugin },
    rules: {
      'import/order': [
        'error',
        {
          groups: [['builtin', 'external'], 'internal', ['parent', 'sibling', 'index']],
          pathGroups: [{ pattern: '@supy/**', group: 'internal', position: 'before' }],
          pathGroupsExcludedImportTypes: ['builtin'],
          'newlines-between': 'always',
          alphabetize: { order: 'asc', caseInsensitive: true },
        },
      ],
      'import/no-relative-packages': 'error', // blocks ../../other-lib/src style imports
    },
  },

  // ── DOMAIN PURITY: no framework imports inside the domain ────────────────
  {
    files: ['**/domain/model/**/*.ts', '**/domain/service/**/*.ts'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['@nestjs/*', 'mongoose', '@nestjs/cqrs', 'class-validator', 'class-transformer'],
              message:
                'Domain layer must stay pure — no framework imports. Move infrastructure concerns to data/ or logic/.',
            },
          ],
        },
      ],
    },
  },

  // ── Typed errors only in domain + logic ──────────────────────────────────
  {
    files: ['**/domain/**/*.ts', '**/logic/**/*.ts'],
    rules: {
      'no-restricted-syntax': [
        'error',
        {
          selector: "NewExpression[callee.name='Error']",
          message:
            'Use a typed error (ValidationError, NotFoundError, ConflictError) instead of generic Error.',
        },
      ],
    },
  },

  // ── TypeScript strictness ────────────────────────────────────────────────
  {
    files: ['**/*.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'error', // override with inline comment when truly needed
      '@typescript-eslint/explicit-member-accessibility': [
        'error',
        { accessibility: 'explicit', overrides: { constructors: 'no-public' } },
      ],
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      'curly': ['error', 'all'],
      'arrow-body-style': ['error', 'as-needed'],
      'padding-line-between-statements': [
        'error',
        { blankLine: 'always', prev: '*', next: 'return' },
        { blankLine: 'always', prev: '*', next: 'throw' },
      ],
    },
  },

  // ── Relax rules in tests ─────────────────────────────────────────────────
  {
    files: ['**/*.spec.ts', '**/*.test.ts', '**/mocks/**/*.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      'no-restricted-syntax': 'off',
    },
  },
);
