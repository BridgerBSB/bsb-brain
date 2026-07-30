---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# DB Column Name Reference

## Critical Column Corrections
- Events_View has NO `batter_id` — JOIN via Pitches_View on `sched_id + event_id = cur_event_id`
- Hits has NO `batter_id` — JOIN via Pitches_View on `sched_id + pitch_id`
- Pitches_View: `balls_before` (not `balls`), `strikes_before` (not `strikes`), `bat_side` (not `batter_side`), `ab_pitch_number` (not `pitch_number`), `release_speed` (NOT `velocity`, NOT `pitch_speed`, NOT `pv.velo` — FB Velo + any velocity calc always reads `pv.release_speed`)
- Schedule_View: `sched_date` (not `game_date`)
- Pitches_Grades: no `pitcher_id` — join via Pitches_View on `sched_id + pitch_id`
- Stuff grades exist DIRECTLY in Pitches_View (`stuffrelvel_grade_2080`, etc.)

## Events_View PA Semantics — BLOCKING
`ev.pa`, `ev.ibb`, `ev.sh` are the three columns that control how you count plate appearances. They are NOT interchangeable.

| ev column | Set on | NOT set on |
|---|---|---|
| `ev.pa = 1` | AB, BB, HBP, SF, **SH** (sacrifice hit — FanGraphs standard) | IBB (`ev.pa = 0`), non-PA events (SB, WP, pickoff) |
| `ev.ibb = 1` | Intentional walks only | Everything else |
| `ev.ab = 1` | At-bats (hits, outs, errors, strikeouts) | BB, IBB, HBP, SF, SH |
| `ev.bb = 1` | Walks — includes IBB (ev.bb=1 AND ev.ibb=1 for IBBs) | Everything else |
| `ev.hbp = 1` | HBP | Everything else |
| `ev.sf = 1` | Sacrifice flies (BIP outs scoring a runner) | SH (different column) |
| `ev.sh = 1` | Sacrifice hits (bunts) | SF |

### PA count vs wOBA denom — DIFFERENT FORMULAS
- **PA count** (for K%, BB%, IP-ish denoms): `SUM(ev.pa) + SUM(ev.ibb)` — total PA including IBB and SH
- **wOBA/xwOBA denom** (FanGraphs standard): `AB + BB - IBB + HBP + SF` — excludes SH
- **Non-IBB PA count** (`SUM(CASE WHEN pa=1 AND ibb=0 THEN 1 ELSE 0 END)`): includes SH. **This is NOT equivalent to wOBA denom.** Using it as wOBA denom inflates the denom by SH count and drops wOBA/wRC+ by ~1 point at org level. See `memory/hitting-org-parity-apr20.md` bug class 4.
- **xwOBA denom** = `AB + BB + HBP + SF` per GC2 reference. **IBB IS counted in xwoba denom AND contributes woba_bb to numer — GC2 treats IBB as walk in xwoba.** OPPOSITE of wOBA which subtracts IBB from both. May 19 2026 alignment fix. See `xwoba-canonical.md`.

### Why this trips people up
Most apps' K%/BB% use `SUM(ev.pa) + SUM(ev.ibb)` as denominator — "total PA." Developers reach for the same pattern for wOBA denom and it silently drifts by the SH count. Always use the explicit `AB + BB - IBB + HBP + SF` formula for wOBA to avoid the trap.

### Official PA TOTALS — use Gamelog_Batting, NOT pitch-derived (BLOCKING)
The event-anchored PA count (`Events_View ⋈ Pitches_View ON cur_event_id`)
**UNDERCOUNTS** any season/career PA total wherever pitch-by-pitch tracking
is incomplete — i.e. older / lower-minors (pre-~2021 A-ball, DSL, FCL). PAs in
games with no pitch rows are silently dropped (the terminal-pitch join finds
nothing). MLB is complete, so MLB totals are fine; **MiLB totals are not.**

When you need a PA **total that must match an official stat line** (a player's
A-ball PA, DSL PA, career-by-level PA, "how many PA at level X" asks), sum the
official gamelog instead:

```sql
SUM(CAST(glb.pa AS int)) AS pa
FROM MLBAM.Gamelog_Batting glb
JOIN Astros.Players p        ON p.mlbam_id = glb.player_id
JOIN Astros.Schedule_View sv ON sv.mlbam_game_pk = glb.game_pk
WHERE sv.gc2_level_code = 'afx'   -- level via Astros side (avoids MLBAM level/gm_type literals)
  AND sv.sched_type = 'R'
GROUP BY ...
```

Verified cases: Heliot Ramos 2018 Low-A = **535** official vs **444** pitch-derived;
Yordan 2016 DSL = 57 official vs 19 pitch-derived. Reference impl:
`pd-goals/src/promotion_velocity_data.py` (`SUM(Gamelog_Batting.pa)` per game).
Fallback when `mlbam_id` is NULL: join `ebis_id → MLBAM.Players`. Pitch-derived
PA is fine ONLY for MLB-scoped work or pitch-level rate metrics (Whiff%/Ctct%/
xwOBAcon), never for a MiLB PA total. Pitching sibling: `ip-calculation.md`
(`Gamelog_Pitching.outs` is gold standard for the same reason).

## Baserunning Tables — SB/SBA Gates (BLOCKING)

### Astros.Pitches_Baserunner_Leads (PBL)
Per-pitch runner lead data. One row per runner per pitch.

| Column | Type | Notes |
|--------|------|-------|
| `sched_id` | int | Game |
| `pitch_id` | int | Pitch within game |
| `groundcontrol_id` | int | Runner GC ID |
| `occupied_base` | tinyint | Base runner is on (1, 2, or 3) |
| `primary_distance_from_occupied_base` | decimal | Primary lead distance (ft) |
| `secondary_distance_from_occupied_base` | decimal | Secondary lead distance (ft) |
| `closest_fielder_distance_to_occupied_base` | decimal | Nearest fielder to base (ft) |
| `primary_x` | decimal | Primary lead x-coordinate |
| `primary_y` | decimal | Primary lead y-coordinate |
| `secondary_x` | decimal | Secondary lead x-coordinate |
| `secondary_y` | decimal | Secondary lead y-coordinate |
| `runner_going` | bit | 1 = runner intentionally going (steal attempt), 0 = not |
| `next_base_open` | bit | 1 = next base unoccupied, 0 = occupied (double steal) |
| `ignore_flag` | bit | Bad tracking data for lead measurements — ALWAYS filter `= 0` (different meaning than Pitches_View ignore_flag) |

**Join key:** `sched_id + pitch_id + groundcontrol_id`
**1B lead gate:** `closest_fielder_distance_to_occupied_base <= 10` (fielder holding)
**2B leads:** No fielder gate.

### Astros.Events_StolenBases (ESB)
Per-event stolen base records. NO `pitch_id`, NO `event_id`.

| Column | Type | Notes |
|--------|------|-------|
| `sched_id` | int | Game |
| `runner_id` | int | Runner GC ID |
| `base` | tinyint | Base stolen FROM (1 or 2) |
| `inning` | tinyint | Inning of attempt |
| `outs_before` | tinyint | Outs at time of attempt |
| `success` | bit | 1 = safe (SB), 0 = out (CS) |
| `sbr` | float | Stolen base runs (run value) |
| `sb_runs` | float | Run value if successful |
| `cs_runs` | float | Run value if caught |

**CRITICAL: `success` is NOT equivalent to an official SB.** ESB records whether each individual runner reached the next base, ignoring double-steal rules (e.g., trailing runner safe but lead runner thrown out = FC, not SB). Gamelog and GC2 both reject these.

### SB/SBA Count Rule — BLOCKING (REVISED Apr 14, 2026)

**Three SB data sources exist. Use the right one for the job:**

| Source | Granularity | Use For | Notes |
|--------|-------------|---------|-------|
| `Events_View.event_result_id` | Per-event (PA-level) | **Org totals, KPI reports, trackers** | Official scoring. Matches GC2/gamelog. Brodie-approved. |
| `gamelog_batting.sb` / `ytd_player_batting_stats.sb` | Per-player per-game/season | **Player career totals** (if needed) | MLBAM official. What GC2 player pages show. |
| `Astros.Events_StolenBases` (ESB) | Per-runner per-attempt | **Play-by-play detail, video lookup** | `success` BIT != official SB (FC in double steal = success=1 but not SB) |

**PRIMARY PATTERN — Events_View event_result_id (Brodie's approach):**
```sql
-- Org-level SB/CS totals (official scoring)
SELECT
    t.mlb_org AS org,
    SUM(CASE WHEN ev.event_result_id IN (42, 43, 44) THEN 1 ELSE 0 END) AS sb,
    SUM(CASE WHEN ev.event_result_id IN (4, 5, 6, 7, 29, 30, 31) THEN 1 ELSE 0 END) AS cs,
    -- Breakdown by base:
    SUM(CASE WHEN ev.event_result_id = 42 THEN 1 ELSE 0 END) AS sb2,
    SUM(CASE WHEN ev.event_result_id = 43 THEN 1 ELSE 0 END) AS sb3,
    SUM(CASE WHEN ev.event_result_id = 44 THEN 1 ELSE 0 END) AS sbh
FROM Astros.Events_View ev
JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
JOIN mlbam.teams t ON t.team_id = ev.batting_team_id AND t.season = sv.year
WHERE ev.sb | ev.cs = 1  -- BIT OR filter for SB/CS events
  AND sv.year = :season AND sv.sched_type = 'R'
GROUP BY t.mlb_org
```

**Event result ID reference (SB/CS):**
| ID | event_result | Type |
|----|-------------|------|
| 42 | stolen_base_2b | SB |
| 43 | stolen_base_3b | SB |
| 44 | stolen_base_home | SB |
| 4 | caught_stealing_2b | CS |
| 5 | caught_stealing_3b | CS |
| 6 | caught_stealing_home | CS |
| 7 | caught_stealing_double (multiple runners) | CS |
| 29 | caught_stealing_2b (variant) | CS |
| 30 | caught_stealing_3b (variant) | CS |
| 31 | caught_stealing_home (variant) | CS |

**Per-runner individual detail (play-by-play, video):** Use `ev.event_result LIKE 'stolen_base%'` + runner_1b/2b/3b matching (already correct in br_data.py play-by-play query).

**NEVER use ESB for SB/CS totals.** ESB `success` != official SB:
- Trailing runner in double steal: `success=1` in ESB but official scoring = FC (not SB)
- Will Bush example: ESB shows success=1 but GC2 shows 0 SB (runner ahead thrown out = FC)
- ESB ungated overcounts. ESB+PBL gate undercounts. Both are wrong for totals.

**PBL gates apply to LEADS ONLY (not SB counts):**
- SB/CS counts: NO PBL gates — use Events_View event_result_id

**Lead filter standard (Apr 14, 2026) — applies to ALL averages and percentiles:**

| Metric | runner_going | fielder ≤ 10 (1B) | next-base-occupied |
|--------|-------------|-------------------|-------------------|
| PL (primary_distance) | NO filter — all leads | YES | YES |
| SL (secondary - primary) | runner_going = 0 only | YES | YES |
| TL (secondary_distance) | runner_going = 0 only | YES | YES |
| n_leads count | NO filter — all leads | YES | YES |

**Why PL is unfiltered:** At pitch release, the runner hasn't left the bag — primary distance is their real lead regardless of intent.
**Why SL/TL filters runner_going=0:** By secondary measurement, a stealing runner is already sprinting — inflates SL by 5-10+ feet.
**Next-base-occupied:** Exclude pitches where someone is on the base ahead (runner behavior changes). Use LEFT JOIN + IS NULL inside CASE WHEN aggregates (NOT EXISTS is illegal inside SQL Server aggregates — error 130). Use NOT EXISTS in standalone WHERE clauses.
**Fielder ≤ 10 (1B):** Only count 1B leads where the first baseman is actually holding the runner.
**Individual pitch-by-pitch display rows:** NO filters — show all leads, all pitches. `runner_going` shows as a display column. BUT:

**Percentile coloring on pitch rows (br_report.py, br_daily_report.py, 1_Baserunning.py):**

| Column | runner_going=1 | base_ahead_occupied=1 | fielder > 10 (1B) | PL outside floor/ceiling |
|--------|---------------|----------------------|-------------------|--------------------------|
| PL | YES — color normally | NO — skip | NO — skip | NO — skip (HawkEye glitch) |
| SL | NO — skip (steal inflates) | NO — skip | NO — skip | NO — skip (PL bad → TL bad) |
| TL | NO — skip (steal inflates) | NO — skip | NO — skip | NO — skip (PL bad → TL bad) |

**PL outside floor/ceiling** = 1B PL ≤ 5.0 OR 1B PL > 20.0 OR 2B PL > 25.0 (per `data-cleaning.md` §2, May 12 2026). Raw values always display. Only the background color is skipped. Same pattern in all 3 rendering files (PDF postgame, PDF daily, Streamlit app).

**File-by-file average/percentile filter status:**

| File | Worktree | PL | SL | TL |
|------|----------|----|----|-----|
| br_tracker_data.py (4 queries) | Intangibles | No filter | runner_going=0 | runner_going=0 |
| br_kpi_data.py (1 CTE) | Intangibles | No filter | runner_going=0 | N/A (no TL) |
| br_percentiles.py (6 queries) | Intangibles | No filter | runner_going=0 | runner_going=0 |
| br_data.py (10 queries) | Intangibles | No filter | runner_going=0 | runner_going=0 |
| baserunning_base.py (aggregate) | Intangibles | No filter | runner_going=0 | runner_going=0 |
| org_kpi_data.py (1 query) | PD-Goals | No filter | runner_going=0 | N/A (no TL) |
| snapshot_data.py (1 CTE) | Intangibles | No filter | N/A (PL only) | N/A |

**All queries also have:** fielder ≤ 10 on 1B, next-base-occupied (LEFT JOIN nbo_2b/nbo_3b IS NULL). Barrelsville and Arm Farm have no lead queries.

**History:** Feb 17 added runner_going=0 to all leads (matching GC2). Apr 14 removed from PL (runner hasn't left), kept on SL/TL (steal inflates secondary). May be re-added to PL as optional contingency later.

### SB Video — Use Steal Pitch, NOT PA-Ending Pitch
Video_Network joins on `sched_id + pitch_id`. For stolen bases, the steal happens MID-AB
on a specific pitch where `runner_going = 1`. Using `cur_event_id` (last pitch of PA) gives
the WRONG video.

**Correct pattern:** Find the steal pitch via PBL `runner_going = 1` within the PA:
```sql
CROSS APPLY (
    SELECT TOP 1 pv2.sched_id, pv2.pitch_id, ...
    FROM Astros.Pitches_Baserunner_Leads pbl_steal
    JOIN Astros.Pitches_View pv2
        ON pbl_steal.sched_id = pv2.sched_id
        AND pbl_steal.pitch_id = pv2.pitch_id
    WHERE pbl_steal.sched_id = ev.sched_id
      AND pbl_steal.groundcontrol_id = :gc_id
      AND pbl_steal.runner_going = 1
      AND pv2.ab_event_id = ev.event_id
    ORDER BY pv2.game_pitch_number DESC
) steal_pitch
```
Then join Video_Network on `steal_pitch.sched_id + steal_pitch.pitch_id`.

**Advancement (1→3, 2→H):** Uses `cur_event_id` correctly — advancement happens ON the BIP
which IS the last pitch of the PA. No fix needed.

### PBL Join Keys — Summary
| Context | Join From | To PBL On | Notes |
|---------|-----------|-----------|-------|
| Lead lengths (per-pitch) | Pitches_View | `sched_id + pitch_id + groundcontrol_id` | Primary use |
| SB/SBA gate (EXISTS) | ESB | `sched_id + runner_id→groundcontrol_id + base→occupied_base` | Gate only, no row join |
| Steal pitch lookup | Events_View PA | `sched_id + groundcontrol_id + runner_going=1` within PA via `ab_event_id` | For video |

## Astros Table Columns
- **Astros.Hits:** `hit_bearing` (NOT hit_spray_angle), `hit_exit_speed`, `hit_vertical_angle`, **`hit_initial_contact_point_x` / `hit_initial_contact_point_y`** (Point-of-Contact source — see PoC note below). NO `hit_trajectory_id` (that's in Events_View/Events)
- **Point of Contact (PoC) — BLOCKING source rule.** The tracker PoC family comes from **`Astros.Hits.hit_initial_contact_point_x/_y`**, NOT from `swing_contact_values.bally_con` (SCV bally_con is raw plate-apex distance, ALWAYS positive — the wrong metric). **PoC** = `hit_initial_contact_point_y * 12.0 - 17.0` (inches from plate FRONT edge; **positive = out front, negative = behind/over the plate**), BIP-only, `BETWEEN -24 AND 48`. PoCRelY/PoCRelX subtract body-center from `player_tracking_bypos` (HawkEye-only). Canonical impl: `barrelsville/src/tracker_data.py` `_POC_QUERY` + `_POC_REL_QUERY`. See `reference-impl-index.md`.
- **Astros.Events_View / Events:** HAS `hit_trajectory_id` (bunt filter: NOT IN 2,3,4)
- **Astros.Pitches_View:** Zone confidence column is `called_strike_chance_mlb` (NOT `csc` — that's only a Python alias)
- **Astros.Video_Network:** Join on `sched_id` + `pitch_id`. Column is `angle` (NOT `camera_angle`). Values: `'M'`=Main CF, `'a'`=alt CF, `'v'`=alt2 CF, `'H'`=high home, `'F'`=1B high, `'7'`=3B high, `'5'`=side mid 1B, `'6'`=side mid 3B, `'s'`=RHH high speed, `'t'`=LHH high speed. URL column is `video_url`.
- **Astros.LK_Event_Results:** `event_result_id`, `event_result`. Error IDs: 11=`error`, 13=`field_error`, 32-34=`pickoff_error_1b/2b/3b`.
- **Astros.Players:** `birthdate` (NOT `birth_date`), `first_name`, `last_name`, `groundcontrol_id`, `ebis_id`, `mlbam_id`, `bats`, `throws`. NO `first_last` column — use PP_MASTER or roster query.
- **Astros.LK_Pitch_Results:** Columns: `pitch_result_id`, `pitch_result`, `did_swing`, `gumbo_code`, `gumbo_description`. Use `gumbo_description` for human-readable labels (NOT `description` — that column does NOT exist). **NO `ab_swing` column.**
- **Astros.Defense_Combined_By_Pos:** `out_made` and `competitive_play` are **BIT columns** — `SUM(bit)` is ILLEGAL in SQL Server. MUST use `SUM(CAST(out_made AS float))`. Same for `competitive_throw`.
- **Astros.Tracking_Defensive_Metrics:** `competitive_play` and `competitive_throw` are also **BIT columns**. Column names: `acceleration_chest_up`, `acceleration_chest_down` (NOT `accel_toward`/`accel_away`).

## groundcontroltracking.tracking.swing_contact_values (SCV)
Per-contact-event vectors. Whiffs have NO row (no contact moment occurred).

**Join path:** `Pitches_View pv → tracking.plays tp ON sched_id+astros_pitch_id → swing_contact_values scv ON sched_id+tracking_play_id`

| Column | Used For |
|---|---|
| `batvx_con`, `batvy_con`, `batvz_con` | Bat velocity vector at contact (FPS). Speed = `SQRT(vx²+vy²+vz²) * 0.681818` MPH. Required filter: `batvx_con IS NOT NULL`. |
| `e1z_con` | Vertical bat angle (z-axis bat orientation at contact). VBA = `90 - DEGREES(ACOS(e1z_con))`, range filter `BETWEEN -70 AND 10`. |
| `e1x_con`, `e1y_con` | Horizontal bat angle components. HBA = `degrees(atn2(e1y_con, ±e1x_con))` per bat side. |
| `batx/y/z_con`, `ballx/y/z_con` | Spatial coords at contact. Used for contact location axis/perpendicular calcs. |

**Pool inclusion (Astros standard):** any row where `batvx_con IS NOT NULL` counts. NO `pitch_result_id` whitelist (we include BIP + fouls + foul tips).
**GC2 leaderboard differs:** filters to `pitch_result_id IN (12,13,14,18,19,20)` (BIP only). Documented divergence in `gc2-metrics.md`.

## MLBAM Table Columns
- **MLBAM.Hits:** `hit_initial_speed` (NOT hit_exit_speed), `hit_horizontal_angle` (spray)
- **MLBAM.Pitch_fx:** whiff filter uses `event_type IN ('swinging_strike',...)` — pitch_result_id does NOT exist in MLBAM tables

## PP_MASTER
- **MUST use full schema:** `MLB_eBis.PP_MASTER` (NOT bare `PP_MASTER`)
- Position column is `POSITION_LK` (NOT `POSITION`)
- Join key is `pm.player_id` = `r.ebis_id` (NOT groundcontrol_id)
- Other cols: `ORG_LK`, `LEVELOFPLAY_LK`, `MNROSTERSTATUS_LK`, `MJROSTERSTATUS_LK`, `EMPLOYEE_FLG`
- **`LEVELOFPLAY_LK` returns UPPERCASE** (`'1F'`, `'R'`, `'DS'`) — always `.strip().lower()` before comparing to code constants
- LEVELOFPLAY_LK codes: `ml`=MLB, `3a`=AAA, `2a`=AA, `1a`=A+, `1f`=A, `r`=FCL/Rookie, `ds`=DSL
- Roster status codes: `ACT`=Active, `7DL`=7-day IL, `VOL`=Voluntary, `RES`=Restricted, `DIS`=Disqualified, `PAC`=Pending Active, `FA`=Free Agent, `REL`=Released
- **Junk ORG_LK:** `'boc'` (Baseball Operations Center) — always exclude. Also filter `ORG_LK IS NOT NULL`. 30 real orgs after filtering.
- **`ORG_LK` uses shorthand for 3 orgs (BLOCKING when joining MLBAM):** `'chi'` = Cubs (MLBAM='CHC'), `'la'` = Dodgers (MLBAM='LAD'), `'ny'` = Mets (MLBAM='NYM'). PLUS `'oak'` vs `'ath'` (Athletics rebrand — either may appear). When JOINing PP_MASTER ↔ MLBAM.Teams on org code, apply the canonical CASE remap or those 4 orgs silently drop. See `rules/org-codes.md` for full reference + SQL templates.

## R4_Draft_Query
- **Full schema:** `MLB_eBis.R4_Draft_Query`
- **Known columns:** `groundcontrol_id`, `mlbam_id`, `first_name`, `last_name`, `draft_year`, `draft_round`, `overall_pick`, `position`, `school_type`, `draft_org`
- **NO `school` column** — do not query school name (confirmed Apr 2026)
- `school_type`: `'HS'` = high school, `'4Y'`/`'JC'` = college (unconfirmed exact codes)
- **`draft_org` is LOWERCASE** — `'hou'`, `'bos'`, `'nyy'`, etc. Known quirk: `'ny'` = NYM (Mets), NOT Yankees. Yankees = `'nyy'`. Same `chi` / `la` / `ny` / `oak`/`ath` shorthand as PP_MASTER above — see `rules/org-codes.md` for the canonical PP_MASTER ↔ MLBAM mapping table. Reference impls: `pd-goals/scripts/ss_draft_analysis.py`, `sql-queries/Historical RAR - Amat Population.sql`.
- Join to PP_MASTER: `R4_Draft_Query.groundcontrol_id` → `Astros.Players.groundcontrol_id` → `Players.ebis_id` = `PP_MASTER.player_id`

## Astros vs MLBAM — KEY DISTINCTION
- **Astros.\*** = ALL teams, ALL levels — "Astros" = processed into Astros DB format, NOT Astros-only
- **MLBAM.\*** = ALL 30 MLB teams (league-wide Statcast data, different schema/columns)
- **Schedule_View.level_code uses MLBAM SPORT codes** (`aax`, `afa`, etc.) — NOT PP_MASTER codes

## ID Mapping
- `groundcontrol_id` = `batter_id`/`pitcher_id` in Astros.Pitches_View
- `mlbam_id` in `Astros.Players` → `player_id` in MLBAM tables
- `ebis_id` = `PP_MASTER.PLAYER_ID`

## Error Type Detection
- `event_result_id IN (11, 13)` flags an error play, but BOTH IDs cover throwing AND fielding errors
- Must parse `play_by_play` description: `"throwing error"` (~26%), `"fielding error"` (~71%), `"missed catch error"` (rare)
- Parse BEFORE description abbreviation (needs full text)

## Astros Join Pattern (Simple)
```sql
SELECT pv.*, pv.ignore_flag   -- ALWAYS select ignore_flag for swing recovery
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
WHERE sv.level_code = '{level}' AND YEAR(sv.sched_date) = {season}
  AND pv.pitch_id > 0
  -- NEVER filter on ignore_flag. See pitfalls.md for swing recovery pattern.
```

## HOU Hitter One-Off Query Template (Apr 8, 2026)
Use this for any ad-hoc hitting query. One row per batter, multi-level players get `AA/AAA` in level column.

**CRITICAL: PA and pitch-level metrics use DIFFERENT query paths.**
- **PA:** FROM `Events_View` → `Pitches_View` on `cur_event_id`, `SUM(CAST(ev.pa AS int))`. This is how ALL our apps count PA.
- **Pitch-level metrics** (damage_window, tracking data): FROM `Pitches_View` → `Events_View` on `ab_event_id`. One row per pitch.
- **NEVER** put `SUM(ev.pa)` in a pitch-level query — PA gets multiplied by pitches per AB.

```sql
SELECT
    dmg.name,
    lvl.level,
    pa.pa,
    dmg.your_metric
FROM (
    -- >>> PITCH-LEVEL METRIC (one row per pitch) <<<
    SELECT
        CONCAT(r.first_name, ' ', r.last_name) AS name,
        pv.batter_id,
        -- >>> SWAP YOUR METRIC HERE <<<
        AVG(...) AS your_metric
    FROM Astros.Pitches_View pv
    LEFT JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    LEFT JOIN Astros.Events_View ev ON pv.sched_id = ev.sched_id
        AND pv.ab_event_id = ev.event_id
    LEFT JOIN MLBAM.Teams bt ON ev.batting_team_id = bt.team_id
        AND sv.year = bt.season
    LEFT JOIN Astros.Players r ON r.groundcontrol_id = pv.batter_id
    -- >>> ADD OPTIONAL TRACKING JOINS HERE <<<
    WHERE sv.year = 2026
      AND sv.sched_type = 'R'
      AND sv.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
      AND bt.org_abbrev = 'HOU'
      AND pv.pitch_id > 0
    GROUP BY r.first_name, r.last_name, pv.batter_id
) dmg
JOIN (
    -- >>> PA COUNT (one row per event — how ALL our apps do it) <<<
    SELECT
        pv.batter_id,
        SUM(CAST(ev.pa AS int)) AS pa
    FROM Astros.Events_View ev
    JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
    JOIN Astros.Pitches_View pv ON ev.sched_id = pv.sched_id
        AND ev.event_id = pv.cur_event_id
    JOIN MLBAM.Teams bt ON ev.batting_team_id = bt.team_id
        AND sv.year = bt.season AND bt.org_abbrev = 'HOU'
    WHERE YEAR(sv.sched_date) = 2026
      AND sv.sched_type = 'R'
      AND sv.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
      AND pv.pitch_id > 0
    GROUP BY pv.batter_id
) pa ON pa.batter_id = dmg.batter_id
CROSS APPLY (
    SELECT STRING_AGG(lv, '/') AS level
    FROM (
        SELECT DISTINCT
            CASE sv2.gc2_level_code
                WHEN 'aaa' THEN 'AAA' WHEN 'aax' THEN 'AA'
                WHEN 'afa' THEN 'A+'  WHEN 'afx' THEN 'A'
                WHEN 'rok' THEN 'FCL' WHEN 'dsl' THEN 'DSL'
                ELSE UPPER(sv2.gc2_level_code)
            END AS lv
        FROM Astros.Pitches_View pv2
        JOIN Astros.Schedule_View sv2 ON pv2.sched_id = sv2.sched_id
        WHERE pv2.batter_id = dmg.batter_id
          AND sv2.year = 2026
          AND sv2.sched_type = 'R'
          AND sv2.level_code NOT IN ('bbc','win','int','sum','nae','hsb','ind','jcb')
          AND pv2.pitch_id > 0
    ) lvls
) lvl
ORDER BY dmg.your_metric DESC;
```

**Key points:**
- **PA subquery separate from metric query** — PA at event granularity, metrics at pitch granularity
- HOU filter via `MLBAM.Teams bt` on `batting_team_id` (game-level, not roster-level)
- Level label via `CROSS APPLY` subquery (SQL Server `STRING_AGG` doesn't support `DISTINCT`)
- Junk levels excluded, `sched_type = 'R'` only
- One decimal output: `CAST(FLOOR(... * 10.0) / 10.0 AS decimal(4,1))`
- Use `sv.year` over `YEAR(sv.sched_date)` in pitch-level queries for index performance

## Arm Angle Formula (Adam Brodie) — VERIFIED Apr 2026
NOT a stored column — computed from release point geometry.

**Scale:** 0° = sidearm, 90° = overhand. LHP values are negative (mirror).
**Data availability:** HawkEye venues — installed at ALL Astros affiliates, so all levels have data.

### Tables & Join Keys — CRITICAL
| Alias | Table | Join Key | Notes |
|-------|-------|----------|-------|
| pht | `groundcontroltracking.tracking.pitch_hit_trajectories` | `pht.sched_id + pht.tracking_play_id` = `pv.sched_id + pv.pitch_id` | **NO `pitch_id` column — use `tracking_play_id`** |
| pos | `groundcontroltracking.tracking.play_starting_positions` | `pos.sched_id + pos.pitch_id` = `pv.sched_id + pv.pitch_id` AND `pos.groundcontrol_id = pv.pitcher_id` | HAS `pitch_id` |
| p | `Astros.Players` | `p.groundcontrol_id = pv.pitcher_id` | Column is `p.throws` (**NOT `pitcher_throws`**) |
| mp | `mlbam.players` | `p.mlbam_id = mp.player_id` | `height_feet`, `height_inches` |

### Verified SQL
```sql
AVG(
    -16.4 +
    1.1 * (90.0 -
        CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
        ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
             pht.pitch_release_pos_z -
             SQRT(CASE WHEN
                POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
             THEN 0 ELSE
                POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
             END)))
    + -0.001 * POWER(90.0 -
        CASE WHEN p.throws = 'L' THEN 180.0/PI() ELSE -180.0/PI() END *
        ATN2(pht.pitch_release_pos_x - pos.x_at_pitch_release,
             pht.pitch_release_pos_z -
             SQRT(CASE WHEN
                POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2) < 0
             THEN 0 ELSE
                POWER((CAST(mp.height_feet AS float) + CAST(mp.height_inches AS float)/12.0) * 0.75, 2) -
                POWER((60.5 - pos.y_at_pitch_release) * 0.85, 2)
             END)), 2)
) AS arm_angle
```
