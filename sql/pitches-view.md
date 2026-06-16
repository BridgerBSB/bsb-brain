---
type: reference
domain: data
tags:
  - sql
  - groundcontrol2
  - table
---
# Astros.Pitches_View

One row **per pitch** — the central Astros table. Combines tracking + grades + swing decision + zone. Part of [[MOC-groundcontrol-schema]].

## Join keys
- `sched_id` + `pitch_id` — unique pitch within a game
- `batter_id` / `pitcher_id` = `groundcontrol_id` ([[Astros.Players]])
- `cur_event_id` → [[events-view]] `.event_id` (the PA-ending event)
- `ab_event_id` = PA identifier (≈ `next_event_id`)
- `sched_id` → [[schedule-view]]; `sched_id`+`pitch_id` → [[hits-table]] (BIP only)

## Gotchas
- **Prefer the `_View`** over base `Pitches` — more computed columns.
- `did_swing` is **int 0/1** here; in `MLBAM.Pitch_fx` it's **varchar `'Y'`/`'N'`**.
- **NEVER filter `ignore_flag`** — it includes legit game pitches (e.g. position players pitching). Filter `pitch_id > 0` only. When `ignore_flag=1`, `did_swing` is NULL but `pitch_result_id` is populated (swing-recovery pattern).
- `called_strike_chance_mlb` (CSC) is the modern zone: `<0.01` chase, `≥0.5` in-zone, `≥0.95` meatball. Feeds weighted swing metrics.
- Whiff codes: `pitch_result_id IN (10,21,22,23)`; BIP: `IN (12,13,14)`.

See [[db-columns]] and [[db-joins]] for full column/join detail.
