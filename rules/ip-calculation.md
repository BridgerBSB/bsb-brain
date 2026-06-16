---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# IP Calculation — NEVER Use (AB - H + SF)

## The Bug (Fixed Apr 4, 2026)
`outs = AB - H + SF` overcounts outs because errors and fielder's choices reaching base are counted as outs. GC2 production NEVER uses this formula.

## Correct Methods (ranked by accuracy)

### 1. MLBAM.Gamelog_Pitching.outs — GOLD STANDARD
Use for **single-game** context (postgame reports, boxscores). Includes ALL outs: PA outs, caught stealing, pickoffs, runner thrown out.

```sql
SELECT p.groundcontrol_id, glp.outs
FROM MLBAM.Gamelog_Pitching glp
JOIN Astros.Schedule_View sv ON sv.mlbam_game_pk = glp.game_pk
JOIN Astros.Players p ON p.mlbam_id = glp.player_id
WHERE sv.sched_id = :sched_id
```
Join key: `mlbam_game_pk` + `player_id` (mlbam_id, NOT groundcontrol_id).

**Caveat:** MLBAM data may be NULL for just-finished games. Always fallback to method 2.

### 2. Events_View outs_after - outs_before — GOOD
Use for **season aggregates** (trackers, KPI snapshots) or as fallback for method 1.

```sql
SUM(CAST(ev.outs_after AS int) - CAST(ev.outs_before AS int)) AS outs
```

Correctly handles: errors (0 outs), DPs (2 outs), TPs (3 outs), FC reaching base (0 outs).
Misses: non-PA outs (CS, pickoffs) — typically 0-2 outs per game, negligible over a season.

### 3. MLBAM.YTD_Player_Pitching_Stats.outs — GOLD STANDARD (season)
Use for **season-level** stats when available. Same accuracy as Gamelog but pre-aggregated.

```sql
sum(YtdPlayerPitching.outs)/3+0.1*(sum(YtdPlayerPitching.outs)%3) as PitcherIP
```

## IP Display Format — Baseball Notation ONLY
```python
ip_str = f"{outs // 3}.{outs % 3}"  # 12 outs = "4.0", 13 = "4.1", 14 = "4.2"
```
NEVER use decimal (4.333). The `.1` and `.2` mean 1/3 and 2/3 of an inning.

## Why Events_View via cur_event_id Undercounts
The tracker PA query joins `Events_View ev ON ev.event_id = pv.cur_event_id`. Since `cur_event_id` is only set on the final pitch of each PA, non-PA events (CS, pickoffs) have no matching row in Pitches_View — their outs get dropped. This caused the affiliate tracker to undercount IP (e.g., 3.2 vs true 4.0 for Gabel Pentecost). Fixed Apr 5 by adding Gamelog override.

## Where Each Method Is Used (after Apr 6 fix)

| File | Method | Context |
|------|--------|---------|
| boxscore_report.py | Gamelog_Pitching + fallback | Single game |
| postgame_data.py | Gamelog_Pitching + fallback | Single game |
| tracker_data.py (per-pitcher) | Gamelog_Pitching + fallback | Season aggregate |
| tracker_data.py (monthly) | Gamelog_Pitching (monthly) + fallback | Monthly breakdown |
| tracker_data.py (org season) | Gamelog_Pitching + fallback | Org aggregate |
| tracker_data.py (org monthly) | Gamelog_Pitching + fallback | Org monthly |
| pitcher_kpi_snapshot.py (×2) | outs_after - outs_before | Season aggregate |
| kpi_snapshot_3.py (×2) | outs_after - outs_before | Season aggregate |
| catcher_data.py | outs_after - outs_before | Season aggregate |

## H/A IP Attribution — PROPORTIONAL SPLIT (May 14 2026, BLOCKING)

Gamelog is per-game and has **no half-inning info** — it cannot be H/A-
filtered natively. So how do we show different IP at Home vs Away in
the tracker?

**The chosen approach: proportional split.** Take gamelog total (gold
standard at All), then split into H/A by the Events_View pa_outs ratio:

```
home_outs = round(gamelog_total * pa_home / pa_total)
away_outs = round(gamelog_total * pa_away / pa_total)
```

**Guarantees:**
- All view: `outs = gamelog` (unchanged)
- Home + Away ≈ All within rounding (0–1 out drift max)
- 100% match rate vs gamelog at every pitcher, every level

**Trade-off:** H/A outs are workload-weighted **estimates**, not exact
baseball-scoring attribution per `top_of_inning`. For a pitcher with 50%
home / 50% away workload, his Home and Away outs are close to "real."
For unbalanced workloads, the same proportional logic applies.

**Why not exact attribution via Events_View `outs_after - outs_before`?**
Events_View and gamelog disagree on the margins (inherited runners,
scoring quirks, event categorization). Bulk AFX audit on 700+ pitchers
showed 25% diverged from gamelog by 1–4 outs even after a CS-event-id
whitelist. The structural data-source mismatch is unfixable without
solving MLB-vs-Astros scoring agreement, which is out of scope.

**Failed approaches (in `feature/bullpen-reports` git history, kept as
reference, do NOT reintroduce):**
- `a5fd7ca` non_pa_outs OUTER APPLY chronological pitcher attribution
- `be13da4` CS-event-id whitelist filter (event_result_id IN 4-7, 29-31)
- `c8c809d` / `e23ee9c` / `18341e4` audit instrumentation for those
- All reverted in `82d72fd` in favor of the proportional split.

**Implementation:** `bullpen-report/src/tracker_data.py`:
- Per-pitcher sites run `_PA_LEVEL_QUERY` a 2nd time with `ha_filter=""`
  to get `pa_total`; compute outs in Python
- Org sites stage `gamelog_outs` + `pa_total_outs` columns onto `pa_df`
  then let `_merge_org_pa_metrics` apply the formula

## AOL — AVERAGE OUTING LENGTH (May 15 2026)

Sibling metric to IP/S. Same gamelog source, different scope + rollup.

| | IP/S | AOL |
|---|---|---|
| Pitchers counted | Starters only (first pitch of inning 1 detection) | All pitchers (any game appearance) |
| Outing definition | One start = one row in `MLBAM.Gamelog_Pitching` | One game appearance = one row in `MLBAM.Gamelog_Pitching` |
| Per-pitcher single-level | outs_in_starts / n_starts / 3 | outs_in_appearances / n_appearances / 3 |
| Per-pitcher multi-level | Count-derived (pool — SUM/SUM) | Count-derived (pool — SUM/SUM) ("same old same old") |
| Per-org single-level | Pool (SUM(starter_outs) / SUM(starts)) | **Per-pitcher simple mean** (each pitcher = 1 vote) |
| Per-org multi-level | Pool | n_pitchers-weighted mean of per-level org AOLs (approximates per-pitcher mean across levels) |
| Pool gate | None (any starter qualifies) | None (any pitcher qualifies) |

**Why divergent org rollup?** Per user direction (May 15 2026):
"each player has their own AOL ... 2 pitchers so 5.1/2." Org AOL is
the simple mean of its pitchers' AOLs. IP/S kept its pool semantics.

**Implementation:**
- SQL: `_APPEARANCES_PITCHER_QUERY` + `_APPEARANCES_ORG_QUERY` in
  `bullpen-report/src/tracker_data.py`. Org query nested CTE produces
  `avg_aol_outs` (per-pitcher simple mean in outs units) directly.
- Per-pitcher AOL == IP/S for any pitcher who only started in the
  scoped window (gamelog source is identical).
- Carried columns through pin: `n_appearances`, `outs_in_appearances`
  for per-pitcher path; `avg_aol_outs`, `total_appearances`,
  `total_outs_in_appearances`, `n_pitchers` for per-org path.

**H/A semantics:** Mirrors IP/S — `{ha_filter}` passes through the
`appearances` CTE so only pitchers who threw at least one pitch on
the selected side qualify, then their full gamelog outs count. Works
cleanly for starters (one side of the ball per start) and relievers
(almost never switch sides mid-game). No proportional split needed.

## Affiliate Tracker Consistency Rule
**Org rankings MUST use the same IP method as the per-pitcher leaderboard.**
Any formula or data source in the individual tab must be replicated in org rankings.
Both use `combine_first(gamelog_outs, events_view_outs)` — NEVER `AB - H + SF`.
