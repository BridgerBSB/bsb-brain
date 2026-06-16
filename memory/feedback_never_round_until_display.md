---
name: Never round until display
description: NEVER round, truncate, or quantize a metric value at any stage before final display. Carry full float precision through all aggregation/weighting/merging. Round ONCE at the display layer.
type: feedback
originSessionId: fffb70a7-2ca6-41ae-a520-03298535f126
---
NEVER round, truncate, or quantize a metric value at any stage before final display. Carry full float precision through every aggregation, weighting, and intermediate merge step. Round ONCE, at the display layer, in the same units as the displayed value.

**Why:** User-stated rule, May 5 2026, while adding SB% column to BR KPI surfaces. Repeated rounding compounds error. Pre-rounding in decimal space and then formatting in percentage space creates float-quantization mismatches that drift values across surfaces — same bug class as the May 2026 PD Goals Damage% incident captured in `rules/damage-pct-cross-app-divergences.md`. The user yelled "DO NOT ROUND UNTIL THE END!!!!!" with five exclamation points, so this is non-negotiable.

**How to apply:**
- **SQL:** don't wrap aggregates in `ROUND()` in CTEs or subqueries. Return raw integer counts (`SUM(sb)`, `SUM(cs)`) or full-precision floats. Let the next layer do math on real numbers.
- **Python aggregation:** `value = numerator / denominator` — full float, never `round(...)` until the very end. When merging dataframes across queries, keep both sides at full precision; never pre-round one to "match" the other.
- **Display layer ONLY:** `f"{val * 100:.1f}%"` — the `:.1f` does the rounding implicitly at format time. If you must STORE a rounded display form, round in PERCENTAGE space (`round(val * 100, 1) / 100`), never in decimal space (`round(val, 4)` is the wrong canonical pattern — see Damage% bug).
- **Cross-surface parity:** if two surfaces show the same metric, they must round at the same boundary with the same precision. Pre-rounding one and post-rounding the other guarantees drift.
- **No "defensive" rounding:** `.round(2)` mid-pipeline "to clean up floats" is exactly what creates the bug. Floats are fine. Display rounds them.

Pairs with `rules/damage-pct-cross-app-divergences.md` (canonical post-percentage round pattern) and `rules/three-surface-parity.md` (cross-surface invariants).
