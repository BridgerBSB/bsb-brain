---
type: artifact
created: '2026-06-26'
source: wrc_eval_report.md
tags:
  - modeling
  - v2
  - eval
  - artifact
---
# v2 wRC+ / xwOBA Projection — Eval (2026-06-26)

Persisted copy of `wrc_eval_report.md` (Downloads) + the council's read.
Parent: [[promotion-release-models]] · register: [[artifacts-register]].

## Bake-off (out-of-fold)

| target | model | reached_mlb_oof_r2 | oof_r2 | n_reached |
|---|---|---|---|---|
| xwoba | lightgbm | +0.412 | +0.421 | 4644 |
| wrc_plus | lightgbm | +0.251 | +0.505 | 4644 |
| xwoba | ridge | +0.159 | +0.134 | 4644 |
| wrc_plus | ridge | +0.083 | +0.315 | 4644 |

## Per-level R² (reached-MLB) — xwoba × lightgbm

| level | n | r2 |
|---|---|---|
| A | 79 | +0.107 |
| A+ | 149 | +0.040 |
| AA | 361 | +0.043 |
| AAA | 1647 | +0.095 |
| **MLB** | **2382** | **+0.602** |

## 🔬 Data Scientist verdict — the headline is a mirage

Reproduced on `wrc_oof_predictions.parquet`:

| slice | R² |
|---|---|
| headline (all reached-MLB) | +0.412 |
| MLB-level input rows (circular) | +0.602 |
| **MiLB-only (the real task)** | **+0.089** |
| age+level baseline (MiLB) | −0.005 |

**51% of reached-MLB rows were MLB-level seasons** → they inflate the headline by
using big-league stats to "predict" big-league results. Honest minor-league→MLB
projection signal is **R² ≈ 0.09 (xwOBA)** / **−0.07 (wRC+)**. Features add only
~+0.09 over age+level. Eval methodology bug: it pooled MLB rows; the metric that
matters is **MiLB-only, player grain**.

**Outcome:** v2 PARKED. v1 is the priority. (Full reasoning in
[[promotion-release-models]] § CRITICAL FINDING.)
