## supy-jsreport-templates — jsreport 2.11 server + Handlebars/Chrome-PDF templates (Node.js)

- **Purpose:** Multi-tenant PDF report generation (purchase orders, invoices w/ header/footer) via filesystem-stored jsreport templates, Handlebars + Chrome rendering.
- **Structure:** `/data/orders/` (main reports), `/data/header-footer/` (page headers); each template folder = `config.json` (jsreport metadata, recipe, engine, margins) + `content.handlebars` + `helpers.js` + sample `dataJson.json`; CSS/images as sibling jsreport resources.
- **Architecture & patterns:** Handlebars templating with page data model (retailer/supplier/user/order/products/totals); helpers (`formatCurrency`, `pdfAddPageItem`); chrome-pdf recipe (printBackground, margins); header/footer merged via `pdfOperations[].templateShortid`; tenant-aware via `tenantId: "supy-io"`; conditional optional fields.
- **Tooling:** lint=none · format=none · test=none · CI=none · codegen=none · pre-commit=none · commits=conventional (sc-XXXX prefixed) · run/deploy=`npm start` / `jsreport start` (port 5488).
- **Testing:** none (test data inlined in dataJson.json).
- **Security / secrets / config:** jsreport.config.json: auth **disabled**, hardcoded admin creds (dev-only), `allowLocalFilesAccess:true`, fs store, no env injection — dev/staging only. (Flag; do not reproduce credential values.)
- **Divergences vs Supy TS conventions:** no TypeScript, no lint/format/CI/tests, no data-contract schemas (JSON examples only), fs-based store (not code-driven).
- **New patterns worth codifying:** template folder structure (config+content+helpers+assets per report); sync-only scoped Handlebars helpers; sample `dataJson.json` as data-contract; `tenantId` metadata; header/footer via template shortid.
- **Recommendation:** **infra/policy-only + docs** — specialized reporting microservice, not a plugin stack. Codify: template folder/naming convention, required config.json fields (recipe/engine/margins/tenantId), Handlebars helper pattern, dataJson.json schema contract, and **move auth config to env-based admin override** before any non-dev use.
