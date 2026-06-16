---
name: Mirror Affiliate-Tracker + Postgame SQL for New BR / Fielding / Catcher Work
description: When building any new BR / fielding / catcher SQL, copy the existing affiliate tracker / postgame canonical query patterns verbatim. They have years of T-SQL pitfall corrections baked in.
type: feedback
originSessionId: 28f6e904-6554-438b-a427-98d7522dcb9f
---
# Rule
For any new drift / KPI / report SQL that aggregates from `Pitches_Baserunner_Leads`, `Tracking_Defensive_Metrics`, `Defense_Combined_By_Pos`, `CatcherDefense_*`, or other domain-specific tables — mirror the affiliate tracker / postgame canonical query patterns VERBATIM. Don't reinvent.

# Why
May 10 2026 PD Flag Tracker drift_br.py shipped with `NOT EXISTS` inside `SUM/AVG/COUNT(CASE WHEN ...)` blocks for the next-base-occupied gate. Error 130 ("Cannot perform an aggregate function on an expression containing an aggregate or a subquery") fired on every BR query. The canonical pattern from `intangibles/src/br_tracker_data.py` uses `LEFT JOIN nbo_2b` + `LEFT JOIN nbo_3b` + `WHEN ... nbo_X.sched_id IS NULL`. The rule was documented in `pitfalls.md` AND `db-columns.md` and I still wrote it wrong because I didn't look at the canonical impl first.

Same shape of bug at the same time: missed the 5.0 ft floor on 1B PL (data-cleaning.md §2 — HawkEye latching on the first baseman). Both bugs would have been impossible if I'd opened `br_tracker_data.py` and copied lines 418-470 line-by-line.

# How to apply
- Before writing new SQL in any of: drift_br.py, drift_catcher.py, drift_fielding.py, future KPI snapshot scripts, future report generators — open the canonical reference file for that domain FIRST.
- BR domain canonical: `intangibles/src/br_tracker_data.py` (Org Rankings + per-runner leaderboard SQL)
- Catcher domain canonical: `intangibles/src/catching_tracker_data.py` (NetK / FramRAA / BlockRAA SUM + framing buckets + AugPop percentile)
- Fielding domain canonical: `intangibles/src/fielding_tracker_data.py` (OF + IF, shared module, 6-term Tier 1 gate)
- Hitting domain canonical: `barrelsville/src/tracker_data.py` (per-batter + per-org)
- Pitching domain canonical: `bullpen-report/src/tracker_data.py` (per-pitcher + per-org)
- Postgame canonical: `<app>/src/postgame_data.py` for per-game shape; never invent a per-game query from scratch
- Copy the JOIN chain + the WHERE filter list + the CASE WHEN gate structure. Adapt only the date/year scoping (weekly date window vs YoY year-bucketed CASE WHEN).
- See `rules/reference-impl-index.md` for the full canonical-pointer table per metric.

# What NOT to do
- Don't reach for `NOT EXISTS` inside SUM/AVG/COUNT/CASE WHEN aggregates — error 130. Use `LEFT JOIN <self_alias> + IS NULL` (per pitfalls.md).
- Don't skip the data-cleaning floors (5.0 ft on 1B PL; 57 mph on bat speed; etc.) — they're documented in `rules/data-cleaning.md`.
- Don't write new SQL based on the rules-file description alone. Open the canonical implementation in the relevant tracker/postgame/KPI file and copy verbatim.
