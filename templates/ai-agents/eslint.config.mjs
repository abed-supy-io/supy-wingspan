// supy-ai-agents ESLint (flat config) — per Node/TS package (Cortex, Oculus, ...).
// Place at the package root. There is no root workspace, so each Node package carries its own copy.
// Adds the correctness rules an MCP server + BullMQ queue service relies on, plus guardrails for the
// ai-agents standard (no hardcoded credentials, no cross-package reach-through imports).
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['dist/**', 'build/**', 'node_modules/**', 'coverage/**', '.wrangler/**'],
  },
  ...tseslint.configs.recommended,
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.json'],
      },
    },
    rules: {
      quotes: ['error', 'single', { avoidEscape: true }],
      curly: ['error', 'all'],

      // Correctness — an MCP tool or queue consumer must not float a promise: a dropped await on a
      // DB write or job ack silently loses work (architecture.md rules 4 & 9).
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/await-thenable': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],

      // Guardrail against hardcoded credentials / connection strings / OAuth secrets
      // (architecture.md rule 1). The gitleaks hook is the real gate; this catches obvious literals
      // early. Cite path:line, never the value.
      'no-restricted-syntax': [
        'warn',
        {
          selector:
            "Property[key.name=/(?:connectionString|databaseUrl|redisUrl|password|secret|token|apiKey|clientSecret)/i] > Literal[value=/.{12,}/]",
          message:
            'Possible hardcoded credential/URI/secret. Read it from the env-driven config singleton — architecture.md rule 1 / secrets-and-config.md rule 1.',
        },
      ],

      // No cross-package reach-through: each package is self-contained, so a `../../<sibling>/` import
      // that climbs out of this package is a boundary violation (architecture.md rule 8).
      'no-restricted-imports': [
        'warn',
        {
          patterns: [
            {
              group: ['../../*'],
              message:
                'Do not reach into a sibling package via deep relative paths. Each package is self-contained (architecture.md rule 8).',
            },
          ],
        },
      ],
    },
  },
);
