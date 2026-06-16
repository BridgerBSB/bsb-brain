# Never Round Until Display (BLOCKING)

NEVER round, truncate, or quantize a metric value at any stage before
final display. Carry full float precision through every aggregation,
weighting, merge, and intermediate computation. Round ONCE, at the
display layer, in the same units as the displayed value.

User-stated rule, May 5 2026, while adding SB% to BR KPI surfaces.
"DO NOT ROUND UNTIL THE END!!!!! THIS SHOULD BE A RUKE!!!!!" — five
exclamation points worth of non-negotiable.

---

## Why this rule exists

Repeated rounding compounds error. Pre-rounding in decimal space and
then formatting in percentage space creates float-quantization
mismatches that drift values across surfaces — exactly the bug class
documented in `rules/damage-pct-cross-app-divergences.md` (May 2026
PD Goals Damage% incident, where `round(x, 4)` decimal-space rounds
diverged from `round(x*100, 1)/100` percentage-space rounds at
boundary values). When two surfaces compute the same metric but
round at different layers with different precision, the displayed
values silently differ across the codebase. Coaches see two values
for the same player and file it as a bug.

---

## How to apply

### SQL
- Don't wrap aggregates in `ROUND()` in CTEs or subqueries.
- Return raw integer counts (`SUM(sb)`, `SUM(cs)`) or full-precision
  floats. Let the next layer do math on real numbers.
- `CAST(... AS DECIMAL(N, K))` mid-pipeline counts as rounding —
  don't.

### Python aggregation
- `value = numerator / denominator` — full float, no `round(...)` call.
- When merging dataframes across queries, keep both sides at full
  precision. Never pre-round one to "match" the other — that
  introduces drift the moment one side's precision changes.
- `.round(2)` on a column "to clean up floats" is exactly what
  creates the bug class. Floats are fine.

### Display layer ONLY
- `f"{val * 100:.1f}%"` — the `:.1f` does the rounding implicitly at
  format time. This is the canonical single-rounding point.
- If you MUST store a rounded display form (e.g., for a Streamlit
  dataframe that doesn't accept format strings), round in **percentage
  space** (`round(val * 100, 1) / 100`), never in decimal space
  (`round(val, 4)` is the wrong canonical pattern — see the Damage%
  bug history).
- Display rounding precision must match across all surfaces showing
  the same metric. If KPI shows 1 decimal and tracker shows 2, the
  same player will appear to have different values.

### Cross-surface parity
- Two surfaces showing the same metric MUST round at the same boundary
  with the same precision. Three-surface metrics (catcher / OF / IF /
  BR — see `three-surface-parity.md`) must all round at the same
  layer.
- Pre-rounding one and post-rounding the other guarantees drift.
- When porting a metric to a new surface, copy the existing surface's
  rounding semantics exactly. Don't "improve" precision in the new
  one — that creates drift.

---

## Pairs with

- `rules/damage-pct-cross-app-divergences.md` — the canonical
  post-percentage-round pattern. Damage% specifically; same principle.
- `rules/three-surface-parity.md` — cross-surface invariants. This
  rule is enforced at every parity boundary.
- `rules/multi-level-rollup.md` — multi-level weighted averages must
  also stay at full precision until display.

---

## What NOT to do

- **Don't** add `round(x, N)` mid-pipeline "for cleanliness." It
  isn't cleanliness — it's drift waiting to happen.
- **Don't** assume two `round(..., 1)` calls at the same precision
  are idempotent across float-representation boundaries. They aren't —
  values like `0.045500001` round differently in decimal-space vs.
  percentage-space.
- **Don't** pre-round one merge side to "match" the other. Keep
  both at full precision and round once after the merge.
- **Don't** round in SQL CTEs and again in Python. Pick the display
  layer and keep everything upstream raw.
- **Don't** introduce a new precision in a new surface. If existing
  surfaces show 1 decimal, the new one shows 1 decimal — same as
  them, no "more accurate" 2-decimal version.
- **Don't** treat `.round()` as a no-op when porting code. Even when
  the result LOOKS the same, you've moved the rounding boundary.
