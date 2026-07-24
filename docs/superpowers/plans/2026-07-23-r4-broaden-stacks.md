# R4 "Broaden Stack Coverage (on-demand)" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make adding a new stack a **repeatable, test-first ritual** rather than a bespoke effort. This plan ships two things: (1) a reusable **add-a-stack asset-set contract** — the exact set of files and doc/manifest edits every new stack must satisfy, plus the `detect-stack.sh` ordering discipline — and (2) one **worked instantiation** of that contract for a **Python services** stack (FastAPI/Django-style), authored end-to-end as the concrete demonstration.

**Architecture:** `supy-wingspan` ships no runtime code — only Markdown, JSON, and shell. A "new stack" is a fixed asset set: a `config/standards/<stack>/` rulebook, an `agents/supy-<stack>-reviewer.md` with an Output Contract, one or more `skills/supy-<stack>/`, a `templates/<stack>/` drop-in, a correctly-**ordered** branch in `hooks/detect-stack.sh`, matching doc/manifest counts, and a proof (fixture + live). The "test" for the load-bearing, error-prone part — stack detection — is `scripts/test-detect-stack.sh`: a new branch is added **test-first** (add the failing fixture case, watch it fail, add the branch, watch it pass). Everything else is validated by the existing `scripts/validate-*.sh` + `scripts/check-docs-inventory.sh` + `plugin-dev:plugin-validator`.

**Tech Stack:** Markdown, JSON, Bash (`bash` arrays, `grep`), `shellcheck`, `markdownlint`, `cspell`, `git` (PRs to `main`).

## Global Constraints

Every task's requirements implicitly include this section. Values are carried verbatim from `docs/superpowers/specs/2026-07-23-enhancement-roadmap-refresh-design.md` §3.

- **On-demand only.** Per spec §10, a stack is authored **only when a real repo warrants it — no speculative stacks.** The Python instantiation in this plan is a **demonstration of the pattern**; landing it as a supported stack is gated on a real Python repo appearing in the fleet. If no such repo exists at execution time, complete the generic contract (Phase 0) and the detector/asset scaffolding, but mark the live-proof task (Phase 5) `- [ ]` blocked until a real repo is available, and do **not** claim Python as "proven" in the docs.
- **Secrets.** NEVER reproduce a secret value in any file, diff, commit message, fixture, or finding. Cite `path:line` only.
- **Conventional Commits.** `feat:` / `docs:` / `fix:` (use `fix()`, never `bug()`). Claude-authored commits end with the trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Component bodies** (agents, skills, hooks) reference their own files via `${CLAUDE_PLUGIN_ROOT}` — never a hardcoded absolute path. Absolute paths are allowed only in human-facing docs.
- **New dictionary words** (e.g. `fastapi`, `pydantic`, `uvicorn`, `pyproject`, `mypy`, `pytest`, `alembic`) go in `config/cspell.json` (alphabetical, case-insensitive) — never suppress the check inline.
- **Pre-commit gate.** The repo-local hook (`git config core.hooksPath .githooks`) runs `markdownlint`, `cspell`, and `shellcheck` on staged files; CI mirrors it. Every task ends green.
- **Detection must not regress.** Adding a branch to `detect-stack.sh` must leave all existing `scripts/test-detect-stack.sh` cases passing. The hook must always `exit 0` (never fail a session).

---

## Part A — The reusable add-a-stack contract (reference)

This is the checklist **every** new stack instantiates. It is authored once (Phase 0) as `docs/adding-a-stack.md` and is the source the Python worked example (Phases 1–5) follows. The eight required deliverables:

| # | Deliverable | Path | Contract |
|---|---|---|---|
| **(a)** | Standards rulebook | `config/standards/<stack>/architecture.md` | A `## Rules` section with numbered, anchor-addressable rules and a `## Red flags` section. Repo-wide gaps go under `## Remediation backlog` (not per-diff blockers). This is the **source of truth** the reviewer cites — authored before the reviewer. |
| **(b)** | Review agent | `agents/supy-<stack>-reviewer.md` | Frontmatter (`name`, `description`, `tools: Read, Grep, Glob, Bash`, `model`); `## Focus`, `## Context Sources (Fallback Order)`, `## What to Review`, `## Worked Examples` (one PASS, one ISSUES FOUND), `## Output Contract`. Governing-standards + severity-rubric lines use `${CLAUDE_PLUGIN_ROOT}`. Every finding cites a rule anchor; secrets by `path:line` only. |
| **(c)** | How-to skill | `skills/supy-<stack>/SKILL.md` | Lean decision procedure (frontmatter `name` + triggering `description`); long/optional material pushed to `references/`; shared content reused from `skills/shared/`. Registered by the skill router. |
| **(d)** | Template drop-in | `templates/<stack>/` | `CLAUDE.md.hbs` (canonical repo guidance), stack enforcement config (linter/formatter), and — per R2 — an offline `pre-commit` hook (secret-scan + commit-message lint + coverage-bar) and secret-scan baseline. |
| **(e)** | Ordered detection | `hooks/detect-stack.sh` **+** `scripts/test-detect-stack.sh` | A new branch inserted in the **correct order** (see ordering rules below) + a nudge message; at least one positive fixture case, plus collision cases proving no existing stack is mis-detected. Added **test-first**. |
| **(f)** | Doc/manifest counts | `README.md`, `docs/USAGE.md`, `.claude-plugin/plugin.json` | Agent/skill/hook counts updated so `scripts/check-docs-inventory.sh` passes; stack tables (README §detection, USAGE §6) gain a row; `plugin.json` keywords extended; `/supy-review` dispatch-by-stack line updated. |
| **(g)** | Validation | — | `plugin-dev:plugin-validator` → VALID; `scripts/validate-agents.sh`, `validate-skills.sh`, `validate-xrefs.sh`, `test-skill-router.sh`, `check-docs-inventory.sh`, `test-detect-stack.sh`, `shellcheck` all green. |
| **(h)** | Proof | `evals/fixtures/<stack>/`, `docs/PILOT.md` | A fixture pilot per R1 (representative diff + expected-findings manifest, secrets scrubbed) and — for the first real repo — a live `/plugin install` → detect → `/supy-review` run recorded in `docs/PILOT.md`. |

### Detection ordering rules (the load-bearing discipline)

`detect-stack.sh` is **first-match-wins**. The invariant: **more specific stacks are tested before more generic ones**, and any app stack that could carry incidental infra YAML is tested **before** `k8s-config` (the generic YAML catch). Current order:

1. Nx flavours (`nx.json` + `package.json` → angular / nestjs / plain nx)
2. `flutter` (`pubspec.yaml` — wins even over Nx markers)
3. `firebase-functions` (`firebase.json` + `functions/`) — before k8s so incidental YAML isn't misread
4. `ts-cli` (root `package.json` with `commander` + `bin`) — inspects only the **root** package.json
5. `ai-agents` (**any** non-`node_modules` `package.json` depending on the MCP or Claude Agent SDK)
6. `k8s-config` (`kustomization.yaml` or a `kind: ConfigMap`/`kind: Secret` YAML anywhere) — the generic catch
7. unknown/mixed → silent

**Where the Python branch goes and why:** insert it **after `ai-agents` (step 5) and before `k8s-config` (step 6).**

- **After `ai-agents`:** the polyglot `supy-ai-agents` monorepo contains Python *and* the MCP SDK. If Python were tested first, that repo would misclassify as `python`. Testing `ai-agents` first preserves its identity; a repo reaching the Python branch is Python-*only* (no MCP/agent SDK, no Node root orchestration).
- **Before `k8s-config`:** a Python service repo routinely ships deployment manifests (Helm charts, raw k8s YAML). If `k8s-config` were tested first, a FastAPI service with a `k8s/` dir would misclassify as `k8s-config`. This mirrors the exact precedence already granted to `firebase-functions` and `ts-cli` over `k8s-config`.
- **No collision with Node/Flutter/Firebase stacks:** Python is detected by `pyproject.toml`/`requirements.txt` at the repo root, which none of those stacks carry; and those branches run earlier anyway.

---

## File Structure (Python worked example)

- `docs/adding-a-stack.md` (create) — the Part A contract, authored as a durable reference.
- `hooks/detect-stack.sh` (modify) — add the `python` branch (step 5.5) + nudge message.
- `scripts/test-detect-stack.sh` (modify) — add positive + collision fixture cases.
- `config/standards/python/architecture.md` (create) — the Python services rulebook.
- `agents/supy-python-reviewer.md` (create) — the Python reviewer with Output Contract.
- `skills/supy-python/SKILL.md` (create) — the Python how-to skill.
- `templates/python/` (create) — `CLAUDE.md.hbs`, `ruff.toml` (or `pyproject.toml` tool config), `pre-commit` hook, secret-scan baseline.
- `evals/fixtures/python/` (create) — fixture diff + expected-findings manifest (per R1's schema).
- `README.md`, `docs/USAGE.md`, `.claude-plugin/plugin.json`, `config/cspell.json` (modify) — counts, tables, keywords, dictionary.
- `docs/PILOT.md` (modify) — a Python row (live proof gated on a real repo).

---

## Phase 0 — Author the reusable contract

### Task 0.1: Write `docs/adding-a-stack.md`

**Files:**
- Create: `docs/adding-a-stack.md`

**Interfaces:**
- Produces: `docs/adding-a-stack.md` containing the Part A table (deliverables a–h) verbatim and the "Detection ordering rules" section. Phases 1–5 cite its section anchors.

- [ ] **Step 1:** Write the doc with two sections: `## The asset-set contract` (the a–h table above) and `## Detection ordering discipline` (the first-match-wins invariant + the "test each new branch first" rule). Add a closing `## Checklist` with an actionable `- [ ]` line per deliverable a–h that a future stack author copies.
- [ ] **Step 2:** Add any new words to `config/cspell.json`; run `npx markdownlint-cli2 --config config/custom.markdownlint.jsonc docs/adding-a-stack.md` and `npx cspell --config config/cspell.json docs/adding-a-stack.md` → both clean.
- [ ] **Step 3:** Commit: `docs: add reusable add-a-stack contract for R4`.

---

## Phase 1 — Detection (test-first)

This is the only load-bearing, regression-prone change. It is done strictly test-first.

### Task 1.1: Add the failing Python fixture cases

**Files:**
- Modify: `scripts/test-detect-stack.sh`

**Interfaces:**
- Consumes: the existing `run_case <name> <expected-substring> <setup-fn>` harness and `setup_*` builder convention.
- Produces: four new fixture builders + `run_case` lines that **fail** until Task 1.2 lands the branch.

- [ ] **Step 1:** Add fixture builders after the existing ones:

```bash
setup_python_pyproject() {
  printf '[project]\nname = "svc"\ndependencies = ["fastapi"]\n' >"$1/pyproject.toml"
}
setup_python_requirements() {
  printf '%s\n' fastapi uvicorn >"$1/requirements.txt"
}
# A Python service that ships deployment manifests must NOT misclassify as k8s-config.
setup_python_over_k8s() {
  setup_python_pyproject "$1"
  mkdir -p "$1/k8s"
  printf 'kind: ConfigMap\n' >"$1/k8s/config.yaml"
}
# The polyglot ai-agents monorepo carries Python AND the MCP SDK — it must stay ai-agents.
setup_ai_agents_with_python() {
  setup_ai_agents "$1"
  printf '[project]\nname = "cortex"\n' >"$1/pyproject.toml"
}
```

- [ ] **Step 2:** Add the `run_case` lines in the `# --- cases ---` block, positioned **after** the `ai-agents` cases and **before** the `k8s-config` cases (mirroring detection order):

```bash
run_case "python via pyproject" "detected python repo" setup_python_pyproject
run_case "python via requirements.txt" "detected python repo" setup_python_requirements
run_case "python beats k8s-config" "detected python repo" setup_python_over_k8s
run_case "ai-agents beats python" "detected ai-agents repo" setup_ai_agents_with_python
```

- [ ] **Step 3:** Run `bash scripts/test-detect-stack.sh`. **Expected: the three `python …` cases FAIL** (`expected substring 'detected python repo', got: <empty>` — Python currently falls through to silent/unknown or, for `python_over_k8s`, to `k8s-config`), and `ai-agents beats python` **passes** (ai-agents is already tested first). This confirms the test is real before writing the branch. Do not commit yet.

### Task 1.2: Add the Python detection branch

**Files:**
- Modify: `hooks/detect-stack.sh`

**Interfaces:**
- Consumes: `$root`, `$stack` from the hook; the `[ -z "$stack" ]` guard convention.
- Produces: a `python` value + a nudge branch; makes Task 1.1's cases pass.

- [ ] **Step 1:** Insert **between** the `ai-agents` block (ends line ~34) and the `k8s-config` block (begins line ~36):

```bash
# Standalone Python service (non-Nx, no MCP/agent SDK): pyproject.toml or requirements.txt at the
# repo root. Checked after ai-agents (the polyglot monorepo carries Python but must stay ai-agents)
# and before k8s-config, so a Python service that ships deployment YAML is not misread as k8s-config.
if [ -z "$stack" ] && { [ -f "$root/pyproject.toml" ] || [ -f "$root/requirements.txt" ]; }; then
  stack="python"
fi
```

- [ ] **Step 2:** Add the nudge branch alongside the other stack-specific messages (before the generic fallback at line ~70):

```bash
if [ "$stack" = "python" ]; then
  msg="supy-wingspan: detected python repo (standalone service) — prioritise secret hygiene (env/secret store, never literals/argv/logs), typed request/response validation, auth on exposed endpoints, and no bare excepts that swallow errors. Run supy-review (supy-python-reviewer); see config/standards/python/architecture.md."
  if [ ! -f "$root/CLAUDE.md" ]; then
    msg="$msg No CLAUDE.md found — run the supy-baseline skill to generate one."
  fi
  echo "$msg"
  exit 0
fi
```

- [ ] **Step 3:** Run `bash scripts/test-detect-stack.sh` → **all cases pass** (the three `python` cases now green, all pre-existing cases still green — no regression). Run `shellcheck hooks/detect-stack.sh scripts/test-detect-stack.sh` → clean.
- [ ] **Step 4:** Commit: `feat: detect standalone python service stack`.

---

## Phase 2 — Standards + reviewer

### Task 2.1: Author `config/standards/python/architecture.md`

**Files:**
- Create: `config/standards/python/architecture.md`

**Interfaces:**
- Produces: anchor-addressable `## Rules` (rule 1..N) + `## Red flags` + `## Remediation backlog`, cited by the reviewer's Output Contract.

- [ ] **Step 1:** Write the rulebook following the `ts-cli/architecture.md` shape. Candidate rules (refine against a real repo when one appears): (1) layer direction (routers/controllers → services → repositories → domain; no DB session in a route handler); (2) typed request/response models (Pydantic / dataclasses) at every external boundary — no untyped `dict` in/out; (3) config from env/secret store via a settings object — **no hardcoded URI/token/password** (high, merge-blocking; `path:line` only); (4) no secrets in argv/logs; (5) auth enforced on every exposed endpoint; (6) no bare `except:` / `except Exception: pass` that swallows errors — surface or re-raise with context; (7) deterministic process exit / structured error responses; (8) DB/IO isolated behind a repository, injectable and testable without a live connection; (9) bulk operations batched/streamed, not loaded whole.
- [ ] **Step 2:** Cross-link secrets rules to `config/standards/secrets-and-config.md#rules`. Add new words to `config/cspell.json`. Lint clean.
- [ ] **Step 3:** Commit: `feat: add python services standards rulebook`.

### Task 2.2: Author `agents/supy-python-reviewer.md`

**Files:**
- Create: `agents/supy-python-reviewer.md`

**Interfaces:**
- Consumes: `config/standards/python/architecture.md` anchors + `config/standards/review-severity.md`.
- Produces: an agent whose Output Contract matches the shared reviewer shape so `supy-review` parses it.

- [ ] **Step 1:** Copy the structure of `agents/supy-ts-cli-reviewer.md` exactly — frontmatter (`name: supy-python-reviewer`, triggering `description`, `tools: Read, Grep, Glob, Bash`, `model: sonnet`), `## Focus`, `## Context Sources (Fallback Order)` (Cortex → repo `CLAUDE.md` → standards file, degrade gracefully), `## What to Review` (one numbered check per rule 1–9), `## Worked Examples` (one PASS, one ISSUES FOUND with `[severity: high|med|low] <file>:<line> — <problem> → <fix> (rule: architecture.md#rules rule N)`), and the exact `## Output Contract` block:

```text
## supy-python-reviewer — <PASS | ISSUES FOUND>
- **[severity: high|med|low]** <file>:<line> — <problem> → <concrete fix> (rule: <standards anchor>)
```

- [ ] **Step 2:** Governing-standards + severity-rubric lines use `${CLAUDE_PLUGIN_ROOT}`. Reinforce "Never reproduce a secret value — cite path:line only" and "Never invent rules." Run `bash scripts/validate-agents.sh` → the new agent validates. Lint clean.
- [ ] **Step 3:** Commit: `feat: add python services review agent`.

---

## Phase 3 — Skill + template

### Task 3.1: Author `skills/supy-python/SKILL.md`

**Files:**
- Create: `skills/supy-python/SKILL.md`

**Interfaces:**
- Produces: a skill registered by the router; `scripts/validate-skills.sh` + `scripts/test-skill-router.sh` pass.

- [ ] **Step 1:** Write a lean `SKILL.md` (frontmatter `name: supy-python`, a `description` that triggers on Python-service work in a `python` repo) whose body is the decision procedure for writing Python-service code the Supy way (the rulebook's rules, condensed). Push any long material to `references/`.
- [ ] **Step 2:** Register it wherever the router enumerates stack skills; run `scripts/validate-skills.sh` and `scripts/test-skill-router.sh` → green.
- [ ] **Step 3:** Commit: `feat: add supy-python how-to skill`.

### Task 3.2: Author `templates/python/`

**Files:**
- Create: `templates/python/CLAUDE.md.hbs`, `templates/python/ruff.toml`, `templates/python/pre-commit`, `templates/python/secret-scan` baseline

**Interfaces:**
- Produces: a drop-in enforcement set following the R2 pre-commit pattern (`templates/flutter/`, `templates/k8s-config/`).

- [ ] **Step 1:** `CLAUDE.md.hbs` — canonical repo guidance for a Python service (layering, config, typing, testing), mirroring `templates/ts-cli/CLAUDE.md.hbs`.
- [ ] **Step 2:** `ruff.toml` (lint/format config) + an offline `pre-commit` hook that runs secret-scan + commit-message lint + the coverage-bar check from `config/standards/ci-coverage-baseline.md`, self-contained shell (no CI dependency), `shellcheck`-clean.
- [ ] **Step 3:** Commit: `feat: add python stack template and pre-commit hook`.

---

## Phase 4 — Docs, manifest, validation

### Task 4.1: Update counts, tables, keywords

**Files:**
- Modify: `README.md`, `docs/USAGE.md`, `.claude-plugin/plugin.json`, `config/cspell.json`

**Interfaces:**
- Consumes: actual tree counts from `scripts/check-docs-inventory.sh`.
- Produces: docs consistent with the new agent + skill; `check-docs-inventory.sh` passes.

- [ ] **Step 1:** Run `bash scripts/check-docs-inventory.sh` to read the current actual counts, then bump the agent count (12 review agents) and skill count in **both** `README.md` and `docs/USAGE.md`. Add a `python` row to the README detection table and USAGE §6 detection table (Detected by: root `pyproject.toml`/`requirements.txt`, after ai-agents, before k8s-config). Update the `/supy-review` dispatch-by-stack line: `python` → 3 (python reviewer, commit/PR, secrets).
- [ ] **Step 2:** Extend `.claude-plugin/plugin.json` `keywords` (`python`, `fastapi`, `pydantic`) and the `description`. Bump `version` per release-please conventions if required by the release flow (else leave to release-please).
- [ ] **Step 3:** Run `bash scripts/check-docs-inventory.sh`, `scripts/validate-xrefs.sh` → green. Lint clean.
- [ ] **Step 4:** Commit: `docs: register python stack in README, USAGE, and manifest`.

### Task 4.2: Full validation gate

**Files:** none (verification only)

- [ ] **Step 1:** Run in sequence and confirm green: `bash scripts/test-detect-stack.sh`, `bash scripts/validate-agents.sh`, `bash scripts/validate-skills.sh`, `bash scripts/validate-commands.sh`, `bash scripts/validate-xrefs.sh`, `bash scripts/test-skill-router.sh`, `bash scripts/check-docs-inventory.sh`, `shellcheck hooks/*.sh scripts/*.sh templates/python/pre-commit`.
- [ ] **Step 2:** Invoke the `plugin-dev:plugin-validator` agent → **VALID**. Fix any finding and re-run.
- [ ] **Step 3:** Install this checkout as a local marketplace and exercise it against a Python repo (or the fixture): `/plugin marketplace add <path>` → `/plugin install supy-wingspan@supy` → `/reload-plugins`, open a Python repo, confirm the SessionStart line reads `detected python repo`.

---

## Phase 5 — Proof (fixture always; live gated on a real repo)

### Task 5.1: Fixture pilot (per R1)

**Files:**
- Create: `evals/fixtures/python/` (diff + expected-findings manifest)

**Interfaces:**
- Consumes: R1's fixture + expected-findings manifest schema and scorecard runner.
- Produces: a `python` fixture asserting the reviewer flags known findings (secrets scrubbed to `path:line`).

- [ ] **Step 1:** Capture a representative Python-service diff (from a real repo if available, else a hand-authored one exercising rules 2/3/5/6) into `evals/fixtures/python/` in R1's fixture layout, paired with an expected-findings manifest.
- [ ] **Step 2:** Run R1's scorecard runner on the `python` fixture → green (expected findings matched, no false positives). Wire into the same CI job R1 established.
- [ ] **Step 3:** Commit: `test: add python reviewer eval fixture`.

### Task 5.2: Live proof (gated)

**Files:**
- Modify: `docs/PILOT.md`

- [ ] **Step 1:** *If a real Python repo exists in the fleet:* run one live `/plugin install` → SessionStart detect → `/supy-review`, and record the row in `docs/PILOT.md` with token/turn counts and the detected-stack line (per R1's live-run capture form). *If not:* add the Python row marked ⏳ with a note "live proof blocked — no live Python repo yet (spec §10 on-demand)." Do **not** mark Python "proven" without this.
- [ ] **Step 2:** Commit: `docs: record python stack pilot status`.

---

## After This Plan

The Python instantiation is complete as a **pattern demonstration**; whether it ships as a supported stack depends on a real repo (Task 5.2). The durable output is `docs/adding-a-stack.md` — the next stack (React/Next.js, Go, IaC) follows it directly, reusing Phases 0–5 as the template. Detection-branch ordering is the one step that always demands the test-first discipline in Phase 1.

## Self-Review (writing-plans)

Checked against spec §10 and the writing-plans criteria:

- **On-demand honored?** Yes — Global Constraints + Task 5.2 gate live proof on a real repo; Python is explicitly a demonstration, not a claim of coverage.
- **Full asset set (a–h)?** Yes — Part A table enumerates all eight; Phases 1–5 instantiate each (detection 1, standard+reviewer 2, skill+template 3, docs+manifest+validation 4, proof 5).
- **Ordering rationale concrete?** Yes — Python inserted after `ai-agents`, before `k8s-config`, with the polyglot-monorepo and deployment-YAML collisions named and covered by fixture cases (`ai-agents beats python`, `python beats k8s-config`).
- **Test-first for the risky part?** Yes — Task 1.1 adds failing cases and asserts the exact failure text *before* Task 1.2 writes the branch.
- **No placeholders?** The detect-stack branch, test cases, nudge message, and Output Contract are shown as real snippets; standards rules are candidate-listed with a "refine against a real repo" note rather than invented as final.
- **Bite-sized + Interfaces?** Each task is 2–5 min of edits with an Interfaces block linking producers/consumers.
- **Constraints threaded?** `${CLAUDE_PLUGIN_ROOT}` in bodies, `path:line`-only secrets, cspell additions, Conventional Commits + trailer, and the pre-commit gate all appear per-task.
