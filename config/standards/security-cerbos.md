---
source: supy-cerbos-policies/README.md, supy-cerbos-policies/resource_policies/resource_user.yaml, supy-cerbos-policies/resource_policies/portal.yaml, supy-cerbos-policies/resource_policies/resource_item.yaml, supy-cerbos-policies/resource_policies/resource_stock_count.yaml, supy-cerbos-policies/resource_policies/resource_wastage.yaml, supy-cerbos-policies/resource_policies/resource_order.yaml
mined_on: 2026-07-15
confidence: medium
---

# Security & Cerbos Authorization

Supy uses [Cerbos](https://docs.cerbos.dev/) as the authorization policy engine. All access-control decisions are expressed as resource policies in the `supy-cerbos-policies` repo. Policies use [Common Expression Language (CEL)](https://github.com/google/cel-spec/blob/master/doc/langdef.md) for conditions.

Note: The cerbos-policies repo stores only policy definitions. Integration logic (how services call Cerbos to check permissions) is in individual backend services. The policy files mined here represent the structural conventions; deeper runtime integration patterns should be verified via Cortex MCP (`search_entities('cerbos')` or `get_repo_guide('<service>')`) when available.

## Rules

1. **Every resource that can be acted upon must have a corresponding resource policy** in `supy-cerbos-policies/resource_policies/`. File naming convention: `resource_<resource_name>.yaml` (snake_case).
2. **Default-deny pattern**: resource policies must start with a catch-all deny rule (`actions: ["*"], effect: EFFECT_DENY, roles: ["*"]`) before any allow rules. This ensures new resources are inaccessible until explicitly granted. (The deny-all example is from `resource_item.yaml`; the explicit allow examples below are from `portal.yaml` / `resource_user.yaml` — these demonstrate each approach separately, not halves of a single file.)
3. **Explicit allow rules** enumerate permitted `roles` for specific `actions` — no implicit grants.
4. Policy files use `apiVersion: api.cerbos.dev/v1`, `resourcePolicy.version: "default"`.
5. **All environment branches**: dev changes go to `dev` branch; production-grade policies go to `main` branch. Never merge policy changes directly to `main` without review.
6. **Policy conditions** use CEL expressions to express context-sensitive rules (e.g., attribute-based checks on the resource or principal).
7. A handler that exposes sensitive actions (create, update, delete, approve, deactivate) must have a Cerbos authorization check before executing business logic.
8. Hardcoded role strings in application code are a red flag — role names must match the canonical values defined in cerbos policies (e.g., `admin`, `superadmin`, `manager`, `staff`, `accounting`).
9. New resources introduced by a feature must be accompanied by a corresponding resource policy PR to `supy-cerbos-policies` before the feature ships to production.
10. Run Cerbos locally to validate policies before pushing: `cerbos server --config=.config.yaml` (HTTP on `localhost:3592`, gRPC on `0.0.0.0:3593`).

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

## Red flags

- A handler that performs create / update / delete / approve / deactivate actions with no Cerbos authorization check.
- Hardcoded role or permission strings in application code (e.g., `if (role === 'admin')`).
- A new resource shipped without a corresponding resource policy in `supy-cerbos-policies`.
- Policy files that lack the default-deny rule (missing catch-all `EFFECT_DENY`).
- Merging policy changes to `main` branch without review (production branch).
- Using `EFFECT_ALLOW` with `roles: ["*"]` for sensitive actions (grants to all roles, including anonymous).
- Resource policy `version` field not set to `"default"`.

## Source

- `supy-cerbos-policies/README.md` — branch strategy (dev/main), Cerbos installation and local run instructions
- `supy-cerbos-policies/resource_policies/resource_user.yaml` — explicit allow for `deactivate` action to `admin`/`superadmin`
- `supy-cerbos-policies/resource_policies/portal.yaml` — broad allow for portal resource across multiple roles
- `supy-cerbos-policies/resource_policies/resource_item.yaml`, `resource_stock_count.yaml`, `resource_wastage.yaml`, `resource_order.yaml` — default-deny-all pattern
- Runtime Cerbos integration patterns (how services call the Cerbos sidecar): not found in static files — verify via Cortex MCP (`search_entities('cerbos')`) or individual service CLAUDE.md files (confidence: medium for integration details)
