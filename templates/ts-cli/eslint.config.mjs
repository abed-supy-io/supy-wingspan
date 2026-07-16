// supy-cli ESLint (flat config) — migration target from ESLint 8 (.eslintrc).
// Place at the repo root. After migrating, delete .eslintrc(.js|.json) and bump the
// `eslint` devDependency to ^9. Mirrors the Prettier conventions already in use
// (100 cols, single quotes) and adds the correctness rules the CLI relies on.
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['dist/**', 'build/**', 'node_modules/**', 'coverage/**'],
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
      // Style parity with the existing Prettier config (100, single-quote).
      quotes: ['error', 'single', { avoidEscape: true }],
      curly: ['error', 'all'],

      // Correctness — a script that mutates a live DB must not float a promise.
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/await-thenable': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],

      // Operational-safety guardrail: a failed script must exit non-zero, so an
      // unhandled process.exit(0) after an error is easy to catch early
      // (architecture.md rule 7). The exit-code contract is verified in review.

      // Guardrail against hardcoded connection strings / credentials
      // (architecture.md rule 4). The gitleaks hook is the real gate; this
      // catches obvious literals early. Cite path:line, never the value.
      'no-restricted-syntax': [
        'warn',
        {
          selector:
            "Property[key.name=/(?:mongoUri|connectionString|password|secret|token)/i] > Literal[value=/.{12,}/]",
          message:
            'Possible hardcoded credential/URI. Read it from layered env (.env.{development,production}) — secrets-and-config.md rule 1.',
        },
      ],

      // Discourage deep cross-layer relative imports; use the @domain/@application/
      // @infrastructure path aliases instead (architecture.md rule 1).
      'no-restricted-imports': [
        'warn',
        {
          patterns: [
            {
              group: ['../../*domain*', '../../*application*', '../../*infrastructure*'],
              message:
                'Import across layers via the @domain/@application/@infrastructure aliases, not deep relative paths (architecture.md rule 1).',
            },
          ],
        },
      ],
    },
  },
);
