---
type: reference
domain: data
tags:
  - sql
  - groundcontrol2
  - moc
  - schema
---
# MOC — GroundControl2 Schema

Map of the key tables in **GroundControl2** (server `gcsql02`, SQL Server / T-SQL). Astros.* = our org only; MLBAM.* = all 30 teams (used for percentile pools). See [[MOC-baseball-analytics]] for the analytics hub and [[statcast-pipeline]] for how this data is sourced.

## Schemas
- **Astros.*** — pitch-level tracking, our org only
- **MLBAM.*** — league-wide, drives [[xwoba]] / [[wrc-plus]] percentile pools
- **GroundControlTracking.Tracking.*** — HawkEye bat/ball/fielder tracking (~50% sparse at non-HawkEye MiLB venues)
- **MLB_eBis.*** — roster system (PP_MASTER)
- **Guts.*** — linear weights for [[woba]] / FIP

## Core tables + join keys

| Table | Purpose | Primary join keys |
|---|---|---|
| `Astros.Pitches_View` | One row per pitch — central table (velo, break, swing, grades, zone). See [[pitches-view]] | `sched_id`, `pitch_id`; `batter_id`/`pitcher_id` = `groundcontrol_id`; `cur_event_id` → Events |
| `Astros.Events_View` | One row per event (PA outcomes — `so`/`bb`/`pa` are **bit**). See [[events-view]] | `event_id` (= `cur_event_id`); no `batter_id` — join via Pitches_View |
| `Astros.Schedule_View` | One row per game (date, level, sched_type, year) | `sched_id`; `game_pk` → MLBAM.Schedule |
| `Astros.Hits` | One row per batted ball (EV, LA, trajectory). No `batter_id`. See [[hits-table]] | `sched_id` + `pitch_id` → Pitches_View |
| `Astros.Players` | One row per player; ID Rosetta stone | `groundcontrol_id`, `mlbam_id`, `ebis_id` |
| `GroundControlTracking.Tracking.*` | Bat speed at contact, swing shapes, fielder/runner positions (64 tables) | `sched_id` + `astros_pitch_id` via `Tracking.plays` |
| `MLB_eBis.PP_MASTER` | Daily roster, level, org, service time, draft | `PLAYER_ID` = `Astros.Players.ebis_id` |
| `Guts.woba_lwts` | Linear weights per year/level/league | `year` + `level` + `league` (per-PA, not per-level avg) |
| `MLBAM.Schedule` | League-wide games (SPORT, LEAGUE, doubleheader) | `GAME_PK` = `Schedule_View.game_pk`; `LEAGUE` → woba_lwts |
| `MLBAM.SplitsBat` / `SplitsPit` | Pre-computed platoon splits — percentile pools | `player_id` = `mlbam_id`; `sit_code` (`all`/`vl`/`vr`) |
| `MLBAM.Pitch_fx` | League-wide pitch data (`did_swing` is `'Y'`/`'N'`) | `game_pk` + `player_id`; ⚠ can't join MLBAM.Hits (NULL `sv_pitch_id`) |

## ID Rosetta stone
```
groundcontrol_id = Pitches_View.batter_id / pitcher_id   (Astros.*)
mlbam_id         = MLBAM.*.player_id                       (league-wide)
ebis_id          = PP_MASTER.PLAYER_ID                     (roster)
```

## Snapshots & deep dives
Rule snapshots: [[db-columns]] · [[db-joins]] · [[db-connection]] · [[level-codes]] · [[pitfalls]]
Metrics built on this schema: [[xwoba]] · [[woba]] · [[wrc-plus]] · [[re24-run-expectancy]] · [[stuff-plus-4s-pitching]]
Atomic table notes: [[pitches-view]] · [[events-view]] · [[hits-table]] · [[schedule-view]]
