---
name: P-metric org rollup = per-catcher weighted avg, never direct pool
description: Org-level P99/P10/P01/P95/P25 metrics require per-player percentile → weighted avg by observation count. Direct pool PERCENTILE_CONT OVER (PARTITION BY org) is WRONG because it lets high-volume players dominate.
type: feedback
originSessionId: b6ecd67d-6ead-46f6-9588-6b40083b16c4
---
Org-level PERCENTILE_CONT metrics (P99 Arm, P10 Exchange, P01 Pop2B/Pop3B, P01 AugPop, P95 TopSpd, P25 React, etc.) MUST be computed as per-player P-metric → weighted avg by player observation count. Multi-level combines per-level org values weighted by level total obs count. Never direct pool. Never unweighted average.

**Why:** Direct pool PERCENTILE_CONT OVER (PARTITION BY org) treats every throw/play as equal. A starter's 200 throws drown out a backup's 5 throws and the "org P99 arm" effectively becomes "the starter's P99 arm." Also user's explicit correction Apr 17 2026 after I made the wrong move twice (first: per-catcher weighted → direct pool, then suggested: unweighted avg). Correct answer is per-catcher weighted by their obs count, stacked at every rollup layer.

**How to apply:**
- Any new/modified org rollup for a percentile metric in pd-goals, intangibles, barrelsville, arm-farm: use the CTE pattern (per_catcher CTE + outer SUM(val * n_obs) / SUM(n_obs) GROUP BY org).
- Rate metrics (K%, BB%, xwOBA, FPinZ%, R2K%, NetK, SurPP, FramRAA, BlockRAA, SB/CS counts, lead distances) stay direct pool SUM/SUM — they're arithmetic on raw events, not percentiles.
- Individual per-player values (PARTITION BY player_id) stay as direct PERCENTILE_CONT — that's each player's own distribution.
- Reference implementation: `pd-goals/src/org_kpi_data.py::_CATCHER_THROWING_ORG_QUERY` (Apr 17 2026, commit 34690de).
- Full standard written to `.claude/rules/gc2-metrics.md` "Org Rollup for P-metrics" section.
