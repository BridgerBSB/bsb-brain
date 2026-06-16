---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# Pitches_View Join Keys — CRITICAL

## cur_event_id vs ab_event_id
- **`cur_event_id`** = NULL for 75% of pitches — only set on FINAL pitch of each PA
- **`ab_event_id`** = stays constant for ALL pitches in a plate appearance — use THIS for Events_View joins
- When joining `Pitches_View -> Events_View`: always use `pv.ab_event_id = ev.event_id`, NOT `pv.cur_event_id`

### Dual-Join Pattern — BLOCKING RULE for Org-Level Queries
Pitch-level queries that need BOTH team assignment AND PA outcomes MUST use two Events_View joins:

```sql
-- aev: always populated, use for team/org assignment + event-level columns
JOIN Astros.Events_View aev
    ON aev.sched_id = pv.sched_id AND aev.event_id = pv.ab_event_id
-- cev: NULL on non-final pitches, use ONLY for PA outcome columns
LEFT JOIN Astros.Events_View cev
    ON cev.sched_id = pv.sched_id AND cev.event_id = pv.cur_event_id
```

**`aev` (ab_event_id) — for:** `top_of_inning`, `fielding_team_id`, `batting_team_id`, `hit_trajectory_id` (bunt filter), any event-level attribute
**`cev` (cur_event_id) — for:** `pa`, `so`, `bb`, `hbp`, `ibb`, `ab`, `sf`, `[1b]`, `[2b]`, `[3b]`, `hr` (PA outcome columns only)

**Why not just use ab_event_id for everything?** PA outcome columns (`pa`, `so`, etc.) on `aev` would broadcast the PA result to ALL pitches in the AB, causing overcounting. `cur_event_id IS NOT NULL` gates these to the final pitch only.

### Why GC2 Doesn't Have This Problem
GC2 queries start FROM `Events_View` (one row per PA), not `Pitches_View` (one row per pitch). Every row already has valid `top_of_inning`, `fielding_team_id`, etc. — no NULL join issue. Our pitch-level queries need `ab_event_id` to get the same event data GC2 gets natively.

### Bug Pattern (Fixed Apr 12, 2026)
Joining on `cur_event_id` then using `ev.top_of_inning` for org: NULL makes CASE fall to ELSE, assigning ~75% of pitches to the wrong team. Found in pd-goals org_kpi_data.py (pitching + hitting), Arm Farm pitcher_kpi_data.py + tracker_data.py (5 queries), Barrelsville hitter_kpi_data.py (1 query). pd-goals + Intangibles fixed; Arm Farm + Barrelsville pending.

## event_id Uniqueness — BLOCKING
- **`event_id` / `cur_event_id` / `ab_event_id` are NOT globally unique** — they repeat across games (e.g., event_id=1 exists in every game)
- NEVER use `COUNT(DISTINCT cur_event_id)` for PA counts across multiple games — it will UNDERCOUNT
- **NEVER use `GROUP BY batter_id, ab_event_id` without `sched_id`** — PAs from different games will collide and merge. gcOBA swing dist bug (Apr 16 2026): 36 PAs → 26 unique event_ids → swing distribution SUM check was 0.72 instead of 1.0.
- **ALWAYS use `GROUP BY batter_id, sched_id, ab_event_id`** for any per-PA aggregation across multiple games
- **Python:** use `df.groupby(["sched_id", "ab_event_id"])` and `df.set_index(["sched_id", "event_id"])` — NEVER groupby `ab_event_id` alone
- To uniquely identify a PA, always use `(sched_id, event_id)` pair

## When Indexing by event_id
Always include `sched_id` in the key: `(batter_id, season, sched_id, event_id)` — never just `(batter_id, season, event_id)`

## PA Aggregation
- Uses `cur_event_id` (matches GC2), not `ab_event_id`
- Events_View PA columns (`[1b]`, `[2b]`, `[3b]`, etc.) are bit/int — MUST CAST before SUM
