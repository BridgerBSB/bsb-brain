# EV Misread P95 Precompute — Phase 1 (Barrelsville Hitting Pin)

Created 2026-06-24, in response to the database-strain escalation from R&D /
Navisite. Scope only. No code ships until reviewed and the freeze (JJ, no
new deploys) is lifted.

## Problem

Navisite flagged five parallel sessions (SPID 78, 99, 161, 196, 173) from
`Login: BASEBALL\zbridger`, `Hostname: PC-2MQ513149N` (the work laptop),
`Program: Python`, all running the same contact-quality query with wait type
`cxconsumer`. Root cause has two layers:

1. Client-side: the affiliate-tracker refresh fans queries five wide
   (`ThreadPoolExecutor(max_workers=5)`).
2. Server-side: each of those queries gets a parallel plan because of the
   `batter_ev_p95` CTE, which runs `PERCENTILE_CONT(0.95) OVER (PARTITION BY
   batter_id)` over a full 7-level season scan. `cxconsumer` is the
   parallel-query consumer wait, i.e. the box is splitting each query across
   many cores. Five wide client queries times many server threads each is the
   saturation.

The `batter_ev_p95` percentile is recomputed inside essentially every tracker
query, redundantly, and during a pin run dozens of those executions stack up.
This is the hottest single piece of code.

## The certified invariant (why a single precompute is output-safe)

`EV_MISREAD_CTE` (in `barrelsville/src/database.py`) is parameterized by
`{{season}}` only. Everything else is hardcoded inside it:

- `pitch_result_id IN (12, 13, 14)`
- `hit_exit_speed > 0 AND hit_exit_speed < 125`
- `sched_type IN ('R', 'S', 'E')`
- level scope `('mlb','aaa','aax','afa','afx')` plus `gc2_level_code IN ('rok','dsl')`
- `n_bip >= 20`
- fallback `ISNULL(bp95.p95_ev, 105)` applied at each call site

It does NOT read the calling query's level filter, H/A split, hand split,
month, or sched_types. Therefore, for a given season, every query that uses
this CTE already computes the identical per-batter P95 values today. Computing
it once and joining the result is the same number every site already produces,
not an approximation. That is the basis for "changes nothing on output."

## Phase 1 scope (this document)

Barrelsville hitting affiliate-tracker pin only: `pin_tracker_seasons.py` and
the `tracker_data.py` query strings it drives. This is exactly where the
`cxconsumer` event lives.

### Mechanism (lowest blast radius)

1. Add a single precompute that runs the existing `batter_ev_p95` SELECT one
   time per process per season and returns a `{batter_id: p95_ev}` map.
2. In each tracker query string, keep the identical
   `LEFT JOIN batter_ev_p95 bp95 ... ISNULL(bp95.p95_ev, 105)` logic and the
   identical `NOT (hit_exit_speed >= 100 AND hit_vertical_angle < -35 AND ...)`
   filter, but swap the CTE body from the `PERCENTILE_CONT(...) OVER (...)`
   sort to a values-backed lookup of the precomputed map. Same join, same
   values, same fallback for under-20-BIP batters, no window sort.

Output is identical because (a) the P95 values are the same numbers the CTE
produces today, and (b) the `ISNULL(..., 105)` fallback and the `NOT(...)`
filter are unchanged.

### The output-neutrality proof (acceptance gate)

A diff harness runs the current pin and the refactored pin for the same season,
then compares every output DataFrame cell-for-cell. Byte-identical across all
of them is the pass condition. A single differing value blocks the ship. This
proves "changes nothing on output" rather than asserting it.

### Expected effect

One league-wide percentile sort per run instead of dozens, and each tracker
query becomes light enough that SQL Server is far less likely to choose a
parallel plan. That directly targets the `cxconsumer` saturation Navisite saw.

## Explicitly OUT of scope (touching these WOULD move outputs)

The audit found three look-alikes that are different corrections. They stay
untouched:

- Pitcher-side `hit_exit_speed >= 0` variant (Arm Farm `tracker_data.py`,
  PD Engine `org_kpi_data.py` pitching). Different application (pBarrel
  allowed). See Phase 3.
- `hit_vertical_angle < -25` junk-level filter (PD Engine `stats.py`,
  `rolling_stats.py`, `drift_hitting.py`). Different filter entirely.
- `hit_exit_speed >= 95` / `>= 98` thresholds (Hard%, HH%, gcOBA components).
  Unrelated metric thresholds.

## Phase 2 (documented progression, not in this pass)

Apply the same precompute-and-join to the other Barrelsville hitting surfaces
that embed `EV_MISREAD_CTE` (`hitter_kpi_data.py`, `weekly_hitter_data.py`,
`postgame_percentiles.py`, `postgame_data.py`, `sugar_land_la_ev_data.py`,
`poc_research_data.py`, `gcoba_canonical.py`) and the PD Engine
`org_kpi_data.py` hitting query (its own `batter_ev_p95` CTE, same scope).
Same invariant, same diff-harness gate.

## Phase 3 (separate, lower priority)

Arm Farm pitcher-side equivalent. Note: the new contact-quality metrics
(Smash, Squared-Up%), which carry the heaviest CTE, are hitting-only, so Arm
Farm never computes them. Arm Farm uses the misread CTE only for
pBarrel-allowed, across fewer query strings and without the hitting pin's
H/A-by-hand matrix, so its compute load is materially lower. Real but
lower-priority. The per-batter P95 object is structurally identical and could
eventually share one precompute, but that is a cross-worktree step taken on its
own.

## Status

- Audit: complete.
- Code: not started (freeze in effect).
- Next: implementation plan for Phase 1 plus the diff harness, for review
  before anything runs.
