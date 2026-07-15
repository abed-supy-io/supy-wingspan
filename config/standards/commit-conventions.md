---
source: supy-service-inventory/.commitlintrc.json, supy-service-inventory/node_modules/@supy/commitlint-config/conventional/.commitlintrc.json, supy-service-inventory/node_modules/@commitlint/config-conventional/index.js, supy-service-inventory/.husky/commit-msg
mined_on: 2026-07-15
confidence: high
---

# Commit Conventions

Supy backend repos use `@supy/commitlint-config/conventional`, which extends `@commitlint/config-conventional`. The husky `commit-msg` hook runs `npx commitlint --edit $1` on every commit.

## Rules

1. **Type must be one of the following (lower-case, no others accepted):**
   `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`
2. Use `fix(scope):` for bug fixes. `bug(...)` is NOT a valid type and will be rejected by commitlint.
3. Type must be lower-case (`type-case: lower-case` is enforced).
4. Subject must not be empty (`subject-empty: never`).
5. Subject must not end with a full stop (`subject-full-stop: never`).
6. Subject must not start with a capital letter or use sentence-case, start-case, pascal-case, or upper-case (`subject-case: never` for those forms).
7. Header (type + scope + subject) must not exceed 100 characters.
8. Body max line length is 100 characters.
9. Footer max line length is 100 characters.
10. If a body is provided, a blank line must precede it (`body-leading-blank: always`).
11. If a footer is provided, a blank line must precede it (`footer-leading-blank: always`).
12. Scopes may be comma-separated when a commit touches multiple scopes (`scopeEnumSeparator: ","`, `enableMultipleScopes: true`).
13. Issue references use the `#` prefix (e.g., `closes #123`) and are placed in the footer.

## Examples

### Good

```
feat(ledger): add stock-movement RPC handler

Adds a new MessagePattern handler for ledger.items.stock-movement.
Delegates to GetStockMovementInteractor.

closes #42
```

```
fix(item): correct unit conversion in output transformer
```

```
chore(ci): upgrade Node to 24.10.0
```

```
refactor(recipe,wastage): migrate write side to CQRS commands layer
```

### Bad

```
bug(ledger): fix null pointer                  ← REJECTED: 'bug' is not a valid type
Fix: correct query                             ← REJECTED: missing type prefix
Feat(item): Add new handler                   ← REJECTED: type not lower-case, subject starts capital
feat(item): Add new handler.                  ← REJECTED: subject ends with full stop
```

## Red flags

- Any commit type not in the allowed list (especially `bug`, `hotfix`, `wip`) — commitlint will reject it.
- Uppercase type or subject starting with a capital.
- Missing scope when the change is clearly scoped to a domain (e.g., `ledger`, `item`, `transfer`).
- Subject that summarises the "what" but not the "why" — body should explain motivation for non-trivial changes.
- Secrets, tokens, connection strings, or env values in commit messages.

## Source

- `supy-service-inventory/.commitlintrc.json` — repo-level commitlint config (extends `@supy/commitlint-config/conventional`)
- `supy-service-inventory/node_modules/@supy/commitlint-config/conventional/.commitlintrc.json` — shared Supy config (extends `@commitlint/config-conventional`, adds multi-scope and issue-prefix settings)
- `supy-service-inventory/node_modules/@commitlint/config-conventional/index.js` — canonical `type-enum` list and formatting rules
- `supy-service-inventory/.husky/commit-msg` — enforces commitlint on every commit via `npx commitlint --edit $1`
