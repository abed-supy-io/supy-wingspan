# Behavioral evals

Everything else in this repo's CI is a **structural** check — does a skill have frontmatter, does
a path resolve, does the JSON parse. None of it answers the question the plugin actually exists to
answer: **does a reviewer catch the thing it is supposed to catch, and stay quiet when it should?**

These evals close that gap with golden fixtures. Each fixture is a small planted diff plus the
ground-truth verdict; a runner feeds the diff to the real review agent and scores what comes back.

## Layout

```text
evals/
├── fixtures/<reviewer>/<NN-case>/
│   ├── input.diff       # a unified diff to feed the reviewer
│   └── expected.json    # ground truth: verdict + expected findings
├── validate-fixtures.sh # deterministic structure check (CI-gated, no API key)
└── run-secrets-eval.sh  # behavioral scorer for supy-secrets-reviewer (needs `claude`)
```

### `expected.json` contract

```json
{
  "description": "what this fixture proves",
  "verdict": "issues",
  "findings": [
    { "file": "src/config/aws.ts", "line": 3, "severity": "high", "rule_contains": "rule 1" }
  ]
}
```

- `verdict` is `"pass"` or `"issues"`, and must agree with `findings` (a `pass` has an empty array).
- `rule_contains` is a substring the reviewer's cited rule must include, or `""` to skip the check.

## The two halves

**`validate-fixtures.sh` — deterministic, CI-gated.** Asserts every fixture is well-formed (diff
present, `expected.json` valid, verdict/findings invariant holds). Runs in CI with no API key, like
the other `validate-*.sh` scripts.

**`run-secrets-eval.sh` — behavioral, run locally or nightly.** Reconstructs the reviewer from its
own `agents/supy-secrets-reviewer.md` (so the eval always tracks the live agent), feeds each fixture
diff, parses the Output Contract, and scores:

- **recall** — did it catch the planted secret? A false negative is a missed credential — unsafe.
- **precision** — did it stay silent on the clean fixtures? A false positive erodes trust in the gate.

Because it calls an LLM it is non-deterministic and needs the `claude` CLI with working credentials,
so it is **not** a default CI gate. Run it before changing a reviewer or a standard it enforces:

```bash
bash evals/run-secrets-eval.sh                 # all secrets fixtures
bash evals/run-secrets-eval.sh 03-configmap    # one, by name substring
MODEL=sonnet bash evals/run-secrets-eval.sh    # try a different tier
```

The precision/recall fixtures include deliberate false-positive traps — e.g. placeholder-only values
in `.env.example`, which the standard explicitly allows and a naive grep-based scanner would flag.

## Extending to other reviewers

1. Add `fixtures/<reviewer>/<NN-case>/{input.diff,expected.json}` cases — include at least one clean
   `pass` fixture so precision is measured, not just recall.
2. Copy `run-secrets-eval.sh` to `run-<reviewer>-eval.sh` and point `agent_file` / `fixtures_root` at
   the new reviewer. The parsing assumes the shared Output Contract (`## <name> — PASS | ISSUES FOUND`
   then `- **[severity: …]** file:line — … (rule: …)`), which every review agent already follows.
