# Skill audit (R0 Task 1)

Audit of every `skills/*/SKILL.md` (excluding `skills/shared/*`, which is reference-only
content, not a skill) against the deterministic hygiene gate in
`scripts/check-skill-hygiene.sh` (Check H) and a manual read of each file. 31 skills total.

## Gate (Check H)

`scripts/check-skill-hygiene.sh` fails a `SKILL.md` when:

1. `name:` is empty or missing.
2. `description:` is empty or missing.
3. `description:` lacks a triggering cue (`use when` / a bare `when`).
4. The body (everything after the frontmatter's closing `---`) has fewer than 15
   non-blank lines — a proxy for "stub, not a decision procedure."

**First run result:** 6 skills failed check 3 (triggering cue) — see below. No skill failed
checks 1, 2, or 4: every skill already had a non-empty name/description and a substantive body
(the shortest, `supy-kg`, has 41 body lines — well over the 15-line floor, appropriate for its
narrow single-purpose scope). The thresholds were not tightened, per the R0 resolution: they
already encoded a genuine bar and finding zero stubs is an honest result, not a signal to
manufacture failures.

All 6 findings were fixed by rewording the existing trailing "Use ..." sentence to include an
explicit `when` clause, without changing the described triggering condition or scope:

| Skill | Before | After |
|---|---|---|
| `supy-review` | "Use before committing or opening a PR on a supy-\* repo." | "Use when about to commit or open a PR on a supy-\* repo." |
| `supy-rebase` | "Use to bring a feature branch up to date before review or merge on any supy-\* repo." | "Use when a feature branch needs to be brought up to date before review or merge on any supy-\* repo." |
| `supy-debrief` | "Use to wrap up a branch before handing off, after a hotfix, or to capture decisions before context is lost on any supy-\* repo." | "Use when wrapping up a branch before handing off, after a hotfix, or when decisions need to be captured before context is lost on any supy-\* repo." |
| `supy-commit` | "Use on any supy repo (backend, frontend, or Flutter/mobile) before pushing." | "Use when committing staged changes on any supy repo (backend, frontend, or Flutter/mobile) before pushing." |
| `supy-create-pr` | "Use after supy-review passes on any supy repo (backend, frontend, or Flutter/mobile)." | "Use when opening a PR, after supy-review passes, on any supy repo (backend, frontend, or Flutter/mobile)." |
| `supy-kg` | (no trailing "Use ..." clause at all) | appended "Use when you need cross-repo architecture context that a local grep cannot answer." |

Re-run after the fixes: `✓ skill-hygiene passed` (exit 0). No exceptions were needed — every
flagged skill was fixed without removing or narrowing its real trigger.

## Inventory table

Description quality is rated against Check H plus a manual read for specificity (does it name
the concrete situation, stack, and repo scope). Decision-procedure depth reflects the actual
body structure (governing-standard read, ordered steps, "before you finish" / "degradation
paths" sections) versus a shallow how-to.

| Skill | Description quality | Decision-procedure depth | references/ extracted? | Overlap flag | Action |
|---|---|---|---|---|---|
| `fix-failing-github-actions` | Good — stack-agnostic, names the trigger phrases | Thorough — When this applies / Prerequisites / The loop / Conventions / Degradation paths | No | None | None |
| `supy-ai-agents` | Good | Thorough — Step 0 standard read, per-concern sections, Before you finish, Degradation paths | No | None | None |
| `supy-analyze-native-codebase` | Good | Thorough — full workflow + output template | Yes (2 files) | None | None |
| `supy-angular-feature` | Good | Thorough — Step 0 standard read, per-concept sections, Before you finish | No | Companion of `supy-scaffold-feature` (by design, cross-referenced — see below) | None |
| `supy-app-release-readiness` | Good | Thorough — phased parallel-audit workflow with report template | No | None | None |
| `supy-baseline` | Good | Thorough, but the largest file in the set (645 lines / 448 body lines) with no `references/` split | No | None | Hardening candidate (not gate-flagged): consider extracting the CLAUDE.md template block into `skills/supy-baseline/references/` to keep `SKILL.md` itself lean, per the "skills stay lean" repo convention. Left as a recorded suggestion, not actioned in this task (no merge/extraction performed). |
| `supy-clean-architecture` | Good | Thorough — Step 0 standard read, per-building-block sections, Before you finish | No | Companion of `supy-scaffold-domain` (by design) | None |
| `supy-code-assessment` | Good | Thorough — Step 0 standard read, numbered assessment dimensions, output template | No | None | None |
| `supy-commit` | Good (fixed — added `when` cue) | Thorough — 5 ordered steps + Degradation paths | No | None | None |
| `supy-create-pr` | Good (fixed — added `when` cue) | Thorough — 6 ordered steps + Degradation paths | No | None | None |
| `supy-debrief` | Good (fixed — added `when` cue) | Thorough — 4 ordered steps + Degradation paths | No | None | None |
| `supy-e2e-tests` | Good | Thorough — run command, non-negotiable policies, workflow for fixing failures | No | None | None |
| `supy-feature-fanout` | Good | Thorough — 5 ordered steps, explicit "what this does not do", Guardrails | No | None | None |
| `supy-feedback` | Good | Thorough — 6 ordered steps + error-handling summary | No | None | None |
| `supy-figma-implement-design` | Good | Thorough — prerequisites, required workflow, troubleshooting | Yes (4 files) | None | None |
| `supy-figma-to-tickets` | Good | Thorough — 6 ordered steps + ticket template + guidelines | No | None | None |
| `supy-firebase-function` | Good | Thorough — Step 0 standard read, per-layer sections, Before you finish, Degradation paths | No | None | None |
| `supy-flutter-feature` | Good | Thorough — Step 0 standard read, per-layer sections, Before you finish | No | Companion of `supy-scaffold-flutter-feature` (by design) | None |
| `supy-flutter-upgrade` | Good | Thorough — 9 ordered steps + Before you finish | No | None | None |
| `supy-hotfix` | Good | Thorough — 8 ordered steps (discipline → branch → fix → commit → review → PR → follow-ups) + Degradation paths | No | None | None |
| `supy-impl-spec` | Good | Adequate — role/process/output sections, fewer explicit steps than the "Step N" skills but concrete and complete | No | Sibling of `supy-spike-spec` (different spec type — cross-referenced "Related skills" sections in both, no merge) | None |
| `supy-interview-feedback` | Good | Thorough — Step 0 standard read, scoring system, process, output | Yes (1 file) | None | None |
| `supy-kg` | Good (fixed — appended `when` cue) | Adequate — intentionally thin: a routing table from question type to Cortex MCP tool, appropriate for its narrow connector scope | No | None | None |
| `supy-rebase` | Good (fixed — added `when` cue) | Thorough — 6 ordered steps + Degradation paths | No | None | None |
| `supy-review` | Good (fixed — added `when` cue) | Thorough — 4 ordered steps, severity-grouped report template, Degradation paths | No | None | None |
| `supy-scaffold-domain` | Good | Thorough — 7 ordered steps (scaffold-first discipline) + Degradation paths | No | Companion of `supy-clean-architecture` (by design, cross-referenced) | None |
| `supy-scaffold-feature` | Good | Thorough — 8 ordered steps + Degradation paths | No | Companion of `supy-angular-feature` (by design, cross-referenced) | None |
| `supy-scaffold-flutter-feature` | Good | Thorough — 8 ordered steps + Degradation paths | No | Companion of `supy-flutter-feature` (by design, cross-referenced) | None |
| `supy-scaffold-handler` | Good | Thorough — 8 ordered steps + Degradation paths | No | None | None |
| `supy-spike-spec` | Good | Thorough — 8 ordered steps + Degradation paths + Related skills | No | Sibling of `supy-impl-spec` (different spec type — cross-referenced, no merge) | None |
| `supy-ts-cli` | Good | Thorough — Step 0 standard read, per-layer sections, Before you finish, Degradation paths | No | None | None |

## Dedup / hardening action list

1. **Six triggering-cue fixes (done in this task).** `supy-review`, `supy-rebase`,
   `supy-debrief`, `supy-commit`, `supy-create-pr`, `supy-kg` — each had a real trigger
   condition but phrased without the word "when"; reworded in place (see table above for
   before/after). Gate is green after the fix. No exceptions recorded — all six were fixed,
   none skipped.
2. **No true duplicates found.** The only same-domain skill pairs are deliberate companions
   (scaffold-structure skill + fill-in-the-code-shape skill: `supy-scaffold-domain` /
   `supy-clean-architecture`, `supy-scaffold-feature` / `supy-angular-feature`,
   `supy-scaffold-flutter-feature` / `supy-flutter-feature`) or deliberate siblings
   (`supy-impl-spec` / `supy-spike-spec` — implementation vs. research spec). Each pair already
   cross-references its counterpart in its own body. This task does not merge anything — that
   is Task 2's registry work; overlap flags above are informational only.
3. **`supy-baseline` is a references-extraction candidate but not actioned here.**
   At 645 lines / 448 body lines it is more than 4x the next-largest skill's body
   (`supy-analyze-native-codebase` at 276) and has no `references/` split, unlike the three
   skills that already extract long material (`supy-analyze-native-codebase`,
   `supy-figma-implement-design`, `supy-interview-feedback`). It passes the hygiene gate (it is
   not a stub — the opposite problem) and was left untouched: extracting its template content
   is a real edit to a skill's structure with its own review surface, out of scope for a
   hygiene-gate task that must not do unrelated rewrites. Recorded here as a candidate for a
   future hardening pass.
4. **Standards-first check.** Every skill whose scope names a stack cites its governing
   `config/standards/` file with a `Step 0 — Read the governing standard` (or equivalent)
   section; `scripts/validate-xrefs.sh` already gates that every `config/standards/*.md` file
   is cited by at least one agent, skill, or command, and that every
   `${CLAUDE_PLUGIN_ROOT}/...` reference resolves. No skill was found to contradict its cited
   standard during this read-through. A full line-by-line diff of every skill's prescriptive
   content against every standard's current text is a larger undertaking than this task's
   scope (a deterministic CI gate plus an inventory audit); none of the 31 reads surfaced a
   contradiction worth flagging.
