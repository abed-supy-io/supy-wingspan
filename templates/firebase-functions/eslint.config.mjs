// supy-firebase-functions ESLint (flat config) — migration target from deprecated TSLint.
// Place at functions/eslint.config.mjs. After migrating, delete tslint.json and the
// `tslint` devDependency. Mirrors the Prettier conventions already in use (120 cols,
// single quotes) and adds the correctness rules TSLint was not enforcing.
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['lib/**', 'node_modules/**', 'coverage/**'],
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
      // Style parity with the existing Prettier config (120, single-quote).
      quotes: ['error', 'single', { avoidEscape: true }],
      curly: ['error', 'all'],

      // Correctness rules the repo currently lacks under TSLint.
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-floating-promises': 'error',
      '@typescript-eslint/no-misused-promises': 'error',
      '@typescript-eslint/await-thenable': 'error',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],

      // Guardrail against the hardcoded-secret pattern this repo has had.
      // The gitleaks hook is the real gate; this catches obvious literals early.
      'no-restricted-syntax': [
        'warn',
        {
          selector:
            "Property[key.name=/(?:apiKey|authToken|secret|password)/i] > Literal[value=/.{12,}/]",
          message:
            'Possible hardcoded secret. Read it from Secret Manager / injected env (secrets-and-config.md rule 1).',
        },
      ],
    },
  },
);
