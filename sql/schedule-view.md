---
type: reference
domain: data
tags:
  - sql
  - groundcontrol2
  - table
---
# Astros.Schedule_View

One row **per game** — date, level, game type, year. The scoping table for nearly every query. Part of [[MOC-groundcontrol-schema]].

## Join keys
- `sched_id` — primary key (Astros side), joins [[pitches-view]] / [[events-view]] / [[hits-table]]
- `game_pk` → `MLBAM.Schedule.GAME_PK` (bridge to league-wide data + `LEAGUE` for [[woba]] weights)

## Key columns
- `level_code` — `mlb`/`aaa`/`aax`/`afa`/`afx`/`rok`/`dsl` (see [[level-codes]])
- `sched_type` — `R` regular, `S` spring, plus practice codes
- `year`, `sched_date`, `venue_id`

## Gotchas
- **No `gameday_number`** (doubleheader indicator) — that lives in `MLBAM.Schedule`.
- Production game-type filter: `sched_type NOT IN ('P','E','I','B','V')` (excludes BP / exhibition / intrasquad / bullpen / live BP).
- Goals window: spring (`S`) through regular season (`R`).
- DSL/FCL splitting uses `gc2_level_code`, not `sv.league` — see [[level-codes]].
