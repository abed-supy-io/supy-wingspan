# Behavioral evals

Everything else in this repo's CI is a **structural** check — does a skill have frontmatter, does
a path resolve, does the JSON parse. None of it answers the question the plugin actually exists to
answer: **does a reviewer catch the thing it is supposed to catch, and stay quiet when it should?**

These evals close that gap with golden fixtures. Each fixture is a small planted diff plus the
ground-truth verdict; a runner feeds the diff to the real review agent and scores what comes back.

## Layout

```text
evals/
├── fixtures/<dimension>/<NN-case>/
│   ├── input.diff        # a unified diff to feed the reviewer
│   └── expected.json     # ground truth: reviewer + verdict + expected findings
├── validate-fixtures.sh  # deterministic structure check (CI-gated, no API key)
├── run-review-eval.sh    # generalized behavioral scorer, any dimension (needs `claude`)
└── run-secrets-eval.sh   # thin shim: run-review-eval.sh secrets, kept for discoverability
```

A "dimension" is a fixture category, not necessarily a 1:1 mapping to a reviewer name — see the
table in [Adding a dimension](#adding-a-dimension) for the current set.

### `expected.json` contract

```json
{
  "reviewer": "supy-secrets-reviewer",
  "description": "what this fixture proves",
  "verdict": "issues",
  "findings": [
    { "file": "src/config/aws.ts", "line": 3, "severity": "high", "rule_contains": "rule 1" }
  ]
}
```

- `reviewer` names the agent that should review this fixture — a real file under `agents/` (e.g.
  `agents/supy-secrets-reviewer.md`). This is what lets `run-review-eval.sh` reconstruct and invoke
  the correct reviewer per fixture without a separate script per reviewer, and it's what
  `validate-fixtures.sh` Check R asserts resolves.
- `verdict` is `"pass"` or `"issues"`, and must agree with `findings` (a `pass` has an empty array).
- `rule_contains` is a substring the reviewer's cited rule must include, or `""` to skip the check.

## The two halves

**`validate-fixtures.sh` — deterministic, CI-gated.** Runs as the `eval-fixtures` job in CI, with no
API key, like the other `validate-*.sh` scripts. It asserts:

- **Check R** — every fixture's `expected.json` names a `reviewer` that resolves to a real
  `agents/<reviewer>.md`.
- **Check S+** — every reviewer agent under `agents/supy-*-reviewer.md` is exercised by at least
  one fixture whose `expected.json` names it in `reviewer`, so a stack's coverage can't silently
  regress to zero. Coverage is derived from the agent set itself, not a hand-maintained list, so it
  can't drift out of sync with the real reviewers.

Beyond those two checks it also validates fixture shape (diff present and non-empty, `expected.json`
valid, verdict/findings invariant holds, each finding well-formed).

**`run-review-eval.sh` — behavioral, run locally or nightly, not a CI gate.** For each fixture it
reconstructs the reviewer from its own `agents/<reviewer>.md` (so the eval always tracks the live
agent, never a copy of its instructions), feeds it the planted diff, parses the Output Contract, and
scores:

- **recall** — did it catch the planted finding(s)? A false negative is a miss — unsafe.
- **precision** — did it stay silent on the clean fixtures? A false positive erodes trust in the gate.

Because it calls an LLM it is non-deterministic and needs the `claude` CLI with working credentials,
so it is **not** a default CI gate — CI only runs the deterministic `validate-fixtures.sh`. Run the
behavioral half locally before changing a reviewer or a standard it enforces:

```bash
bash evals/run-review-eval.sh                       # every dimension
bash evals/run-review-eval.sh secrets                # one dimension, all its fixtures
bash evals/run-review-eval.sh secrets 03-configmap   # one dimension, filtered by name substring
MODEL=sonnet bash evals/run-review-eval.sh secrets   # override the agent's declared model tier
```

`run-secrets-eval.sh [fixture-name-substring]` still works as a shorter alias for
`run-review-eval.sh secrets`.

Each dimension prints a scorecard footer once its fixtures finish:

```text
<dim>  fixtures=N  TP=… FP=… missed=…  recall=… precision=…  ~tokens=…
```

`recall` and `precision` are 2-decimal ratios, or `n/a` when their denominator is zero (e.g. a
dimension with only `pass` fixtures has no denominator for recall). **`~tokens` is an approximate
estimate** — `chars(prompt + output) / 4` — not a real token count from the API; treat it as a
rough order-of-magnitude baseline for comparing runs, not a billing figure.

The precision/recall fixtures include deliberate false-positive traps — e.g. placeholder-only values
in `.env.example`, which the standard explicitly allows and a naive grep-based scanner would flag.

## Adding a dimension

1. Create `agents/<name>.md` for the new reviewer (or reuse an existing reviewer if the dimension is
   a new fixture category for an agent that already exists).
2. Add `evals/fixtures/<dim>/<fixture>/{input.diff,expected.json}` cases, with `expected.json.reviewer`
   pointing at the agent from step 1. Include at least one clean `pass` fixture so precision is
   measured, not just recall.
3. No separate registration step — Check S+ derives required coverage from `agents/supy-*-reviewer.md`
   directly, so once a fixture's `expected.json.reviewer` names the new agent, coverage is enforced
   automatically.

No new runner script is needed — `run-review-eval.sh <dim>` picks up any dimension whose fixtures
exist under `evals/fixtures/`, driven entirely by each fixture's `reviewer` field. The parsing
assumes the shared Output Contract (`## <name> — PASS | ISSUES FOUND` then
`- **[severity: …]** file:line — … (rule: …)`), which every review agent already follows.

Current dimensions and their reviewers (11 reviewers, 23 fixtures total):

| Dimension | Reviewer | Fixtures |
|---|---|---|
| `secrets` | `supy-secrets-reviewer` | 6 (incl. k8s ConfigMap) |
| `architecture` | `supy-architecture-reviewer` | 2 |
| `angular` | `supy-angular-reviewer` | 2 |
| `flutter` | `supy-flutter-reviewer` | 3 (Profile A + Profile B + clean) |
| `firebase-functions` | `supy-firebase-functions-reviewer` | 2 |
| `ts-cli` | `supy-ts-cli-reviewer` | 2 |
| `ai-agents` | `supy-ai-agents-reviewer` | 2 |
| `nats-event` | `supy-nats-event-reviewer` | 1 |
| `test-quality` | `supy-test-quality-reviewer` | 1 |
| `security` | `supy-security-reviewer` | 1 |
| `commit-pr` | `supy-commit-pr-reviewer` | 1 |
