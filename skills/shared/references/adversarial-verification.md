# Gated adversarial verification (canonical)

A second-pass skeptic that tries to refute a finding before it ships in the consolidated
report. This is R2 in the roadmap: raise review **precision** without a blanket cost
multiplier on every review. `supy-review` invokes this gate after findings are graded and
before the consolidated report is built.

## The gate

Verification fires **only** for a finding that is:

- **High-severity**, per `config/standards/review-severity.md`'s `high` definition — merging
  causes concrete harm: incorrect behavior, data loss or corruption, security or secret
  exposure, broken build/release/deploy, an unguarded external boundary, or a violation of a
  rule the governing standard marks non-negotiable (MUST / NEVER / "non-negotiable"); **or**
- **Flagged low-confidence** by the reviewer that raised it — the reviewer itself is unsure
  the defect is real or unsure of its blast radius.

Medium- and low-severity findings the reviewer is confident about skip verification entirely
and pass straight into the consolidated report. This is the precision lever: spend the extra
pass only where being wrong is expensive (a high finding blocks the merge) or where the
reviewer already signaled doubt — not on every line.

## The refutation test

For each gated finding, run a single skeptic pass: **a second read tries to prove this
finding wrong; it survives only if it cannot be refuted from the diff plus the cited
standard.**

Concretely:

1. Re-read the finding's cited evidence — the exact diff lines and the standard anchor it
   invokes (`rule: <anchor>`).
2. Attempt to construct the strongest counter-argument available from that same evidence:
   is the cited line actually reachable, does the standard actually mandate what the finding
   claims, is there a guard elsewhere in the diff the original pass missed, is the "harm"
   actually present or hypothetical.
3. If the counter-argument holds — the finding cannot be defended from the diff and the
   standard alone — drop the finding, or fold it into a lower-severity note if a real but
   smaller issue remains.
4. If the counter-argument fails — the finding stands up to the challenge — the finding
   survives unchanged into the report.

This is **one pass, one attempt at refutation**, not an open-ended adversarial loop. It either
refutes the finding or it doesn't.

## No blanket multiplier

This gate is deliberately narrow. It is **not** a second full review pass over every finding,
and it must never be implemented as one. Only gated findings (high-severity or
low-confidence) get the skeptic read; everything else is unaffected. A change that runs
verification over the whole findings set — inflating token cost across every review
regardless of risk — violates this reference and should be treated as a regression against
the R1 token baseline recorded in `docs/PILOT.md`.

## Budget-pressure degradation

The verification pass is cheap by design (one targeted re-read per gated finding), but it is
not free, and it must never be allowed to block the whole review. If token or time budget is
under pressure when a gated finding comes up for verification:

- **Skip the refutation attempt** for that finding.
- **Label it `unverified`** rather than either dropping it or asserting it survived — this is
  distinct from a normal PASS/finding line and must say so in the consolidated report (e.g.
  append `(unverified — skipped under budget pressure)` to the finding).
- **Proceed with the rest of the review.** Degrading one finding to `unverified` never stops
  the overall report from being produced — the same principle Step 3/4 of `supy-review`
  already apply to a skipped or errored reviewer.

Do not multiply the token budget to force every gated finding through verification
regardless of pressure — degrade to `unverified` and move on.
