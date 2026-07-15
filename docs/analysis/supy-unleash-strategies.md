## supy-unleash-strategies — Node.js / vanilla JavaScript (Unleash proxy custom strategies)

- **Purpose:** Custom Unleash feature-flag strategies for Supy retail ops (retailerId / roleIds / locationIds context targeting).
- **Structure:** single `/strategies` dir; `index.js` exports Strategy classes; minimal Unleash-proxy plugin layout.
- **Architecture & patterns:** classes extend `unleash-client` `Strategy`; each implements `isEnabled(parameters, context)` with CSV-delimited param parsing + `context.properties` matching; flexible singular/plural field handling (locationId vs locationIds); exported as array for proxy registration.
- **Tooling:** lint=none · format=none · test=placeholder echo · CI=none · codegen=none · pre-commit=none · commits=conventional (fix/feat/chore/style) · deploy=Dockerfile (copy strategies onto unleashorg/unleash-proxy base).
- **Testing:** none (placeholder); manual proxy validation.
- **Security / secrets / config:** Unleash API tokens external (proxy container env); no hardcoded creds; context injected at eval time.
- **Divergences vs Supy TS conventions:** plain JS (no TS); no lint/format/test/CI/pre-commit/commitlint.
- **New patterns worth codifying:** CSV param parsing reused across strategies; dual singular/plural context fields for backward compat.
- **Recommendation:** **docs-only** — lightweight Unleash-proxy extension. Optional: TS + ESLint/Prettier + a strategy unit-test harness to align with Supy standards; not critical. Verify unleash-client 3.15.0 prod compatibility.
