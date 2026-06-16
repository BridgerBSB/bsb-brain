---
name: PD-Goals Pool Gate — Pitchfx Hitter Future Change
description: Track potential switch from 200-pitch gate to 50-PA gate on CSC-weighted hitter Pitchfx pools (ZSw, OSw, Whiff, etc.) for SplitsBat parity
type: project
originSessionId: 006c9c74-3da8-4852-9d83-f2293c8fe16d
---
PD-Goals CSC-weighted hitter Pitchfx pools (ZSw%, OSw%, ZCon%, OCtct%, ZWhiff%, Whiff%, Chase%) currently gate pool entry by `200 pitches` per batter (`min_pitches=200` in `_get_pitchfx_distribution`). Pitcher K%/BB% pools use the same 200-pitch gate.

**Why:** Original Pitchfx template default. ~53 PA equivalent at league-avg 3.8 pitches/PA.

**Why it might be wrong:** SplitsBat hitter pools (K%, BB%, SLG) gate by `50 PA`. CSC-weighted gates by pitches. An aggressive early-count swinger (3.2 pitches/PA) could clear 50 PA but not 200 pitches → silently excluded from CSC-weighted pools but present in SplitsBat pools. Inconsistent inclusion.

**Why deferred (Apr 20 2026):** No reported issue yet. Practical drift is small (~3 PA difference for a typical hitter). User chose to leave 200-pitch gate in place for now.

**How to switch when needed:**
Replace `HAVING COUNT(*) >= {min_pitches}` with `HAVING COUNT(DISTINCT CONCAT(CAST(pv.sched_id AS varchar), '_', CAST(pv.ab_event_id AS varchar))) >= 50` across all CSC-weighted hitter templates in `pd-goals/src/percentiles.py::PITCHFX_QUERY_TEMPLATES`. Composite key needed because `ab_event_id` is NOT globally unique (per `db-joins.md` event_id rule).

For pitcher K%/BB% pools (`k_pct_pitcher`, `bb_pct_pitcher`): same pattern, but switch to **50 BF** (batters faced) — same SQL since each BF = one ab_event_id from pitcher's perspective.

**Why:** When/if a coach reports a hitter who clearly should rank but shows no percentile, this is the first thing to check.

**How to apply:** Trigger the change when (a) a user reports the inconsistency or (b) the pool is being audited for any other reason.
