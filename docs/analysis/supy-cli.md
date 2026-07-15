## supy-cli — TypeScript CLI (commander.js) · MongoDB scripts runner (standalone)

- **Purpose:** Domain DB-scripting CLI for bulk operations across Supy MongoDB databases (catalog, inventory, core, orders, settlements, audit) — replacements, syncs, exports.
- **Structure:** Clean Architecture (domain/application/infrastructure/presentation). domain=interfaces+entities; application=use cases + 50+ script impls; infrastructure=config/DB/logging/UI; presentation=commands. Scripts expose `ScriptDetails` for rich `--info` (overview, inputs, DBs touched, steps, warnings).
- **Architecture & patterns:** commander.js (`supy-cli scripts [run|list|info]`); env-based config (.env + .env.{development,production}); Mongoose pooling per DB; scripts implement `IScript` with async `execute(context)`; chalk + inquirer UX (prod warnings, prompts); try-catch at CLI entry + per-script validation.
- **Tooling:** lint=ESLint 8.56 (@typescript-eslint) · format=Prettier 3.1 (100 cols) · test=**none** · CI=**none** · codegen=none · pre-commit=**none** · commits=conventional not enforced · distribution=npm bin (shebang via scripts/copy-shebang.js).
- **Testing:** none; scripts manually integration-tested vs dev/prod DBs.
- **Security / secrets / config:** creds via env (MONGO_DB_USER/PASS); .env layering; **production requires explicit confirmation prompt**; no secrets in VCS; DB URIs from env (DEV_*/PROD_* pattern).
- **Divergences vs Supy nestjs-nx conventions:** standalone (not Nx); commander.js; Clean Arch (not NestJS layers); direct Mongoose (not shared DB lib); no Jest; ESLint 8 (not flat 9); Prettier not shared config.
- **New patterns worth codifying:** **`ScriptDetails` self-documenting metadata** (inputs/DBs/steps/warnings); environment-aware confirmation flow; batch-processing utils (batchArray); path aliases (@domain/@application/@infrastructure).
- **Recommendation:** **candidate NEW stack (ts-cli)** — codify commander.js + ScriptDetails + env-layering + prod confirmation guards as the Supy CLI archetype. Do NOT fold into nestjs-nx (operational safety > monorepo coupling). Share only ESLint/Prettier/tsconfig baseline. Add Husky + commitlint to align tooling.
