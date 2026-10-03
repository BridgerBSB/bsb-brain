# Database Tour

Every report we ship comes from one server: `gcsql02.GroundControl2`.
This chapter is the map. By the end you'll know the five tables you
touch every day, the schemas they live in, the IDs that link
everything, the join patterns we use, and the level/sched-type codes
you'll filter against.

::: tip
**What you'll learn:** the schema landscape, the canonical 5-table
hitting/pitching join, the dual-join trap (`cur_event_id` vs
`ab_event_id`), how player IDs map across systems, level codes,
sched_type codes, and the BIT-column SUM trap that's bitten everyone.
:::

## Connection

```
Server:        gcsql02.astros.com
Database:      GroundControl2
Auth (work):   ODBC Driver 17 / Windows Auth (BASEBALL\<username>)
Auth (Connect): FreeTDS / DB_USER + DB_PASS env vars
```

Each app has a `database.py` module that auto-detects environment
(Linux container vs Windows machine) and picks the right driver. You
don't write connection code from scratch --- import the existing
helpers.

```python
# Standard pattern in every src/database.py:
from sqlalchemy import create_engine, text
import pandas as pd

engine = get_engine()  # picks FreeTDS or ODBC 17 based on env
df = pd.read_sql(text(query), engine, params={"season": 2026})
```

## The schema landscape

| Schema | Scope | What's in it |
|---|---|---|
| **`Astros.*`** | All teams, all levels (processed into Astros DB format) | Pitch-level tracking, batted balls, defensive plays, baserunning leads, video |
| **`MLBAM.*`** | All 30 MLB teams | League-wide Statcast data --- gamelogs, schedule, splits, YTD stats |
| **`Guts.*`** | League-wide | Linear weights for wOBA / FIP, hit-spec exponents, count run expectancy |
| **`MLB_eBis.*`** | All 30 teams | eBis roster system --- `PP_MASTER` is the daily roster source of truth |
| **`groundcontroltracking.tracking.*`** | Astros org only | HawkEye tracking --- 64 tables of bat tracking, fielder positions, ball flight |
| **`Trackman.*`** | Astros org only | Portable TrackMan unit data (bullpens, BP) |
| **`proj.*`** | Astros forecasts | Batter/pitcher projections, MLE-adjusted stats |
| **`scout.*`** | Scouting | Scouting reports + bios |
| **`sportsmed.*`** | Performance science | Force plate, speed gates, ForceDeck |

::: blocking
**Always use full schema prefixes for cross-schema tables.**
`MLB_eBis.PP_MASTER`, `Guts.woba_lwts`, `MLBAM.Pitch_fx`. The default
schema is `dbo` --- anything outside the default schema crashes
without the prefix.
:::

::: note
**`Astros.*` is NOT Astros-org-only.** It's the entire league
processed into Astros' canonical schema. `Astros.Pitches_View` has
every pitch from every game at every level (MLB + 4 MiLB + Rookie +
DSL) for all 30 orgs. The "Astros" name is misleading. Treat it as
the canonical pitch + event + hit data layer for the whole league.
:::

## The five tables you touch every day

### 1. `Astros.Pitches_View`

**Granularity:** one row per pitch. Central table that combines
multiple underlying tables into a single denormalized view.

Key columns you'll use constantly:

| Column | What |
|---|---|
| `batter_id`, `pitcher_id` | `groundcontrol_id` of batter/pitcher |
| `sched_id` | Game identifier (joins to `Schedule_View`) |
| `pitch_id` | Unique pitch within the game (always filter `pitch_id > 0`) |
| `cur_event_id` | NULL on 75% of pitches --- only populated on the LAST pitch of each PA |
| `ab_event_id` | Stays constant for ALL pitches in a PA --- this is the PA identifier |
| `next_event_id` | Approximately equals `ab_event_id` |
| `pitch_type` | `'FF'`, `'SL'`, `'CU'`, `'CH'`, `'FT'`, `'FC'`, etc. |
| `release_speed` | Pitch velocity (NEVER `velocity`, NEVER `pitch_speed` --- the column is `release_speed`) |
| `inducedvertbreak`, `horzbreak` | Pitch movement |
| `plate_x`, `plate_z` | Pitch location at the plate |
| `pitcher_throws`, `bat_side` | Handedness (NOT `batter_side` --- it's `bat_side`) |
| `did_swing` | 0 or 1 (integer, NOT 'Y'/'N' like MLBAM) |
| `pitch_result_id` | Maps to `Astros.LK_Pitch_Results` --- 31 codes, see Ch 6 |
| `called_strike_chance` | Level-adjusted called-strike probability (preferred for new code) |
| `called_strike_chance_mlb` | MLB-model called-strike probability (used for FramRAA, NOT NetK) |
| `swing_zone` | Categorical: `'meatball'`, `'heart'`, `'shadow'`, `'chase'`, `'waste'` |
| `swing_decision_grade_2080`, `swing_decision_abs_grade_2080` | Swing decision on 20-80 scale |
| `stuffrelvel_grade_2080` | Stuff+ on 20-80 scale (also in `Astros.Pitches_Grades`) |
| `balls_before`, `strikes_before` | Count BEFORE this pitch (NOT `balls`, `strikes`) |
| `ab_pitch_number` | Pitch number within the PA (1 = first pitch, used for FPS%) |
| `net_k` | Pre-computed framing contribution per pitch (used for NetK) |
| `ignore_flag` | DO NOT filter on this --- some legitimate pitches are flagged. SELECT it as a column for swing recovery. |

::: blocking
**`ignore_flag` is a tripwire.** Filtering `WHERE pv.ignore_flag = 0`
on Pitches_View excludes legitimate game pitches (e.g. ABs vs position
players pitching) and causes PA undercounts vs GC2. The ONLY standard
pitch filter is `pv.pitch_id > 0`. Two exceptions where filtering on
ignore_flag IS required: NetK queries (GC2 spec) and PBL lead queries
(different column with different meaning). See Ch 6 for full
recovery pattern.
:::

### 2. `Astros.Events_View`

**Granularity:** one row per event (PA outcomes, plus mid-PA events
like SBs and passed balls).

| Column | What |
|---|---|
| `event_id` | Join key (= `cur_event_id` from Pitches_View) |
| `sched_id` | Game identifier |
| `pa` | BIT --- 1 if this is a PA-ending event, 0 for mid-PA events. **MUST CAST to int before SUM.** |
| `ab` | BIT --- 1 for at-bats (hits/outs/errors/strikeouts). MUST CAST. |
| `bb` | BIT --- 1 for walks (includes IBB; for non-IBB walks, `bb=1 AND ibb=0`). |
| `ibb` | BIT --- intentional walks. **`pa=0` on IBBs** --- the explicit `OR ibb=1` gate is required to count IBBs. |
| `hbp` | BIT --- hit by pitch. |
| `sf` | BIT --- sacrifice fly. |
| `sh` | BIT --- sacrifice hit (bunt). **`pa=1` on SHs** --- they inflate PA-count denominators if you're computing wOBA. |
| `so` | BIT --- strikeout. |
| `[1b]`, `[2b]`, `[3b]`, `hr` | BIT --- hit by type (must use square brackets in T-SQL --- they're reserved-ish). |
| `event_result` | Text outcome name (`'single'`, `'walk'`, `'home_run'`, `'stolen_base_2b'`, etc.) |
| `event_result_id` | Numeric code, joins to `Astros.LK_Event_Results`. 51 codes total --- see DB reference for the full table. |
| `batting_team_id`, `fielding_team_id` | Team IDs --- join to `MLBAM.Teams` for org abbreviation |
| `top_of_inning` | 0 = bottom of inning (home batting), 1 = top of inning (away batting) |
| `runner_1b`, `runner_2b`, `runner_3b` | `groundcontrol_id` of runners on each base |
| `hit_trajectory_id` | 2/3/4 = bunts. NOT in Hits table --- it's HERE. |

::: blocking
**`pa` semantics are subtle and BLOCKING.**

- `pa=1` on AB, BB, HBP, SF, **SH** (FanGraphs standard).
- `pa=0` on IBB --- the IBB row has `pa=0` AND `ibb=1`. The full PA
  count is `SUM(CAST(pa AS int)) + SUM(CAST(ISNULL(ibb,0) AS int))`.
- For wOBA/xwOBA denominators, use `AB + BB - IBB + HBP + SF` ---
  this excludes SH. Using a "PA count" instead silently inflates the
  denom by SH count and drops wOBA/wRC+ by ~1 point at org level.

This is the most common silent-drift bug in the codebase.
:::

### 3. `Astros.Hits`

**Granularity:** one row per batted ball.

| Column | What |
|---|---|
| `sched_id`, `pitch_id` | Joins to `Pitches_View` |
| `hit_exit_speed` | Exit velocity (mph). Cap at 125 to filter sensor errors. |
| `hit_vertical_angle` | Launch angle (degrees) |
| `hit_bearing` | Spray direction (NOT `hit_spray_angle` --- it's `hit_bearing`) |
| `hit_initial_contact_point_y` | Depth of contact |
| `hit_useful_exit_speed` | Pre-computed useful EV |

**`Hits` has NO `batter_id`.** You always join through Pitches_View to
get the batter. The full BIP-with-batter pattern:

```sql
LEFT JOIN Astros.Hits h
    ON pv.sched_id = h.sched_id
   AND pv.pitch_id = h.pitch_id
   AND pv.pitch_result_id IN (12, 13, 14)  -- Ball in play only
```

The `pitch_result_id IN (12,13,14)` is the canonical BIP filter.
**Bunt exclusion** (when needed --- and it's needed for nearly every
hitting metric) lives in `Events_View.hit_trajectory_id NOT IN (2,3,4)`,
NOT in the Hits join. See Ch 6 for the full BIP filter chain.

### 4. `Astros.Schedule_View`

**Granularity:** one row per game.

| Column | What |
|---|---|
| `sched_id` | Primary key, unique per game (Astros side) |
| `sched_date` | Game date (NOT `game_date`) |
| `sched_type` | `'R'` regular, `'S'` spring, `'E'` exhibition, `'I'` intersquad, `'V'` Live BP, `'B'` bullpen, etc. |
| `level_code` | `'mlb'`, `'aaa'`, `'aax'`, `'afa'`, `'afx'`, `'rok'`, `'dsl'` (and junk codes like `'bbc'`, `'sum'`, `'hsb'`, `'jcb'`, `'ind'`, `'win'`) |
| `gc2_level_code` | The SAME as `level_code` for most levels, but **DSL/FCL split lives here.** `level_code = 'rok'` covers BOTH FCL and DSL; `gc2_level_code = 'rok'` is FCL/ACL, `gc2_level_code = 'dsl'` is DSL. |
| `level_display` | Display label |
| `year` | Season year |
| `game_pk` | MLBAM game identifier (joins to `MLBAM.Schedule.GAME_PK`) |
| `is_int_level` | 1 if internal/private game (DSL Live AB scrimmages live here) |

::: blocking
**Use `gc2_level_code` for DSL detection, NOT `league`.** Multiple
older queries used `sv.league = 'DSL'` and silently broke when league
went NULL. The canonical helper is `_build_level_filter()` in each
app's `database.py`:

```python
def _build_level_filter(level_code, sv_alias="sv"):
    if level_code in ("dsl", "rok"):
        return f"{sv_alias}.gc2_level_code = '{level_code}'"
    return f"{sv_alias}.level_code = '{level_code}'"
```
:::

### 5. `Astros.Players`

**Granularity:** one row per player.

| Column | What |
|---|---|
| `groundcontrol_id` | **Primary Astros ID.** Equals `batter_id`/`pitcher_id` in Pitches_View. |
| `mlbam_id` | Maps to `player_id` in ALL MLBAM tables. Sometimes NULL (use `ebis_id` fallback). |
| `ebis_id` | eBis system ID --- joins to `MLB_eBis.PP_MASTER.player_id`. |
| `first_name`, `last_name` | (No `first_last` column --- compose with `CONCAT`.) |
| `bats`, `throws` | Handedness. Column is `throws` here, NOT `pitcher_throws` (that's only in Pitches_View). |
| `birthdate` | (NOT `birth_date`.) |

## ID mapping --- the cross-walk you'll learn cold

```
Astros.Players.groundcontrol_id  =  Astros.Pitches_View.batter_id / pitcher_id
                                  =  Astros.Pitches_Baserunner_Leads.groundcontrol_id

Astros.Players.mlbam_id          =  MLBAM.Players.player_id
                                  =  MLBAM.Pitch_fx.batter_id / pitcher_id
                                  =  MLBAM.Hits.* (joined via game_pk)
                                  =  MLBAM.Splits*.player_id

Astros.Players.ebis_id           =  MLB_eBis.PP_MASTER.player_id

Astros.Schedule_View.game_pk     =  MLBAM.Schedule.GAME_PK
```

**When `mlbam_id` is NULL** (some recent acquisitions or international
signings), join through `ebis_id`:

```sql
SELECT ap.groundcontrol_id, ap.first_name, ap.last_name, mp.player_id AS mlbam_id
FROM Astros.Players ap
JOIN MLBAM.Players mp ON ap.ebis_id = mp.ebis_id
WHERE ap.mlbam_id IS NULL
```

## The dual-join pattern (BLOCKING)

This is the single most important join trap in the codebase. Read it
twice.

### The problem

`Astros.Pitches_View` is one row per pitch. To get PA outcomes (was
this PA a strikeout? a walk? a hit?), you join to `Events_View`. But
which event ID do you use?

- `pv.cur_event_id` is **NULL on 75% of pitches** --- only the
  last pitch of each PA has a non-null cur_event_id.
- `pv.ab_event_id` is **populated on every pitch** --- every pitch
  in a PA shares the same `ab_event_id`.

If you join `Events_View` on `cur_event_id`, you can only see PA
outcomes on PA-ending pitches. If you join on `ab_event_id`, you can
see event-level data (`top_of_inning`, `batting_team_id`, etc.) on
every pitch --- but if you also pull PA outcome columns (`pa`, `so`,
`bb`), they get broadcast to every pitch in the AB and overcount when
you SUM them.

### The fix --- two joins, named differently

```sql
SELECT
    pv.batter_id,
    aev.top_of_inning,                         -- always populated
    aev.batting_team_id,                       -- always populated
    cev.pa, cev.so, cev.bb,                    -- only on final pitch of PA
    SUM(CAST(cev.pa AS int)) AS pa_count       -- correct count
FROM Astros.Pitches_View pv
-- aev: PA-anchored event (every pitch), use for team / event-level fields
JOIN Astros.Events_View aev
    ON aev.sched_id = pv.sched_id
   AND aev.event_id = pv.ab_event_id
-- cev: current-event (NULL on non-final pitches), use ONLY for PA outcomes
LEFT JOIN Astros.Events_View cev
    ON cev.sched_id = pv.sched_id
   AND cev.event_id = pv.cur_event_id
WHERE pv.pitch_id > 0
GROUP BY pv.batter_id
```

Use `aev.*` (anchored to `ab_event_id`) for: `top_of_inning`,
`fielding_team_id`, `batting_team_id`, `hit_trajectory_id` (bunt
filter), any event-level attribute you want for every pitch.

Use `cev.*` (anchored to `cur_event_id`) for: `pa`, `so`, `bb`, `hbp`,
`ibb`, `ab`, `sf`, `[1b]`, `[2b]`, `[3b]`, `hr`. PA outcome columns
only.

### Why GC2 doesn't have this problem

GC2 production queries start FROM `Events_View` (one row per PA), not
`Pitches_View`. Every row already has valid `top_of_inning`,
`fielding_team_id`, etc. --- no NULL join issue. Our pitch-level
queries need both joins to get the same data GC2 gets natively.

### `event_id` is NOT globally unique --- BLOCKING

`event_id` (and `cur_event_id`, `ab_event_id`) **repeat across games**.
`event_id = 1` exists in every game. Three rules:

- Never `COUNT(DISTINCT cur_event_id)` for PA counts across multiple
  games --- it undercounts.
- Never `GROUP BY batter_id, ab_event_id` without `sched_id` --- PAs
  from different games will collide and merge.
- Always use `(sched_id, event_id)` as the unique PA key. In Python:
  `df.groupby(["sched_id", "ab_event_id"])`, never groupby
  `ab_event_id` alone.

## Standard hitting + pitching query patterns

Memorize these. Every metric query in the codebase starts from one of
these two skeletons.

### Hitting query (event-anchored)

```sql
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Schedule_View sv
    ON pv.sched_id = sv.sched_id
LEFT JOIN Astros.Events_View cev                      -- PA outcomes
    ON pv.sched_id = cev.sched_id
   AND pv.cur_event_id = cev.event_id
LEFT JOIN Astros.Hits h                               -- BIPs only
    ON pv.sched_id = h.sched_id
   AND pv.pitch_id = h.pitch_id
   AND pv.pitch_result_id IN (12, 13, 14)
LEFT JOIN Astros.Players p
    ON p.groundcontrol_id = pv.batter_id
WHERE sv.year = :season
  AND sv.sched_type = 'R'
  AND sv.level_code = :level_code     -- or use _build_level_filter
  AND pv.pitch_id > 0
```

### Pitching query (PA-anchored, with `pa = 1` gate)

```sql
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Schedule_View sv
    ON pv.sched_id = sv.sched_id
LEFT JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id
   AND ev.event_id = pv.cur_event_id
   AND ev.pa = 1                                       -- PA-ending pitches only
LEFT JOIN Astros.Players pr
    ON pr.groundcontrol_id = pv.pitcher_id
LEFT JOIN Astros.Hits h
    ON h.sched_id = pv.sched_id
   AND h.pitch_id = pv.pitch_id
   AND pv.pitch_result_id IN (12, 13, 14)
WHERE sv.year = :season
  AND sv.sched_type = 'R'
  AND pv.pitch_id > 0
```

## Level codes --- MLBAM SPORT vs Astros vs MLB_eBis

Three systems, three encodings. Master one cross-walk:

| Level | Astros `level_code` | MLBAM `SPORT` | PP_MASTER `LEVELOFPLAY_LK` |
|---|---|---|---|
| MLB | `mlb` | `mlb` | `ML` |
| AAA | `aaa` | `aaa` | `3A` |
| AA | `aax` | `aax` | `2A` |
| A+ | `afa` | `afa` | `1A` |
| A | `afx` | `afx` | `1F` |
| FCL/ACL (Rookie) | `rok` | `rok` | `R` |
| DSL | `rok` (with `gc2_level_code='dsl'`) | --- | `DS` |

PP_MASTER returns its codes in **uppercase**. Always
`.strip().lower()` before comparing.

The MLBAM SPORT has no DSL code --- DSL never goes through MLBAM
schedule. Filter DSL via `Astros.Schedule_View.gc2_level_code = 'dsl'`.

### Junk level codes --- always exclude (with two exceptions)

These show up in production data and pollute pro pools if you don't
filter them out:

| Code | What | Notes |
|---|---|---|
| `bbc` | 4-year college (amateur) | Always exclude for pro reports; ALLOW for draft / amateur-vs-pro |
| `sum` | Summer league (Cape Cod, Northwoods --- amateur college) | Same treatment as bbc |
| `hsb` | High school showcase | Same |
| `jcb` | Junior college (amateur) | Same |
| `ind` | Independent league | Always exclude |
| `win` | Winter league | Always exclude |
| `nae` | Unknown | Always exclude |
| `int` | Internal/private | Mostly junk; **two exceptions** below |
| `min` | MiLB minor/exhibition | NOT junk --- has real games |
| NULL | No level | Always exclude |

::: blocking
**Every junk code has `sched_type = 'R'` games.** `sched_type = 'R'`
alone does NOT protect against contamination. Always pair with a
level-code filter. Use one of:

- Whitelist: `sv.level_code IN ('mlb','aaa','aax','afa','afx','rok','dsl')`
- `_build_level_filter()` helper
- `EXCLUDE_LEVELS_SQL` constant (full junk list)
- `_JUNK_LEVELS_R` (with `int`) for R-type queries
:::

### `int` level exceptions

`int` is "internal/private" --- two real-data exceptions:

1. **`int` + `sched_type='V'`** = DSL bullpen sessions (1,267+ games).
   Allow for V/I queries, block for R-type.
2. **`int` + `sched_type='R'` + `is_int_level=1`** = HOU DSL DR-Private
   intrasquad scrimmages (Live AB). Postgame surface only --- never
   leaks into KPI / trackers / org KPI.

### `bbc` is College --- corrected Apr 2026

`bbc` is **4-year college baseball**, NOT "Big League Camp" as some
older docs claimed. Spring training games are `sched_type = 'S'` on
`level_code = 'mlb'` (or affiliate level), not `level_code = 'bbc'`.
The four amateur level codes (`bbc`, `jcb`, `hsb`, `sum`) are
intentionally INCLUDED in draft/amateur-vs-pro analysis and in advance
reports (recency wins over level purity), and intentionally EXCLUDED
everywhere else.

## Schedule types

| `sched_type` | What | Include in pro stats? |
|---|---|---|
| `R` | Regular season | Yes (default) |
| `S` | Spring training | Yes (PD goals begin here) |
| `C` | AAA Championship | Yes |
| `D` | Division Series | Yes |
| `F` | Wild Card | Yes |
| `L` | LCS | Yes |
| `W` | World Series | Yes |
| `E` | Exhibition | No |
| `I` | Intersquad | No |
| `B` | Bullpen session | No (separate analysis) |
| `P` | Batting practice | No |
| `V` | Live BP | No |
| `U` | Summer Camp | TBD |
| `A` | All-Star Game | TBD |

In code, the scheduling-types module exports:

```python
DATA_SCHED_TYPES = ("R", "S", "E", "V", "I")  # what reports can show
```

## SQL Server quirks --- the BIT trap and friends

::: blocking
**`SUM(bit_col)` throws an error in SQL Server.** Always
`SUM(CAST(col AS int))`.

Known BIT columns:

- `Events_View`: `pa`, `ab`, `bb`, `ibb`, `hbp`, `sf`, `sh`, `so`, `[1b]`, `[2b]`, `[3b]`, `hr`
- `Defense_Combined_By_Pos`: `out_made`, `competitive_play`, `competitive_throw`
- `Tracking_Defensive_Metrics`: `competitive_play`, `competitive_throw`
- `Pitches_Baserunner_Leads`: `runner_going`, `next_base_open`, `ignore_flag`
- `Events_StolenBases`: `success`

Comparison (`= 1`) works fine. Aggregation (`SUM`, `AVG`) requires
explicit cast. Most production code uses `CAST(col AS int)`; floats
are also fine.
:::

::: blocking
**No `SUM(CASE WHEN EXISTS (...) THEN 1 ELSE 0 END)`.** SQL Server
won't let you aggregate over an expression containing a subquery. Move
the EXISTS to the WHERE clause and `COUNT(*)` instead.
:::

::: blocking
**`Astros.*` tables are case-sensitive on view aliases like `LK_*`.**
`SELECT ... FROM .dbo.LK_Pitch_Results` will fail. The default schema
is `dbo` and `Astros.LK_Pitch_Results` is the correct fully-qualified
form.
:::

## Pitch result codes (preview)

There are 31 pitch result codes in `Astros.LK_Pitch_Results`. The
groupings you'll memorize:

```sql
-- Whiff (swinging strike): pitch_result_id IN (10, 21, 22, 23)
-- Called Strike:            pitch_result_id IN (3, 6, 24, 30, 31)
-- Ball:                     pitch_result_id IN (1, 2, 4, 5, 11, 15, 17, 26, 27, 28, 29)
-- BIP (Ball in Play):       pitch_result_id IN (12, 13, 14)
-- BIP including pitchout:   pitch_result_id IN (12, 13, 14, 18, 19, 20)
-- Foul:                     pitch_result_id IN (7, 8, 9)
-- Foul tip (counted as whiff): pitch_result_id = 10
```

Full table is in **Chapter 6** with the data-cleaning rules. The most
common confusion: foul tip (10) IS a whiff, missed bunt (16) is debated
(GC2 excludes it from whiffs; we include it).

## Lookup tables you'll consult

| Table | Purpose |
|---|---|
| `Astros.LK_Pitch_Results` | 31 pitch result codes |
| `Astros.LK_Event_Results` | 51 event result codes (`stolen_base_2b`, `home_run`, etc.) |
| `Astros.LK_Hit_Trajectories` | Bunt detection (`hit_trajectory_id IN (2,3,4)`) |
| `Astros.LK_Schedule_Types` | sched_type to display name |
| `Astros.LK_Levels` | Level code metadata |
| `Astros.LK_Video_Angles_Char` | Video angle code reference |

## The other tables (browse later)

This chapter focused on the five you'll touch every day. There are
hundreds more. Bookmark `sql-queries/DATABASE_REFERENCE.md` for the
full schema --- key callouts:

- `Astros.Bat_Tracking_Metrics` --- peak bat speed (now superseded
  by `swing_contact_values` for at-contact bat speed)
- `Astros.Pitches_Baserunner_Leads` (PBL) --- per-pitch primary +
  secondary lead distances per runner
- `Astros.Events_StolenBases` (ESB) --- per-runner SB/CS detail
  (NEVER use `success` BIT for SB totals --- use Events_View
  `event_result_id`)
- `Astros.Tracking_Defensive_Metrics` (TDM), `Astros.Defense_Combined_By_Pos` (DCBP) --- per-play fielding tracking; the 6-term Tier 1 gate uses BOTH
- `Astros.Hits_Probabilities` --- per-BIP outcome probabilities for xBA / xSLG / xwOBA
- `Astros.Video_Network` + `Astros.Video` --- two video tables (string-angle vs integer-angle-id), see Ch 11 for the V-column three-tier fallback
- `groundcontroltracking.tracking.Swing_Contact_Values` --- bat speed at contact, contact-frame bat orientation
- `groundcontroltracking.tracking.Plays` --- joins Pitches_View pitch_id to tracking play_id
- `groundcontroltracking.tracking.Play_Event_Positions` --- per-fielder catch/field position
- `MLBAM.SplitsBat`, `MLBAM.SplitsPit` --- pre-computed splits by player/level/year/sit_code (vs LHP/RHP, etc.) --- excellent for league percentiles
- `MLBAM.YTD_Player_Batting_Stats`, `MLBAM.YTD_Player_Pitching_Stats` --- year-to-date official stats
- `Guts.woba_lwts` --- linear weights by year + level + league
- `Guts.hit_specs_ratios` --- xwOBA exponents by year (no level dim)
- `Guts.Count_RE` --- count run expectancy (used for zxwOBA)
- `MLB_eBis.PP_MASTER` --- daily roster (`ORG_LK`, `LEVELOFPLAY_LK`, `MNROSTERSTATUS_LK`)
- `MLB_eBis.R4_Draft_Query` --- draft history per player

## Where to look next

- **Chapter 4** (GC2 & Deviations) --- what GC2 is, what its
  proprietary metrics mean, and the 7 places where we deliberately
  diverge from GC2.
- **Chapter 6** (Data Cleaning Canon) --- the BIP filter chain, EV
  misread filter, BIT casting, and the bat speed canonical helper.
- `sql-queries/DATABASE_REFERENCE.md` --- the full schema reference,
  ~1,400 lines.
- `.claude/rules/db-columns.md`, `db-joins.md`, `db-connection.md`,
  `pitch-codes.md`, `level-codes.md`, `sched-types.md` --- the
  canonical rules underlying this chapter.
