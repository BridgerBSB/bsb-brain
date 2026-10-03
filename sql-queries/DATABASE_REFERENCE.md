# GroundControl2 Database Reference

**Server:** gcsql02 → GroundControl2
**Authentication:** Windows Auth (ODBC Driver 17)
**Last Updated:** February 2, 2026

---

## Table of Contents

1. [Schema Overview](#1-schema-overview)
2. [Key Tables](#2-key-tables)
3. [Lookup Tables (Astros.LK_*)](#3-lookup-tables-astroslk_)
4. [MLBAM Pitch Type Classification](#4-mlbam-pitch-type-classification)
5. [Pitch Result Codes](#5-pitch-result-codes)
6. [ID Mapping](#6-id-mapping)
7. [Key Join Patterns](#7-key-join-patterns)
8. [Bat Speed Calculation](#8-bat-speed-calculation)
9. [Important Production Filters](#9-important-production-filters)
10. [Schedule Types](#10-schedule-types)
11. [Metric Formulas](#11-metric-formulas)
12. [Roster and Position Codes](#12-roster-and-position-codes)
13. [Zone System and Swing Zones](#13-zone-system-and-swing-zones)
14. [Quick Reference](#14-quick-reference)
15. [Future Reference Tables](#15-future-reference-tables)

---

## 1. Schema Overview

| Schema | Scope | Description |
|--------|-------|-------------|
| **Astros.*** | Astros org only | Detailed pitch-level tracking for all Astros MiLB/MLB players |
| **MLBAM.*** | All 30 MLB teams | League-wide data, used for percentile calculations |
| **GroundControlTracking.tracking.*** | Astros org only | Bat tracking, swing shapes, contact values |
| **MLB_eBis.*** | All 30 teams | eBis roster system (PP_MASTER for daily rosters) |
| **Guts.*** | League-wide | Linear weights for wOBA/FIP calculations |
| **Trackman.*** | Astros org only | Portable TrackMan unit data (bullpens, BP) |

Additional schemas (less frequently used):
- **Proj.*** - Batting/Pitching MLEs and projections
- **Scout.*** - Scouting reports and bios
- **Sportsmed.*** - Speed gates, force plates, ForceDeck metrics
- **College.*** - College YTD batting/pitching stats
- **Player_Val.*** - Dollar per WAR values

---

## 2. Key Tables

### Astros.Pitches_View

**Granularity:** One row per pitch. Central table -- combines multiple underlying tables.

| Column | Type | Notes |
|--------|------|-------|
| batter_id | int | = groundcontrol_id from Astros.Players |
| pitcher_id | int | = groundcontrol_id from Astros.Players |
| pitch_type | varchar | See pitch type classification (section 4) |
| release_speed | float | Pitch velocity |
| spin_rate | float | Spin rate (RPM) |
| extension | float | Release extension (feet) |
| inducedvertbreak | float | Induced vertical break |
| horzbreak | float | Horizontal break |
| called_strike_chance_mlb | float | Called strike probability (0.0 - 1.0) |
| did_swing | int | **0/1 integer** (contrast with MLBAM 'Y'/'N' varchar) |
| pitch_result_id | int | Maps to Astros.LK_Pitch_Results |
| swing_decision_grade_2080 | float | Swing decision on 20-80 scale |
| swing_decision_abs_grade_2080 | float | SwDec using Automated Ball-Strike zone |
| stuffrelvel_grade_2080 | float | Stuff+ relative value on 20-80 scale |
| swing_zone | varchar | Categorical zone: 'meatball', 'heart', 'shadow', 'chase', 'waste' |
| bat_side | varchar | Batter handedness |
| balls_before | int | Ball count before this pitch |
| strikes_before | int | Strike count before this pitch |
| ab_pitch_number | int | Pitch number within the PA (1 = first pitch, used for FPS%) |
| game_pitch_number | int | Pitch number within the game |
| pitcher_pitch_number | int | Pitch number for the pitcher |
| sched_id | int | Game identifier (joins to Schedule_View) |
| pitch_id | int | Unique pitch within a game |
| cur_event_id | int | Current event (joins to Events_View.event_id) |
| ab_event_id | int | PA identifier (same as next_event_id most of the time) |
| next_event_id | int | Next event ID (approx equals ab_event_id) |
| event_number | int | Event sequence number |
| ignore_flag | int | DO NOT filter on this — includes legit game pitches (e.g. vs position players pitching). Use pitch_id > 0 only. |

---

### Astros.Events_View

**Granularity:** One row per event (plate appearance outcomes).

| Column | Type | Notes |
|--------|------|-------|
| event_id | int | Join key (= cur_event_id from Pitches_View) |
| sched_id | int | Game identifier |
| so | **bit** | Strikeout. **MUST CAST to int before SUM:** `SUM(CAST(so AS int))` |
| bb | **bit** | Walk. Same casting requirement. |
| pa | **bit** | Plate appearance. Same casting requirement. |
| event_result | varchar | Text description of outcome |
| event_result_id | int | Maps to LK_Event_Results |
| inning | int | Inning number |
| outs_before | int | Outs before the event |
| ab_event_id | int | PA identifier (despite "ab" name, this IS the PA identifier) |
| cur_event_id | int | Current event ID |
| next_event_id | int | Approximately equals ab_event_id most of the time |

**Important:** Has NO batter_id column. Must join through Pitches_View to get player info.

**Event ID logic:** Stolen bases, passed balls, and similar mid-PA events are events that do NOT end plate appearances. This is why cur_event_id and ab_event_id can differ.

---

### Astros.Hits

**Granularity:** One row per batted ball (Astros org only).

| Column | Type | Notes |
|--------|------|-------|
| sched_id | int | Game identifier |
| pitch_id | int | Joins to Pitches_View.pitch_id |
| hit_exit_speed | float | Exit velocity (mph) |
| hit_vertical_angle | float | Launch angle (degrees) |
| hit_initial_contact_point_y | float | Depth of contact (DOC) |
| hit_bearing | float | Spray direction |
| hit_useful_exit_speed | float | Pre-calculated useful EV |
| hit_trajectory_id | int | Maps to LK_Hit_Trajectories; 2,3,4 = bunts |

**Important:** Has NO batter_id column. Must join through Pitches_View.

---

### Astros.Schedule_View

**Granularity:** One row per game.

| Column | Type | Notes |
|--------|------|-------|
| sched_id | int | Primary key, unique per game (Astros) |
| sched_date | date | Game date |
| sched_type | varchar | Game type code (see section 10) |
| level_code | varchar | Level (e.g., 'mlb', 'aaa', 'aax', 'afa') |
| level_display | varchar | Display name for level |
| year | int | Season year |
| game_pk | int | MLBAM game identifier (joins to MLBAM.Schedule.GAME_PK) |
| mlbam_game_pk | int | Alternate MLBAM game identifier |
| venue_id | int | Venue identifier |

**Note:** Does NOT have gameday_number (doubleheader indicator). That column IS in MLBAM.Schedule.

---

### Astros.Players

**Granularity:** One row per player.

| Column | Type | Notes |
|--------|------|-------|
| groundcontrol_id | int | **Primary Astros ID.** = batter_id and pitcher_id in Pitches_View |
| mlbam_id | int | Maps to player_id in ALL MLBAM tables |
| ebis_id | int | eBis system ID |
| college_splits_id | int | College stats ID |
| first_name | varchar | |
| last_name | varchar | |
| bats | varchar | Batting handedness |
| throws | varchar | Throwing handedness |
| player_type | varchar | 'P' = Pitcher, 'H' = Hitter, 'B' = Two-Way |

---

### Astros.Bat_Tracking_Metrics

**Granularity:** One row per swing (Astros org only).

| Column | Type | Notes |
|--------|------|-------|
| sched_id | int | Game identifier |
| pitch_id | int | Joins to Pitches_View.pitch_id |
| groundcontrol_id | int | Player ID |
| vx_true_peak | float | Peak bat speed X component (FPS) |
| vy_true_peak | float | Peak bat speed Y component (FPS) |
| vz_true_peak | float | Peak bat speed Z component (FPS) |

See [Bat Speed Calculation](#8-bat-speed-calculation) for the formula. Source: Adam Brodie (RnD).

---

### Astros.Pitches_Grades

**Granularity:** Pitch-level grades.

| Column | Type | Notes |
|--------|------|-------|
| stuffvel_grade_2080 | float | Stuff + velocity grade (20-80) |
| stuffrelvel_grade_2080 | float | Stuff + relative velocity grade (20-80) |
| stuffrelvelloc_grade_2080 | float | Stuff + relative velocity + location (20-80) |
| component_grade_2080 | float | Component grade (20-80) |

---

### Astros.Projections_Pitches_Grades

**Granularity:** Projected pitch grades.

| Column | Type | Notes |
|--------|------|-------|
| fb_grade | float | Overall pitch grade (most predictive) |
| pg_swing | float | Projected swing rate |
| pg_whiff_swing | float | Projected whiff rate on swings |
| swing_decision | float | Projected swing decision grade |

---

### Astros.Hits_Probabilities

Used for xBA, xSLG, xwOBA calculations.

---

### MLBAM.Pitch_fx

**Granularity:** One row per pitch, all 30 MLB teams.

| Column | Type | Notes |
|--------|------|-------|
| game_pk | int | MLBAM game identifier |
| batter_id | int | MLBAM player ID |
| pitcher_id | int | MLBAM player ID |
| pitch_type | varchar | Pitch classification code |
| called_strike_chance_mlb | float | Called strike probability |
| did_swing | **varchar** | **'Y'/'N' string** (contrast with Astros 0/1 integer) |
| pitch_result_id | int | Pitch outcome code |
| swing_decision_score | float | Swing decision metric |
| stuffrelvel_grade_2080 | float | Stuff+ on 20-80 scale |
| bat_side | varchar | Batter handedness |
| year | int | Season year |
| InducedVertBreak | float | Induced vertical break |
| initial_speed | float | Pitch velocity |
| spin_rate | float | Spin rate (RPM) |
| extension | float | Release extension |
| balls_before | int | Ball count |
| strikes_before | int | Strike count |
| sv_pitch_id | varchar | **NULL in this table** -- cannot join to MLBAM.Hits |

---

### MLBAM.Hits

**Granularity:** One row per batted ball, all 30 MLB teams.

| Column | Type | Notes |
|--------|------|-------|
| game_pk | int | MLBAM game identifier |
| sv_pitch_id | varchar | Format: "YYMMDD_HHMMSS" |
| hit_initial_speed | float | Exit velocity (mph) |
| hit_vertical_angle | float | Launch angle (degrees) |
| hit_horizontal_angle | float | Spray angle |
| hit_initial_contact_point_x | float | Contact point X |
| hit_initial_contact_point_y | float | Contact point Y |
| hit_initial_contact_point_z | float | Contact point Z |
| hit_initial_velocity_x | float | Batted ball velocity X |
| hit_initial_velocity_y | float | Batted ball velocity Y |
| hit_initial_velocity_z | float | Batted ball velocity Z |
| hit_average_lop_error | float | |
| hit_chopper | bit | Chopper flag |

**CRITICAL:** Has NO batter_id or pitcher_id. Cannot join to MLBAM.Pitch_fx via sv_pitch_id (it is NULL in Pitch_fx). Alternative: check if MLBAM.Pitch_fx has hit_initial_speed/hit_vertical_angle directly — see `sql-queries/damage-percentile-discovery.sql`.

---

### MLBAM.Schedule

**Granularity:** One row per game, all 30 MLB teams + all MiLB levels.
**Verified:** Mar 13, 2026 via advance batch diagnostic.

| Column | Type | Notes |
|--------|------|-------|
| GAME_PK | int | Primary key. Joins to Astros.Schedule_View.game_pk |
| GAMEDATE | date | Game date (also aliased as GAME_DATE) |
| GAME_DATE | date | Same as GAMEDATE |
| GAME_ID | varchar | Game string identifier |
| SPORT | char | MLBAM level code ('aaa', 'aax', 'afa', 'afx', 'rok', 'mlb', 'min') |
| HOME | varchar | Home team display name (e.g., 'Sugar Land Space Cowboys') |
| AWAY | varchar | Away team display name |
| HOME_TEAM_ID | int | Home team ID (joins to MLBAM.Teams.team_id) |
| AWAY_TEAM_ID | int | Away team ID (joins to MLBAM.Teams.team_id) |
| YEAR | int | Season year |
| LEAGUE | char | League identifier (joins to Guts.woba_lwts.league) |
| LEAGUE_ID | int | League numeric ID |
| DAY | varchar | Day of week |
| TIME_ET | time | Game time (Eastern) |
| TIME_LOCAL | time | Game time (local) |
| ZONE | char | Time zone |
| GAME_TYPE | char | Game type |
| GAME_NBR | tinyint | Game number (doubleheader) |
| DOUBLE_HEADER_SW | char | Doubleheader flag |
| SCHEDULED_INNINGS | tinyint | Scheduled innings |
| VENUE_ID | int | Venue identifier |
| VENUE | varchar | Venue name |
| DAY_NIGHT | varchar | Day/Night indicator |
| SER_GAME_NBR | tinyint | Series game number |
| SER_GAMES | tinyint | Total games in series |
| DESCRIPTION | varchar | Game description |
| GAME_STATUS_IND | char | Game status |

---

### mlb_ebis.gbl_club_lkup

**Granularity:** One row per club/org/level combination.
**Purpose:** Maps eBis club identifiers to ORG_LK codes for PP_MASTER joins.
**Verified:** Mar 13, 2026 via advance batch diagnostic.

| Column | Type | Notes |
|--------|------|-------|
| CLUB_LK | varchar | Club identifier (unique per team at level) |
| ORG_LK | varchar | Organization code — **CASE MATTERS**: uses uppercase (CHI, LA, NY, etc.) |
| LEVELOFPLAY_LK | varchar | eBis level code: '3a', '2a', '1a', '1f', 'r', 'ml', 'ds' |
| ACTIVE_FLG | tinyint | 1 = active, 0 = inactive |
| CLUBNAME | varchar | Full club name |
| CLUBSHORTNAME | varchar | Short name |
| CLUBNICKNAME | varchar | Nickname |
| SEASON | int | Season year |
| MNLEAGUE_LK | varchar | Minor league code |
| LEAGUE | varchar | League name |
| DIVISION | varchar | Division name |

**Org remapping quirks** (ORG_LK → MLBAM.Teams org_abbrev):
- `CHI` → `chc` (Cubs, not White Sox — CWS is separate)
- `LA` → `lad` (Dodgers, not Angels — LAA is separate)
- `NY` → `nym` (Mets, not Yankees — NYY is separate)
- `OAK` / `ATH` — Athletics use both codes (ATH is newer)
- Filter: `ORG_LK <> 'boc'` (excludes inactive/legacy)

---

### MLBAM.SplitsBat / MLBAM.SplitsPit

**Granularity:** One row per player/level/year/split combination. Pre-computed splits for all 30 teams. Excellent for platoon percentiles.

| Column | Type | Notes |
|--------|------|-------|
| player_id | int | MLBAM player ID |
| level | varchar | Level code |
| year | int | Season year |
| sit_code | varchar | Split type (82 total codes) |
| ab | int | At-bats |
| bb | int | Walks |
| hbp | int | Hit by pitch |
| sf | int | Sac flies |
| so | int | Strikeouts |
| ... | | Additional counting stats |

**Key sit_code values:**
- `'all'` = Overall
- `'vl'` = vs LHP
- `'vr'` = vs RHP

**Recommended min PA filter:** `(ab + bb + hbp + sf) >= 50`

Use `PERCENT_RANK()` over these tables for K%, BB%, wOBA, SLG percentiles.

---

### MLBAM.YTD_* Tables (Year-to-Date Aggregated Stats)

All have `player_id`, `level`, `season` columns.

| Table | Key Columns |
|-------|-------------|
| **YTD_Player_Batting_Stats** | pa, avg, ab, h, 2b, 3b, hr, bb, so, slg, obp, ops, gm_type, split_id |
| **YTD_Player_Batting_Stats_Given_Hit_Specs** | wOBA, xwOBA, wRCplus, xwRCplus, xba, xslg, rv_bip |
| **YTD_Player_Pitching_Stats** | w, l, era, outs, so, bb, whip, k_9, bb_9 |
| **YTD_Player_Pitching_Stats_Given_Hit_Specs** | wOBA, xwOBA (pitcher side) |
| **YTD_Player_Batting_Stats_MLE** | MLE-adjusted stats |
| **YTD_Player_Batting_Stats_MLE_Weighted** | Weighted MLE with age, level PA breakdowns |
| **YTD_Baserunning** | ha_runs, ga_runs, sb_runs, aa_runs |
| **YTD_Catcher_Defense** | framing_runs, blocking_ground/air, sb/cs |
| **YTD_Team_Batting_Stats** | Team-level aggregates (team_id + level + season) |
| **YTD_Team_Pitching_Stats** | Team pitching aggregates |

Full column details: `sql-queries/mlbam-ytd-columns.csv`
Sample rows: `sql-queries/mlbam-ytd-sample-rows.csv`

---

### Other MLBAM Tables

| Table | Key Columns | Usage |
|-------|-------------|-------|
| **MLBAM.Players** | player_id, name_first, name_last | MLB player identification |
| **MLBAM.Rosters** | player_id, team_id, status_code, primary_position | Active rosters |
| **MLBAM.Teams** | team_id, season, name_abbrev, sport_code | Team info |
| **MLBAM.Gamelog_Batting** | player_id, game_pk | Game-by-game batting |
| **MLBAM.Gamelog_Pitching** | player_id, game_pk | Game-by-game pitching |
| **MLBAM.PBP_Postgame** | game_pk | Post-game data (win/loss) |

---

### Guts.woba_lwts

Linear weights by year and level. Used for wOBA and FIP calculations.

| Column | Type | Notes |
|--------|------|-------|
| year | int | Season year |
| level | varchar | Level code |
| league | varchar | League identifier |
| ... | float | Various linear weight coefficients |

---

### GroundControlTracking.tracking.* (and groundcontroltracking.Tracking.*)

Bat tracking, swing shapes, contact data, plus full per-fielder + per-runner
position tracking. Astros org only. **64 tables total** — see
`.claude/rules/tracking-schema.md` for the complete schema map, event-type
lookup, and HawkEye coverage caveats.

**Hitting / swing tables** (used today):

| Table | Key Columns |
|-------|-------------|
| **plays** | sched_id, astros_pitch_id, tracking_play_id (links Pitches_View to tracking) |
| **swing_shapes** | sched_id, tracking_play_id, loft, tilt, Km30, Km15, K0, K15, K30, K45 |
| **Swing_Contact_Values** | batvx_con, batvy_con, batvz_con (bat speed at contact), con_loc_axis, con_loc_perp, e1x_con, e1y_con |
| **swing_damage_windows** | damage_window |
| **pitch_hit_trajectories** | hit_launch_speed, hit_launch_angle, hit_launch_direction, hit_launch_spinrate, hit_launch_spinaxis |

**Fielding / position tracking** (discovered Apr 30 2026 — see `tracking-schema.md` for full reference):

| Table | Key Columns |
|-------|-------------|
| **Play_Starting_Positions** | sched_id, pitch_id, pos_id, X_at_pitch_release, Y_at_pitch_release (used today only for catcher depth, pos_id=2) |
| **Play_Event_Positions** | sched_id, pitch_id, pos_id, tracking_play_event_id, **pos_x, pos_y** (per-fielder catch/field position via event_type 4/5/17) |
| **LK_Play_Event_Types** | event id catalog: 4=BALL_WAS_CAUGHT, 5=BALL_WAS_CAUGHT_OUT, 17=BALL_WAS_FIELDED |
| **INF_Tracking_Metrics** | per-play IF metrics: `time_to_field`, `field_dist`, full reaction suite |
| **OF_Tracking_Metrics** | OF equivalent of INF_Tracking_Metrics |
| **Player_Tracking_ByPos** | per-timestamp WIDE format — all 9 fielders + ball + 3 runners as `x_<pos>`/`y_<pos>` columns |

**HawkEye coverage caveat (BLOCKING):** these populate only at HawkEye-installed venues (all MLB + Astros affiliate venues). Expect ~50% sparsity at non-HawkEye MiLB venues. See `tracking-schema.md` §HawkEye for fallbacks.

---

### Trackman.Pitches

Portable TrackMan unit data for bullpens and batting practice. Mapped to schedule types: `'B'` (Bullpen Session), `'V'` (Live BP), `'P'` (Batting Practice). Source: Adam Brodie.

---

### MLB_eBis.PP_MASTER

eBis roster system. Used for daily roster status and position lookups. Joins via `ebis_id` from Astros.Players.

---

## 3. Lookup Tables (Astros.LK_*)

| Table | Purpose |
|-------|---------|
| Astros.LK_Event_Results | Event outcome codes |
| Astros.LK_Hit_Trajectories | Batted ball trajectory types (2,3,4 = bunts) |
| Astros.LK_Leagues | League definitions |
| Astros.LK_LevelGroup_Link | Level grouping links |
| Astros.LK_LevelGroups | Level groupings |
| Astros.LK_Levels | Level definitions |
| Astros.LK_Lwts_Event_Types | Linear weights event type mapping |
| Astros.LK_Lwts_Events | Linear weights event definitions |
| Astros.LK_OptPitch_Conditions | Optimal pitch conditions |
| Astros.LK_Pitch_Generic_Comments | Pitch comment templates |
| Astros.LK_Pitch_Results | Pitch result codes (31 total, see section 5) |
| Astros.LK_Pitch_Types | Pitch type definitions |
| Astros.LK_Play_Probabilities | Play probability data |
| Astros.LK_Player_Ownership_DataPlatform | Player ownership (data platform) |
| Astros.LK_Player_Ownership_Measures | Player ownership measures |
| Astros.LK_PlayerPerformance_Parameters | Player performance parameters |
| Astros.LK_PlayerPerformance_Performance... | Player performance metrics (multiple tables) |
| Astros.LK_RulesOfThumb_Category | Rules of thumb categories |
| Astros.LK_RulesOfThumb_Type | Rules of thumb types |
| Astros.LK_Schedule_Types | Game type codes (see table below) |
| Astros.LK_Shift_Types | Defensive shift types |
| Astros.LK_Sources | Data source definitions |
| Astros.LK_Squeeze_Definitions_Scores | Squeeze definitions/scores |
| Astros.LK_Video_Angles | Video angle definitions |
| Astros.LK_Video_Angles_Char | Video angle character codes |

### Astros.LK_Schedule_Types (Full Table)

| sched_type_id | sched_type | description |
|---|---|---|
| 1 | A | All-Star Game |
| 2 | C | AAA Championship |
| 3 | D | Division Series |
| 4 | E | Exhibition |
| 5 | F | Wild Card Game |
| 6 | I | Intersquad |
| 7 | L | League Championship Series |
| 8 | R | Regular Season |
| 9 | S | Spring Training |
| 10 | W | World Series |
| 11 | B | Bullpen Session |
| 12 | P | Batting Practice |
| 13 | U | Summer Camp |
| 14 | V | Live BP |

### Astros.LK_Hit_Trajectories (Key Values)

| ID | Meaning |
|----|---------|
| 2 | Bunt Popup |
| 3 | Bunt Groundout |
| 4 | Bunt Foul |
| 5 | Fly Ball |
| 6 | Ground Ball |
| 7 | Line Drive |
| 8 | Popup |

### Astros.LK_Event_Results (Complete — 51 Codes)

Maps `event_result_id` to `event_result` text in `Astros.Events_View`. Used for PA outcome classification, baserunning events, and defensive plays.

**Note:** `event_result` in Events_View maps to `event_result_id` via this table. Fly-ball double plays use `double_play` (ID 10) and `sac_fly_double_play` (ID 40) — confirmed via DB discovery.

#### Hits

| event_result_id | event_result |
|---|---|
| 41 | single |
| 9 | double |
| 48 | triple |
| 21 | home_run |

#### Outs — Batted Ball

| event_result_id | event_result |
|---|---|
| 14 | field_out |
| 18 | force_out |
| 17 | fielders_choice_out |
| 16 | fielders_choice |
| 19 | grounded_into_double_play |
| 10 | double_play |
| 49 | triple_play |
| 39 | sac_fly |
| 40 | sac_fly_double_play |
| 37 | sac_bunt |
| 38 | sac_bunt_double_play |

#### Outs — Strikeout

| event_result_id | event_result |
|---|---|
| 45 | strikeout |
| 46 | strikeout_double_play |
| 47 | strikeout_triple_play |

#### Walks / HBP

| event_result_id | event_result |
|---|---|
| 50 | walk |
| 22 | intent_walk |
| 20 | hit_by_pitch |

#### Errors

| event_result_id | event_result |
|---|---|
| 11 | error |
| 13 | field_error |

#### Stolen Bases

| event_result_id | event_result |
|---|---|
| 42 | stolen_base_2b |
| 43 | stolen_base_3b |
| 44 | stolen_base_home |

#### Caught Stealing

| event_result_id | event_result |
|---|---|
| 4 | caught_stealing_2b |
| 5 | caught_stealing_3b |
| 6 | caught_stealing_home |
| 7 | cs_double_play |

#### Pickoffs

| event_result_id | event_result |
|---|---|
| 26 | pickoff_1b |
| 27 | pickoff_2b |
| 28 | pickoff_3b |
| 29 | pickoff_caught_stealing_2b |
| 30 | pickoff_caught_stealing_3b |
| 31 | pickoff_caught_stealing_home |
| 32 | pickoff_error_1b |
| 33 | pickoff_error_2b |
| 34 | pickoff_error_3b |

#### Interference / Other

| event_result_id | event_result |
|---|---|
| 2 | batter_interference |
| 15 | fielder_interference |
| 12 | fan_interference |
| 36 | runner_interference |
| 3 | catcher_interf |
| 8 | defensive_indiff |
| 1 | balk |
| 25 | passed_ball |
| 51 | wild_pitch |
| 23 | other_advance |
| 24 | other_out |
| 35 | runner_double_play |

---

### Astros.LK_Levels (Level Codes)

| level_id | level_code | MLBAM SPORT | Description |
|----------|------------|-------------|-------------|
| 1 | aaa | aaa | Triple-A |
| 2 | aax | aax | Double-A |
| 3 | afa | afa | High-A (A+) |
| 4 | afx | afx | Single-A |
| 5 | asx | - | Low-A (legacy) |
| 6 | bbc | - | College (amateur 4-year college) |
| 8 | hsb | - | High School |
| 13 | mlb | mlb | Major League Baseball |
| 20 | rok | rok | Rookie Ball |
| 21 | win | - | Winter Leagues |
| 22 | sum | - | Summer Leagues |
| 23 | jcb | - | Junior College |
| 24 | dsl | - | Dominican Summer League |

**Key for queries:**
- `Astros.Schedule.level_id = 3` for A+ (High-A)
- `MLBAM.Schedule.SPORT = 'afa'` for A+ (High-A)
| ind | IND | Independent |

---

## 4. MLBAM Pitch Type Classification

| Code | Type | Category | Count (2025) |
|------|------|----------|-------------|
| FF | Four-Seam Fastball | Fastball | 1,731,517 |
| SL | Slider | Breaking | 748,263 |
| CH | Changeup | Offspeed | 480,861 |
| CU | Curveball | Breaking | 450,065 |
| FT | Two-Seam/Sinker | Fastball | 394,275 |
| FC | Cutter | Breaking | 286,601 |
| FS | Splitter | Offspeed | 66,996 |
| KN | Knuckleball | Offspeed | 2,219 |
| SI | Sinker | Fastball | 46 |
| SC | Screwball | Offspeed | 39 |
| OT | Other | Uncategorized | 6 |
| NULL | Unknown | - | 683,167 |

---

## 5. Pitch Result Codes

From Astros.LK_Pitch_Results (31 total codes).

### Complete Pitch Result Table

| ID | Result | Is Strike? | Is Whiff? |
|----|--------|-----------|-----------|
| 1 | (empty) | No | No |
| 2 | automatic_ball | No | No |
| 3 | automatic_strike | Yes | No |
| 4 | ball | No | No |
| 5 | blocked_ball | No | No |
| 6 | called_strike | Yes | No |
| 7 | foul | Yes | No |
| 8 | foul_bunt | Yes | No |
| 9 | foul_pitchout | Yes | No |
| 10 | foul_tip | Yes | **Yes** |
| 11 | hit_by_pitch | No | No |
| 12 | hit_into_play | Yes | No |
| 13 | hit_into_play_no_out | Yes | No |
| 14 | hit_into_play_score | Yes | No |
| 15 | intent_ball | No | No |
| 16 | missed_bunt | Yes | No |
| 17 | pitchout | No | No |
| 18-20 | pitchout_hit_into_play | Yes | No |
| 21 | swinging_pitchout | Yes | **Yes** |
| 22 | swinging_strike | Yes | **Yes** |
| 23 | swinging_strike_blocked | Yes | **Yes** |
| 24 | automatic_strike variant | Yes | No |
| 25 | bunt_foul_tip | Yes | No |
| 26-29 | automatic_ball variants | No | No |
| 30-31 | automatic_strike variants | Yes | No |

### Key Groupings

```sql
-- Whiff (swinging miss): pitch_result_id IN (10, 21, 22, 23)
-- NOTE: 16 (foul tip from missed bunt) is NOT a whiff -- foul tip IS contact

-- Called Strike: pitch_result_id IN (6, 3, 24, 30, 31)

-- CSW (Called Strike + Whiff): pitch_result_id IN (6, 3, 24, 30, 31, 10, 21, 22, 23)

-- Ball in Play (BIP): pitch_result_id IN (12, 13, 14)

-- All Balls (non-strikes): pitch_result_id IN (1, 2, 4, 5, 11, 15, 17, 26, 27, 28, 29)

-- Contact (swings that made contact):
-- did_swing = 1 AND pitch_result_id NOT IN (10, 21, 22, 23)
```

---

## 6. ID Mapping

| ID | Location | Usage |
|----|----------|-------|
| groundcontrol_id | Astros.Players | **Primary Astros ID.** Equals batter_id and pitcher_id in Pitches_View |
| mlbam_id | Astros.Players | Maps to player_id in ALL MLBAM tables |
| ebis_id | Astros.Players, MLB_eBis.PP_MASTER | eBis roster system ID |
| sched_id | Astros.Schedule_View | Unique per game (Astros side) |
| game_pk | MLBAM tables | Unique per game (MLBAM side); links via Schedule_View.game_pk |
| pitch_id | Astros.Pitches_View | Unique pitch within a game |
| cur_event_id | Astros.Pitches_View | Links to Events_View.event_id |
| ab_event_id | Astros.Pitches_View | PA identifier (equals next_event_id most of the time) |

### Player ID Cross-Reference

```
Astros.Players.groundcontrol_id  =  Astros.Pitches_View.batter_id / pitcher_id
Astros.Players.mlbam_id          =  MLBAM.*.player_id (all MLBAM tables)
Astros.Players.ebis_id           =  MLB_eBis.PP_MASTER.ebis_id
MLBAM.Players.player_id          =  MLBAM.*.batter_id / pitcher_id
MLBAM.Players.ebis_id (last col) =  Astros.Players.ebis_id (useful for joining!)
```

### MLBAM.Players Key Columns

| Column | Description |
|--------|-------------|
| player_id | MLBAM player ID (= mlbam_id in Astros.Players) |
| name_last | Last name |
| name_first | First name |
| birth_date | Date of birth |
| bats | Batting hand (R/L/S) |
| throws | Throwing hand (R/L) |
| ebis_id | eBis ID (last column, useful for cross-referencing) |

### Joining Astros to MLBAM via ebis_id

When Astros.Players.mlbam_id is NULL, use ebis_id as fallback:
```sql
SELECT ap.groundcontrol_id, ap.first_name, ap.last_name, mp.player_id AS mlbam_id
FROM Astros.Players ap
JOIN MLBAM.Players mp ON ap.ebis_id = mp.ebis_id
WHERE ap.mlbam_id IS NULL
```

---

## 7. Key Join Patterns

### Astros pitch to event (PA outcomes)
```sql
SELECT ...
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Events_View ev
  ON pv.sched_id = ev.sched_id
  AND ev.event_id = pv.cur_event_id
```

### Astros pitch to hits (batted balls)
```sql
SELECT ...
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Hits h
  ON pv.sched_id = h.sched_id
  AND pv.pitch_id = h.pitch_id
  AND pv.pitch_result_id IN (12, 13, 14)  -- Ball in play only
```

### Astros pitch to schedule
```sql
SELECT ...
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Schedule_View sv
  ON pv.sched_id = sv.sched_id
```

### Astros pitch to bat tracking
```sql
SELECT ...
FROM Astros.Pitches_View pv
LEFT JOIN Astros.Bat_Tracking_Metrics btm
  ON pv.sched_id = btm.sched_id
  AND pv.pitch_id = btm.pitch_id
```

### Astros player to MLBAM (for league-wide data)
```sql
SELECT ...
FROM Astros.Players p
JOIN MLBAM.SplitsBat sb
  ON p.mlbam_id = sb.player_id
```

### Astros schedule to MLBAM schedule
```sql
SELECT ...
FROM Astros.Schedule_View sv
JOIN MLBAM.Schedule ms
  ON sv.game_pk = ms.GAME_PK
```

### MLBAM Pitch_fx to Schedule (for level filtering)
```sql
SELECT ...
FROM MLBAM.Pitch_fx pf
JOIN MLBAM.Schedule ms
  ON pf.game_pk = ms.GAME_PK
WHERE ms.SPORT = 'aaa'  -- filter by level
```

### Adding wOBA linear weights
```sql
LEFT JOIN MLBAM.Schedule MlbamSchedule
  ON Schedule.mlbam_game_pk = MlbamSchedule.game_pk
LEFT JOIN Guts.woba_lwts Woba
  ON MlbamSchedule.year = Woba.year
  AND MlbamSchedule.league = Woba.league
```

### Standard Hitting Query (full pattern)
```sql
FROM Astros.Pitches_View Pitches
LEFT JOIN Astros.Schedule_View Schedule
  ON Pitches.sched_id = Schedule.sched_id
LEFT JOIN Astros.Events_View CurEvents
  ON Pitches.sched_id = CurEvents.sched_id
  AND Pitches.cur_event_id = CurEvents.event_id
LEFT JOIN Astros.Hits h
  ON Pitches.sched_id = h.sched_id
  AND Pitches.pitch_id = h.pitch_id
  AND Pitches.pitch_result_id IN (12, 13, 14)
LEFT JOIN Astros.Players p
  ON p.groundcontrol_id = Pitches.batter_id
```

### Standard Pitching Query (full pattern)
```sql
FROM Astros.Pitches_View Pitches
LEFT JOIN Astros.Schedule_View Schedule
  ON Pitches.sched_id = Schedule.sched_id
LEFT JOIN Astros.Events_View e
  ON e.sched_id = Pitches.sched_id
  AND e.event_id = Pitches.cur_event_id
  AND e.pa = 1
LEFT JOIN Astros.Players pr
  ON pr.groundcontrol_id = Pitches.pitcher_id
LEFT JOIN Astros.Hits h
  ON h.sched_id = Pitches.sched_id
  AND h.pitch_id = Pitches.pitch_id
  AND Pitches.pitch_result_id IN (12, 13, 14)
```

### Defense Query Pattern
```sql
FROM Astros.Events_View CurEvents
LEFT JOIN Astros.Players_Games PlayersGames
  ON CurEvents.sched_id = PlayersGames.sched_id
  AND PlayersGames.pos_id <> 0
LEFT JOIN Astros.Defense_Combined_By_Pos OutProbs
  ON CurEvents.sched_id = OutProbs.sched_id
  AND CurEvents.event_id = OutProbs.event_id
  AND PlayersGames.pos_id = OutProbs.pos_id
LEFT JOIN Astros.Tracking_Defensive_Metrics DefensiveMetrics
  ON CurEvents.sched_id = DefensiveMetrics.sched_id
  AND CurEvents.event_id = DefensiveMetrics.event_id
```

### Known Broken Join
```sql
-- MLBAM.Hits CANNOT join to MLBAM.Pitch_fx
-- sv_pitch_id is NULL in Pitch_fx
-- For league-wide batted ball data, use Astros.Hits or find alternate MLBAM join path
```

---

## 8. Bat Speed Calculation

Source: Adam Brodie (RnD).

### Peak bat speed (sweet spot at interpolated peak)
```sql
-- Result in MPH
SQRT(
  POWER(btm.vx_true_peak, 2) +
  POWER(btm.vy_true_peak, 2) +
  POWER(btm.vz_true_peak, 2)
) * 0.681818
```

### Bat speed at contact
```sql
-- From GroundControlTracking.tracking.Swing_Contact_Values
-- Result in MPH
SQRT(
  POWER(sc.batvx_con, 2) +
  POWER(sc.batvy_con, 2) +
  POWER(sc.batvz_con, 2)
) * 0.681818
```

**Key notes:**
- v_true_peak is stored in FPS; multiply by 0.682 to convert to MPH
- This is peak swing speed (sweet spot at interpolated peak), NOT Statcast's "speed of sweet spot at contact"
- Astros-only metric -- no MLBAM equivalent for bat speed

---

## 9. Important Production Filters

### Standard pitch filters
```sql
WHERE pv.pitch_id > 0
-- NEVER filter on ignore_flag. SELECT it as a column for swing recovery.
-- When ignore_flag=1: did_swing=NULL but pitch_result_id IS populated.
-- Swing recovery: (pv.did_swing = 1 OR (pv.ignore_flag = 1 AND pv.did_swing IS NULL
--   AND pv.pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
```

### Batted ball filters (exclude bunts, cap EV)
```sql
AND h.hit_trajectory_id NOT IN (2, 3, 4)  -- exclude bunts
AND h.hit_exit_speed < 125                  -- cap extreme values
```

### Bunt exclusion (alternative form)
```sql
AND (h.hit_trajectory_id NOT IN (2, 3, 4) OR h.hit_trajectory_id IS NULL)
```

### Negative launch angle filter (low levels only)
```sql
AND NOT (h.hit_vertical_angle < -25 AND sv.level_code IN ('hsb', 'sum', 'bbc'))
```

### Game type filter (production)
```sql
-- Exclude unofficial game types
AND sv.sched_type NOT IN ('P', 'E', 'I', 'B', 'V')
```

### Bit column casting (Events_View)
```sql
-- MUST cast bit columns to int before aggregating
SUM(CAST(ev.so AS int)) AS strikeouts,
SUM(CAST(ev.bb AS int)) AS walks,
SUM(CAST(ev.pa AS int)) AS plate_appearances
```

### did_swing type difference
```sql
-- Astros: did_swing is int (0/1)
WHERE pv.did_swing = 1

-- MLBAM: did_swing is varchar ('Y'/'N')
WHERE pf.did_swing = 'Y'
```

---

## 10. Schedule Types

| sched_type | Description | Include in Stats? |
|---|---|---|
| A | All-Star Game | TBD |
| C | AAA Championship | Yes |
| D | Division Series | Yes |
| E | Exhibition | No |
| F | Wild Card Game | Yes |
| I | Intersquad | No |
| L | League Championship Series | Yes |
| R | Regular Season | Yes |
| S | Spring Training | Yes (goals start here) |
| W | World Series | Yes |
| B | Bullpen Session | No (separate analysis) |
| P | Batting Practice | No (separate analysis) |
| U | Summer Camp | TBD |
| V | Live BP | No (separate analysis) |

---

## 11. Metric Formulas

### DAMAGE (Astros Internal Hit Quality Metric)

Directionality: Higher = better for hitters, worse for pitchers.

```sql
Damage = AVG(
  CASE WHEN hit_exit_speed IS NOT NULL THEN
    1.6 * POWER(1.3,
      COS(-0.34) * (hit_exit_speed - 98.0)
      - SIN(-0.34) * (hit_vertical_angle - 27.0)
      - 0.02 * POWER(
          2 + SIN(-0.34) * (hit_exit_speed - 98.0)
          + COS(-0.34) * (hit_vertical_angle - 27.0), 2
        )
    ) / (
      7.0 + POWER(1.3,
        COS(-0.34) * (hit_exit_speed - 98.0)
        - SIN(-0.34) * (hit_vertical_angle - 27.0)
        - 0.02 * POWER(
            2 + SIN(-0.34) * (hit_exit_speed - 98.0)
            + COS(-0.34) * (hit_vertical_angle - 27.0), 2
          )
      )
    )
  ELSE NULL END
)
```

Python implementation:
```python
import numpy as np

def calculate_damage(ev, la):
    if ev is None or la is None:
        return None
    exp_term = (
        np.cos(-0.34) * (ev - 98.0)
        - np.sin(-0.34) * (la - 27.0)
        - 0.02 * (2 + np.sin(-0.34) * (ev - 98.0)
                   + np.cos(-0.34) * (la - 27.0))**2
    )
    return 1.6 * (1.3 ** exp_term) / (7.0 + 1.3 ** exp_term)
```

Required columns: `Astros.Hits.hit_exit_speed`, `Astros.Hits.hit_vertical_angle`

---

### BARREL (MLB Definition)

```sql
Barrel = CASE WHEN
  hit_exit_speed * 1.5 - hit_vertical_angle >= 116.5
  AND (hit_exit_speed + hit_vertical_angle) >= 123.5
  AND hit_exit_speed >= 97.5
  AND hit_vertical_angle > 4.5
  AND hit_vertical_angle < 49.5
THEN 1 ELSE 0 END
```

Stricter variant (from Player Hitting Tracking):
```sql
hit_exit_speed * 1.5 - hit_vertical_angle >= 117.0
AND (hit_exit_speed + hit_vertical_angle) >= 124.0
AND hit_exit_speed >= 98.0
AND hit_vertical_angle > 4.0
AND hit_vertical_angle < 50.0
```

---

### pBARREL (Astros Custom - Parabolic Barrel)

```sql
pBarrel = CASE WHEN
  hit_exit_speed >= 0.011 * POWER(hit_vertical_angle, 2)
                 - 0.91 * hit_vertical_angle
                 + 95.0
THEN 1 ELSE 0 END
```

---

### TOP 50th AVG EXIT VELO

```sql
-- First calculate the 50th percentile for the player
HitExitVelo50th = PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hit_exit_speed)

-- Then average only the hits above that threshold
Top50thAvgEV = AVG(
  CASE WHEN hit_exit_speed >= HitExitVelo50th
  THEN hit_exit_speed
  ELSE NULL END
)
```

---

### Whiff%

```sql
Whiff% = SUM(CASE WHEN pitch_result_id IN (10, 21, 22, 23) THEN 1.0 ELSE 0.0 END)
       / NULLIF(SUM(CAST(did_swing AS FLOAT)), 0)
```

---

### Strike%

```sql
Strike% = AVG(CASE WHEN pitch_result_id NOT IN (1, 2, 4, 5, 11, 15, 17, 26, 27, 28, 29)
              THEN 1.0 ELSE 0.0 END)
```

---

### FPS% (First Pitch Strike)

```sql
FPS% = AVG(CASE WHEN ab_pitch_number = 1
                 AND pitch_result_id NOT IN (1, 2, 4, 5, 11, 15, 17, 26, 27, 28, 29)
           THEN 1.0 ELSE 0.0 END)
```

---

### Swing Rate Metrics (Weighted vs Binary)

**Important:** OSw% and Chase% are DIFFERENT metrics.

| Metric | Formula | Type | Description |
|--------|---------|------|-------------|
| OSw% | `SUM(swing * (1-csc)) / SUM(1-csc)` | Weighted | Every pitch contributes by how far out of zone |
| Chase% | `swings / pitches WHERE csc < 0.01` | Binary | Only extreme chase zone pitches |
| ZSw% | `SUM(swing * csc) / SUM(csc)` | Weighted | Every pitch contributes by how in-zone |

```sql
-- ZSw% (In-Zone Swing Rate - WEIGHTED)
ZSw = SUM(CASE WHEN did_swing = 1 THEN called_strike_chance_mlb ELSE NULL END)
    / NULLIF(SUM(called_strike_chance_mlb), 0)

-- OSw% (Out-Zone Swing Rate - WEIGHTED)
OSw = SUM(CASE WHEN did_swing = 1 THEN 1.0 - called_strike_chance_mlb ELSE NULL END)
    / NULLIF(SUM(1.0 - called_strike_chance_mlb), 0)

-- Chase% (BINARY threshold)
Chase = AVG(CASE WHEN called_strike_chance_mlb < 0.01
            THEN CASE WHEN did_swing = 1 THEN 1.0 ELSE 0.0 END END)

-- ZContact% (In-Zone Contact - WEIGHTED)
ZContact = SUM(CASE WHEN did_swing = 1 AND pitch_result_id NOT IN (10,21,22,23)
               THEN called_strike_chance_mlb ELSE NULL END)
         / NULLIF(SUM(CASE WHEN did_swing = 1 THEN called_strike_chance_mlb ELSE NULL END), 0)

-- OContact% (Out-Zone Contact - WEIGHTED)
OContact = SUM(CASE WHEN did_swing = 1 AND pitch_result_id NOT IN (10,21,22,23)
               THEN 1.0 - called_strike_chance_mlb ELSE NULL END)
         / NULLIF(SUM(CASE WHEN did_swing = 1 THEN 1.0 - called_strike_chance_mlb ELSE NULL END), 0)

-- ZWhiff% (In-Zone Whiff - WEIGHTED)
ZWhiff = SUM(CASE WHEN did_swing = 1
             THEN CASE WHEN pitch_result_id IN (10,21,22,23) THEN called_strike_chance_mlb ELSE 0 END
             ELSE NULL END)
       / NULLIF(SUM(CASE WHEN did_swing = 1 THEN called_strike_chance_mlb ELSE NULL END), 0)
```

---

### gcPerformanceGrade (Astros Custom 20-80)

```sql
gcPerformanceGrade = 50.0 - 1500.0 * AVG(
    CASE
        WHEN pitch_result_id IN (10, 22, 23) THEN
            CASE WHEN swing_zone IN ('heart', 'meatball') THEN -0.10 ELSE -0.08 END
        WHEN pitch_result_id IN (6) THEN -0.02
        WHEN pitch_result_id IN (4, 5, 11) THEN +0.02
        WHEN pitch_result_id IN (12, 13, 14) THEN
            CASE WHEN hit_exit_speed >= 0.011 * POWER(hit_vertical_angle, 2)
                                             - 0.91 * hit_vertical_angle + 95.0
                 THEN +0.09   -- pBarrel = bad for pitcher
                 ELSE -0.02   -- weak contact = good for pitcher
            END
        ELSE 0.0
    END
)
```

Scale: 20-80 where 50 = average. Higher = better pitcher performance.

---

### Swing Decision (SwDec) - 3 Variants

| Variant | Column | Table | Description |
|---------|--------|-------|-------------|
| Grade | swing_decision | Projections_Pitches_Grades | Most predictive (projection model) |
| Component | swing_decision_grade_2080 | Pitches_View | Includes count and location context |
| ABS Component | swing_decision_abs_grade_2080 | Pitches_View | Uses Automated Ball-Strike zone |

---

### Pitch Quality Metrics

| Metric | Column | Table |
|--------|--------|-------|
| StuffVel | stuffvel_grade_2080 | Astros.Pitches_Grades |
| StuffRelVel | stuffrelvel_grade_2080 | Astros.Pitches_Grades |
| All (StuffRelVel+Loc) | stuffrelvelloc_grade_2080 | Astros.Pitches_Grades |
| Component | component_grade_2080 | Astros.Pitches_Grades |
| Grade (fb_grade) | fb_grade | Astros.Projections_Pitches_Grades |
| Exp Whiff% | pg_whiff_swing | Astros.Projections_Pitches_Grades |
| ProjLoc | fb_grade - stuffrelvel_grade_2080 | Calculated |

---

### Pitch Movement

```sql
-- FF Hop (Fastball Induced Vertical Break)
FF_Hop = AVG(CASE WHEN pitch_type = 'FF' THEN inducedvertbreak END)

-- Horizontal Movement
HorzBreak = AVG(horzbreak)

-- Break Magnitude
BreakMagnitude = AVG(SQRT(POWER(horzbreak, 2) + POWER(inducedvertbreak, 2)))
```

---

## 12. Roster and Position Codes

### Roster Status (from MLB_eBis.PP_MASTER)

| Code | Description | Include in Goals? |
|------|-------------|-------------------|
| ACT | Active | Yes |
| VOL | Voluntary (leave) | Yes |
| RES | Restricted | Yes |
| DIS | Disqualified | Yes |
| PAC | Pending Active | Yes |
| FA | Free Agent | No |
| REL | Released | No |

### Pitcher Positions (Normalize to RHP/LHP for goals)

| Code | Description | Normalized |
|------|-------------|------------|
| RHS | Right-Handed Starter | RHP |
| RHR | Right-Handed Reliever | RHP |
| LHS | Left-Handed Starter | LHP |
| LHR | Left-Handed Reliever | LHP |

### Position Players

| Code | Description | Category |
|------|-------------|----------|
| C | Catcher | C |
| 1B | First Base | INF |
| 2B | Second Base | INF |
| 3B | Third Base | INF |
| SS | Shortstop | INF |
| IF | Infield (utility) | INF |
| LF | Left Field | OF |
| CF | Center Field | OF |
| RF | Right Field | OF |
| OF | Outfield (utility) | OF |

---

## 13. Zone System and Swing Zones

### swing_zone Column (Categorical Zones in Astros.Pitches_View)

| Zone | % of Strike Zone | Description |
|------|------------------|-------------|
| meatball | Inner ~33% | Dead center, easiest pitch to hit |
| heart | 33-67% | Inner zone, very hittable |
| shadow | 67-133% | Straddles the zone edge (100% = edge) |
| chase | 133-200% | Outside zone, batter might chase |
| waste | >200% | Way outside, intentional ball |

```
                    +---------------------+
                    |       WASTE         |  > 200%
                    |  +---------------+  |
                    |  |    CHASE      |  |  133-200%
                    |  |  +---------+  |  |
                    |  |  | SHADOW  |  |  |  67-133%  <-- Zone edge (100%) sits HERE
                    |  |  | +-----+ |  |  |
                    |  |  | |HEART| |  |  |  33-67%
                    |  |  | | ... | |  |  |
                    |  |  | |MEAT | |  |  |  0-33% (meatball)
                    |  |  | +-----+ |  |  |
                    |  |  +---------+  |  |
                    |  +---------------+  |
                    +---------------------+
```

### Zone System Options

| System | Column | Values | Use Case |
|--------|--------|--------|----------|
| Probability (CSC) | called_strike_chance_mlb | 0.0 - 1.0 | Weighted calculations, modern approach |
| swing_zone | swing_zone | 'heart', 'meatball', 'shadow', 'chase', 'waste' | Categorical zone labels |
| MLBAM Binary | in_zone | 'Y' / 'N' | Legacy binary approach |

### CSC Thresholds

- `< 0.01` = Out of zone (chase territory)
- `>= 0.50` = In zone
- `>= 0.95` = Middle-middle (meatball territory)

---

## 14. Quick Reference

### Streamlit App URLs (when running locally)
- **Local URL:** `http://localhost:8501`
- **Network URL:** `http://10.223.1.115:8501` (share on same WiFi/network)
- **External URL:** `http://50.225.198.211:8501` (may need firewall)

### Player Photo URLs
```python
# From Alvaro's R code - use mlbam_id
if roster_status == 'ACT':
    url = f"https://img.mlbstatic.com/mlb-photos/image/upload/c_fill,g_auto/w_180/v1/people/{mlbam_id}/headshot/milb/current"
else:
    url = f"https://securea.mlb.com/mlb/images/players/head_shot/{mlbam_id}.jpg"
```

### Metric Directionality Quick Reference

| Metric | Higher is better for... |
|--------|------------------------|
| Damage | Hitters |
| Barrel%, pBarrel% | Hitters |
| K% (strikeout rate) | Pitchers |
| BB% (walk rate) | Hitters |
| OSw% / Chase% | Pitchers |
| ZSw% | Hitters (context-dependent for pitchers) |
| ZWhiff% | Pitchers |
| ZContact% | Hitters |
| Whiff% | Pitchers |
| SwDec | Hitters |
| StuffVel / StuffRelVel | Pitchers |
| gcPerformanceGrade | Pitchers |
| EV (exit velocity) | Hitters |
| FF Hop (iVB) | Pitchers |

### GC2 Query Reference Files

| File | Purpose |
|------|---------|
| gc2_query_pitcher_tracking.sql | Pitcher performance by level/year/pitch type |
| gc2_query_pitch_grades.sql | Pitch grades and projections by bat side/pitch type |
| gc2_query_pitch_attributes.sql | Pitch physical shape by pitch type |
| alvaro_roster_queries.sql | Player selection with photos |

---

## 15. Future Reference Tables

| Table | Purpose | Notes |
|-------|---------|-------|
| Astros.Video_Network | Video URLs | video_url, sched_id, pitch_id, angle ('a'=main, 's'=RHH high speed, 't'=LHH high speed) |
| Astros.LK_Video_Angles_Char | Video angle identifiers | Unreliable in minors per Adam Brodie |
| GroundControlTracking.tracking.swing_shapes | GCZ swing shape data | loft, tilt, curvature at various points |
| Astros.OF_Ability_Metrics | Outfield defense | Joins via Pitches_View / Schedule_View |
| Astros.INF_Ability_Metrics | Infield defense | Joins via Pitches_View / Schedule_View |
| Astros.Hits_Probabilities | Expected stats | xBA, xSLG, xwOBA |
| Astros.Players_Games | Per-game player data | |
| Astros.Defense_Combined_By_Pos | Defensive metrics by position | |
| Astros.Tracking_Defensive_Metrics | Advanced defensive tracking | |

---

### Notes for Future Development

1. **Views vs Base Tables:** The `_View` versions (Pitches_View, Events_View, Schedule_View) have more computed columns and are preferred for queries.

2. **Goals Time Period:** Goals start in Spring Training (`sched_type = 'S'`) and track through Regular Season (`sched_type = 'R'`).

3. **Pro Levels Filter:** Use `is_pro_level_and_winter = 1` or check `sched_type` for regular season games.

4. **called_strike_chance_mlb:** Probability of a called strike. Defines zones: `< 0.01` = chase, `> 0.5` = in zone.

---

*Houston Astros Baseball Operations -- GroundControl2 Database Reference*
