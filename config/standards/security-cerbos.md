---
source: supy-cerbos-policies/README.md, supy-cerbos-policies/resource_policies/resource_user.yaml, supy-cerbos-policies/resource_policies/portal.yaml, supy-cerbos-policies/resource_policies/resource_item.yaml, supy-cerbos-policies/resource_policies/resource_stock_count.yaml, supy-cerbos-policies/resource_policies/resource_wastage.yaml, supy-cerbos-policies/resource_policies/resource_order.yaml, supy-cerbos-policies/principal_policies/admin.yaml, supy-cerbos-policies/principal_policies/superadmin.yaml, supy-cerbos-policies/derived_roles/ (empty .gitkeep), supy-api-authorization (runtime integration)
mined_on: 2026-07-15
confidence: medium
---

# Security & Cerbos Authorization

Supy uses [Cerbos](https://docs.cerbos.dev/) as the authorization policy engine. All access-control decisions are expressed as policies in the `supy-cerbos-policies` repo.

**As mined, the policies are pure static RBAC.** Resource policies are default-deny catch-all plus explicit role allow-lists; every `resourcePolicy.version` is `"default"`; there are **no `condition:`/CEL blocks and no derived roles** (`derived_roles/` holds only an empty `.gitkeep`), and there are no policy test suites. Two `principal_policies/` (`admin.yaml`, `superadmin.yaml`) grant wildcard `actions: ["*"]` that override resource-level rules. Access is decided purely by matching a principal's `roles` against a resource's `actions`.

Because of that, this file has three parts and a reviewer must read them differently:

- **`## Rules`** — the conventions that hold in the mined policies *today*. Findings against these are defects.
- **`## Runtime integration`** — how backend services (primarily `supy-api-authorization`) actually call Cerbos. Confidence is medium; verify against the service via Cortex MCP (`search_entities('cerbos')`, `get_repo_guide('supy-api-authorization')`) before flagging.
- **`## Target state`** — the fine-grained model (derived roles, CEL ownership conditions, test suites) that the policies do *not* yet implement. These are recommendations. **A reviewer must NOT flag the absence of CEL, derived roles, or policy tests as a defect** — cite `security-cerbos.md#target-state` at `low` severity only when code contradicts the target direction.

The `supy-cerbos-policies` repo stores only policy definitions; integration logic lives in individual backend services.

## Rules

1. **Every resource that can be acted upon must have a corresponding resource policy** in `supy-cerbos-policies/resource_policies/`. File naming convention: `resource_<resource_name>.yaml` (snake_case).
2. **Default-deny pattern**: resource policies must start with a catch-all deny rule (`actions: ["*"], effect: EFFECT_DENY, roles: ["*"]`) before any allow rules. This ensures new resources are inaccessible until explicitly granted. (The deny-all example is from `resource_item.yaml`; the explicit allow examples below are from `portal.yaml` / `resource_user.yaml` — these demonstrate each approach separately, not halves of a single file.)
3. **Explicit allow rules** enumerate permitted `roles` for specific `actions` — no implicit grants.
4. Policy files use `apiVersion: api.cerbos.dev/v1`, `resourcePolicy.version: "default"`.
5. **All environment branches**: dev changes go to `dev` branch; production-grade policies go to `main` branch. Never merge policy changes directly to `main` without review.
6. **No conditions in current policies.** As mined, resource policies are role-based only — there are no `condition:`/CEL blocks and no derived roles. A rule grants an action to a set of `roles`, nothing more. (CEL ownership conditions and derived roles are target-state, not defects — see `## Target state`; do not flag their absence.)
7. A handler that exposes sensitive actions (create, update, delete, approve, deactivate) must have a Cerbos authorization check before executing business logic.
8. Hardcoded role strings in application code are a red flag — role names must match the canonical values defined in cerbos policies (e.g., `admin`, `superadmin`, `manager`, `staff`, `accounting`).
9. New resources introduced by a feature must be accompanied by a corresponding resource policy PR to `supy-cerbos-policies` before the feature ships to production.
10. Run Cerbos locally to validate policies before pushing: `cerbos server --config=.config.yaml` (HTTP on `localhost:3592`, gRPC on `0.0.0.0:3593`).
11. **Principal policies override resource policies.** `principal_policies/admin.yaml` and `principal_policies/superadmin.yaml` grant `actions: ["*"]`, which take precedence over resource-level rules. Any new or widened principal-policy grant has a large blast radius and must be reviewed as carefully as a wildcard resource allow.
12. **Capabilities are named roles, not inline conditions.** Role variants encode scope in the role name using `-with-*` / `-with-no-*` suffixes (e.g. a role that can or cannot see cost). A new capability is expressed as a new named role in the allow-list, never as an inline `condition:` bolted onto an existing rule.
13. **Policies compile in CI before merge.** `cerbos-compile-action` runs on PR and push and must pass before a policy change lands. There are currently **no policy test suites** (`*_test.yaml`) — adding them is target-state (see `## Target state` T3), not a current requirement.

## Examples

### Good — default-deny then explicit allow

```yaml
# resource_policies/resource_user.yaml
---
apiVersion: api.cerbos.dev/v1
resourcePolicy:
  version: "default"
  resource: "User"
  rules:
    - actions: ["deactivate"]
      effect: EFFECT_ALLOW
      roles:
        - admin
        - superadmin
```

### Good — broad role access for a portal resource

```yaml
# resource_policies/resource_portal.yaml
---
apiVersion: api.cerbos.dev/v1
resourcePolicy:
  version: "default"
  resource: "Portal"
  rules:
    - actions: ["*"]
      effect: EFFECT_ALLOW
      roles:
        - admin
        - superadmin
        - manager
        - staff
        - accounting
```

### Good — strict deny-all (resource under construction / not yet open)

```yaml
# resource_policies/resource_item.yaml
---
apiVersion: api.cerbos.dev/v1
resourcePolicy:
  version: "default"
  resource: "Item"
  rules:
    - actions: ["*"]
      effect: EFFECT_DENY
      roles: ["*"]
```

### Bad

```typescript
// WRONG: hardcoded permission check bypassing Cerbos
if (user.role === 'admin') {
  await this.transferInteractor.delete(id);
}

// WRONG: missing authorization check on a destructive handler
@MessagePattern('transfer.delete.one')
async deleteTransfer(@Payload(StrictValidationPipe) payload: DeleteTransferPayload) {
  // No Cerbos check before executing
  return await this.deleteTransferInteractor.execute(payload);
}
```

## Runtime integration

How backend services drive Cerbos. Mined primarily from `supy-api-authorization`; confidence medium — verify via Cortex MCP before flagging.

1. **A handler checks the decision, it never branches on the role.** Application code calls the authorization service (which calls Cerbos) and acts on the allow/deny result. It must not read `principal.roles` and `if (role === 'admin')` — that duplicates policy in code and drifts (see rule 8).
2. **Policy IDs come from `PolicyIdFactory`, not string concatenation.** Resource and policy identifiers are built through the factory so scope and naming stay consistent; hand-built id strings are a red flag.
3. **Admin policy writes are batched and bounded.** `CerbosAdminClient` runs in DB storage mode and syncs policies in batches of **≤ 10 per request**. An unbatched or unbounded admin push is a defect.
4. **Scoped checks carry the scope.** Scope-namespaced resources use the `@scope:reference` form; a check against a scoped resource that omits the `@scope:` qualifier will resolve against the wrong policy.
5. **Conditions are built through the condition-expression DSL, not raw CEL.** Where dynamic conditions exist at runtime, they are assembled via the DSL (`ConditionGroupOperatorEnum` → Cerbos `MatchExpr`) over `@cerbos/grpc` / `@cerbos/http`, not hand-written CEL strings.

## Target state

The fine-grained model the mined policies do **not** yet implement. These are recommendations — do not flag their absence as a defect. When code actively contradicts the target direction, cite `security-cerbos.md#target-state` at `low` severity.

- **T1 — Derived roles.** `derived_roles/` is currently an empty `.gitkeep`. The target is derived roles that compute effective roles from principal/resource attributes.
- **T2 — CEL ownership conditions.** Attribute-based rules such as `request.resource.attr.ownerId == request.principal.id`, expressed as CEL `condition:` blocks, to replace coarse role allow-lists where ownership matters.
- **T3 — Policy test suites.** `*_test.yaml` suites run by `cerbos compile` so policy changes are verified, not only compiled.
- **T4 — Pre-commit `cerbos compile`.** Compile locally in a pre-commit hook, not only in CI.
- **T5 — Role → principal binding contract.** A documented contract mapping application roles to the principal roles Cerbos evaluates, so the two cannot drift.

## Red flags

- A handler that performs create / update / delete / approve / deactivate actions with no Cerbos authorization check.
- Hardcoded role or permission strings in application code (e.g., `if (role === 'admin')`).
- A new resource shipped without a corresponding resource policy in `supy-cerbos-policies`.
- Policy files that lack the default-deny rule (missing catch-all `EFFECT_DENY`).
- Merging policy changes to `main` branch without review (production branch).
- Using `EFFECT_ALLOW` with `roles: ["*"]` for sensitive actions (grants to all roles, including anonymous).
- Resource policy `version` field not set to `"default"`.
- A new or widened `principal_policies/` wildcard grant (`admin`/`superadmin`) merged without explicit review (rule 11).
- A capability added as an inline `condition:` on an existing rule instead of a new named role variant (rule 12).
- Application code that hand-builds a Cerbos policy id by string concatenation instead of `PolicyIdFactory`, or pushes admin policy writes unbatched / above 10 per request (`#runtime-integration` rules 2-3).
- A check against a scope-namespaced resource that omits the `@scope:` qualifier (`#runtime-integration` rule 4).

## Source

- `supy-cerbos-policies/README.md` — branch strategy (dev/main), Cerbos installation and local run instructions
- `supy-cerbos-policies/resource_policies/resource_user.yaml` — explicit allow for `deactivate` action to `admin`/`superadmin`
- `supy-cerbos-policies/resource_policies/portal.yaml` — broad allow for portal resource across multiple roles
- `supy-cerbos-policies/resource_policies/resource_item.yaml`, `resource_stock_count.yaml`, `resource_wastage.yaml`, `resource_order.yaml` — default-deny-all pattern
- `supy-cerbos-policies/principal_policies/admin.yaml`, `superadmin.yaml` — wildcard `actions: ["*"]` principal grants that override resource rules (rule 11)
- `supy-cerbos-policies/derived_roles/` — empty (`.gitkeep` only); confirms no derived roles today (target-state T1)
- `supy-cerbos-policies` CI — `cerbos-compile-action` on PR/push compiles policies; no `*_test.yaml` suites present (rule 13, target-state T3)
- `supy-api-authorization` — runtime integration: `PolicyIdFactory`, `CerbosAdminClient` DB storage mode with batched sync (≤ 10/request), scope namespacing (`@scope:reference`), condition-expression DSL (`ConditionGroupOperatorEnum` → `MatchExpr`) over `@cerbos/grpc` / `@cerbos/http`. Confidence medium — verify via Cortex MCP (`get_repo_guide('supy-api-authorization')`, `search_entities('cerbos')`)
