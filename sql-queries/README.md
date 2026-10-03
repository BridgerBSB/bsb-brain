# GroundControl SQL Queries

SQL queries for the Houston Astros GroundControl2 database. These queries power player development dashboards, tracking apps, and analytical reports.

## Database Connection

| Property | Value |
|----------|-------|
| **Server** | `gcsql02` |
| **Database** | `GroundControl2` |
| **Authentication** | Windows Authentication (`BASEBALL\<username>`) |

### Python Connection Setup

See [db_connection.py](./db_connection.py) for a SQLAlchemy-based connection helper using environment variables.

```python
# Quick example
from db_connection import get_engine, run_query
import pandas as pd

df = pd.read_sql("SELECT TOP 10 * FROM astros.players", get_engine())
```

---

## Query Reference

### Player Performance Queries

| File | Description | Key Metrics |
|------|-------------|-------------|
| [Player Hitting Stats.sql](Player%20Hitting%20Stats.sql) | Comprehensive hitting statistics by season/level | BA, OBP, SLG, OPS, wOBA, wRC+, gcOBA |
| [Player Pitching Stats.sql](Player%20Pitching%20Stats.sql) | Pitcher statistics aggregated by year/level | FIP, ERA, gcERA, FIP-, K%, BB%, HR/FB |
| [Player Hitting Tracking - Top Table.sql](Player%20Hitting%20Tracking%20-%20Top%20Table.sql) | Hitting tracking dashboard (top metrics) | - |
| [Player Hitting Tracking - Bottom Table.sql](Player%20Hitting%20Tracking%20-%20Bottom%20Table.sql) | Hitting tracking dashboard (detail) | - |
| [Player Pitching Tracking - Top Table.sql](Player%20Pitching%20Tracking%20-%20Top%20Table.sql) | Pitching tracking dashboard (top metrics) | - |
| [Player Pitching Tracking - Bottom Table.sql](Player%20Pitching%20Tracking%20-%20Bottom%20Table.sql) | Pitching tracking dashboard (detail) | - |
| [Pro Player Tracking Per Player.sql](Pro%20Player%20Tracking%20Per%20Player.sql) | Individual player tracking report | - |
| [single pitcher query by year.sql](single%20pitcher%20query%20by%20year.sql) | Single pitcher season analysis | - |

### Swing & Contact Queries

| File | Description | Key Metrics |
|------|-------------|-------------|
| [Daily Swing Tracking.sql](Daily%20Swing%20Tracking.sql) | Daily swing mechanics breakdown | Bat Speed, Attack Angle, Contact Point, Loft, Tilt, Damage Window |
| [brl_per_ab.sql](brl_per_ab.sql) | Barrel rate per at-bat analysis | Barrels, BRL/AB, BRL/BBE, Whiff%, BRL/Whiff ratio, HR/BRL |

### Proprietary Metrics Queries

| File | Description | Key Metrics |
|------|-------------|-------------|
| [flyscore.sql](flyscore.sql) | Starting pitcher game scoring system | FlyScore, QualityStart, FlyingStart, pBRL, SO, BB, HBP |
| [pitcher_perf_by_first_p_outcome.sql](pitcher_perf_by_first_p_outcome.sql) | Pitcher performance by first-pitch count state | Stuff, gcERA, gcPG, CSW%, Chase%, wOBA |

### Projection & Value Queries

| File | Description | Key Metrics |
|------|-------------|-------------|
| [Historical RAR - Amat Population.sql](Historical%20RAR%20-%20Amat%20Population.sql) | Historical Runs Above Replacement for amateur population | RAR, WAR, Dollar/RAR, Rule 5 eligibility |
| [Promo Pressure v2.sql](Promo%20Pressure%20v2.sql) | Promotion readiness scoring | pRAR, pORP, Age percentile, PA percentile, MLE OPS |
| [first_N_ML_PA.sql](first_N_ML_PA.sql) | Performance in first N MLB plate appearances | xBA, xSLG, wOBA, ORP, Contact metrics |

### Athletic Performance Queries

| File | Description | Key Metrics |
|------|-------------|-------------|
| [2025 Class Best Speed Gates.sql](2025%20Class%20Best%20Speed%20Gates.sql) | Sprint/speed gate metrics for 2025 class | Split times, Gate totals |
| [Recent Jumps and Runs.sql](Recent%20Jumps%20and%20Runs.sql) | Force plate + speed gate data | Concentric Impulse, Vertical Velocity, CMJ metrics |

### Monitoring Queries

| File | Description | Key Metrics |
|------|-------------|-------------|
| [straw_watch.sql](straw_watch.sql) | Player monthly performance tracking | BA, OBP, SLG, OPS, ISO, K% by month |

---

## Key Tables & Views

### Astros Schema (`astros.`)

| Object | Type | Description |
|--------|------|-------------|
| `pitches_view` | View | All pitch-level data with enhanced fields |
| `events_view` | View | Plate appearance events with outcomes |
| `schedule_view` | View | Game schedule with level, type, date info |
| `players` | Table | Player master with `groundcontrol_id`, `mlbam_id`, `ebis_id` |
| `hits` | Table | Hit trajectory data (EV, LA, spray, etc.) |
| `hits_probabilities` | Table | Expected outcome probabilities for batted balls |
| `projections_pitches_grades` | Table | Pitch grades (Stuff, Location, etc.) |
| `bat_tracking_metrics` | Table | Bat speed, attack angle, swing path data |
| `video_network` | Table | Video URLs by angle ('a'=centerfield, 's'=high CF, 't'=third base) |

### MLBAM Schema (`mlbam.`)

| Object | Type | Description |
|--------|------|-------------|
| `gamelog_batting` | Table | Official game-level batting stats |
| `gamelog_pitching` | Table | Official game-level pitching stats |
| `schedule` | Table | MLB schedule with `game_pk` |
| `teams` | Table | Team info by season |
| `rosters` | Table | Active roster info |
| `pbp_postgame` | Table | Post-game info (winning/losing pitcher) |
| `ytd_team_batting_stats` | Table | League-wide batting stats for normalizing |
| `ytd_team_pitching_stats` | Table | League-wide pitching stats |

### Guts Schema (`guts.`)

| Object | Type | Description |
|--------|------|-------------|
| `woba_lwts` | Table | wOBA coefficients + FIP constant by year/league |

### Projection Schema (`proj.`)

| Object | Type | Description |
|--------|------|-------------|
| `batting` | Table | Batter projections |
| `pitching` | Table | Pitcher projections |
| `batting_mles` | Table | MLE-adjusted batting stats |

### Tracking Schema (`GroundControlTracking.tracking.`)

| Object | Type | Description |
|--------|------|-------------|
| `plays` | Table | Tracking plays linked to `astros_pitch_id` |
| `swing_shapes` | Table | Swing shape parameters (loft, tilt) |
| `swing_contact_values` | Table | Contact point metrics |
| `swing_damage_windows` | Table | Damage window calculations |
| `pitch_hit_trajectories` | Table | Hit launch metrics from tracking |

### SportsMed Schema (`sportsmed.`)

| Object | Type | Description |
|--------|------|-------------|
| `forcedeck_metrics` | Table | Force plate test results (CMJ, etc.) |
| `metrics` | Table | Speed gate and other athletic metrics |

---

## Key Formulas Implemented

### gcERA (GroundControl ERA)
```sql
(3.9 + 31.1 * HR/(HR+AO)) * pBRL_Rate + 3.5 * non_pBRL_Rate - 3.3 * K_Rate + 9.9 * BB_Rate
```
Expected run average based on pitch-level outcomes. Lower is better.

### pBarrel Definition
```sql
hit_exit_speed >= 0.011 * POWER(hit_vertical_angle, 2) - 0.91 * hit_vertical_angle + 95.0
```
Predicted barrel based on exit velocity and launch angle (parabolic threshold).

### Statcast Barrel Definition
```sql
hit_exit_speed * 1.5 - hit_vertical_angle >= 117 
AND (hit_exit_speed + hit_vertical_angle) >= 124 
AND hit_exit_speed >= 98 
AND hit_vertical_angle BETWEEN 4 AND 50
```
MLB's official barrel definition.

### FlyScore (Pitcher Start Scoring)
```sql
50.0 
+ SO * 3.0 
+ BB * -4.0 
+ HBP * -4.0 
+ pBRL * -1.5 
+ non_pBRL * 0.75
```
Game-level pitcher performance score. 60+ = "FlyingStart".

### gcOBA (GroundControl OBA)
Weights multiple outcome factors including swing counts, barrel rates, and league-adjusted OBP.

### wRC+ Calculation
```sql
100.0 * ((wOBA - lgwOBA) / wOBA_scale + runs_per_pa) / runs_per_pa
```
Runs Created Plus, scaled to 100 = league average.

---

## Common Parameters

Many queries use these variable patterns:

```sql
DECLARE @Param0 varchar(1000) = '93850'  -- groundcontrol_id
DECLARE @Param1 varchar(1000) = '0'       -- team filter (0 = all teams)
-- @Param2: Level exclusions (14=instructs, 6=DSL, 22=FCL, etc.)
```

### Schedule Types (`sched_type`)
| Code | Meaning |
|------|---------|
| `R` | Regular Season |
| `S`, `U` | Spring Training |
| `F`, `D`, `L`, `W`, `C` | Postseason |
| `P`, `E`, `I`, `A`, `V` | Unofficial/Exhibitions |
| `B` | Bullpen sessions |

### Level Codes (`level_code`)
| Code | Level |
|------|-------|
| `mlb` | Major League |
| `aaa` | Triple-A |
| `aax` | Double-A |
| `afa` | High-A |
| `afx` | Single-A |
| `rok` | Rookie |

---

## Usage Tips

1. **Always filter by year**: Most queries assume `year >= CURRENT_YEAR` or use `@year` parameter
2. **Use groundcontrol_id**: This is the primary player identifier across all Astros tables
3. **Level exclusions**: Some levels (DSL, instructs) should be excluded for clean analysis
4. **Video URLs**: Use `video_network` table with angle codes for replay access
5. **MLE adjustments**: For minor league comparisons, use `proj.batting_mles` for MLE-adjusted stats

---

## Related Resources

- See [astros-docs/](../astros-docs/) for metric definitions (gcERA, gcPerf, Glossary)
- See [tjstats-pitching/](../tjstats-pitching/) for pitcher report formatting examples
