## supy-cerbos-policies — Cerbos authorization policies (YAML) — re-verified 2026-07-15

- **Purpose:** RBAC policies for the Supy platform across mobile, portal, and backend resources.
- **Structure:** `resource_policies/` (47 files, `resource_<name>.yaml`), `principal_policies/` (2: admin, superadmin), `derived_roles/` (empty, .gitkeep only). API `api.cerbos.dev/v1`.
- **Architecture & patterns:** **default-deny** dominant (most resources EFFECT_DENY per role); explicit allow-lists per resource; principal policies for admin/superadmin use wildcard (`*` actions on `*`); **no conditions / no derived roles / no CEL** — simple static RBAC; `version: "default"` everywhere.
- **Tooling:** validate=`cerbos-compile-action@v1` on PR/push (main, dev) · CI=GitHub Actions (cerbos.compile.yaml) · lint=none · pre-commit=none · commits=conventional · deploy=none (compile-only).
- **Testing:** **no Cerbos policy tests** (no `*_test.yaml`, no tests/ dir); .vscode references test schema but none exist; coverage implicit via allow/deny rules.
- **Security / secrets / config:** `.gitignore` excludes `.config/*`; branching main=PROD, dev=DEV; roles admin/superadmin unrestricted, plus manager/staff/accounting/drafter variants; external systems must bind roles to principals.
- **Divergences vs the plugin's documented security-cerbos standard (stale/wrong?):** no derived roles (empty placeholder); no CEL conditions (no owner/org/time checks); no policy tests; coarse granularity (all-actions-per-resource); no pre-commit compile.
- **New patterns worth codifying:** default-deny everywhere (make mandatory in templates); principal-policy precedence (admin/superadmin override resource policies — document precedence); role-variant naming (`-with-*` / `-with-no-*`).
- **Recommendation:** **deepen security-cerbos standard.** Add: (1) derived roles for composite/conditional logic; (2) CEL conditions for fine-grained access (`resource.owner == principal.id`); (3) `*_test.yaml` allow/deny suites per resource; (4) pre-commit `cerbos compile`; (5) documented role→principal binding contract (OIDC scopes/claims).
