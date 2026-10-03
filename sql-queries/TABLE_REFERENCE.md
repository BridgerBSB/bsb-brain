# GroundControl2 Table Reference

> Auto-generated from database exploration on 2026-01-25
> Server: gcsql02, Database: GroundControl2

---

## � Core Tables (Used in sql-queries)

These are the primary tables referenced in existing SQL queries:

| Schema | Table | Purpose |
|--------|-------|---------|
| Astros | Events / Events_View | Plate appearance outcomes (K, BB, hits) |
| Astros | Hits | Batted ball data (EV, LA for Damage) |
| Astros | Pitches / Pitches_View | Pitch-level data (velo, movement) |
| Astros | Players | Player info & ID mapping |
| Astros | Schedule / Schedule_View | Game schedule & level info |
| MLBAM | Hits | MLB batted ball data |
| MLBAM | Players | MLB player info |
| MLBAM | Schedule | MLB game schedule |
| MLBAM | Rosters | Team roster info |

---

## 👤 Player Lookup

### Astros.Players
Player information linking GroundControl IDs to other systems.

Key columns:
- `groundcontrol_id` - Primary player ID
- `mlbam_id` - MLB Advanced Media ID
- `first_name`, `last_name` - Player name
- `throws`, `bats` - Handedness

---

## ⚾ Hitting Metrics

### Astros.Hits
Batted ball data for calculating Damage, EV metrics.

| Column | Type | Metric |
|--------|------|--------|
| `sched_id` | int | Game ID |
| `pitch_id` | smallint | Pitch sequence |
| `hit_exit_speed` | float | **Exit Velocity (EV)** |
| `hit_vertical_angle` | float | **Launch Angle (LA)** |
| `hit_horizontal_angle` | float | Spray angle |
| `hit_distance` | float | Hit distance |
| `hit_hangtime` | float | Hang time |

**Damage Formula** (from Daily Swing Tracking.sql):
```sql
CASE WHEN (1.6 * POWER(1.3, COS(-.34) * (EV - 98) - SIN(-.34) * (LA - 27) - ...) / 7.0 + ...) > 0.5 
THEN 1 ELSE 0 END as Damage
```

### MLBAM.Hitter_Swing_Type_Breakdown
Swing decision metrics by zone, pitch type, count.

| Column | Type | Description |
|--------|------|-------------|
| `player_id` | int | MLBAM player ID |
| `pitch_type` | varchar | Pitch type |
| `in_zone` | varchar | 'Y' = zone, 'N' = chase |
| `throws` | varchar | Pitcher handedness |
| `count` | varchar | Count situation |
| `pitches` | int | Total pitches |
| `swings` | int | Swings taken |
| `misses` | int | Swings and misses |

**Calculated Metrics:**
- **OSw% (Chase)**: `swings / pitches` WHERE `in_zone = 'N'`
- **ZSw% (Zone Swing)**: `swings / pitches` WHERE `in_zone = 'Y'`
- **ZCon% (Zone Contact)**: `(swings - misses) / swings` WHERE `in_zone = 'Y'`
- **Whiff%**: `misses / swings`

---

## ⚡ Pitching Metrics

### Astros.Pitches
Pitch-level data for all trackable metrics.

Key columns for PD Goals:
| Column | Metric |
|--------|--------|
| `release_speed` | Velocity |
| `inducedvertbreak` | **FF Hop (iVB)** |
| `horzbreak` | **Horizontal Movement** |
| `pitch_type` | FF, SL, CH, CU, etc. |
| `pitcher_id` | Links to player |
| `pitcher_throws` | L or R |

**Horizontal Movement Convention:**
- RHP FF: Higher (more positive) = better
- LHP FF: Lower (more negative) = better (-20 > -15)
- Breaking balls: Opposite of fastball convention

### MLBAM.YTD_Player_Pitching_Stats
Year-to-date pitching statistics.

Key columns (likely includes):
- K%, BB%, FIP, ERA
- IP, TBF (batters faced)
- Per-game and rate stats

---

## 🛡️ Defense Metrics - Infield

### Astros.INF_Ability_Metrics
Aggregated infield ability metrics by player/season/level.

| Column | Metric | Goal Direction |
|--------|--------|----------------|
| `reaction_time_radius` | **ReactRad** | Lower is better (Decrease to .460) |
| `reaction_time_4mph` | **React** | Lower is better (Decrease to .435) |
| `top_speed` | **TopSpeed** | Higher is better (Increase to 23.6) |
| `arm_strength` | **Arm** | Higher is better (Increase to 91.4) |
| `exchange_time` | **Exch** | Lower is better |
| `useful_reaction_4mph` | **UseReact** | Lower is better |

Other columns:
- `season`, `groundcontrol_id`, `level_code` - Keys
- `n_plays`, `n_outs` - Sample size
- `acceleration_chest_down`, `acceleration_chest_up` - Acceleration metrics
- `hands_rate` - Soft hands metric

---

## 🏃 Defense Metrics - Outfield

### Astros.OF_Ability_Metrics
Aggregated outfield ability metrics by player/season/level.

| Column | Metric | Goal Direction |
|--------|--------|----------------|
| `reaction_time_4mph` | **React** | Lower is better (Decrease to .57) |
| `useful_reaction_4mph` | **UseReact** | Lower is better (Decrease to .737) |
| `exchange_time` | **Exch** | Lower is better (Decrease to .91) |
| `arm_strength` | **ArmOF** | Higher is better (Increase to 96) |
| `top_speed` | **TopSpeed** | Higher is better |
| `reaction_time_radius` | **ReactRad** | Lower is better |

---

## 🧤 Catcher Metrics

### Astros.CatcherDefense_Framing
Catcher framing metrics.

| Column | Type | Metric |
|--------|------|--------|
| `raa650` | float | **Frame650** - Runs Above Average per 650 pitches |
| `net_strikes_per_pitch` | float | Net strikes per pitch |
| `adj_net_strikes_per_pitch` | float | Adjusted for pitcher/ump |
| `raa` | float | Raw runs above average |
| `qualifying_pitches` | smallint | Sample size |

### Astros.CatcherDefense_Blocking
Catcher blocking metrics.

| Column | Type | Metric |
|--------|------|--------|
| `surpluss_pppp` | float | Surplus passed balls prevented? |
| `np` | int | Number of pitches |
| `pp` | smallint | Passed balls |
| `pb` | smallint | Wild pitches? |
| `r` | float | Runs value |

### Other Catcher Tables
- `Astros.CatcherDefense_Arm` - Throwing metrics
- `Astros.CatcherDefense_SBA_Metrics` - Stolen base metrics
- `Astros.CatcherDefense_Throwing` - Pop time, exchange

---

## 📊 Play-Level Tracking

### Astros.Tracking_Defensive_Metrics
Per-play defensive tracking data (raw, not aggregated).

| Column | Type | Description |
|--------|------|-------------|
| `sched_id` | int | Game ID |
| `pitch_id` | smallint | Pitch sequence |
| `tracking_play_id` | smallint | Tracking system ID |
| `pos_id` | tinyint | Position |
| `groundcontrol_id` | int | Player |
| `out_made` | bit | Out recorded |
| `competitive_play` | bit | Competitive play flag |
| `reaction_4mph` | float | Reaction time (4mph threshold) |
| `reaction_radius` | float | Reaction radius |
| `top_speed` | float | Top speed reached |
| `arm_strength` | decimal | Throw velocity |
| `exchange` | decimal | Exchange time |
| `pop_time` | decimal | Pop time (catchers) |

---

## 🔗 Common Joins

```sql
-- Goals with player names
SELECT pg.*, p.first_name, p.last_name
FROM PlayerDev.PD_Goals pg
LEFT JOIN Astros.Players p ON p.groundcontrol_id = pg.groundcontrol_id

-- Hits with pitch info
SELECT h.*, pt.pitch_type, pt.batter_id
FROM Astros.Hits h
INNER JOIN Astros.Pitches pt ON pt.sched_id = h.sched_id AND pt.pitch_id = h.pitch_id

-- Defense metrics with player
SELECT dm.*, p.first_name, p.last_name
FROM Astros.INF_Ability_Metrics dm
LEFT JOIN Astros.Players p ON p.groundcontrol_id = dm.groundcontrol_id
WHERE dm.season = 2025
```

---

## 📝 Notes

1. **ID Mapping**: `groundcontrol_id` is the primary player ID. Use `Astros.Players` to map to `mlbam_id` for MLBAM tables.

2. **Levels**: `level_code` values likely include 'MLB', 'AAA', 'AA', 'A+', 'A', 'ROK', etc.

3. **Time Filters**: Most goals are for 6-week windows. Use `date_created` from PD_Goals.

4. **Aggregation**: 
   - `INF_Ability_Metrics` and `OF_Ability_Metrics` are pre-aggregated by season/level
   - `Tracking_Defensive_Metrics` is play-level (need to aggregate)
   - `Hitter_Swing_Type_Breakdown` is pre-aggregated by player/situation
